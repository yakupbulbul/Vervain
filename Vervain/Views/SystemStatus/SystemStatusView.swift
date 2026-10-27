import SwiftUI

struct SystemStatusView: View {
    @State private var vm = SystemStatusViewModel()

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "System Status", subtitle: "Live view of your Mac") {
                Label("Updates every 2 seconds", systemImage: "waveform.path.ecg")
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
            Divider().background(Theme.divider)
            if let snapshot = vm.snapshot {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)], alignment: .center, spacing: 16) {
                        cpuCard(snapshot)
                        memoryCard(snapshot)
                        networkCard(snapshot)
                        if let disk = snapshot.disk { diskCard(disk) }
                        if let battery = snapshot.battery { batteryCard(battery) }
                        systemCard(snapshot)
                        processesCard(snapshot)
                    }
                    .padding(24)
                }
            } else {
                ProgressView().controlSize(.large).tint(Theme.statusAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .task { await vm.run() }
    }

    // MARK: - Cards

    private func cpuCard(_ s: SystemSnapshot) -> some View {
        StatusCard(title: "CPU", icon: "cpu") {
            Text(percent(s.cpuTotal)).font(.system(size: 30, weight: .bold, design: .rounded))
            Sparkline(values: vm.cpuHistory, ceiling: 1, color: Theme.statusAccent).frame(height: 36)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(s.cpuCores.enumerated()), id: \.offset) { _, core in
                    Capsule().fill(usageColor(core))
                        .frame(height: max(3, 28 * core))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 28, alignment: .bottom)
            .accessibilityLabel(Text("Per-core usage"))
            if s.loadAverage.count == 3 {
                Text("Load average \(s.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " · "))")
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
        }
    }

    private func memoryCard(_ s: SystemSnapshot) -> some View {
        StatusCard(title: "Memory", icon: "memorychip") {
            if let memory = s.memory {
                Text(percent(memory.usedFraction)).font(.system(size: 30, weight: .bold, design: .rounded))
                UsageBar(fraction: memory.usedFraction, color: usageColor(memory.usedFraction))
                Text("\(Int64(memory.used).formattedBytes) of \(Int64(memory.total).formattedBytes) in use")
                    .font(.caption).foregroundStyle(Theme.textMuted)
            } else {
                Text("Unavailable").foregroundStyle(Theme.textMuted)
            }
        }
    }

    private func networkCard(_ s: SystemSnapshot) -> some View {
        StatusCard(title: "Network", icon: "arrow.up.arrow.down") {
            HStack(spacing: 20) {
                rate("Download", s.downloadBytesPerSecond, icon: "arrow.down")
                rate("Upload", s.uploadBytesPerSecond, icon: "arrow.up")
            }
            Sparkline(values: vm.downloadHistory, ceiling: nil, color: Theme.statusAccent).frame(height: 36)
        }
    }

    private func diskCard(_ disk: DiskUsage) -> some View {
        StatusCard(title: "Startup Disk", icon: "internaldrive") {
            Text(percent(disk.usedFraction)).font(.system(size: 30, weight: .bold, design: .rounded))
            UsageBar(fraction: disk.usedFraction, color: usageColor(disk.usedFraction))
            Text("\(disk.available.formattedBytes) available of \(disk.total.formattedBytes)")
                .font(.caption).foregroundStyle(Theme.textMuted)
        }
    }

    private func batteryCard(_ b: BatteryStatus) -> some View {
        StatusCard(title: "Battery", icon: b.isCharging ? "battery.100.bolt" : "battery.75") {
            Text("\(b.percent)%").font(.system(size: 30, weight: .bold, design: .rounded))
            UsageBar(fraction: Double(b.percent) / 100, color: b.percent <= 20 && !b.onACPower ? .red : Theme.statusAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text(powerLine(b))
                if let health = b.health { Text("Maximum capacity \(percent(health))") }
                if let cycles = b.cycleCount { Text("\(cycles) charge cycles") }
                if let temperature = b.temperatureCelsius {
                    Text("Battery temperature \(String(format: "%.1f", temperature)) °C")
                }
            }
            .font(.caption).foregroundStyle(Theme.textMuted)
        }
    }

    private func systemCard(_ s: SystemSnapshot) -> some View {
        StatusCard(title: "System", icon: "thermometer.medium") {
            HStack {
                Text("Thermal state").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(thermalText(s.thermal)).foregroundStyle(thermalColor(s.thermal)).fontWeight(.semibold)
            }
            HStack {
                Text("Uptime").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(uptimeText(s.uptime))
            }
        }
        .font(.callout)
    }

    private func processesCard(_ s: SystemSnapshot) -> some View {
        StatusCard(title: "Busiest Processes", icon: "list.number") {
            ForEach(s.topProcesses) { process in
                HStack {
                    Text(process.name).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text("\(Int(process.cpuPercent.rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(process.cpuPercent >= 80 ? Color.orange : Theme.textSecondary)
                }
                .font(.callout)
            }
        }
    }

    // MARK: - Pieces

    private func rate(_ title: LocalizedStringKey, _ bytesPerSecond: Double, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(Theme.textMuted)
            Text("\(Int64(bytesPerSecond).formattedBytes)/s")
                .font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit()
        }
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private func usageColor(_ fraction: Double) -> Color {
        fraction < 0.6 ? Theme.statusAccent : (fraction < 0.85 ? .orange : .red)
    }

    private func powerLine(_ b: BatteryStatus) -> String {
        if b.isCharging {
            return b.minutesRemaining.map { String(localized: "Charging · \(duration(minutes: $0)) to full") }
                ?? String(localized: "Charging")
        }
        if b.onACPower { return String(localized: "On AC power") }
        return b.minutesRemaining.map { String(localized: "On battery · \(duration(minutes: $0)) remaining") }
            ?? String(localized: "On battery")
    }

    private func duration(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }

    private func uptimeText(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? ""
    }

    private func thermalText(_ level: ThermalLevel) -> String {
        switch level {
        case .nominal:  return String(localized: "Normal")
        case .fair:     return String(localized: "Warm")
        case .serious:  return String(localized: "Hot")
        case .critical: return String(localized: "Critical")
        }
    }

    private func thermalColor(_ level: ThermalLevel) -> Color {
        switch level {
        case .nominal:  return Theme.statusAccent
        case .fair:     return .yellow
        case .serious:  return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Building blocks

private struct StatusCard<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.divider)
                Capsule().fill(color).frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 8)
    }
}

/// A small line graph of recent values. `ceiling` fixes the top of the scale
/// (CPU is always 0...1); nil scales to the largest value seen.
private struct Sparkline: View {
    let values: [Double]
    let ceiling: Double?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let top = max(ceiling ?? (values.max() ?? 1), 1)
            let step = values.count > 1 ? proxy.size.width / CGFloat(SystemStatusViewModel.historyLength - 1) : 0
            let offset = proxy.size.width - step * CGFloat(max(values.count - 1, 0))
            Path { path in
                for (index, value) in values.enumerated() {
                    let point = CGPoint(
                        x: offset + step * CGFloat(index),
                        y: proxy.size.height * (1 - CGFloat(min(value / top, 1)))
                    )
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
