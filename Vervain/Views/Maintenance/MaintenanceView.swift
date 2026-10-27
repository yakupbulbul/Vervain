import SwiftUI

struct MaintenanceView: View {
    @State private var vm = MaintenanceViewModel()

    private var runnable: [MaintenanceTask] { MaintenanceTask.all.filter { $0.terminalCommand == nil } }
    private var terminalOnly: [MaintenanceTask] { MaintenanceTask.all.filter { $0.terminalCommand != nil } }

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Maintenance", subtitle: "Quick fixes for a sluggish Mac") { EmptyView() }
            Divider().background(Theme.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Quick fixes", footnote: "These run right away and need no password.") {
                        ForEach(runnable) { task in row(task) }
                    }
                    section("Needs Terminal", footnote: "These need administrator rights, so Vervain never runs them. Copy the command and paste it into Terminal.") {
                        ForEach(terminalOnly) { task in row(task) }
                    }
                    LocalSnapshotsSection()
                }
                .padding(24)
            }
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        footnote: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            VStack(spacing: 0) { content() }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            Text(footnote).font(.caption).foregroundStyle(Theme.textMuted)
        }
    }

    private func row(_ task: MaintenanceTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.icon)
                .foregroundStyle(Theme.maintenanceAccent).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.system(size: 13, weight: .medium))
                Text(task.detail).font(.caption).foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if case .failed(let message) = vm.states[task.id] {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            action(for: task)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func action(for task: MaintenanceTask) -> some View {
        if let command = task.terminalCommand {
            Button(vm.copiedCommand == command ? String(localized: "Copied") : String(localized: "Copy Command")) {
                vm.copy(command)
            }
            .buttonStyle(.bordered)
        } else {
            switch vm.states[task.id] {
            case .running:
                ProgressView().controlSize(.small)
            case .done:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.maintenanceAccent).font(.callout)
            default:
                Button("Run") { vm.run(task.id) }
                    .buttonStyle(.borderedProminent).tint(Theme.maintenanceAccent)
            }
        }
    }
}
