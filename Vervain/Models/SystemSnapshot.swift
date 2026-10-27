import Foundation

/// Raw CPU time counters of one core, as the kernel reports them.
struct CPUTicks: Sendable, Equatable {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32
}

/// Byte counters of one network interface. The kernel keeps them in 32 bits,
/// so they wrap; deltas are taken with wrapping subtraction.
struct InterfaceCounters: Sendable, Equatable {
    var received: UInt32
    var sent: UInt32
}

struct BatteryStatus: Sendable, Equatable {
    /// 0...100
    var percent: Int
    var isCharging: Bool
    var onACPower: Bool
    var cycleCount: Int?
    /// Current full-charge capacity as a fraction of the design capacity.
    var health: Double?
    var temperatureCelsius: Double?
    var minutesRemaining: Int?
}

enum ThermalLevel: Int, Sendable, Equatable {
    case nominal, fair, serious, critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:  self = .nominal
        case .fair:     self = .fair
        case .serious:  self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}

struct ProcessCPU: Identifiable, Sendable, Equatable {
    let pid: Int32
    let name: String
    /// Percent of one core, so it can exceed 100 on a busy multi-core process.
    let cpuPercent: Double
    var id: Int32 { pid }
}

/// Everything the System Status screen shows at one instant.
struct SystemSnapshot: Sendable {
    /// Whole-machine CPU use, 0...1.
    var cpuTotal: Double
    /// Per-core CPU use, 0...1 each.
    var cpuCores: [Double]
    var loadAverage: [Double]
    var memory: MemoryUsage?
    var disk: DiskUsage?
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
    var battery: BatteryStatus?
    var thermal: ThermalLevel
    var uptime: TimeInterval
    var topProcesses: [ProcessCPU]
}
