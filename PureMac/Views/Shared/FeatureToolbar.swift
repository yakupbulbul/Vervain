import SwiftUI

struct FeatureToolbar<Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let actions: () -> Actions

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title    = title
        self.subtitle = subtitle
        self.actions  = actions
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            actions()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Theme.background)
    }
}

// MARK: - Convenience initialiser (no subtitle)
extension FeatureToolbar where Actions == EmptyView {
    init(title: String) {
        self.title    = title
        self.subtitle = nil
        self.actions  = { EmptyView() }
    }
}
