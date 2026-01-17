# Claude Code Configuration

This file contains design context and guidelines for GitBar that inform all development and design decisions.

## Design Context

### Users

**Primary Audience:** Solo developers and indie hackers working on personal and side projects using Claude Code, Codex, or any git repositories.

**Context of Use:** GitBar lives in the menubar and is accessed during development when developers need quick visibility into their git status across multiple repos. Users are context-switching frequently between projects and need instant awareness of uncommitted changes, branch status, and the ability to perform common git operations without leaving their flow.

**Job to Be Done:** Provide instant git status visibility across all active projects and enable quick git operations (stage, commit, push, pull) without context-switching to terminal or opening a dedicated git client.

### Brand Personality

**Three Words:** Refined. Reliable. Effortless.

**Emotional Goals:**
- **Craft and Polish:** GitBar should feel like a beautifully crafted tool where every detail has been considered. Using it should feel satisfying and premium.
- **Reliability and Trust:** Git operations are critical - the app must inspire confidence that it will work correctly every time.

**Voice & Tone:**
- Concise and clear - no unnecessary words
- Confident but not verbose
- Professional but approachable
- Uses developer-friendly language without being overly technical

### Aesthetic Direction

**Visual Tone:** Modern productivity tool aesthetic inspired by Linear, Height, and Raycast - fast, refined, excellent typography and spacing with attention to micro-interactions.

**Key Characteristics:**
- Native macOS feel with SwiftUI's design language
- Dark mode optimized (primary use case)
- Subtle animations with spring physics for polish
- Clean hierarchy through typography and spacing, not decoration
- Purposeful use of color for status and state

**References:**
- **Linear/Height/Raycast:** Fast, refined interfaces with excellent typography, generous spacing, and satisfying micro-interactions
- **Native macOS utilities:** System-level polish and reliability

**Anti-References (Explicitly Avoid):**
- **Cluttered developer tools:** Not packed with buttons, panels, and excessive options
- **Overly minimal/sterile:** Should have personality and warmth, not feel clinical
- **Generic Electron apps:** Must feel native macOS, not Chrome-in-a-window
- **Trendy/flashy UI:** No gratuitous animations, neon colors, or design trends that age poorly

### Color Palette

**Functional Colors:**
- `#0A84FF` - Primary blue (branch info, uncommitted changes indicator, primary actions)
- `#30D158` - Success green (clean state, successful operations)
- `#FF453A` - Error red (failures, deleted files)
- `#BF5AF2` - Purple (Codex project badge, unmerged status)

**UI Colors:**
- `#1a1a1a` - Dark background (subtle containers)
- `#2a2a2a` - Interactive surfaces (buttons, selected states)
- System secondary/tertiary for text hierarchy

**Neutrals:**
- Tinted grays (never pure black/white)
- System colors for native macOS integration

### Typography

**Current Implementation:**
- System font (SF Pro) at various weights
- Size scale: 9px (badges) → 11px (labels) → 13px (body) → 15px (headings)
- Monospace design for file paths and status indicators
- Weight variations for hierarchy (medium, semibold)

**Best Practices:**
- Use fluid sizing sparingly - menubar apps need consistency
- Vary weight more than size for hierarchy
- Maintain readability at small sizes (11px minimum for body text)

### Spacing & Layout

**Current Patterns:**
- Compact but breathable spacing (6-16px range)
- Consistent padding: 12px horizontal for rows, 16px for containers
- 8px spacing between related elements
- Uses NavigationSplitView for sidebar + detail layout

**Principles:**
- Create visual rhythm through varied spacing
- Tight groupings, generous separations
- Asymmetric layouts where appropriate (left-aligned text)
- No cards-within-cards

### Design Principles

1. **Invisible Until Needed**
   - GitBar lives quietly in the menubar until you need it
   - Information hierarchy surfaces critical status immediately
   - Actions are discoverable but not demanding attention
   - The best interface disappears and lets you focus on git tasks

2. **Refined Micro-Interactions**
   - Every hover, click, and transition should feel intentional and satisfying
   - Spring physics for natural, polished motion
   - Subtle feedback for all interactive states
   - Delight comes from craft, not decoration

3. **Trust Through Consistency**
   - Git operations must be reliable and predictable
   - Clear feedback for all actions (loading, success, error states)
   - No surprises - users should always know what will happen
   - Visual consistency builds confidence

4. **Information, Not Decoration**
   - Every visual element serves a purpose
   - Color indicates state and status, not just aesthetics
   - Typography creates hierarchy without unnecessary decoration
   - Empty states are opportunities to teach and guide

5. **Native First**
   - Feels like it belongs in macOS
   - Respects system preferences (appearance, reduced motion)
   - Uses SF Symbols and system patterns
   - Performance and efficiency expected of native apps

---

## Implementation Notes

- Built with SwiftUI for native macOS (13.0+)
- Uses git CLI via Process for all operations
- Auto-discovers projects from Claude Code and Codex configs
- Supports manual folder addition for any git repository
- Menubar-only app (no Dock icon)
- Sparkle framework for auto-updates
