# GitBar Known Issues and Limitations

**Version:** 1.0.0
**Last Updated:** 2026-01-16

This document tracks known issues, limitations, and planned improvements for GitBar.

## Known Issues

### Critical Issues (Blockers)
*None identified as of 2026-01-16*

### Non-Critical Issues

#### 1. Empty State for Sparkle Updates
**Status:** Low Priority
**Description:** When Sparkle framework is not properly configured (missing EdDSA key), the auto-update functionality falls back to a mock implementation. This is by design for development builds.

**Impact:** Development builds will show "Checking..." but won't actually check for updates.

**Workaround:** This only affects development builds. Production releases with proper code signing and appcast configuration work correctly.

**Fix Plan:** No fix needed - intended behavior for development environment.

---

#### 2. Placeholder Public Key in Info.plist
**Status:** Must Fix Before Release
**Description:** The `SUPublicEDKey` in `GitBar/Info.plist` contains `PLACEHOLDER_PUBLIC_KEY` which must be replaced with actual EdDSA public key before release.

**Impact:** Auto-updates won't work without valid public key.

**Workaround:** Generate EdDSA key pair using Sparkle's `generate_keys` tool:
```bash
./Sparkle.framework/Versions/B/Resources/generate_keys
```

**Fix Plan:** Update during release process (see BUILD_RELEASE.md).

---

## Limitations (By Design)

### 1. macOS Version Support
**Description:** GitBar requires macOS 13.0 (Ventura) or later.

**Reason:** Uses SwiftUI features and APIs only available in macOS 13+.

**Impact:** Users on macOS 12 (Monterey) or earlier cannot use GitBar.

**Alternative:** None - upgrading macOS is the only option.

---

### 2. Menubar-Only Application
**Description:** GitBar runs as a menubar-only app with no Dock icon (`LSUIElement = true`).

**Reason:** Design choice to keep the app lightweight and non-intrusive.

**Impact:**
- No Dock icon for quick access
- Can't Command+Tab to the app
- Must click menubar icon or use Settings to interact

**Alternative:** None planned - this is core to the app's design.

---

### 3. Git Command-Line Dependency
**Description:** GitBar requires `git` to be installed and available in PATH.

**Reason:** Uses command-line `git` for all operations rather than implementing git protocol.

**Impact:** Won't work if git is not installed (rare on developer machines).

**Detection:** App checks for git on launch and shows error if missing.

**Fix:** Users must install Xcode Command Line Tools or Homebrew git.

---

### 4. Local Repository Only
**Description:** GitBar only works with local git repositories - no GitHub API integration.

**Reason:** Keeps the app simple, focused, and privacy-friendly (no network calls, no auth).

**Impact:**
- Can't show GitHub issues, PRs, or discussions
- Can't create PRs from the app
- Only shows what's in local git state

**Future Enhancement:** Possible future feature, but not planned for v1.0.

---

### 5. Single Remote Support
**Description:** GitBar assumes single remote named "origin" for push/pull operations.

**Reason:** Simplifies UI and covers 95% of use cases.

**Impact:** Projects with multiple remotes or non-standard remote names may not show correct ahead/behind counts.

**Workaround:** Works fine for most projects. Power users with complex remote setups can use terminal.

**Future Enhancement:** Could add remote selection in future versions.

---

### 6. No Merge Conflict Resolution UI
**Description:** GitBar doesn't provide UI for resolving merge conflicts.

**Reason:** Conflict resolution is complex and better handled in IDEs or terminal.

**Impact:** When conflicts occur during pull, user must resolve in external tool.

**Workaround:** App shows clear error message directing users to resolve conflicts externally.

**Future Enhancement:** Not planned - conflicts are rare and complex.

---

### 7. Limited Git Worktree Support
**Description:** Basic worktree detection but limited UI for managing worktrees.

**Reason:** Worktrees are advanced feature used by small subset of users.

**Impact:** Can detect and switch between worktrees, but can't create or delete them.

**Workaround:** Use terminal for advanced worktree management.

**Future Enhancement:** Possible if user demand exists.

---

## Performance Considerations

### 1. Large Repositories
**Description:** Repositories with 1000+ uncommitted files may experience slow refresh.

**Reason:** `git status` command itself is slow on large working directories.

**Impact:** Auto-refresh may cause brief UI lag on very large repos.

