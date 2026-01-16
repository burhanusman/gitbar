import SwiftUI
import AppKit

/// Settings sheet view with app configuration options
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Form content
            ScrollView {
                VStack(spacing: 0) {
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GENERAL")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.launchAtLogin) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Launch at Login")
                                        .font(.system(size: 13))
                                    Text("Automatically start GitBar when you log in")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    // Updates Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("UPDATES")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.checkForUpdatesAutomatically) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Check for updates automatically")
                                        .font(.system(size: 13))
                                    Text("Get notified when new versions are available")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.leading, 20)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Check for updates")
                                        .font(.system(size: 13))
                                    if viewModel.isCheckingForUpdates {
                                        Text("Checking...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    } else if let lastCheck = viewModel.lastUpdateCheck {
                                        Text("Last checked: \(formatDate(lastCheck))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Button(action: { viewModel.checkForUpdates() }) {
                                    Text("Check Now")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "#2a2a2a"))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isCheckingForUpdates)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Version")
                                        .font(.system(size: 13))
                                    Text("GitBar \(viewModel.appVersion)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.leading, 20)

                            Button(action: { viewModel.openGitHub() }) {
                                HStack {
                                    Text("View on GitHub")
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .background(Color(hex: "#1a1a1a"))
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .frame(width: 400, height: 300)
        .background(Color(hex: "#0d0d0d"))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SettingsView()
}
