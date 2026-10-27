import XCTest
@testable import Vervain

final class SystemStatusTests: XCTestCase {

    // MARK: CPU

    func testCPUUsageIsBusyShareOfElapsedTicks() {
        let before = [CPUTicks(user: 100, system: 100, idle: 800, nice: 0)]
        let after  = [CPUTicks(user: 150, system: 130, idle: 920, nice: 0)]
        // busy 80 of 200 elapsed ticks
        XCTAssertEqual(SystemStatusMath.cpuUsage(from: before, to: after)[0], 0.4, accuracy: 0.0001)
    }

    func testCPUUsageWithNoElapsedTicksIsZero() {
        let ticks = [CPUTicks(user: 1, system: 2, idle: 3, nice: 4)]
        XCTAssertEqual(SystemStatusMath.cpuUsage(from: ticks, to: ticks), [0])
    }

    func testCPUUsageSurvivesCounterWraparound() {
        let before = [CPUTicks(user: .max - 9, system: 0, idle: 0, nice: 0)]
        let after  = [CPUTicks(user: 10, system: 0, idle: 20, nice: 0)]
        // user advanced 20 (wrapped), idle 20
        XCTAssertEqual(SystemStatusMath.cpuUsage(from: before, to: after)[0], 0.5, accuracy: 0.0001)
    }

    // MARK: Network

    func testNetworkDeltaSumsInterfacesAndHandlesWraparound() {
        let before = ["en0": InterfaceCounters(received: .max - 99, sent: 1_000),
                      "en1": InterfaceCounters(received: 500, sent: 500)]
        let after  = ["en0": InterfaceCounters(received: 100, sent: 1_400),
                      "en1": InterfaceCounters(received: 700, sent: 500),
                      "en9": InterfaceCounters(received: 9_999, sent: 9_999)]
        let delta = SystemStatusMath.networkDelta(from: before, to: after)
        XCTAssertEqual(delta.received, 200 + 200)
        XCTAssertEqual(delta.sent, 400)
    }

    func testOnlyEthernetAndWiFiPortsCount() {
        XCTAssertTrue(SystemStatusMath.isPhysicalInterface("en0"))
        XCTAssertTrue(SystemStatusMath.isPhysicalInterface("en4"))
        for name in ["lo0", "utun3", "bridge0", "awdl0", "llw0", "anpi0", "ap1"] {
            XCTAssertFalse(SystemStatusMath.isPhysicalInterface(name), name)
        }
    }

    // MARK: Processes

    func testParsesProcessesBusiestFirstAndKeepsNamesWithSpaces() {
        let output = """
          101  2.5 /usr/sbin/cfprefsd
           42 87.3 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome Helper
            7  0.0 /sbin/launchd
        garbage line
        """
        let top = SystemStatusMath.parseProcesses(output, limit: 2)
        XCTAssertEqual(top.map(\.pid), [42, 101])
        XCTAssertEqual(top[0].name, "Google Chrome Helper")
        XCTAssertEqual(top[0].cpuPercent, 87.3, accuracy: 0.001)
    }

    // MARK: Battery

    func testBatteryFromAppleSiliconProperties() throws {
        let battery = try XCTUnwrap(SystemStatusMath.battery(from: [
            "CurrentCapacity": 80, "MaxCapacity": 100, "IsCharging": false, "ExternalConnected": true,
            "CycleCount": 1305, "DesignCapacity": 5103, "NominalChargeCapacity": 4038,
            "Temperature": 3081, "TimeRemaining": 65_535
        ]))
        XCTAssertEqual(battery.percent, 80)
        XCTAssertTrue(battery.onACPower)
        XCTAssertFalse(battery.isCharging)
        XCTAssertEqual(battery.cycleCount, 1305)
        XCTAssertEqual(try XCTUnwrap(battery.health), 4038.0 / 5103.0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(battery.temperatureCelsius), 30.81, accuracy: 0.001)
        XCTAssertNil(battery.minutesRemaining, "65535 means unknown")
    }

    func testBatteryPercentFromMilliampHoursOnOlderMacs() throws {
        let battery = try XCTUnwrap(SystemStatusMath.battery(from: [
            "CurrentCapacity": 2000, "MaxCapacity": 4000, "TimeRemaining": 95
        ]))
        XCTAssertEqual(battery.percent, 50)
        XCTAssertEqual(battery.minutesRemaining, 95)
        XCTAssertNil(battery.health)
    }

    func testNoChargeLevelMeansNoBattery() {
        XCTAssertNil(SystemStatusMath.battery(from: [:]))
    }

    // MARK: Live

    func testSamplerReturnsPlausibleValuesOnThisMachine() async throws {
        let sampler = SystemStatusSampler()
        let first = await sampler.sample()
        XCTAssertEqual(first.cpuCores.count, ProcessInfo.processInfo.processorCount)
        XCTAssertEqual(first.downloadBytesPerSecond, 0, "no rate before a second reading")
        try await Task.sleep(for: .milliseconds(300))
        let second = await sampler.sample()
        XCTAssertTrue((0...1).contains(second.cpuTotal))
        XCTAssertTrue(second.cpuCores.allSatisfy { (0...1).contains($0) })
        XCTAssertGreaterThanOrEqual(second.downloadBytesPerSecond, 0)
        XCTAssertGreaterThan(second.uptime, 0)
        XCTAssertFalse(second.topProcesses.isEmpty)
    }
}
