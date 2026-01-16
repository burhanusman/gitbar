# GitBar Demo GIF

## Requirements

**Specs:**
- **Duration**: 10-15 seconds
- **Resolution**: 1270x760 (minimum)
- **File Size**: < 5MB (for Product Hunt/Twitter)
- **Frame Rate**: 15-20 FPS
- **Format**: GIF

---

## Storyboard (10-15 seconds)

Follow this sequence for a compelling demo:

### [0-2s] Introduction
- Start with clean desktop
- Show macOS menubar clearly
- GitBar icon visible

### [2-4s] Open Menu
- Click GitBar menubar icon
- Dropdown menu smoothly opens
- Show 3-4 projects listed

### [4-6s] Hover Interaction
- Hover over different projects
- Show git status updates in menubar (if implemented)
- Demonstrate interactivity

### [6-8s] Add Project
- Click "Add Folder" button
- File picker appears
- Select a git repository

### [8-10s] Project Added
- New project appears in list
- Show its git status
- Menubar updates (if applicable)

### [10-12s] Switch Projects
- Click between different projects
- Menubar status updates for each
- Demonstrates core functionality

### [12-14s] Settings (Optional)
- Click settings icon
- Settings panel slides in
- Show auto-update options

### [14-15s] Closing
- Return to menubar view
- Clean end state
- Or fade to GitBar logo

---

## Recording Tools

### Option 1: Kap (Recommended) ⭐

**Install:**
```bash
brew install --cask kap
```

**Recording:**
1. Launch Kap
2. Click menubar icon → "New Recording"
3. Select screen area (1270x760 or larger)
4. Click "Start Recording"
5. Perform demo actions (practice first!)
6. Click "Stop" in menubar
7. Configure export settings:
   - Format: GIF
   - FPS: 15 (balance quality/size)
   - Quality: Adjust to stay under 5MB
8. Export

**Kap Plugins (Optional):**
- `kap-trim` - Trim recording
- `kap-optimize` - Better compression

### Option 2: LICEcap (Simpler)

**Install:**
```bash
brew install --cask licecap
```

**Recording:**
1. Launch LICEcap
2. Position window over area to record
3. Resize to ~1270x760
4. Set FPS: 15-20
5. Click "Record"
6. Choose save location: `gitbar-demo.gif`
7. Perform demo actions
8. Click "Stop"

### Option 3: Record Video, Convert to GIF

**Record with macOS:**
```bash
# Press Cmd+Shift+5 → Record Selected Portion
# Save as .mov
```

**Convert to GIF:**
```bash
# Install ffmpeg
brew install ffmpeg

# Convert (adjust settings for size)
ffmpeg -i demo.mov -vf "fps=15,scale=1270:-1:flags=lanczos" -c:v gif gitbar-demo.gif

# If too large, reduce FPS or scale
ffmpeg -i demo.mov -vf "fps=10,scale=800:-1:flags=lanczos" -c:v gif gitbar-demo-small.gif
```

---

## Optimization

If your GIF is > 5MB, optimize it:

### Using gifsicle

**Install:**
```bash
brew install gifsicle
```

**Optimize:**
```bash
# Optimize with lossy compression
gifsicle -O3 --lossy=80 --colors 256 gitbar-demo.gif -o gitbar-demo-optimized.gif

# Check file size
ls -lh gitbar-demo-optimized.gif

# If still too large, reduce colors
gifsicle -O3 --lossy=100 --colors 128 gitbar-demo.gif -o gitbar-demo-optimized.gif
```

### Using ImageOptim

```bash
# Install
brew install --cask imageoptim

# Drag GIF to ImageOptim
# It will compress automatically
```

---

## Recording Tips

### Before Recording

**Environment:**
- Clean desktop (solid color or minimal wallpaper)
- Hide unnecessary menubar items
- Close distracting applications
- Disable notifications (Do Not Disturb)

**GitBar Setup:**
- Have multiple git repositories ready
- Different git states (clean, dirty, ahead, behind)
- One repository ready to add manually

**Practice:**
- Run through the storyboard 2-3 times
- Time yourself (should be 10-15 seconds)
- Smooth, deliberate mouse movements

### During Recording

**Mouse Movement:**
- Slow and deliberate (not rushed)
- Pause briefly on each action
- Avoid unnecessary movements
- No erratic cursor jumping

**Pacing:**
- 2 seconds per major action
- Don't rush - viewers need time to see
- Smooth transitions between states

**Common Mistakes:**
- Moving too fast
- Mouse cursor off-screen
- Text too small to read
- Too many actions (keep it simple)

---

## Testing the Demo

Before finalizing, test your demo:

**Checklist:**
- [ ] File size < 5MB
- [ ] Duration 10-15 seconds
- [ ] All text readable
- [ ] Smooth playback (no stuttering)
- [ ] Demonstrates core functionality clearly
- [ ] Professional appearance
- [ ] Loops well (if applicable)

**Preview:**
- Upload to Imgur or GIPHY as private
- View on different devices
- Check mobile playback
- Ensure Twitter/Product Hunt compatibility

---

## Alternative: Video Demo

If you prefer video over GIF (for YouTube, website):

**Record:**
```bash
# Use macOS screen recording (Cmd+Shift+5)
# Or QuickTime Player → File → New Screen Recording
```

**Edit (Optional):**
- iMovie (free, built-in)
- Final Cut Pro (professional)
- DaVinci Resolve (free, powerful)

**Export:**
- Format: MP4 (H.264)
- Resolution: 1920x1080 or higher
- Duration: 60-90 seconds for full demo
- Upload to YouTube as unlisted

---

## File Naming

**Primary:**
```
gitbar-demo.gif
```

**If you create multiple versions:**
```
gitbar-demo-full.gif       # Full 15s demo
gitbar-demo-short.gif      # Quick 5s demo
gitbar-demo-twitter.gif    # Optimized for Twitter
gitbar-demo.mp4            # Video version
```

---

## Distribution

### Where to Use

**Product Hunt:**
- Upload as product demo
- Max 5MB
- GIF preferred over video

**Twitter:**
- Attach to launch tweet
- Max 5MB for GIF
- Max 512MB for video (MP4)

**Website:**
- Can use higher quality
- Consider video for homepage
- GIF for quick demos

**GitHub README:**
- Reference from docs/images/
- Keep under 10MB for fast loading
- Or link to YouTube for video

---

## Checklist

- [ ] Demo GIF created (gitbar-demo.gif)
- [ ] Duration: 10-15 seconds
- [ ] File size: < 5MB
- [ ] Resolution: 1270x760 minimum
- [ ] Tested playback
- [ ] Loops smoothly
- [ ] Text is readable
- [ ] Demonstrates core features
- [ ] Professional appearance
- [ ] Saved to this directory

---

## Examples & Inspiration

Look at demos from successful Product Hunt launches:

- **Raycast** - Clean, focused demos showing key features
- **Rectangle** - Simple, effective window management demo
- **Ice** - macOS menubar app demo (similar to GitBar)

Search "macOS menu bar app demo" on Product Hunt for more examples.

---

**Status**: To be created before launch
**Required for**: Product Hunt, Twitter
**Priority**: High - critical for launch
**Estimated time**: 1-2 hours (including practice and optimization)

---

## Need Help?

If you're struggling with GIF creation:
- Kap has great documentation: https://getkap.co
- GIPHY has guides: https://giphy.com/create/gifmaker
- Ask in Product Hunt makers community
