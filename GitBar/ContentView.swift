import SwiftUI

struct ContentView: View {
    @StateObject private var projectListViewModel = ProjectListViewModel()
    @State private var showSettings = false
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with settings gear
            headerView

            Divider()

            // Main content
            NavigationSplitView {
                ProjectListView(viewModel: projectListViewModel)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
            } detail: {
                if let selectedProject = projectListViewModel.selectedProject {
                    GitStatusView(project: selectedProject)
                } else {
                    SelectProjectEmptyState()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(hasAppeared ? 1.0 : 0.95)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0), value: hasAppeared)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            hasAppeared = false
        }
    }

    private var headerView: some View {
        HStack {
            Text("GitBar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Select Project Empty State

/// Refined empty state when no project is selected
struct SelectProjectEmptyState: View {
    @State private var isAnimating = false
    @State private var showText = false
    @State private var arrowOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            // Animated folder with subtle motion
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 64, height: 64)
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                    .opacity(isAnimating ? 0.2 : 0.1)

                Image(systemName: "folder")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .opacity(isAnimating ? 0.7 : 0.5)
            }
            .frame(height: 64)

            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .offset(x: arrowOffset)

                    Text("Choose a project")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                .opacity(showText ? 1.0 : 0.0)

                Text("View git status and make commits")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .opacity(showText ? 1.0 : 0.0)
            }
        }
        .onAppear {
            // Gentle breathing animation for folder
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }

            // Arrow pointing left with subtle motion
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                arrowOffset = -3
            }

            // Text fade in
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showText = true
            }
        }
    }
}

#Preview {
    ContentView()
}
