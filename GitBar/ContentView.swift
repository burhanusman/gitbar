import SwiftUI

// MARK: - Focus Areas

enum AppFocus: Hashable {
    case sidebar
    case search
    case fileList
    case commitMessage
}

struct ContentView: View {
    @StateObject private var projectListViewModel = ProjectListViewModel()
    @State private var showSettings = false
    @State private var hasAppeared = false
    @FocusState private var focusedArea: AppFocus?

    // Environment object for keyboard actions from GitStatusView
    @StateObject private var keyboardState = KeyboardState()

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .background(Theme.border)

            // Main content
            ZStack {
                Theme.background.ignoresSafeArea()

                NavigationSplitView {
                    ProjectListView(
                        viewModel: projectListViewModel,
                        focusedArea: $focusedArea
                    )
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                        .background(Theme.sidebarBackground)
                } detail: {
                    ZStack {
                        Theme.background.ignoresSafeArea()

                        if let selectedProject = projectListViewModel.selectedProject {
                            GitStatusView(
                                project: selectedProject,
                                focusedArea: $focusedArea
                            )
                            .environmentObject(keyboardState)
                        } else {
                            SelectProjectEmptyState()
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.2), value: hasAppeared)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
        .onAppear {
            hasAppeared = true
            // Default focus to sidebar
            focusedArea = .sidebar
        }
        .onDisappear {
            hasAppeared = false
        }
        // Global keyboard shortcuts
        .background(
            KeyboardShortcutHandler(
                focusedArea: $focusedArea,
                showSettings: $showSettings,
                keyboardState: keyboardState
            )
        )
    }

    private var headerView: some View {
        HStack(spacing: Theme.space3) {
            // App title
            HStack(spacing: Theme.space2) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.accent)

                Text("GitBar")
                    .font(.system(size: Theme.fontBase, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()

            // Settings button
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: Theme.fontBase, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(Theme.surface.opacity(0.01)) // Invisible but hittable
                    .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(HeaderButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, Theme.space4)
        .padding(.vertical, Theme.space3)
        .background(Theme.sidebarBackground)
    }
}

// MARK: - Header Button Style

struct HeaderButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(isHovered ? Theme.surfaceHover : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Empty State

struct SelectProjectEmptyState: View {
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: Theme.space5) {
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.accentMuted)
                    .frame(width: 72, height: 72)

                Image(systemName: "folder")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.accent)
            }

            // Text
            VStack(spacing: Theme.space2) {
                HStack(spacing: Theme.space2) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: Theme.fontSM, weight: .semibold))
                        .foregroundColor(Theme.accent)

                    Text("Select a project")
                        .font(.system(size: Theme.fontLG, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }

                Text("Choose a repository from the sidebar")
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Keyboard State

/// Observable object for communicating keyboard actions between views
class KeyboardState: ObservableObject {
    @Published var triggerPush = false
    @Published var triggerPull = false
    @Published var triggerCommit = false
    @Published var triggerStageAll = false
    @Published var triggerUnstageAll = false
    @Published var triggerStageSelected = false
    @Published var triggerUnstageSelected = false
    @Published var triggerDiscardSelected = false
    @Published var triggerOpenTerminal = false
    @Published var triggerOpenEditor = false
    @Published var triggerRevealInFinder = false
    @Published var triggerCopyBranch = false
    @Published var triggerRefresh = false
}

// MARK: - Keyboard Shortcut Handler

struct KeyboardShortcutHandler: View {
    var focusedArea: FocusState<AppFocus?>.Binding
    @Binding var showSettings: Bool
    @ObservedObject var keyboardState: KeyboardState

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            // Navigation shortcuts
            .keyboardShortcut("f", modifiers: .command, action: { focusedArea.wrappedValue = .search })
            .keyboardShortcut("1", modifiers: .command, action: { focusedArea.wrappedValue = .sidebar })
            .keyboardShortcut("2", modifiers: .command, action: { focusedArea.wrappedValue = .fileList })
            // Git operation shortcuts
            .keyboardShortcut("p", modifiers: [.command, .shift], action: { keyboardState.triggerPull = true })
            .keyboardShortcut("p", modifiers: .command, action: { keyboardState.triggerPush = true })
            .keyboardShortcut(.return, modifiers: .command, action: { keyboardState.triggerCommit = true })
            .keyboardShortcut("s", modifiers: [.command, .shift], action: { keyboardState.triggerStageAll = true })
            .keyboardShortcut("u", modifiers: [.command, .shift], action: { keyboardState.triggerUnstageAll = true })
            .keyboardShortcut("s", modifiers: .command, action: { keyboardState.triggerStageSelected = true })
            .keyboardShortcut("u", modifiers: .command, action: { keyboardState.triggerUnstageSelected = true })
            .keyboardShortcut(.delete, modifiers: .command, action: { keyboardState.triggerDiscardSelected = true })
            // External actions
            .keyboardShortcut("t", modifiers: .command, action: { keyboardState.triggerOpenTerminal = true })
            .keyboardShortcut("e", modifiers: .command, action: { keyboardState.triggerOpenEditor = true })
            .keyboardShortcut("o", modifiers: [.command, .shift], action: { keyboardState.triggerRevealInFinder = true })
            .keyboardShortcut("c", modifiers: [.command, .shift], action: { keyboardState.triggerCopyBranch = true })
            .keyboardShortcut("r", modifiers: .command, action: { keyboardState.triggerRefresh = true })
            // Settings
            .keyboardShortcut(",", modifiers: .command, action: { showSettings = true })
    }
}

// MARK: - Keyboard Shortcut View Extension

extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command, action: @escaping () -> Void) -> some View {
        self.background(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }
}

#Preview {
    ContentView()
}
