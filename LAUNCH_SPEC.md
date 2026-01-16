# GitBar Launch Specification

## Problem Statement

GitBar exists but isn't production-ready. Users can't easily discover or install it, the UI looks unpolished, and there's no professional web presence. We need a complete launch package: beautiful UI, frictionless distribution, professional marketing, and open-source community setup.

## Target User

**Persona:** Developer who uses Claude Code or Codex daily, switches between multiple projects frequently, wants quick git status visibility without leaving their workflow.

**Trigger:** Getting frustrated opening Terminal or IDE just to check git status, or losing track of which projects have uncommitted changes.

## Non-Goals

- **Not building**: Windows/Linux versions (macOS only for v1)
- **Not building**: Advanced git features (rebase, merge conflict resolution, stash management)
- **Not building**: Integration with GitHub/GitLab APIs (local git only)
- **Not building**: Multiple window support (single popover only)
- **Not seeking**: Active open-source contributors yet (transparent, but not community-driven)
- **Not optimizing**: For giant repos (>10k files) - good enough performance is acceptable

## User Flow: Discovery to Daily Use

### First-Time Installation (Homebrew)
1. User hears about GitBar on Product Hunt/Twitter
2. Visits gitbar.app, sees clean one-pager with value prop
3. Copies Homebrew command: `brew install --cask gitbar`
4. Terminal installs and launches GitBar
5. App appears in menubar (branch icon)
6. User clicks icon → popover opens
7. Auto-discovery finds all Claude/Codex projects
8. User clicks a project → sees git status immediately

### First-Time Installation (DMG)
1. User visits gitbar.app, clicks "Download DMG"
2. Downloads GitBar-v1.0.0.dmg from GitHub
3. Opens DMG → drags app to Applications
4. Launches app (no Gatekeeper warning due to notarization)
5. App appears in menubar
6. (Same as steps 6-8 above)

### Daily Usage
1. User working in Claude Code on project A
2. Switches to project B in menubar
3. Sees uncommitted changes (visual indicator)
4. Clicks project B → views changed files
5. Stages files, writes commit message, commits
6. Pushes to remote (single click)
7. Switches back to project A
8. Repeat

### Auto-Update Experience
1. Week later, v1.1.0 releases
2. GitBar detects update (Sparkle check)
3. Shows notification: "Update available"
4. User clicks "Install and Relaunch"
5. App updates seamlessly, relaunches
6. User sees new features in release notes

## Requirements: Must-Have (MVP Launch)

