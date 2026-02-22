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

            Text("Version \(viewModel.currentAppVersionLabel)")
                .font(AppTypography.body(size: 12))
                .foregroundStyle(AppPalette.mutedText)

            if viewModel.isCheckingForUpdates {
                Text("Checking for updates...")
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.mutedText)
            } else if viewModel.isUpdateRequired {
                Text("Required update available: \(viewModel.latestVersionLabel)")
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.warning)
            } else if viewModel.isUpdateAvailable {
                Text("Update available: \(viewModel.latestVersionLabel)")
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.success)
            } else if viewModel.updateStatus != nil {
                Text("You are up to date.")
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.mutedText)
            }

            if !viewModel.updateCheckError.isEmpty {
                Text(viewModel.updateCheckError)
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(viewModel.isCheckingForUpdates ? "Checking for Updates..." : "Check for Updates") {
                viewModel.checkForUpdatesManually()
            }
            .disabled(viewModel.isCheckingForUpdates)

            if viewModel.canOpenUpdateDownload {
                Button(viewModel.isUpdateRequired ? "Download Required Update" : "Download Latest Update") {
                    viewModel.openUpdateDownloadPage()
                }
            }

            if viewModel.canOpenUpdateReleaseNotes {
                Button("View Release Notes") {
                    viewModel.openUpdateReleaseNotes()
                }
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
