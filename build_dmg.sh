#!/bin/bash
set -e

APP_NAME="OpenCodeStatusBall"
VERSION="0.1.1"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="/Users/xuhao/Documents/light/OpenCodeStatusBall/dmg_build"
DIST_DIR="/Users/xuhao/Documents/light/OpenCodeStatusBall/dist"
ICNS_PATH="${DIST_DIR}/AppIcon.icns"

# Create DMG background with gradient
create_dmg_background() {
    python3 << 'PYTHON'
import subprocess
import os

# Create a gradient background image
w, h = 640, 400
subprocess.run([
    'convert', '-size', f'{w}x{h}',
    'gradient:#1a1a2e-#16213e',
    '/tmp/dmg_background.png'
], check=True)
PYTHON
}

# Create icon for Applications shortcut
create_applications_icon() {
    # Create a symlink icon placeholder
    ln -sf /Applications "${BUILD_DIR}/Applications" 2>/dev/null || true
}

# Build DMG
build_dmg() {
    # Copy files
    cp -r "${BUILD_DIR}/${APP_NAME}.app" "${BUILD_DIR}/"
    
    # Create DMG
    hdiutil create -srcfolder "${BUILD_DIR}" \
        -volname "${DMG_NAME}" \
        -fs HFS+ \
        -format UDRO \
        -imagekey zlib-level=9 \
        -size 2m \
        "${DIST_DIR}/${DMG_NAME}.dmg"
    
    echo "DMG created: ${DIST_DIR}/${DMG_NAME}.dmg"
}

# Create final DMG with custom background
create_final_dmg() {
    # Create temporary DMG
    hdiutil create -srcfolder "${BUILD_DIR}" \
        -volname "${DMG_NAME}" \
        -fs HFS+ \
        -format UDRW \
        -size 2m \
        /tmp/${DMG_NAME}.tmp.dmg
    
    # Mount it
    MOUNT_POINT=$(hdiutil attach /tmp/${DMG_NAME}.tmp.dmg -nobrowse -noautoopen | awk '{print $NF}')
    
    # Copy background image
    # Create a simple gradient background using ImageMagick
    if command -v convert &> /dev/null; then
        convert -size 640x400 gradient:#1a1a2e-#16213e "${MOUNT_POINT}/.background.png" 2>/dev/null || true
    fi
    
    # Create AppleScript for window appearance
    osascript << EOF
tell application "Finder"
    tell disk "${DMG_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 1040, 500}
        set position of item "${APP_NAME}.app" of container window to {160, 200}
        set position of item "Applications" of container window to {480, 200}
        close
        open
        set position of container window to {100, 100}
    end tell
end tell
EOF
    
    # Unmount
    hdiutil detach "$MOUNT_POINT" -quiet
    
    # Convert to read-only
    hdiutil convert /tmp/${DMG_NAME}.tmp.dmg -format UDRO -imagekey zlib-level=9 -o "${DIST_DIR}/${DMG_NAME}.dmg"
    
    # Cleanup
    rm -f /tmp/${DMG_NAME}.tmp.dmg
    
    echo "Final DMG created: ${DIST_DIR}/${DMG_NAME}.dmg"
}

# Main
echo "Building DMG for ${APP_NAME} v${VERSION}..."
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

# Copy app to build dir
cp -r "${BUILD_DIR}/${APP_NAME}.app" "${BUILD_DIR}/" 2>/dev/null || true

# Create Applications symlink
ln -sf /Applications "${BUILD_DIR}/Applications" 2>/dev/null || true

# Build DMG
hdiutil create -srcfolder "${BUILD_DIR}" \
    -volname "${DMG_NAME}" \
    -fs HFS+ \
    -format UDRO \
    -imagekey zlib-level=9 \
    -size 2m \
    "${DIST_DIR}/${DMG_NAME}.dmg"

echo "✓ DMG created: ${DIST_DIR}/${DMG_NAME}.dmg"
ls -lh "${DIST_DIR}/${DMG_NAME}.dmg"
