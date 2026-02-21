import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .font(AppTypography.bodySemibold(size: 14))
                Text(viewModel.statusLabel)
                    .font(AppTypography.body(size: 14))
            }

            Text("Hold \(viewModel.activeShortcutLabel) to speak in any app.")
                .font(AppTypography.body(size: 13))
                .foregroundStyle(AppPalette.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            if !viewModel.hasAccessibilityPermission {
                Text("Accessibility permission is required for global hotkey and paste.")
                    .font(AppTypography.body(size: 13))
                    .foregroundStyle(AppPalette.warning)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Grant Accessibility Permission") {
                    viewModel.requestAccessibilityPermissionPrompt()
                }

                Button("Refresh Permission Status") {
                    viewModel.refreshAccessibilityPermission()
                }
            }

            if viewModel.isAccountAuthenticated {
                Button("Start Capture") {
                    viewModel.startCapture()
                }

                Button("Stop + Transcribe") {
                    viewModel.finishCapture()
                }

                if !viewModel.lastError.isEmpty {
                    Text(viewModel.lastError)
                        .font(AppTypography.body(size: 13))
                        .foregroundStyle(AppPalette.error)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Clear Error") {
                        viewModel.resetError()
                    }
                }

                Button {
                    viewModel.copyLatestToClipboard()
                } label: {
                    Label("Copy Last Entry to Clipboard", systemImage: "doc.on.doc")
                }
                .disabled(!viewModel.hasLatestTranscription)
            } else {
                Button {
                    openDashboard()
                } label: {
                    Text("Login to start using")
                        .font(AppTypography.bodySemibold(size: 13))
                        .foregroundStyle(AppPalette.success)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button("Open PressToSpeak") {
                openDashboard()
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .font(AppTypography.body(size: 13))
        .frame(width: 320)
        .onAppear {
            viewModel.refreshUIStateOnOpen()
        }
    }

    private func openDashboard() {
        viewModel.refreshUIStateOnOpen()
        openWindow(id: "main-dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }
}
