import SwiftUI

struct SystemJunkView: View {
    @Environment(SystemJunkViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "System Junk", subtitle: "Caches, logs, language files") {
                toolbarButtons
            }

            Divider().background(Color.white.opacity(0.08))

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
    }

    // MARK: - Toolbar buttons

    @ViewBuilder
    private var toolbarButtons: some View {
        switch vm.state {
        case .scanning:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .results:
            HStack(spacing: 8) {
                Button("Select All")    { vm.selectAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.white)
                Button("Deselect All") { vm.deselectAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.white)
                Button("Re-Scan") { vm.scan() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.white)
            }
        default:
            Button("Scan") { vm.scan() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            idleView
        case .scanning:
            loadingView(message: "Scanning system files…")
        case .results, .cleaning:
            if vm.categories.isEmpty {
                ContentUnavailableView(
                    "Your Mac is Clean!",
                    systemImage: "checkmark.circle.fill",
                    description: Text("No junk files found.")
                )
                .foregroundStyle(.white)
            } else {
                resultsView
            }
        case .done(let freed):
            DoneView(freedBytes: freed, message: "Junk Cleaned Successfully") {
                vm.state = .idle
            }
        }
    }

    // MARK: - Views

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Clean System Junk")
                    .font(.title.bold())
                Text("Scan for caches, logs, language files\nand other unnecessary files.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            Button("Scan for Junk") { vm.scan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
        }
        .padding(40)
    }

    private func loadingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.orange)
            Text(message)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(vm.categories) { category in
                    JunkCategoryRow(
                        category: category,
                        isSelected: category.isSelected,
                        onToggle: { vm.toggleCategory(category.id) }
                    )
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(Color.white.opacity(0.07))
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            Divider().background(Color.white.opacity(0.08))

            // Bottom action bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.categories.filter(\.isSelected).count) categories selected")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(vm.totalSelected.formattedBytes)
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if vm.isCleaning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.orange)
                        .padding(.trailing, 8)
                }
                Button(vm.isCleaning ? "Cleaning…" : "Clean \(vm.totalSelected.compactBytes)") {
                    vm.clean()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(vm.totalSelected == 0 || vm.isCleaning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        }
    }
}