**Workaround:**
- Commit or stash changes regularly
- Add large files to `.gitignore`
- Disable auto-refresh in Settings (future feature)

**Metrics:** Tested with up to 500 files with acceptable performance.

---

### 2. Auto-Refresh Interval
**Description:** Status refreshes every 30 seconds (hardcoded).

**Reason:** Balance between freshness and performance.

**Impact:** Changes may not appear immediately (up to 30s delay).

**Workaround:** Click manual refresh button for immediate update.

**Future Enhancement:** Make refresh interval configurable.

---

## Privacy & Security

### 1. No Analytics or Telemetry
**Description:** GitBar collects zero data and makes no network calls (except Sparkle updates).

**Reason:** Privacy-first design philosophy.

**Impact:** Developer has no visibility into usage, crashes, or feature adoption.

**Trade-off:** Accepted - user privacy is more important than analytics.

---

### 2. No Credential Storage
**Description:** GitBar doesn't store or manage git credentials.

**Reason:** Security and simplicity - relies on system git credential helper.

**Impact:** Users must configure git credentials separately (SSH keys, credential helper).

**Workaround:** Standard git setup:
```bash
# SSH (recommended)
ssh-keygen -t ed25519
# Add public key to GitHub

# Or HTTPS with credential helper
git config --global credential.helper osxkeychain
```

---

## Documentation Gaps

### 1. Missing Demo Video/GIF
**Description:** README has placeholder for demo.gif but no actual demo.

**Status:** Todo before v1.0 launch.

**Impact:** Users can't see app in action before installing.

**Plan:** Record with Kap before launch (see TESTING.md).

---

### 2. No FAQ Section
**Description:** No centralized FAQ for common questions.

**Status:** Low priority.

**Impact:** Users may have unanswered questions.

**Plan:** Build FAQ based on GitHub Issues after launch.

---

## Compatibility Notes

### Apple Silicon (M1/M2/M3)
**Status:** ✅ Fully Supported
**Build:** Universal binary (arm64 + x86_64)

### Intel Macs
**Status:** ✅ Fully Supported
**Build:** Universal binary includes Intel slice

### Rosetta
**Status:** Not tested, not needed (universal binary)

---

## Testing Gaps

The following test scenarios have NOT been completed yet:

### Untested Scenarios
- [ ] Clean macOS 13 installation
- [ ] Clean macOS 14 installation
- [ ] Clean macOS 15 installation
- [ ] Homebrew installation on clean machine
- [ ] Auto-update flow (v1.0.0 → v1.0.1)
- [ ] Performance with 20+ projects
- [ ] Very large repositories (5000+ files)
- [ ] Repositories with submodules
- [ ] Repositories with LFS
- [ ] Multiple git worktrees (advanced)

### Partially Tested
- ✅ Basic git operations (commit, push, pull) - tested manually
- ✅ Project discovery - tested with Claude Code projects
- ⚠️ First-run experience - tested but not on clean machine
- ⚠️ Empty states - tested but not comprehensive

### Required Before Launch
See TESTING.md for comprehensive testing checklist.

---

## Reported Issues

*No user-reported issues yet - app not publicly released*

After launch, issues will be tracked at:
https://github.com/burhanusman/gitbar/issues

---

## Future Improvements (Not v1.0)

These are potential future enhancements, not committed features:

### Maybe Later
- [ ] Configurable auto-refresh interval
- [ ] Multiple remote support
- [ ] Branch creation/deletion UI
- [ ] Stash management UI
- [ ] Git log viewer
- [ ] Diff viewer
- [ ] GitHub integration (issues, PRs)
- [ ] GitLab/Bitbucket support
- [ ] Custom git command execution
- [ ] Keyboard shortcuts
- [ ] Project groups/favorites
- [ ] Status bar customization
- [ ] Dark/light mode toggle (currently system-only)

---

## How to Report Issues

### For Developers
1. Check this document first
2. Search existing issues: https://github.com/burhanusman/gitbar/issues
3. If not found, create new issue with:
   - macOS version
   - GitBar version (Settings → About)
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if relevant

### For Beta Testers
See BETA_TESTING_GUIDE.md for feedback instructions.

---

**Document Maintained By:** GitBar Development Team
**Next Review:** After v1.0 launch based on user feedback
