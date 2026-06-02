# -*- coding: utf-8 -*-
# dmgbuild settings for GitBar
# This creates a DMG with proper background that works in CI (no AppleScript needed)

import os
import sys

# Get paths from environment or use defaults
app_path = os.environ.get('APP_PATH', 'build/Release/GitBar.app')
dmg_resources = os.environ.get('DMG_RESOURCES', 'dmg-resources')

# Volume name
volume_name = 'GitBar'

# Volume format
format = 'UDBZ'

# Volume size (None = auto-calculate)
size = None

# Files to include
files = [app_path]

# Symlinks to create
symlinks = {'Applications': '/Applications'}

# Volume icon
icon = os.path.join(dmg_resources, 'AppIcon.icns')

# Background image (retina: 1800x800, display: 900x400)
background = os.path.join(dmg_resources, 'background.png')

# Window position on screen
window_rect = ((200, 120), (900, 400))

# Icon size
icon_size = 100

# Icon positions (based on 900x400 window)
# Centered layout: window center is 450
icon_locations = {
    'GitBar.app': (270, 200),
    'Applications': (630, 200),
}

# Hide file extensions
hide_extension = ['GitBar.app']

# Text size in Finder
text_size = 12

# License (optional)
# license = {
#     'default-language': 'en_US',
#     'licenses': {'en_US': 'LICENSE'},
# }
