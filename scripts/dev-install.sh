#!/bin/bash
set -euo pipefail

# Build, install, and launch a local build of GitBar.
# Intended for day-to-day development from any terminal location.

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    SOURCE_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    if [[ "$SOURCE" != /* ]]; then
        SOURCE="$SOURCE_DIR/$SOURCE"
    fi
done

SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="GitBar"
CONFIGURATION="${GITBAR_CONFIGURATION:-Debug}"
DERIVED_DATA="${GITBAR_DERIVED_DATA:-$PROJECT_DIR/build/DerivedData}"
DEFAULT_INSTALL_DIR="/Applications"

if [ ! -w "$DEFAULT_INSTALL_DIR" ]; then
    DEFAULT_INSTALL_DIR="$HOME/Applications"
fi

INSTALL_DIR="${GITBAR_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
BUILD_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME.app"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<EOF
Usage: gitbar-dev

Build, install, and open GitBar.

Environment overrides:
  GITBAR_CONFIGURATION=Release
  GITBAR_INSTALL_DIR="$HOME/Applications"
  GITBAR_DERIVED_DATA="$PROJECT_DIR/build/DerivedData"
EOF
    exit 0
fi

echo "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
    -project "$PROJECT_DIR/GitBar.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    build \
    -quiet

if [ ! -d "$BUILD_APP" ]; then
    echo "Build succeeded, but app bundle was not found at: $BUILD_APP" >&2
    exit 1
fi

echo "Stopping running $APP_NAME instances..."
pkill -x "$APP_NAME" 2>/dev/null || true

echo "Installing to $INSTALL_PATH..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_PATH"
ditto "$BUILD_APP" "$INSTALL_PATH"

echo "Opening $APP_NAME..."
open "$INSTALL_PATH"

echo "Done: $INSTALL_PATH"
