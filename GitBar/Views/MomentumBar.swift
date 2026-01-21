import SwiftUI

/// Shared state to track which momentum bar is currently expanded
class MomentumBarState: ObservableObject {
    static let shared = MomentumBarState()
    @Published var expandedBarId: String?
}

/// A GitHub/GitLab-style commit activity visualization
/// Shows 5 cells (fixed size), expands to floating 6x5 grid overlay on hover
struct MomentumBar: View {
    let activity: CommitActivity
    let barId: String
    var nextBarId: String? = nil  // ID of the bar in the row below (if any)

    @ObservedObject private var state = MomentumBarState.shared
    @State private var isExpanded = false

    /// Whether this bar's collapsed view should be hidden (the bar below is expanded)
    private var shouldHideCollapsed: Bool {
        guard let expandedId = state.expandedBarId else { return false }
        // Hide only if the bar directly below me is expanded
        return expandedId == nextBarId
    }

    // Configuration
    private let columns = 5
    private let totalRows = 6
    private let cellSize: CGFloat = 8
    private let spacing: CGFloat = 2
    private let cellRadius: CGFloat = 2

    /// Activity organized as rows for the grid (oldest at top, newest at bottom)
    private var gridRows: [[Int]] {
        let allActivity = activity.last(30)
        var result: [[Int]] = []

        for rowIndex in 0..<totalRows {
            let startDay = (totalRows - 1 - rowIndex) * columns
            let endDay = startDay + columns
            let rowData = Array(allActivity[startDay..<min(endDay, allActivity.count)])
            result.append(rowData.reversed())
        }

        return result
    }

    /// Bottom row (most recent 5 days)
    private var bottomRow: [Int] {
        gridRows.last ?? []
    }

    var body: some View {
        // Fixed-size collapsed bar - this determines the row height
        collapsedBar
            .opacity(isExpanded || shouldHideCollapsed ? 0 : 1)
            .overlay(alignment: .bottomTrailing) {
                // Floating expanded grid - doesn't affect layout
                expandedGrid
                    .scaleEffect(x: 1, y: isExpanded ? 1 : 0, anchor: .bottom)
                    .opacity(isExpanded ? 1 : 0)
            }
            .onHover { hovering in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    isExpanded = hovering
                    state.expandedBarId = hovering ? barId : nil
                }
            }
    }

    /// The always-visible 5-cell bar (fixed size)
    private var collapsedBar: some View {
        HStack(spacing: spacing) {
            ForEach(Array(bottomRow.enumerated()), id: \.offset) { _, count in
                ActivityCell(
                    count: count,
                    maxCount: max(activity.maxCount, 1),
                    size: cellSize,
                    radius: cellRadius
                )
            }
        }
    }

    /// The floating 30-day grid that overlays on hover
    private var expandedGrid: some View {
        VStack(alignment: .trailing, spacing: spacing) {
            ForEach(0..<totalRows, id: \.self) { rowIndex in
                HStack(spacing: spacing) {
                    ForEach(Array(gridRows[rowIndex].enumerated()), id: \.offset) { _, count in
                        ActivityCell(
                            count: count,
                            maxCount: max(activity.maxCount, 1),
                            size: cellSize,
                            radius: cellRadius
                        )
                    }
                }
            }
        }
//        .padding(6)
//        .background(
//            RoundedRectangle(cornerRadius: 6)
//                .fill(Theme.sidebarBackground)
//        )
        .zIndex(9999)
    }
}

/// Individual cell in the momentum bar
struct ActivityCell: View {
    let count: Int
    let maxCount: Int
    let size: CGFloat
    let radius: CGFloat

    private var intensity: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    private var cellColor: Color {
        if count == 0 {
            // Use a visible dark gray that contrasts with the sidebar background
            return Color(hex: "#2A2F3A")
        }
        let baseColor = Color(hex: "#22C55E")
        return baseColor.opacity(0.3 + (intensity * 0.7))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(cellColor)
            .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ForEach(0..<5) { i in
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("project-\(i)")
                    .foregroundColor(.white)
                Spacer()
                MomentumBar(
                    activity: CommitActivity(dailyCounts: [3, 1, 0, 5, 2, 0, 0, 1, 4, 2, 0, 0, 3, 1, 2, 0, 0, 0, 1, 5, 3, 2, 1, 0, 0, 4, 2, 1, 0, 3]),
                    barId: "project-\(i)"
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    .frame(width: 260)
    .padding(.vertical, 20)
    .background(Theme.sidebarBackground)
}
