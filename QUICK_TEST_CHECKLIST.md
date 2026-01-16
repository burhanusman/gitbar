# GitBar Quick Test Checklist

**Use this checklist for rapid testing before releases or after making changes.**

## Pre-Test Setup
- [ ] Build succeeds without errors or warnings
- [ ] App launches successfully
- [ ] Menubar icon appears

## Core Functionality (5 min)

### Project Discovery
- [ ] Claude Code projects detected (if any)
- [ ] Codex projects detected (if any)
- [ ] Can add folder manually
- [ ] Invalid folder rejected with error

### Git Status Display
- [ ] Select a project
- [ ] Branch name shows correctly
- [ ] Uncommitted changes indicator works (blue dot)
- [ ] Working tree status accurate
- [ ] Ahead/behind counts correct (if applicable)

### Basic Git Operations
- [ ] Stage a file
- [ ] Unstage a file
- [ ] Write commit message
- [ ] Create commit
- [ ] Push works (if remote configured)
- [ ] Pull works (if remote configured)

### UI/UX
- [ ] No layout glitches or misalignments
- [ ] Hover states work on all buttons
- [ ] Text is readable
- [ ] No visual bugs
- [ ] Popover size appropriate (400x500)

### Settings
- [ ] Settings opens (gear icon)
- [ ] Can toggle "Check for updates automatically"
- [ ] "Check Now" button works
- [ ] "View on GitHub" opens browser
- [ ] App version displays correctly

## Edge Cases (3 min)

### Empty States
- [ ] No projects: shows "No repos found"
- [ ] No selection: shows "Select a project"
- [ ] Clean repo: shows "Working tree clean"

### Error Handling
- [ ] Invalid git repo: shows error
- [ ] Network error during push/pull: shows error message
- [ ] Empty commit message: commit button disabled

### Performance
- [ ] No freezing or lag
- [ ] Auto-refresh works (30s interval)
- [ ] Manual refresh button works

## Installation (if testing DMG/Homebrew)

### DMG Installation
- [ ] DMG opens without errors
- [ ] Drag to Applications works
- [ ] No Gatekeeper warnings (if notarized)
- [ ] Launches from Applications

### Homebrew (if testing cask)
```bash
brew install --cask gitbar
```
- [ ] Installs without errors
- [ ] Launches successfully

## Quick Regression Test (2 min)

After making code changes:
- [ ] Build still succeeds
- [ ] App still launches
- [ ] Can still select project
- [ ] Can still commit changes
- [ ] Settings still opens

## Pass Criteria

All items must pass for release approval:
- [ ] All core functionality works
- [ ] No visual bugs
- [ ] No crashes or freezes
- [ ] No error messages during normal use

---

**Test Date:** _____
**Tested By:** _____
**Build Version:** _____
**macOS Version:** _____
**Result:** ✅ Pass / ❌ Fail

**Notes:**
