import SwiftUI

/// View displaying project statistics including lines changed and token usage
struct ProjectStatsView: View {
    let project: Project
    var worktreePath: String?

    @StateObject private var viewModel = ProjectStatsViewModel()

    private var effectivePath: String {
        worktreePath ?? project.path
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space6) {
                // Header
                headerView

                if viewModel.isLoading {
                    loadingView
                } else {
                    // Stats cards
                    VStack(spacing: Theme.space4) {
                        // Lines Changed Card
                        StatsCard(
                            title: "Lines Changed (30 days)",
                            icon: "text.line.first.and.arrowtriangle.forward",
                            content: {
                                HStack(spacing: Theme.space4) {
                                    StatValue(
                                        value: "+\(viewModel.linesAdded)",
                                        label: "Added",
                                        color: Theme.success
                                    )
                                    StatValue(
                                        value: "-\(viewModel.linesRemoved)",
                                        label: "Removed",
                                        color: Theme.error
                                    )
                                }
                            }
                        )

                        // Commits Card
                        StatsCard(
                            title: "Commit Activity",
                            icon: "point.3.connected.trianglepath.dotted",
                            content: {
                                VStack(alignment: .leading, spacing: Theme.space3) {
                                    HStack(spacing: Theme.space4) {
                                        StatValue(
                                            value: "\(viewModel.totalCommits)",
                                            label: "Total (30 days)",
                                            color: Theme.accent
                                        )
                                        StatValue(
                                            value: "\(viewModel.commitsThisWeek)",
                                            label: "This Week",
                                            color: Theme.purple
                                        )
                                    }

                                    // Activity chart
                                    ActivityChart(dailyCounts: viewModel.dailyCommits)
                                        .frame(height: 60)
                                }
                            }
                        )

                        // Token Usage Card (if available)
                        if let tokens = viewModel.tokenUsage {
                            StatsCard(
                                title: "AI Token Usage",
                                icon: "sparkles",
                                content: {
                                    HStack(spacing: Theme.space4) {
                                        StatValue(
                                            value: formatTokens(tokens.input),
                                            label: "Input Tokens",
                                            color: Theme.accent
                                        )
                                        StatValue(
                                            value: formatTokens(tokens.output),
                                            label: "Output Tokens",
                                            color: Theme.purple
                                        )
                                        if let cost = tokens.cost {
                                            StatValue(
                                                value: formatCost(cost),
                                                label: "Cost",
                                                color: Theme.success
                                            )
                                        }
                                    }
                                }
                            )
                        }

                        // File Types Card
                        if !viewModel.fileTypeStats.isEmpty {
                            StatsCard(
                                title: "Files by Type",
                                icon: "doc.on.doc",
                                content: {
                                    VStack(alignment: .leading, spacing: Theme.space2) {
                                        ForEach(viewModel.fileTypeStats.prefix(5), id: \.extension) { stat in
                                            HStack {
                                                Text(".\(stat.extension)")
                                                    .font(.system(size: Theme.fontSM, weight: .medium).monospaced())
                                                    .foregroundColor(Theme.textSecondary)
                                                Spacer()
                                                Text("\(stat.count) files")
                                                    .font(.system(size: Theme.fontXS))
                                                    .foregroundColor(Theme.textMuted)
                                            }
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(Theme.space6)
        }
        .background(Theme.background)
        .onAppear {
            viewModel.loadStats(at: effectivePath)
        }
        .onChange(of: effectivePath) { newPath in
            viewModel.loadStats(at: newPath)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            HStack(spacing: Theme.space2) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Text("Project Statistics")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            Text(effectivePath)
                .font(.system(size: Theme.fontXS))
                .foregroundColor(Theme.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var loadingView: some View {
        VStack(spacing: Theme.space4) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading statistics...")
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Formatting

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatCost(_ cost: Double) -> String {
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Stats Card

private struct StatsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            HStack(spacing: Theme.space2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(.system(size: Theme.fontSM, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }

            content()
        }
        .padding(Theme.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Stat Value

private struct StatValue: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundColor(color)
            Text(label)
                .font(.system(size: Theme.fontXS))
                .foregroundColor(Theme.textMuted)
        }
    }
}

// MARK: - Activity Chart

private struct ActivityChart: View {
    let dailyCounts: [Int]

    private var maxCount: Int {
        dailyCounts.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(dailyCounts.enumerated()), id: \.offset) { index, count in
                    let height = maxCount > 0
                        ? CGFloat(count) / CGFloat(maxCount) * geometry.size.height
                        : 0

                    RoundedRectangle(cornerRadius: 2)
                        .fill(count > 0 ? Theme.accent : Theme.surfaceHover)
                        .frame(height: max(4, height))
                }
            }
        }
    }
}

#Preview {
    ProjectStatsView(project: Project(name: "Demo", path: "/Users/demo/project"))
        .frame(width: 500, height: 600)
}
