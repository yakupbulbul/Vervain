import SwiftUI

/// Owns the long-lived view models of the scan-then-review modules so their
/// results survive switching between sidebar items. The view models are built
/// in `init` (not as property defaults) because their scanner closures are
/// not main-actor isolated.
@Observable
@MainActor
final class ModuleScanStore {
    let largeFiles: ModuleScanViewModel
    let duplicates: ModuleScanViewModel
    let privacy: ModuleScanViewModel

    init() {
        largeFiles = ModuleScanViewModel {
            try await LargeFilesScanner().scan(config: LargeFilesConfig.fromDefaults())
        }
        duplicates = ModuleScanViewModel {
            try await DuplicateScanner().scan()
        }
        privacy = ModuleScanViewModel {
            try await PrivacyScanner().scan()
        }
    }
}
