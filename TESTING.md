# GitBar Pre-Launch Testing Guide

## Overview
This document outlines comprehensive testing procedures for GitBar before the v1.0.0 launch. All tests should be performed on clean macOS installations to ensure the first-run experience works correctly.

## Test Environment Requirements

### macOS Versions
- [ ] macOS 13 (Ventura)
- [ ] macOS 14 (Sonoma)
- [ ] macOS 15 (Sequoia)

### Test Methods
- Virtual machines (UTM, Parallels, VMware)
- Physical devices (borrowed or secondary machines)
- Clean user accounts on existing machines

## Installation Testing

### Homebrew Installation (Primary Method)
```bash
brew install --cask gitbar
```

**Test Checklist:**
- [ ] Cask installs without errors
- [ ] App appears in Applications folder
- [ ] App launches successfully from Spotlight
- [ ] Menubar icon appears immediately
- [ ] No Dock icon is shown (LSUIElement working)
- [ ] Gatekeeper accepts the app signature
- [ ] No security warnings appear

### Manual DMG Installation (Secondary Method)
1. Download DMG from GitHub Releases
2. Open DMG file
3. Drag to Applications folder
4. Launch from Applications

**Test Checklist:**
- [ ] DMG opens without errors
- [ ] Drag-and-drop installation works
- [ ] App is properly code-signed
- [ ] App is notarized (no Gatekeeper warnings)
- [ ] First launch doesn't trigger security blocks
- [ ] Menubar icon appears
- [ ] No Dock icon is shown

## First-Run Experience

### Empty State Testing
Test with a fresh installation on a machine with:
- No Claude Code projects
- No Codex projects
- No git repositories

**Test Checklist:**
- [ ] App launches without crashing
- [ ] Menubar icon appears
- [ ] Clicking menubar icon opens popover
- [ ] "No repos found" message shown for all sections
- [ ] Empty state UI is clear and helpful
- [ ] Settings button is accessible
- [ ] "Select a project" placeholder shown in detail view
- [ ] UI is responsive and doesn't freeze

### Project Discovery Testing

#### Claude Code Projects
Setup:
1. Create `~/.claude` directory
2. Add test projects in `~/.claude/projects/`

