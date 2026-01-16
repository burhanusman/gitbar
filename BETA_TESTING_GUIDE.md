# GitBar Beta Testing Guide

Thank you for helping test GitBar before the v1.0.0 launch! Your feedback is invaluable.

## What is GitBar?

GitBar is a macOS menubar app that provides instant visibility into the git status of your development projects. It automatically discovers Claude Code and Codex projects, and allows you to monitor any git repository.

## Installation

You have two options for installing the beta:

### Option 1: DMG File (Recommended)
1. Download the DMG file provided
2. Open the DMG file
3. Drag GitBar.app to your Applications folder
4. Launch GitBar from Applications or Spotlight
5. Look for the git branch icon in your menubar

### Option 2: Build from Source
```bash
git clone https://github.com/burhanusman/gitbar.git
cd gitbar
open GitBar.xcodeproj
# Build and run in Xcode (⌘R)
```

## What to Test

### 1. Installation & First Launch (5 minutes)
- Does the installation work smoothly?
- Does the app launch without errors?
- Does the menubar icon appear?
- Is there a Dock icon? (There shouldn't be one!)
- Any security warnings or issues?

### 2. Project Discovery (5 minutes)
- Does GitBar find your Claude Code projects?
- Does GitBar find your Codex projects?
- Try adding a git repository manually (Add Folder button)
- Are all your projects showing up correctly?

### 3. Git Status Display (10 minutes)
- Select a project from the list
- Does the git status look accurate?
- Check branch name, ahead/behind counts, uncommitted changes
- Try projects with different git states:
  - Clean repository (no changes)
  - Uncommitted changes
  - Commits ahead of remote
  - Commits behind remote

### 4. Git Operations (10 minutes)
**Please test on a non-critical repository!**

- Try staging a file
- Try unstaging a file
- Create a commit with a message
- Try pushing to remote (if you have a remote setup)
- Try pulling from remote
- Does the UI update correctly after each operation?

### 5. Settings & Features (5 minutes)
- Open Settings (gear icon)
- Toggle "Check for updates automatically"
- Click "Check for Updates" button
- Open the GitHub link - does it work?
- Check the app version number

### 6. Performance (5 minutes)
- How does the app perform with your projects?
- Is the UI responsive?
- Any lag or freezing?
- How's the memory/CPU usage? (Check Activity Monitor)

### 7. Overall Experience (5 minutes)
- Is the UI intuitive and easy to understand?
- Does anything feel confusing or unclear?
- Are there any visual bugs or layout issues?
- Does the app do what you expected?

## Feedback Form

Please answer these questions and send your feedback:

### Installation
- [ ] Installation was smooth
- [ ] Installation had issues (describe below)

**Notes:**


### Functionality
- [ ] All features worked as expected
- [ ] Some features had issues (describe below)

**Notes:**


### Performance
- [ ] Performance is excellent
- [ ] Performance is acceptable
- [ ] Performance needs improvement (describe below)

**Notes:**


### User Interface
- [ ] UI is intuitive and easy to use
- [ ] UI is confusing in some areas (describe below)

**Notes:**


### Bugs Found
Please describe any bugs you encountered:

1.
2.
3.

### Feature Requests
Any features you wish GitBar had?

1.
2.
3.

### Overall Impression
Rate your experience (1-5 stars): ⭐

Would you use GitBar daily? Yes / No

Any other comments:


## Reporting Issues

### For Bugs
Please include:
1. **What you did:** Step-by-step actions
2. **What happened:** The actual result
3. **What you expected:** The expected result
4. **Screenshots:** If applicable
5. **Environment:**
   - macOS version
   - GitBar version
   - Installation method (DMG/source)

### Where to Report
- **GitHub Issues:** https://github.com/burhanusman/gitbar/issues
- **Email:** [your email here]
- **Direct message:** [your contact method]

## Privacy & Data

GitBar runs entirely locally on your machine:
- No data is sent to external servers
- No analytics or tracking
- No account required
- Open source - you can inspect the code

## Beta Testing Timeline

- **Beta Start:** [Date]
- **Feedback Deadline:** [Date]
- **Target Launch:** [Date]

## Questions?

If you have any questions during testing:
- Check the [README](README.md) for basic usage
- Open an issue on GitHub
- Contact [your contact method]

## Thank You! 🙏

Your testing helps make GitBar better for everyone. We appreciate your time and feedback!

---

**Beta Version:** 1.0.0-beta
**Test Build Date:** 2026-01-16
