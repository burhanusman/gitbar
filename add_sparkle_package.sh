#!/bin/bash

# Script to add Sparkle 2 package dependency to GitBar Xcode project
# This script must be run manually or from Xcode

set -e

echo "=== Adding Sparkle 2 Package to GitBar ==="
echo ""
echo "IMPORTANT: This requires Xcode to be installed."
echo ""
echo "To add Sparkle 2 package dependency:"
echo ""
echo "1. Open GitBar.xcodeproj in Xcode"
echo "2. Select the GitBar project in the navigator"
echo "3. Select the 'GitBar' target"
echo "4. Go to the 'Package Dependencies' tab"
echo "5. Click '+' button"
echo "6. Enter package URL: https://github.com/sparkle-project/Sparkle"
echo "7. Set dependency rule to: 'Up to Next Major Version' with 2.0.0"
echo "8. Click 'Add Package'"
echo "9. Ensure 'Sparkle' is added to the GitBar target"
echo "10. Build the project"
echo ""
echo "Alternatively, if you have xcodebuild and xcode-select configured:"
echo ""
echo "  xed GitBar.xcodeproj"
echo ""
echo "Then follow steps 2-10 above."
echo ""
echo "For automated CI/CD, the package will be resolved automatically when:"
echo "  - Package.resolved is committed to git"
echo "  - xcodebuild is run with -resolvePackageDependencies"
echo ""
