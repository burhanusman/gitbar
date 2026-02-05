import SwiftUI
import AppKit

enum DetailTab: String, CaseIterable {
    case changes = "Changes"
    case history = "History"
    case files = "Files"
    case mdFiles = ".md Files"
}

struct ContentView: View {
    @StateObject private var projectListViewModel = ProjectListViewModel()
    @State private var showSettings = false
    @State private var hasAppeared = false
    @State private var selectedTab: DetailTab = .changes

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .background(Theme.border)

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
                            let activePath = projectListViewModel.selectedWorktreePath ?? selectedProject.activeWorktreePath

                            VStack(spacing: 0) {
                                // Tab switcher
                                DetailTabBar(selectedTab: $selectedTab)

                                // Content based on selected tab
                                switch selectedTab {
                                case .changes:
                                    GitStatusView(project: selectedProject, worktreePath: activePath)
                                case .history:
                                    GitTreeView(project: selectedProject, worktreePath: activePath)
                                case .files:
                                    FileBrowserView(project: selectedProject, worktreePath: activePath)
                                case .mdFiles:
                                    MarkdownBrowserView(project: selectedProject, worktreePath: activePath)
                                }
                            }
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
        }
        .onDisappear {
            hasAppeared = false
        }
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
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(isHovered ? Theme.surfaceHover : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
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

// MARK: - Detail Tab Bar

struct DetailTabBar: View {
    @Binding var selectedTab: DetailTab

    private func iconForTab(_ tab: DetailTab) -> String {
        switch tab {
        case .changes:
            return "doc.badge.plus"
        case .history:
            return "point.3.connected.trianglepath.dotted"
        case .files:
            return "folder"
        case .mdFiles:
            return "doc.richtext"
        }
    }

    var body: some View {
        HStack(spacing: Theme.space1) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    icon: iconForTab(tab),
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                )
            }

            Spacer()
        }
        .padding(.horizontal, Theme.space4)
        .padding(.vertical, Theme.space2)
        .background(Theme.surfaceElevated)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.space2) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))

                Text(title)
                    .font(.system(size: Theme.fontSM, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? Theme.accent : (isHovered ? Theme.textSecondary : Theme.textTertiary))
            .padding(.horizontal, Theme.space3)
            .padding(.vertical, Theme.space2)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(isSelected ? Theme.accentMuted : (isHovered ? Theme.surfaceHover : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .animation(.easeOut(duration: Theme.animationFast), value: isSelected)
        .pointingHandCursor()
    }
}

#Preview {
    ContentView()
}
