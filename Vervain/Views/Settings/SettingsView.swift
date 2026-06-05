import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @State private var needsRestart = false

    var body: some View {
        Form {
            Picker("Language", selection: $appLanguage) {
                Text("System Default").tag("")
                Divider()
                Text("English").tag("en")
                Text("Français").tag("fr")
                Text("Deutsch").tag("de")
                Text("Türkçe").tag("tr")
                Text("Español").tag("es")
                Text("中文(简体)").tag("zh-Hans")
            }
            .onChange(of: appLanguage) { _, newValue in
                if newValue.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                }
                needsRestart = true
            }

            if needsRestart {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Restart Vervain to apply the new language.")
                        .font(.callout)
                    Spacer()
                    Button("Restart Now") {
                        restartApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }

    private func restartApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
}
