# GitBar Screenshots

## Required Screenshots

Create 5 screenshots at **1270x760** resolution for Product Hunt and press use.

### 1. Hero Menubar (01-hero-menubar.png)
**What to show:**
- GitBar icon in macOS menubar
- Dropdown menu open showing projects
- 3-4 projects with different git states
- Clean, professional appearance

**Tips:**
- Clean desktop background
- Hide unnecessary menubar items
- Ensure text is readable

---

### 2. Project List (02-project-list.png)
**What to show:**
- Full project list view
- Mix of Claude Code, Codex, and manual folders
- Different git states (clean, dirty, ahead, behind)
- "Add Folder" button visible

**Tips:**
- Show at least 5-6 projects
- Variety of states demonstrates functionality
- Make labels clear

---

### 3. Git Status Detail (03-git-status.png)
**What to show:**
- Close-up of git status information
- Branch name
- Commits ahead/behind remote
- Working directory status
- Last updated timestamp

**Tips:**
- Zoom in so details are readable
- Show a realistic branch name
- Include both uncommitted changes and ahead/behind info

---

### 4. Settings Panel (04-settings.png)
**What to show:**
- Settings view open
- Auto-update toggle
- Check for updates button
- About section with version

**Tips:**
- Show auto-update enabled
- Version info visible
- Clean, organized layout

---

### 5. Multiple Repos (05-multiple-repos.png)
**What to show:**
- Managing 5-8 repositories simultaneously
- Mix of project types
- Various git states
- Demonstrates scalability

**Tips:**
- More projects = better demonstration
- Scroll view showing more items
- Shows real-world usage

---

## How to Create Screenshots

### Using macOS Screenshot Tool (Built-in)

1. **Launch GitBar** in the state you want to capture
2. **Press Cmd+Shift+5** to open Screenshot tool
3. **Select "Capture Selected Window"** or "Capture Selected Portion"
4. **Click the window** or select the area to capture
5. **Screenshot saves** to Desktop by default
6. **Rename and move** to this directory

### Using Kap (Better Quality)

```bash
# Install Kap
brew install --cask kap

# Use Kap's screenshot feature for high-quality captures
```

### Resize if Needed

If your screenshots are not exactly 1270x760:

**Using Preview (Built-in):**
1. Open screenshot in Preview
2. Tools → Adjust Size
3. Width: 1270, Height: 760
4. Uncheck "Scale proportionally" if needed
5. OK

**Using ImageMagick:**
```bash
# Install
brew install imagemagick

# Resize
convert input.png -resize 1270x760! output.png
```

---

## Optimization

Keep file sizes reasonable (< 500KB per image if possible):

**Using ImageOptim:**
```bash
# Install
brew install --cask imageoptim

# Drag screenshots to ImageOptim to compress
```

**Using Preview:**
1. Open in Preview
2. File → Export
3. Quality: ~70-80%
4. Save

---

## File Naming Convention

```
01-hero-menubar.png
02-project-list.png
03-git-status.png
04-settings.png
05-multiple-repos.png
```

Use this exact naming so scripts/documentation can reference them consistently.

---

## Retina Screenshots (Optional)

For very high-quality press use, create 2x versions:

```
retina/
├── 01-hero-menubar@2x.png (2540x1520)
├── 02-project-list@2x.png
├── ...
```

Most platforms will downscale automatically, but having high-res versions available is nice for print media.

---

## Checklist

- [ ] 01-hero-menubar.png (1270x760)
- [ ] 02-project-list.png (1270x760)
- [ ] 03-git-status.png (1270x760)
- [ ] 04-settings.png (1270x760)
- [ ] 05-multiple-repos.png (1270x760)
- [ ] All images optimized (< 500KB each)
- [ ] Clear, readable text in all screenshots
- [ ] Professional appearance (clean desktop, etc.)

---

**Status**: To be created before launch
**Required for**: Product Hunt, Twitter, Press Kit
**Priority**: High - needed for launch day
