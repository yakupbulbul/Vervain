import SwiftUI

struct AIModelsView: View {
    let vm: ModuleScanViewModel

    var body: some View {
        ModuleScanView(
            vm: vm,
            title: "AI Models",
            subtitle: "Model downloads you can fetch again",
            icon: "brain",
            accent: Theme.aiModelsAccent,
            idleHeadline: "Reclaim Model Downloads",
            idleDescription: "Looks for models from Hugging Face, LM Studio, Ollama, PyTorch, Whisper and similar tools.\nNothing is pre-selected, because downloading a model again can take a long time.",
            scanButtonTitle: "Scan for Models",
            emptyTitle: "No Models Found",
            emptyDescription: "No local AI model downloads were found.",
            reviewTitle: String(localized: "Review AI Models")
        ) {
            EmptyView()
        }
    }
}
