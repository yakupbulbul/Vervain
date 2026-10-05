import Foundation
import AppKit
import Darwin

/// Physical memory in use, read from the kernel (read-only, no shell).
struct MemoryUsage: Sendable, Equatable {
    let total: UInt64
    let used: UInt64

    var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(used) / Double(total))
    }

    /// Used = active + wired + compressed pages, like Activity Monitor's "Memory Used".
    static func current() -> MemoryUsage? {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = UInt64(getpagesize())
        let usedPages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return MemoryUsage(total: ProcessInfo.processInfo.physicalMemory, used: usedPages * page)
    }
}

/// Resident memory of running apps, for the menu bar's "top memory users".
struct AppMemory: Identifiable, Sendable {
    let pid: pid_t
    let name: String
    let bytes: UInt64
    var id: pid_t { pid }

    /// Resident size of a process the current user owns, or nil if unreadable.
    static func residentBytes(pid: pid_t) -> UInt64? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let read = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        return read == size ? info.pti_resident_size : nil
    }

    @MainActor
    static func topApps(limit: Int = 5) -> [AppMemory] {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != me }
            .compactMap { app -> AppMemory? in
                guard let bytes = residentBytes(pid: app.processIdentifier) else { return nil }
                return AppMemory(pid: app.processIdentifier,
                                 name: app.localizedName ?? "pid \(app.processIdentifier)",
                                 bytes: bytes)
            }
            .sorted { $0.bytes > $1.bytes }
            .prefix(limit)
            .map { $0 }
    }
}
