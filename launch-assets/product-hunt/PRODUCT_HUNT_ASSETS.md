# Product Hunt Launch Assets

## Tagline
**Git status in your menubar. Stay in sync, effortlessly.**

## Short Description (60 chars)
Track git repos from your Mac menubar. Zero configuration.

## Product Description

GitBar is a lightweight macOS menubar app that keeps you in sync with your git repositories. Built for developers who use Claude Code, Codex, or any git-based workflow.

### The Problem
Switching between terminals, checking git status, wondering if you have uncommitted changes or unpushed commits - it breaks your flow. You lose track of which projects need attention.

### The Solution
GitBar lives quietly in your menubar, showing real-time git status for all your projects:
- Branch name and sync state at a glance
- Auto-discovers Claude Code and Codex projects
- Shows uncommitted changes and commits ahead/behind
- Click to see all your projects in one place
- Zero configuration required

### Why I Built This
As a developer working with AI coding tools like Claude Code, I kept losing track of which projects had changes. GitBar was born from the frustration of constantly running `git status` in multiple terminals. Now I can see everything at once, right in my menubar.

### Features
✨ Auto-discovers Claude Code and Codex projects
✨ Real-time git status monitoring
✨ Native macOS menubar integration
✨ Add any git repository folder
✨ Automatic updates via Sparkle
✨ Open source (MIT license)

### Perfect For
- Developers using Claude Code or Codex
- Anyone managing multiple git repositories
- Teams who want to stay in sync
- Solo developers juggling many projects

### Installation
Available via Homebrew: `brew install --cask gitbar`
Or download the DMG from GitHub releases.

Requires macOS 13.0 (Ventura) or later.

---

## Screenshots Needed

### 1. Hero Screenshot (1270x760)
**Filename**: `01-hero-menubar.png`
**Description**: Menubar icon showing git status with dropdown menu open
**Key elements to show**:
- GitBar icon in menubar
- Dropdown showing multiple projects
- Git status indicators (branch, ahead/behind, dirty/clean)
- Clean, professional macOS appearance

### 2. Project List View (1270x760)
**Filename**: `02-project-list.png`
**Description**: Full project list showing discovered Claude Code projects
**Key elements to show**:
- Multiple repositories listed
- Different git states (some clean, some with changes)
- Auto-discovered projects labeled
- Add folder button visible

### 3. Git Status Detail (1270x760)
**Filename**: `03-git-status.png`
**Description**: Close-up of git status information
**Key elements to show**:
- Branch name
- Commits ahead/behind remote
- Working directory status
- Last updated timestamp

### 4. Settings Panel (1270x760)
**Filename**: `04-settings.png`
**Description**: Settings view showing auto-update configuration
**Key elements to show**:
- Auto-update toggle
- Check for updates button
- About section
- Clean settings interface

### 5. Multiple Repos (1270x760)
**Filename**: `05-multiple-repos.png`
**Description**: Showing GitBar managing 5+ repositories simultaneously
**Key elements to show**:
- Mix of Claude Code, Codex, and manual folders
- Various git states
- Demonstrates scalability

---

## Demo GIF Requirements

**Filename**: `gitbar-demo.gif`
**Duration**: 10-15 seconds
**Size**: 1270x760 recommended
**FPS**: 15-20 fps to keep file size under 5MB

### Storyboard (10-15 seconds)

1. **[0-2s]** Start with clean desktop, show menubar
2. **[2-4s]** Click GitBar icon, dropdown opens smoothly
3. **[4-6s]** Hover over different projects, show git status updates
4. **[6-8s]** Click "Add Folder" button, file picker appears
5. **[8-10s]** Select a git repo, it appears in the list
6. **[10-12s]** Switch between projects, status updates in menubar
7. **[12-14s]** Click settings icon, settings panel slides in
8. **[14-15s]** Fade to GitBar logo/tagline

### Recording Tips
- Use Kap (https://getkap.co/) or LICEcap for recording
- Record at 2x scale, then optimize for web
- Keep file size under 5MB for Product Hunt
- No audio needed
- Smooth, deliberate mouse movements
- Clean desktop background (solid color or minimal)
- Hide other menubar items if possible

### Optimization
```bash
# Use gifsicle to optimize
gifsicle -O3 --colors 256 gitbar-demo.gif -o gitbar-demo-optimized.gif
```

---

## Product Hunt Maker Checklist

### Before Launch Day

- [ ] Create/verify Product Hunt maker account
- [ ] Add clear profile photo and bio
- [ ] Connect Twitter/X account
- [ ] Prepare all screenshots (5 images)
- [ ] Create and optimize demo GIF
- [ ] Write and refine product description
- [ ] Prepare first comment with additional context
- [ ] Set up GitHub releases page
- [ ] Verify download links work
- [ ] Test installation on clean Mac

### Launch Day Preparation

- [ ] Schedule launch for Tuesday or Wednesday
- [ ] Plan to launch at 12:01 AM PST for full 24hr visibility
- [ ] Have coffee ready ☕
- [ ] Clear calendar for first 4-6 hours to engage
- [ ] Prepare response templates for common questions

### Product Hunt Submission Fields

**Name**: GitBar
**Tagline**: Git status in your menubar. Stay in sync, effortlessly.
**Topics**: Developer Tools, macOS, Productivity, Open Source, Git
**Pricing**: Free (Open Source)
**Website**: https://gitbar.app
**Download Link**: https://github.com/burhanusman/gitbar/releases/latest

### First Comment Template

```
👋 Hey Product Hunt! I'm excited to share GitBar with you today.

As a developer working with AI coding tools like Claude Code, I constantly found myself switching between terminals just to run `git status` and check if I had uncommitted changes. It broke my flow.

GitBar solves this by putting git status right in your menubar - where it should be.

✨ What makes GitBar special:
• Zero configuration - auto-discovers Claude Code & Codex projects
• Real-time status updates
• Native macOS design
• Open source (MIT license)
• Free forever

🚀 Installation:
brew install --cask gitbar

I built this to scratch my own itch, and I hope it helps your workflow too!

Happy to answer any questions. What git workflow challenges do you face?

GitHub: https://github.com/burhanusman/gitbar
```

---

## Tips for Launch Day

### Engagement Strategy
- **First 4 hours are critical** - respond to every comment
- **Be authentic** - share your story, why you built it
- **Ask questions** - engage with commenters about their workflows
- **Thank hunters** if someone hunts it for you
- **Share progress updates** as you climb the rankings
- **Cross-post** to Twitter/X for amplification

### Common Questions to Prepare For
1. "How is this different from git in terminal?"
   - Always-visible status, no context switching, auto-discovery
2. "Does it work with GitHub Desktop?"
   - Works with any git repository, regardless of tools used
3. "Will it slow down my Mac?"
   - Lightweight, only polls git when active, minimal CPU/memory
4. "Can I customize what it shows?"
   - Future feature - vote on what you'd like to see!
5. "Does it work with private repos?"
   - Yes, it's local-only, no data leaves your Mac

### Metrics to Track
- Upvotes on Product Hunt
- Comments and engagement rate
- Website traffic (via analytics)
- GitHub stars
- Download count
- Homebrew install stats (cask analytics)

### Post-Launch Follow-up
- **Within 24 hours**: Thank top commenters
- **Day 2**: Share results on Twitter/X
- **Week 1**: Write a launch retrospective
- **Month 1**: Share user testimonials and updates
