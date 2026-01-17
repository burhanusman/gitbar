#!/bin/bash
set -e

# Simple release script for GitBar
# Usage: ./scripts/release.sh [patch|minor|major]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the bump type (default to patch)
BUMP_TYPE="${1:-patch}"

if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'${NC}"
    echo "Usage: $0 [patch|minor|major]"
    echo ""
    echo "  patch  - Bug fixes (1.0.0 → 1.0.1)"
    echo "  minor  - New features (1.0.0 → 1.1.0)"
    echo "  major  - Breaking changes (1.0.0 → 2.0.0)"
    exit 1
fi

# Get the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "Current version: ${YELLOW}$LATEST_TAG${NC}"

# Remove 'v' prefix and split into parts
VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

# Bump the version
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="v$MAJOR.$MINOR.$PATCH"
echo -e "New version:     ${GREEN}$NEW_VERSION${NC} ($BUMP_TYPE bump)"
echo ""

# Show recent commits since last tag
echo "Commits since $LATEST_TAG:"
git log --oneline "$LATEST_TAG"..HEAD 2>/dev/null | head -10 || echo "  (none)"
echo ""

# Confirm
read -p "Create and push tag $NEW_VERSION? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create and push the tag
echo ""
echo "Creating tag $NEW_VERSION..."
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"

echo "Pushing tag to origin..."
git push origin "$NEW_VERSION"

echo ""
echo -e "${GREEN}✓ Released $NEW_VERSION${NC}"
echo ""
echo "GitHub Actions will now build and publish the release."
echo "Watch progress: https://github.com/burhanusman/gitbar/actions"
