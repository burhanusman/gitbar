import SwiftUI

/// Settings popover view with app configuration options
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Launch at Login toggle
            Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                .toggleStyle(.switch)

            Spacer()
        }
        .padding()
        .frame(width: 250, height: 120)
    }
}

#Preview {
    SettingsView()
}
