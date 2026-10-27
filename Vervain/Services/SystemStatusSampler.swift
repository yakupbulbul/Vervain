import Foundation
import Darwin
import IOKit

/// Pure calculations behind the System Status screen, kept apart from the
/// kernel calls so they can be tested with fixed numbers.
enum SystemStatusMath {

    /// Per-core use between two readings. A core with no elapsed ticks reads 0.
    static func cpuUsage(from previous: [CPUTicks], to current: [CPUTicks]) -> [Double] {
        zip(previous, current).map { before, now in
            let user = Double(now.user &- before.user)
            let system = Double(now.system &- before.system)
            let nice = Double(now.nice &- before.nice)
            let idle = Double(now.idle &- before.idle)
            let busy = user + system + nice
            let total = busy + idle
            return total > 0 ? min(1, busy / total) : 0
        }
    }

    /// Bytes moved since the last reading, summed over the given interfaces.
    static func networkDelta(
        from previous: [String: InterfaceCounters],
        to current: [String: InterfaceCounters]
    ) -> (received: UInt64, sent: UInt64) {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, now) in current {
            guard let before = previous[name] else { continue }
            received += UInt64(now.received &- before.received)
            sent += UInt64(now.sent &- before.sent)
        }
        return (received, sent)
    }

    /// Only real network ports count. Tunnels, bridges and Apple's internal
    /// links carry the same traffic again and would double it.
    static func isPhysicalInterface(_ name: String) -> Bool {
        name.hasPrefix("en") && !name.hasPrefix("ens")
    }

    /// Parses `ps -Ao pid=,pcpu=,comm=` output, busiest first.
    static func parseProcesses(_ output: String, limit: Int) -> [ProcessCPU] {
        output.split(whereSeparator: \.isNewline).compactMap { line -> ProcessCPU? in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1].replacingOccurrences(of: ",", with: ".")) else { return nil }
            let name = (String(parts[2]) as NSString).lastPathComponent
            return ProcessCPU(pid: pid, name: name, cpuPercent: cpu)
        }
        .sorted { $0.cpuPercent > $1.cpuPercent }
        .prefix(limit)
        .map { $0 }
    }

    /// Reads an `AppleSmartBattery` property dictionary. Returns nil when there
    /// is no charge level to show (desktop Macs have no battery).
    static func battery(from props: [String: Any]) -> BatteryStatus? {
        func int(_ key: String) -> Int? { (props[key] as? NSNumber)?.intValue }
        func flag(_ key: String) -> Bool { (props[key] as? NSNumber)?.boolValue ?? false }

        guard let current = int("CurrentCapacity") else { return nil }
        let maximum = int("MaxCapacity") ?? 100
        let percent = maximum > 100 ? current * 100 / maximum : current

        var health: Double?
        if let design = int("DesignCapacity"), design > 0,
           let full = int("NominalChargeCapacity") ?? int("AppleRawMaxCapacity") {
            health = min(1, max(0, Double(full) / Double(design)))
        }
        let minutes = int("TimeRemaining").flatMap { $0 > 0 && $0 < 65_535 ? $0 : nil }

        return BatteryStatus(
            percent: min(100, max(0, percent)),
            isCharging: flag("IsCharging"),
            onACPower: flag("ExternalConnected"),
            cycleCount: int("CycleCount"),
            health: health,
            temperatureCelsius: int("Temperature").map { Double($0) / 100 },
            minutesRemaining: minutes
        )
    }
}

/// Reads CPU, network, battery and process figures. Read-only: it asks the
/// kernel and IOKit, and runs `ps` for the busiest processes. Rates need two
/// readings, so the first sample after creation reports zero.
actor SystemStatusSampler {

    private var lastTicks: [CPUTicks] = []
    private var lastCounters: [String: InterfaceCounters] = [:]
    private var lastTime: Date?

    func sample() -> SystemSnapshot {
        let now = Date()
        let ticks = Self.readCPUTicks()
        let cores = lastTicks.count == ticks.count
            ? SystemStatusMath.cpuUsage(from: lastTicks, to: ticks)
            : Array(repeating: 0, count: ticks.count)
        lastTicks = ticks

        let counters = Self.readInterfaceCounters()
        var down = 0.0, up = 0.0
        if let lastTime {
            let seconds = now.timeIntervalSince(lastTime)
            if seconds > 0 {
                let delta = SystemStatusMath.networkDelta(from: lastCounters, to: counters)
                down = Double(delta.received) / seconds
                up = Double(delta.sent) / seconds
            }
        }
        lastCounters = counters
        lastTime = now

        return SystemSnapshot(
            cpuTotal: cores.isEmpty ? 0 : cores.reduce(0, +) / Double(cores.count),
            cpuCores: cores,
            loadAverage: Self.readLoadAverage(),
            memory: MemoryUsage.current(),
            disk: DiskUsage.current(),
            downloadBytesPerSecond: down,
            uploadBytesPerSecond: up,
            battery: Self.readBattery(),
            thermal: ThermalLevel(ProcessInfo.processInfo.thermalState),
            uptime: ProcessInfo.processInfo.systemUptime,
            topProcesses: Self.readTopProcesses(limit: 5)
        )
    }

    // MARK: - Kernel readings

    private static func readCPUTicks() -> [CPUTicks] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_, vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { core in
            let base = core * stride
            return CPUTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
    }

    private static func readLoadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : []
    }

    private static func readInterfaceCounters() -> [String: InterfaceCounters] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [:] }
        defer { freeifaddrs(head) }

        var result: [String: InterfaceCounters] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let name = String(cString: entry.pointee.ifa_name)
            let flags = Int32(entry.pointee.ifa_flags)
            guard SystemStatusMath.isPhysicalInterface(name),
                  flags & IFF_UP != 0,
                  let address = entry.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = entry.pointee.ifa_data else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            result[name] = InterfaceCounters(received: stats.ifi_ibytes, sent: stats.ifi_obytes)
        }
        return result
    }

    private static func readBattery() -> BatteryStatus? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any] else { return nil }
        return SystemStatusMath.battery(from: dictionary)
    }

    private static func readTopProcesses(limit: Int) -> [ProcessCPU] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Ao", "pid=,pcpu=,comm=", "-r"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return SystemStatusMath.parseProcesses(String(decoding: data, as: UTF8.self), limit: limit)
    }
}
