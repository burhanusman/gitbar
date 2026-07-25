import SwiftUI
import AppKit

enum DetailTab: String, CaseIterable {
    case changes = "Changes"
    case history = "History"
    case files = "Files"
    case mdFiles = ".md Files"
    case tickets = "Tickets"
    case stats = "Stats"

    static func availableTabs(for project: Project) -> [DetailTab] {
        if project.isGitRepository {
            return allCases
        }

        return [.files, .mdFiles, .tickets]
    }
}

enum ContentSurface: Hashable {
    case popover
    case window
}

struct SettingsPresentationRequest: Equatable {
    let id = UUID()
    let surface: ContentSurface
}

/// Durable workspace state shared by the quick popover and persistent window.
///
/// Only one surface is intended to be interactive at a time, but tracking a
/// set keeps refresh work correct during the brief handoff between surfaces.
@MainActor
final class WorkspaceSession: ObservableObject {
    let projectListViewModel: ProjectListViewModel

    @Published var selectedTab: DetailTab {
        didSet {
            SettingsService.shared.lastSelectedDetailTab = selectedTab.rawValue
        }
    }
    @Published private(set) var settingsRequest: SettingsPresentationRequest?

    private var activeSurfaces: Set<ContentSurface> = []
    private var claimedSettingsRequestId: UUID?

    init(projectListViewModel: ProjectListViewModel? = nil) {
        self.projectListViewModel = projectListViewModel ?? ProjectListViewModel()
        self.selectedTab = SettingsService.shared.lastSelectedDetailTab
            .flatMap { DetailTab(rawValue: $0) } ?? .changes
    }

    func activate(_ surface: ContentSurface) {
        let wasInactive = activeSurfaces.isEmpty
        guard activeSurfaces.insert(surface).inserted else { return }

        if wasInactive {
            projectListViewModel.loadProjects()
            projectListViewModel.startAutoRefresh()
        }
    }

    func deactivate(_ surface: ContentSurface) {
        guard activeSurfaces.remove(surface) != nil else { return }
        if activeSurfaces.isEmpty {
            projectListViewModel.stopAutoRefresh()
        }
    }

    func requestSettings(on surface: ContentSurface) {
        settingsRequest = SettingsPresentationRequest(surface: surface)
    }

    func claimSettingsPresentation(
        _ request: SettingsPresentationRequest?,
        on surface: ContentSurface
    ) -> Bool {
        guard let request,
              request.surface == surface,
              request.id != claimedSettingsRequestId else {
            return false
        }

        claimedSettingsRequestId = request.id
        return true
    }
}

struct ContentView: View {
    @ObservedObject private var session: WorkspaceSession
    @ObservedObject private var projectListViewModel: ProjectListViewModel

    private let surface: ContentSurface
    private let onOpenWindow: () -> Void

    @State private var showSettings = false
    @State private var hasAppeared = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(
        session: WorkspaceSession,
        surface: ContentSurface,
        onOpenWindow: @escaping () -> Void = {}
    ) {
        self._session = ObservedObject(wrappedValue: session)
        self._projectListViewModel = ObservedObject(wrappedValue: session.projectListViewModel)
        self.surface = surface
        self.onOpenWindow = onOpenWindow
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .background(Theme.border)

            // Main content
            ZStack {
                Theme.background.ignoresSafeArea()

                NavigationSplitView(columnVisibility: $columnVisibility) {
                    ProjectListView(viewModel: projectListViewModel)
                        .navigationSplitViewColumnWidth(
                            min: surface == .window ? 220 : 200,
                            ideal: surface == .window ? 280 : 240,
                            max: surface == .window ? 360 : 300
                        )
                        .background(Theme.sidebarBackground)
                } detail: {
                    ZStack {
                        Theme.background.ignoresSafeArea()

                        if let selectedProject = projectListViewModel.selectedProject {
                            let activePath = projectListViewModel.selectedWorktreePath ?? selectedProject.activeWorktreePath
                            let availableTabs = DetailTab.availableTabs(for: selectedProject)
                            let activeTab = availableTabs.contains(session.selectedTab)
                                ? session.selectedTab
                                : .tickets

                            VStack(spacing: 0) {
                                // Tab switcher
                                DetailTabBar(
                                    selectedTab: Binding(
                                        get: { activeTab },
                                        set: { session.selectedTab = $0 }
                                    ),
                                    tabs: availableTabs
                                )

                                // Content based on selected tab
                                // Use .id() to force view recreation when project/worktree changes, ensuring fresh view model state
                                let viewId = "\(selectedProject.id)-\(activePath ?? "")"
                                switch activeTab {
                                case .changes:
                                    GitStatusView(project: selectedProject, worktreePath: activePath)
                                        .id(viewId)
                                case .history:
                                    GitTreeView(project: selectedProject, worktreePath: activePath)
                                        .id(viewId)
                                case .files:
                                    FileBrowserView(project: selectedProject, worktreePath: activePath)
                                        .id(viewId)
                                case .mdFiles:
                                    MarkdownBrowserView(project: selectedProject, worktreePath: activePath)
                                        .id(viewId)
                                case .tickets:
                                    TicketsView(project: selectedProject, worktreePath: activePath)
                                        .id(viewId)
                                case .stats:
                                    ProjectStatsView(project: selectedProject, worktreePath: activePath)
                                        .id(viewId)
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
        .onChange(of: session.settingsRequest) { request in
            handleSettingsRequest(request)
        }
        .onAppear {
            hasAppeared = true
            handleSettingsRequest(session.settingsRequest)
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

            if surface == .window {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .frame(width: 28, height: 28)
                        .font(.system(size: Theme.fontBase, weight: .medium))
                        .foregroundColor(
                            columnVisibility == .detailOnly
                                ? Theme.textTertiary
                                : Theme.textSecondary
                        )
                        .background(Theme.surface.opacity(0.01))
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(HeaderButtonStyle())
                .help(columnVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar")
                .accessibilityLabel(columnVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar")
            }

            Spacer()

            if surface == .popover {
                Button(action: onOpenWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 28, height: 28)
                        .font(.system(size: Theme.fontBase, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                        .background(Theme.surface.opacity(0.01))
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(HeaderButtonStyle())
                .help("Open in Window")
                .accessibilityLabel("Open GitBar in a window")
            }

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
            .accessibilityLabel("Settings")
        }
        .padding(.leading, surface == .window ? 76 : Theme.space4)
        .padding(.trailing, Theme.space4)
        .padding(.vertical, Theme.space3)
        .background(Theme.sidebarBackground)
    }

    private func toggleSidebar() {
        withAnimation(.easeOut(duration: Theme.animationBase)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }

    private func handleSettingsRequest(_ request: SettingsPresentationRequest?) {
        guard session.claimSettingsPresentation(request, on: surface) else { return }
        showSettings = true
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

                Text("Choose a project from the sidebar")
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
    let tabs: [DetailTab]

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
        case .tickets:
            return "ticket"
        case .stats:
            return "chart.bar.xaxis"
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(tabs, id: \.self) { tab in
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
            }
            .padding(.horizontal, Theme.space3)
            .padding(.vertical, Theme.space2)
        }
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
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))

                Text(title)
                    .font(.system(size: Theme.fontXS, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(isSelected ? Theme.accent : (isHovered ? Theme.textSecondary : Theme.textTertiary))
            .padding(.horizontal, Theme.space2)
            .padding(.vertical, 6)
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
    ContentView(
        session: WorkspaceSession(),
        surface: .window
    )
}