**Test Checklist:**
- [ ] Claude projects are discovered automatically
- [ ] Projects appear under "Claude Projects" section
- [ ] Badge shows "claude" label
- [ ] Badge color is blue (#0A84FF)
- [ ] Projects can be selected
- [ ] Git status displays correctly

#### Codex Projects
Setup:
1. Create `~/Library/Application Support/Codex/projects/` directory
2. Add test projects

**Test Checklist:**
- [ ] Codex projects are discovered automatically
- [ ] Projects appear under "Codex Projects" section
- [ ] Badge shows "codex" label
- [ ] Badge color is purple (#BF5AF2)
- [ ] Projects can be selected
- [ ] Git status displays correctly

#### Manual Folder Projects
**Test Checklist:**
- [ ] "Add Folder" button is visible and functional
- [ ] File picker opens when clicked
- [ ] Can select any git repository folder
- [ ] Non-git folders are rejected with clear error
- [ ] Added projects appear under "Folders" section
- [ ] No badge shown for manual folders
- [ ] Projects persist after app restart

## Git Operations Testing

### Repository States
Create test repositories with various states:

1. **Clean repository** (no changes)
2. **Uncommitted changes** (modified files)
3. **Staged changes** (files in staging area)
4. **Untracked files** (new files)
5. **Ahead of remote** (local commits not pushed)
6. **Behind remote** (remote commits not pulled)
7. **Diverged** (both ahead and behind)
8. **No remote** (local-only repository)

### Git Status Display
**Test Checklist:**
- [ ] Branch name displays correctly
- [ ] Current branch shown accurately
- [ ] Uncommitted changes indicator (blue dot) works
- [ ] Staged changes count is accurate
- [ ] Unstaged changes count is accurate
- [ ] Untracked files count is accurate
- [ ] Ahead/behind commit counts correct
- [ ] "Up to date" message shown when synced
- [ ] "No remote" message shown for local repos

### Git Operations
Test all git operations through the UI:

**Stage/Unstage Files:**
- [ ] Can stage individual files
- [ ] Can unstage individual files
- [ ] Can stage all files
- [ ] Can unstage all files
- [ ] UI updates immediately after staging/unstaging
- [ ] File counts update correctly

**Commit:**
- [ ] Commit message field is functional
- [ ] Can commit staged changes
- [ ] Commit creates new commit in git log
- [ ] Working directory updates after commit
- [ ] Empty commit message is prevented
- [ ] Commit message persists in git history

**Push/Pull:**
- [ ] Can push commits to remote
- [ ] Can pull commits from remote
- [ ] Push/pull with authentication works
- [ ] SSH keys are respected
- [ ] HTTPS credentials are requested
- [ ] Error messages shown for failed operations
- [ ] Network errors handled gracefully

**Refresh:**
- [ ] Manual refresh button works
- [ ] Auto-refresh works (every 30 seconds)
- [ ] Status updates in background
- [ ] No UI freezing during refresh

## Performance Testing

### Single Project
**Test Checklist:**
- [ ] App launches quickly (&lt;2 seconds)
- [ ] Menubar popover opens instantly
- [ ] Git status loads quickly (&lt;1 second)
- [ ] UI is responsive during operations
- [ ] No memory leaks after extended use

### 5 Projects
**Test Checklist:**
- [ ] All projects load correctly
- [ ] Project list scrolls smoothly
- [ ] Switching between projects is instant
- [ ] Auto-refresh doesn't cause lag
- [ ] Memory usage is reasonable (&lt;100 MB)

### 20+ Projects
**Test Checklist:**
- [ ] App handles large project counts
- [ ] Project list remains responsive
- [ ] Scrolling is smooth
- [ ] Auto-refresh performance acceptable
- [ ] No significant memory increase
- [ ] CPU usage remains low (&lt;5% idle)
- [ ] No UI freezing or stuttering

### Memory & CPU Benchmarks
Record baseline metrics:
- Idle memory usage: _____ MB
- Active memory usage: _____ MB
- Idle CPU usage: _____ %
- Active CPU usage: _____ %

## Auto-Update Testing

### Sparkle Framework Setup
**Test Checklist:**
- [ ] Sparkle framework is properly embedded
- [ ] Public key is configured in Info.plist
- [ ] Appcast URL is correct
- [ ] App can reach appcast.xml

### Update Check
**Test Checklist:**
- [ ] "Check for Updates" button works
- [ ] Update check completes without errors
- [ ] "Checking..." status shows during check
- [ ] "Last checked" timestamp updates
- [ ] "No updates available" message shown when current

### Update Flow (Simulated)
To test update flow:
1. Build version 1.0.0
2. Install and run
3. Build version 1.0.1 with updated appcast
4. Trigger update check

**Test Checklist:**
- [ ] Update is detected correctly
- [ ] Release notes are displayed
- [ ] "Install and Relaunch" button appears
- [ ] Update downloads successfully
- [ ] Update installs without errors
- [ ] App relaunches automatically
- [ ] New version number shown in Settings
- [ ] No data loss (projects persist)

### Automatic Update Checks
**Test Checklist:**
- [ ] Setting "Check for updates automatically" works
- [ ] Automatic checks occur on schedule
- [ ] User is notified of available updates
- [ ] Can disable automatic checks
- [ ] Setting persists after restart

## UI/UX Polish

### Visual Consistency
**Test Checklist:**
- [ ] All fonts are consistent (SF Pro)
- [ ] Colors match design system
- [ ] Spacing is uniform throughout
- [ ] Icons are properly sized and aligned
- [ ] Hover states work on all interactive elements
- [ ] Selection states are clear and visible

### Dark Mode
**Test Checklist:**
- [ ] App respects system dark mode
- [ ] All text is readable in dark mode
- [ ] Colors have sufficient contrast
- [ ] Hover states visible in dark mode
- [ ] No white/light backgrounds appear

### Layout & Responsiveness
**Test Checklist:**
- [ ] Popover size is appropriate (400x500)
- [ ] Navigation split view works correctly
- [ ] Sidebar resizes properly
- [ ] Detail view fills available space
- [ ] Scrolling works smoothly
- [ ] No content clipping or overflow
- [ ] Text truncates properly (middle truncation for paths)

### Animations & Transitions
**Test Checklist:**
- [ ] Disclosure groups animate smoothly
- [ ] Hover effects are subtle and smooth
- [ ] Sheet presentations are smooth
- [ ] No jarring transitions or flashes

### Accessibility
**Test Checklist:**
- [ ] All buttons have accessible labels
- [ ] Keyboard navigation works
- [ ] VoiceOver reads elements correctly
- [ ] Sufficient color contrast ratios
- [ ] Help text available for key features

## Link Verification

### External Links
**Test Checklist:**
- [ ] GitHub repository link works (Settings → View on GitHub)
- [ ] GitHub releases link works (manual installation)
- [ ] Website link works (https://gitbar.app)
- [ ] Appcast URL is accessible
- [ ] All links open in default browser

### Internal Navigation
**Test Checklist:**
- [ ] Settings sheet opens/closes correctly
- [ ] Project selection works
- [ ] Section disclosure groups expand/collapse
- [ ] Add folder button opens file picker

## Error Handling

### Git Errors
**Test Checklist:**
- [ ] Invalid git repo shows error message
- [ ] Network errors show user-friendly message
- [ ] Authentication failures are handled
- [ ] Merge conflicts don't crash app
- [ ] Detached HEAD state handled gracefully
- [ ] Large repositories don't timeout

### File System Errors
**Test Checklist:**
- [ ] Missing project folders handled
- [ ] Permission denied errors shown clearly
- [ ] Deleted projects removed from list
- [ ] Inaccessible paths don't crash app

### Update Errors
**Test Checklist:**
- [ ] Failed update check shows error
- [ ] Network timeout handled gracefully
- [ ] Invalid appcast shows error message
- [ ] Download failures are recoverable

## Beta Testing

### Tester Recruitment
- [ ] Recruit 2-3 external beta testers
- [ ] Provide test build via DMG or TestFlight
- [ ] Send testing instructions
- [ ] Set up feedback collection method

### Feedback Areas
**Key questions for testers:**
1. Was installation smooth?
2. Did the app launch successfully?
3. Were your projects discovered correctly?
4. Is the UI intuitive and easy to use?
5. Did you encounter any bugs or crashes?
6. Is the performance acceptable?
7. Are there any confusing or unclear parts?
8. Would you use this app daily?

### Feedback Collection
**Methods:**
- GitHub Issues for bug reports
- Google Form for structured feedback
- Direct email/message for detailed feedback
- Screen recordings for UI/UX issues

## Known Issues Documentation

### Critical Issues (Blockers)
Document any issues that must be fixed before launch:
- [ ] None identified (or list below)

### Non-Critical Issues (Can defer)
Document minor issues for future releases:
- [ ] None identified (or list below)

### Limitations (By Design)
Document known limitations:
- macOS 13+ only (no support for older versions)
- Menubar app only (no Dock icon by design)
- Requires git command-line tools
- Limited to local repositories (no GitHub API integration)

## Test Results Summary

### Environment Tested
- macOS Version: _____
- Test Date: _____
- Tester: _____
- Installation Method: _____

### Overall Results
- [ ] All critical tests passed
- [ ] No blocking issues found
- [ ] Performance is acceptable
- [ ] Ready for v1.0.0 release

### Issues Found
1. _____
2. _____
3. _____

### Recommendations
- _____
- _____
- _____

## Pre-Launch Checklist

Before launching v1.0.0:
- [ ] All installation methods tested
- [ ] First-run experience validated
- [ ] All git operations working
- [ ] Performance benchmarks met
- [ ] Auto-updates tested successfully
- [ ] All links verified
- [ ] Beta tester feedback incorporated
- [ ] Known issues documented
- [ ] Release notes prepared
- [ ] Screenshots/demo recorded
- [ ] Marketing website ready
- [ ] Social media posts scheduled

## Post-Launch Monitoring

After launch, monitor:
- GitHub Issues for bug reports
- User feedback on social media
- Download/installation metrics
- Crash reports (if any)
- Update adoption rates

---

**Last Updated:** 2026-01-16
**Document Version:** 1.0
**Target Release:** v1.0.0
