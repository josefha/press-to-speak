import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .font(.headline)
                Text(viewModel.statusLabel)
            }

            Text("Hold \(viewModel.activeShortcutLabel) to speak in any app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !viewModel.hasAccessibilityPermission {
                Text("Accessibility permission is required for global hotkey and paste.")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Grant Accessibility Permission") {
                    viewModel.requestAccessibilityPermissionPrompt()
                }

                Button("Refresh Permission Status") {
                    viewModel.refreshAccessibilityPermission()
                }
            }

            Button("Start Capture (manual)") {
                viewModel.startCapture()
            }

            Button("Stop + Transcribe (manual)") {
                viewModel.finishCapture()
            }

            if !viewModel.lastError.isEmpty {
                Text(viewModel.lastError)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Clear Error") {
                    viewModel.resetError()
                }
            }

            if !viewModel.lastTranscription.isEmpty {
                Text("Last transcription:")
                    .font(.headline)
                Text(viewModel.lastTranscription)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear {
            viewModel.refreshAccessibilityPermission()
        }
    }
}
