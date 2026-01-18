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
            ZStack {
                Theme.background.ignoresSafeArea()

                NavigationSplitView {
                    ProjectListView(viewModel: projectListViewModel)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                        .background(Theme.sidebarBackground)
                } detail: {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        
                        if let selectedProject = projectListViewModel.selectedProject {
                            GitStatusView(project: selectedProject)
                        } else {
                            SelectProjectEmptyState()
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
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
        VStack(spacing: 24) {
            // Animated folder with subtle motion
            ZStack {
                // Glow effect
                Circle()
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .blur(radius: 20)

                Image(systemName: "folder.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .opacity(0.8)
            }
            .frame(height: 80)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .offset(x: arrowOffset)

                    Text("Choose a project")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                .opacity(showText ? 1.0 : 0.0)

                Text("Select a repository to view status")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                    .opacity(showText ? 1.0 : 0.0)
            }
        }
        .onAppear {
            // Gentle breathing animation for folder
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }

            // Arrow pointing left with subtle motion
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                arrowOffset = -4
            }

            // Text fade in
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showText = true
            }
        }
    }
}

#Preview {
    ContentView()
}
