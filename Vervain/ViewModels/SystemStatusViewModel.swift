import SwiftUI

@Observable
@MainActor
final class SystemStatusViewModel {

    nonisolated static let historyLength = 60
    static let interval: Duration = .seconds(2)

    var snapshot: SystemSnapshot?
    var cpuHistory: [Double] = []
    var downloadHistory: [Double] = []
    var uploadHistory: [Double] = []

    private let sampler = SystemStatusSampler()

    /// Samples until the calling task is cancelled (the view's `.task` ends
    /// when the screen goes away, so nothing runs in the background).
    func run() async {
        while !Task.isCancelled {
            let next = await sampler.sample()
            guard !Task.isCancelled else { return }
            snapshot = next
            cpuHistory = Self.appending(next.cpuTotal, to: cpuHistory)
            downloadHistory = Self.appending(next.downloadBytesPerSecond, to: downloadHistory)
            uploadHistory = Self.appending(next.uploadBytesPerSecond, to: uploadHistory)
            try? await Task.sleep(for: Self.interval)
        }
    }

    nonisolated static func appending(_ value: Double, to history: [Double]) -> [Double] {
        Array((history + [value]).suffix(historyLength))
    }
}
