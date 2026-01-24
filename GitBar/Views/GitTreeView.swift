import SwiftUI
import AppKit

/// Git Tree visualization showing commit history with graph
struct GitTreeView: View {
    let project: Project
    @StateObject private var viewModel = GitTreeViewModel()
    @State private var showCopiedFeedback = false
    @State private var copiedCommitId: String?

    // Layout constants
    private let graphColumnWidth: CGFloat = 48
    private let rowHeight: CGFloat = 52
    private let nodeSize: CGFloat = 8
    private let lineWidth: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.horizontal, Theme.space6)
                .padding(.vertical, Theme.space4)
                .background(Theme.surfaceElevated)

            Divider()
                .background(Theme.border)

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if !viewModel.hasCommits {
                emptyStateView
            } else {
                commitTreeView
            }
        }
        .background(Theme.background)
        .onAppear {
            viewModel.loadCommits(for: project.path)
        }
        .onChange(of: project.path) { newPath in
            viewModel.loadCommits(for: newPath)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: Theme.space4) {
            HStack(spacing: Theme.space2) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)

                Text("History")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                if let branch = viewModel.currentBranch {
                    BranchBadge(name: branch, isHead: true)
                }
            }

            Spacer()

            if !viewModel.commits.isEmpty {
                Text("\(viewModel.commits.count) commits")
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    // MARK: - Commit Tree

    private var commitTreeView: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Graph lines layer
                GitGraphCanvas(
                    nodes: viewModel.graphNodes,
                    drawProgress: viewModel.drawProgress,
                    graphColumnWidth: graphColumnWidth,
                    rowHeight: rowHeight,
                    nodeSize: nodeSize,
                    lineWidth: lineWidth
                )

                // Commit rows layer
                VStack(spacing: 0) {
                    ForEach(viewModel.graphNodes) { node in
                        CommitRow(
                            node: node,
                            isExpanded: viewModel.expandedCommitId == node.id,
                            isVisible: viewModel.nodesAppeared.contains(node.id),
                            graphColumnWidth: graphColumnWidth,
                            nodeSize: nodeSize,
                            showCopiedFeedback: copiedCommitId == node.id,
                            onTap: { viewModel.toggleExpanded(for: node.id) },
                            onCopySha: {
                                viewModel.copyCommitSha(node.commit.sha)
                                withAnimation {
                                    copiedCommitId = node.id
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        if copiedCommitId == node.id {
                                            copiedCommitId = nil
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .padding(.vertical, Theme.space4)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Theme.space4) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading history...")
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: Theme.space4) {
            ZStack {
                Circle()
                    .fill(Theme.errorMuted)
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.error)
            }

            VStack(spacing: Theme.space2) {
                Text("Couldn't load history")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(error.localizedDescription)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.space8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.space5) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceHover)
                    .frame(width: 72, height: 72)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(spacing: Theme.space2) {
                Text("No commits yet")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("Make your first commit to see history")
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Branch Badge

struct BranchBadge: View {
    let name: String
    var isHead: Bool = false
    var color: Color? = nil

    var body: some View {
        HStack(spacing: 4) {
            if isHead {
                Circle()
                    .fill(Theme.success)
                    .frame(width: 5, height: 5)
            }

            Text(truncatedName)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(badgeColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(badgeColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var truncatedName: String {
        if name.count > 16 {
            return String(name.prefix(14)) + "…"
        }
        return name
    }

    private var badgeColor: Color {
        color ?? BranchColors.color(for: name)
    }
}

// MARK: - Git Graph Canvas

struct GitGraphCanvas: View {
    let nodes: [GitGraphNode]
    let drawProgress: CGFloat
    let graphColumnWidth: CGFloat
    let rowHeight: CGFloat
    let nodeSize: CGFloat
    let lineWidth: CGFloat

    private let columnSpacing: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            // Draw all connections/lines
            for node in nodes {
                let nodeCenter = centerPoint(for: node)

                // Draw lines to parent commits
                for childNode in nodes {
                    if childNode.commit.parentShas.contains(node.commit.sha) {
                        let childCenter = centerPoint(for: childNode)
                        let branchColor = getBranchColor(for: childNode)

                        drawConnection(
                            context: &context,
                            from: childCenter,
                            to: nodeCenter,
                            fromColumn: childNode.column,
                            toColumn: node.column,
                            color: branchColor,
                            progress: drawProgress
                        )
                    }
                }
            }
        }
        .frame(width: graphColumnWidth + CGFloat(maxColumn) * columnSpacing, height: CGFloat(nodes.count) * rowHeight)
        .allowsHitTesting(false)
    }

    private var maxColumn: Int {
        nodes.map { $0.column }.max() ?? 0
    }

    private func centerPoint(for node: GitGraphNode) -> CGPoint {
        let x = 20 + CGFloat(node.column) * columnSpacing
        let y = CGFloat(node.row) * rowHeight + rowHeight / 2
        return CGPoint(x: x, y: y)
    }

    private func getBranchColor(for node: GitGraphNode) -> Color {
        if let branchName = node.commit.branches.first {
            return BranchColors.color(for: branchName)
        }
        return Theme.accent
    }

    private func drawConnection(
        context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        fromColumn: Int,
        toColumn: Int,
        color: Color,
        progress: CGFloat
    ) {
        var path = Path()

        if fromColumn == toColumn {
            // Straight vertical line
            path.move(to: from)
            path.addLine(to: CGPoint(x: from.x, y: from.y + (to.y - from.y) * progress))
        } else {
            // Curved connection
            path.move(to: from)

            let midY = from.y + (to.y - from.y) * 0.5
            let controlPoint1 = CGPoint(x: from.x, y: midY)
            let controlPoint2 = CGPoint(x: to.x, y: midY)
            let endPoint = CGPoint(x: to.x, y: from.y + (to.y - from.y) * progress)

            path.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
        }

        context.stroke(
            path,
            with: .color(color.opacity(0.7)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        // Add subtle glow
        context.stroke(
            path,
            with: .color(color.opacity(0.2)),
            style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Commit Row

struct CommitRow: View {
    let node: GitGraphNode
    let isExpanded: Bool
    let isVisible: Bool
    let graphColumnWidth: CGFloat
    let nodeSize: CGFloat
    let showCopiedFeedback: Bool
    let onTap: () -> Void
    let onCopySha: () -> Void

    @State private var isHovered = false

    private let columnSpacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 0) {
                // Graph node area
                ZStack {
                    commitNode
                        .position(x: 20 + CGFloat(node.column) * columnSpacing, y: 26)
                }
                .frame(width: graphColumnWidth + CGFloat(maxColumnInView) * columnSpacing, height: 52)

                // Commit info
                VStack(alignment: .leading, spacing: 2) {
                    // Message
                    Text(node.commit.message)
                        .font(.system(size: Theme.fontBase, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    // Metadata row
                    HStack(spacing: Theme.space2) {
                        // Branch badges
                        ForEach(node.commit.branches.prefix(2), id: \.self) { branch in
                            BranchBadge(name: branch, isHead: node.commit.isHead && branch == node.commit.branches.first)
                        }

                        Text("·")
                            .foregroundColor(Theme.textMuted)

                        Text(node.commit.relativeTime)
                            .font(.system(size: Theme.fontSM))
                            .foregroundColor(Theme.textTertiary)

                        Text("·")
                            .foregroundColor(Theme.textMuted)

                        // SHA with copy
                        HStack(spacing: 4) {
                            Text(node.commit.shortSha)
                                .font(.system(size: Theme.fontSM, design: .monospaced))
                                .foregroundColor(Theme.textTertiary)

                            if isHovered || showCopiedFeedback {
                                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(showCopiedFeedback ? Theme.success : Theme.textMuted)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .onTapGesture {
                            onCopySha()
                        }
                        .pointingHandCursor()
                    }
                }
                .padding(.trailing, Theme.space4)

                Spacer()
            }
            .contentShape(Rectangle())
            .background(isHovered ? Theme.surfaceHover.opacity(0.5) : .clear)
            .onTapGesture { onTap() }
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: Theme.animationFast), value: isHovered)

            // Expanded details
            if isExpanded {
                expandedDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    }

    private var maxColumnInView: Int {
        // Simplified - would need to be passed from parent for accuracy
        max(node.column, 2)
    }

    private var commitNode: some View {
        ZStack {
            // HEAD pulse ring
            if node.commit.isHead {
                Circle()
                    .stroke(nodeColor.opacity(0.3), lineWidth: 2)
                    .frame(width: nodeSize + 8, height: nodeSize + 8)
                    .scaleEffect(isVisible ? 1.2 : 1.0)
                    .opacity(isVisible ? 0.5 : 0)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isVisible
                    )
            }

            // Merge node (donut)
            if node.commit.isMerge {
                Circle()
                    .stroke(nodeColor, lineWidth: 2)
                    .frame(width: nodeSize + 2, height: nodeSize + 2)
            } else {
                // Regular node
                Circle()
                    .fill(nodeColor)
                    .frame(width: node.commit.isHead ? nodeSize + 2 : nodeSize, height: node.commit.isHead ? nodeSize + 2 : nodeSize)
            }
        }
        .shadow(color: nodeColor.opacity(isHovered ? 0.5 : 0.2), radius: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.2 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
    }

    private var nodeColor: Color {
        if let branch = node.commit.branches.first {
            return BranchColors.color(for: branch)
        }
        return Theme.accent
    }

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            Divider()
                .background(Theme.border)

            VStack(alignment: .leading, spacing: Theme.space2) {
                // Full commit message
                Text(node.commit.message)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.space3) {
                    // Author
                    HStack(spacing: Theme.space1) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)

                        Text(node.commit.authorName)
                            .font(.system(size: Theme.fontSM))
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Full SHA
                    HStack(spacing: Theme.space1) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)

                        Text(node.commit.sha.prefix(12))
                            .font(.system(size: Theme.fontSM, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                    }

                    // Parents count for merge
                    if node.commit.isMerge {
                        HStack(spacing: Theme.space1) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textMuted)

                            Text("\(node.commit.parentShas.count) parents")
                                .font(.system(size: Theme.fontSM))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.space4)
            .padding(.vertical, Theme.space3)
            .padding(.leading, graphColumnWidth)
        }
        .background(Theme.surface.opacity(0.5))
    }
}

// MARK: - Preview

#Preview {
    GitTreeView(project: Project(name: "Demo", path: "/"))
        .frame(width: 500, height: 600)
}
