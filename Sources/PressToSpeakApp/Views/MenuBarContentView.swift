import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .font(.headline)
                Text(viewModel.statusLabel)
            }

            Button {
                openWindow(id: "main-dashboard")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open App", systemImage: "rectangle.on.rectangle")
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

            Button("Open Settings…") {
                openWindow(id: "main-dashboard")
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
