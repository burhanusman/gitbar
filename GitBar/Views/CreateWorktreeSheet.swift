import SwiftUI

/// Compact sheet for creating a new worktree
struct CreateWorktreeSheet: View {
    @StateObject private var viewModel: CreateWorktreeViewModel
    @Environment(\.dismiss) private var dismiss
    let onCreated: () -> Void

    init(repoPath: String, onCreated: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: CreateWorktreeViewModel(repoPath: repoPath))
        self.onCreated = onCreated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space5) {
            // Header
            HStack {
                Text("New Worktree")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: Theme.fontSM, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(Theme.surface)
                        .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }

            // Branch mode toggle
            HStack(spacing: Theme.space2) {
                BranchModeButton(
                    title: "New Branch",
                    isSelected: viewModel.isNewBranch,
                    action: { viewModel.isNewBranch = true }
                )

                BranchModeButton(
                    title: "Existing Branch",
                    isSelected: !viewModel.isNewBranch,
                    action: { viewModel.isNewBranch = false }
                )
            }

            // Branch input
            if viewModel.isNewBranch {
                VStack(alignment: .leading, spacing: Theme.space2) {
                    Text("BRANCH NAME")
                        .font(.system(size: Theme.fontXS, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(Theme.textMuted)

                    TextField("feature/my-branch", text: $viewModel.branchName)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontBase))
                        .padding(.horizontal, Theme.space3)
                        .padding(.vertical, Theme.space3)
                        .background(Theme.surface)
                        .cornerRadius(Theme.radius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.space2) {
                    Text("SELECT BRANCH")
                        .font(.system(size: Theme.fontXS, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(Theme.textMuted)

                    if viewModel.isLoadingBranches {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading branches...")
                                .font(.system(size: Theme.fontSM))
                                .foregroundColor(Theme.textTertiary)
                        }
                    } else {
                        Picker("Branch", selection: Binding(
                            get: { viewModel.selectedExistingBranch ?? "" },
                            set: { viewModel.selectedExistingBranch = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Select a branch...").tag("")
                            ForEach(viewModel.existingBranches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            // Path preview
            if !viewModel.autoPath.isEmpty {
                VStack(alignment: .leading, spacing: Theme.space2) {
                    Text("WORKTREE PATH")
                        .font(.system(size: Theme.fontXS, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(Theme.textMuted)

                    Text(viewModel.autoPath)
                        .font(.system(size: Theme.fontSM, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, Theme.space3)
                        .padding(.vertical, Theme.space2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .cornerRadius(Theme.radius)
                }
            }

            // Agent label pills
            VStack(alignment: .leading, spacing: Theme.space2) {
                Text("AGENT LABEL")
                    .font(.system(size: Theme.fontXS, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Theme.textMuted)

                HStack(spacing: Theme.space2) {
                    AgentLabelPill(label: "Claude", isSelected: viewModel.agentLabel == "Claude") {
                        viewModel.agentLabel = viewModel.agentLabel == "Claude" ? nil : "Claude"
                    }

                    AgentLabelPill(label: "Codex", isSelected: viewModel.agentLabel == "Codex") {
                        viewModel.agentLabel = viewModel.agentLabel == "Codex" ? nil : "Codex"
                    }

                    // Optional: custom label
                    AgentLabelPill(label: "Custom", isSelected: viewModel.agentLabel != nil && viewModel.agentLabel != "Claude" && viewModel.agentLabel != "Codex") {
                        if viewModel.agentLabel != nil && viewModel.agentLabel != "Claude" && viewModel.agentLabel != "Codex" {
                            viewModel.agentLabel = nil
                        } else {
                            viewModel.agentLabel = "Agent"
                        }
                    }
                }
            }

            // Error
            if let error = viewModel.error {
                Text(error)
                    .font(.system(size: Theme.fontSM))
                    .foregroundColor(Theme.error)
            }

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, Theme.space4)
                .padding(.vertical, Theme.space2)
                .pointingHandCursor()

                Button(action: {
                    Task {
                        let success = await viewModel.createWorktree()
                        if success {
                            onCreated()
                            dismiss()
                        }
                    }
                }) {
                    Group {
                        if viewModel.isCreating {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Text("Create")
                                .font(.system(size: Theme.fontBase, weight: .semibold))
                        }
                    }
                    .frame(width: 80, height: 32)
                    .foregroundColor(viewModel.canCreate ? .white : Theme.textMuted)
                    .background(viewModel.canCreate ? Theme.accent : Theme.surface)
                    .cornerRadius(Theme.radius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .stroke(viewModel.canCreate ? Theme.accent : Theme.border, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!viewModel.canCreate)
                .pointingHandCursor()
            }
        }
        .padding(Theme.space6)
        .frame(width: 400)
        .background(Theme.background)
        .onAppear {
            viewModel.loadBranches()
        }
    }
}

// MARK: - Branch Mode Button

private struct BranchModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Theme.fontSM, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Theme.accent : (isHovered ? Theme.textSecondary : Theme.textTertiary))
                .padding(.horizontal, Theme.space3)
                .padding(.vertical, Theme.space2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .fill(isSelected ? Theme.accentMuted : (isHovered ? Theme.surfaceHover : Theme.surface))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }
}

// MARK: - Agent Label Pill

private struct AgentLabelPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: Theme.fontSM, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Theme.purple : (isHovered ? Theme.textSecondary : Theme.textTertiary))
                .padding(.horizontal, Theme.space3)
                .padding(.vertical, Theme.space2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .fill(isSelected ? Theme.purpleMuted : (isHovered ? Theme.surfaceHover : Theme.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(isSelected ? Theme.purple.opacity(0.3) : .clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: Theme.animationFast), value: isHovered)
        .pointingHandCursor()
    }
}