### UI Polish
- **Minimalist dark theme** matching codexbar.app aesthetic
- **Consistent spacing**: 16px padding headers, 12px sidebar, 8px list items
- **Typography**: SF Pro Text, 13px body / 11px secondary / 15px headers
- **Color palette**: Grays (#1a1a1a, #2a2a2a, #3a3a) + blue accent (#0A84FF)
- **Settings panel** as separate sheet (400x300), not inline
- **Proper hover states** for all interactive elements

### Distribution
- **Homebrew cask** for one-command install
- **Signed and notarized DMG** for direct download
- **Sparkle auto-updates** with daily check, manual "Check now" button
- **GitHub Releases** as single source of truth for downloads

### Website
- **Next.js on Vercel**, separate repo (gitbar-website)
- **One-page design**: hero, features (3-4), screenshot, install, footer
- **Dark mode only**, minimalist, fast (<1s load)
- **Vercel Analytics** for visitor tracking
- **Custom domain**: gitbar.app (purchase via Namecheap)

### Open Source
- **MIT License** for maximum permissiveness
- **README.md**: features, screenshots, install, build instructions
- **CONTRIBUTING.md + CODE_OF_CONDUCT** (standard templates)
- **BUILD.md**: detailed build process for developers
- **Issue templates**: bug report, feature request

### Launch Campaign
- **Product Hunt**: screenshots, demo GIF, engaging description
- **Twitter/X**: 3-5 tweet thread with visual
- **Press kit**: logos (SVG/PNG), screenshots, description
- **Timing**: Tuesday/Wednesday for max Product Hunt visibility

## Requirements: Should-Have (Post-Launch v1.1)

- **Keyboard shortcuts** for common actions (Cmd+R refresh, Cmd+1-9 switch projects)
- **Search/filter** in project list
- **Custom refresh intervals** in settings
- **Export settings** for backup/sync
- **Crash reporting** (Sentry or similar)

## Requirements: Nice-to-Have (Icebox)

- **Branch switching UI** in popover
- **Diff viewer** for changed files
- **Multiple repo batch operations**
- **GitLab/GitHub issue integration**
- **Custom themes** (light mode, custom colors)

## Edge Cases and How We Handle Them

### Project Discovery
- **~/.claude or ~/.codex missing**: Gracefully show empty state, explain where to find projects
- **Invalid git repos**: Skip silently, log to console for debugging
- **Duplicate projects** (same path in Claude + Codex): Show once, badge with "Claude, Codex"
- **Very large project lists (50+)**: Scrollable sidebar, search filter (v1.1)

### Git Operations
- **No remote configured**: Disable push/pull buttons, show tooltip
- **Merge conflicts**: Show error message, suggest opening Terminal
- **Large commits (100+ files)**: Show loading spinner, don't block UI
- **Git command fails**: Show error alert with actual git output

### Updates
- **Sparkle update fails**: User can manually download DMG, app continues working
- **Network offline during update check**: Fail silently, retry next check
- **User declines update**: Remember choice, ask again in 7 days

### Installation
- **Gatekeeper blocks app** (shouldn't happen if notarized): Document right-click → Open workaround
- **Homebrew not installed**: Website shows DMG download as alternative
- **macOS 12 or earlier**: App won't run, state requirement clearly on website

## MVP Scope: What Ralph Needs to Build

Ralph should implement all 14 user stories in sequence:

1. **LAUNCH-001-003**: UI redesign + Codex support (foundation)
2. **LAUNCH-004**: Logo design (can parallelize or outsource)
3. **LAUNCH-005-007**: Code signing + Sparkle + DMG (distribution core)
4. **LAUNCH-008**: Homebrew cask (after DMG ready)
5. **LAUNCH-009**: Open source prep (documentation)
6. **LAUNCH-010-011**: Website (separate repo, can parallelize)
7. **LAUNCH-012**: Release automation (GitHub Actions)
8. **LAUNCH-013**: Launch assets (marketing materials)
9. **LAUNCH-014**: Testing and polish (final QA)

**Estimated timeline**: 2-3 weeks if working full-time, 4-6 weeks part-time.

## Open Questions and Assumptions

### Decisions Made (Opinionated Choices)
- **Domain**: gitbar.app (assume available, ~$12/year from Namecheap)
- **Hosting**: Vercel for website (free tier), GitHub for DMG hosting (free)
- **Auto-updates**: Daily check, user can disable in settings
- **Menubar icon**: Use current branch symbol, iterate if needed post-launch
- **Launch timing**: ASAP = 2-3 weeks from now, targeting mid-week Product Hunt launch

### Unresolved Questions
1. **Logo design**: DIY in Figma or hire designer (~$50 Fiverr)? → Recommend DIY for speed, iterate later
2. **Website copy**: Who writes it? → Draft in LAUNCH-011, user edits before launch
3. **Beta testing**: How many testers? → 2-3 friends/colleagues, informal feedback
4. **Analytics beyond Vercel**: GitHub stars, download count tracking? → Manual for now, automate later
5. **Support channel**: GitHub Issues only, or add Discord/email? → GitHub Issues only (keep it simple)

### Risks and Mitigations
- **Risk**: Notarization takes hours/fails → **Mitigation**: Test early (LAUNCH-005), document workarounds
- **Risk**: Product Hunt launch flops → **Mitigation**: Pre-seed with friends, engage in comments actively
- **Risk**: Homebrew PR rejected → **Mitigation**: Follow cask guidelines exactly, test locally first
- **Risk**: Logo looks amateur → **Mitigation**: Get designer feedback before finalizing, iterate fast

## Technical Decisions

### Why Sparkle over manual updates?
- **Users expect auto-updates** in native Mac apps (standard practice)
- **Reduces support burden** (users always on latest version)
- **Sparkle 2 is mature**, well-documented, free

### Why separate website repo?
- **Different deploy cycle** (website updates ≠ app updates)
- **Different tech stack** (Next.js vs Swift)
- **Cleaner organization** (app developers don't need website code)

### Why DMG + Homebrew instead of Mac App Store?
- **Mac App Store**: Sandboxing breaks filesystem access, $99/year + review delays
- **DMG**: Industry standard for developer tools, full filesystem access
- **Homebrew**: Expected by developer audience, trivial install

### Why dark mode only?
- **Target audience**: Developers overwhelmingly prefer dark mode
- **Simplifies design**: Half the work, faster iteration
- **Matches aesthetic**: codexbar.app, modern dev tools are dark-first

## Success Metrics (Post-Launch)

- **Day 1**: 100+ downloads, 50+ GitHub stars
- **Week 1**: 500+ downloads, Product Hunt top 10 in dev tools
- **Month 1**: 1,000+ active users, 200+ GitHub stars
- **Qualitative**: Positive comments on PH/Twitter, feature requests flowing in

---

**Ready for Ralph**: This spec + prd-launch.json = complete blueprint for launch. Ralph should execute stories in order, ask questions if ambiguous, and ship iteratively.
