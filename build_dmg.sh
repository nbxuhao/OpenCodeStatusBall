#!/bin/bash
set -e

APP_NAME="OpenCodeStatusBall"
VERSION="0.1.1"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="/Users/xuhao/Documents/light/OpenCodeStatusBall/dmg_build"
DIST_DIR="/Users/xuhao/Documents/light/OpenCodeStatusBall/dist"

rm -rf "${BUILD_DIR}"
rm -f /tmp/${DMG_NAME}.tmp.dmg
mkdir -p "${BUILD_DIR}"

cp -r "${DIST_DIR}/${APP_NAME}.app" "${BUILD_DIR}/"
ln -sf /Applications "${BUILD_DIR}/Applications"

sips -Z 640 400 "${DIST_DIR}/AppIcon.png" -o "${BUILD_DIR}/.background.png" 2>/dev/null || \
cp "${DIST_DIR}/AppIcon.png" "${BUILD_DIR}/.background.png"

hdiutil create -srcfolder "${BUILD_DIR}" -volname "${DMG_NAME}" -fs HFS+ -format UDRW -size 2m /tmp/${DMG_NAME}.tmp.dmg

MOUNT_POINT=$(hdiutil attach /tmp/${DMG_NAME}.tmp.dmg -nobrowse -noautoopen 2>/dev/null | grep -o '/Volumes/[^ ]*' | head -1)

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    MOUNT_POINT=$(ls -d /Volumes/${DMG_NAME}* 2>/dev/null | head -1)
fi

echo "Mount point: $MOUNT_POINT"

if [ -d "$MOUNT_POINT" ]; then
    cp "${BUILD_DIR}/.background.png" "${MOUNT_POINT}/.background.png"
    
    osascript << 'EOF'
tell application "Finder"
    tell disk "OpenCodeStatusBall-0.1.1"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 1040, 500}
        set position of item "OpenCodeStatusBall.app" of container window to {160, 200}
        set position of item "Applications" of container window to {480, 200}
        close
        open
        set position of container window to {100, 100}
    end tell
end tell
EOF
    
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
fi

hdiutil convert /tmp/${DMG_NAME}.tmp.dmg -format UDRO -imagekey zlib-level=9 -o "${DIST_DIR}/${DMG_NAME}.dmg"

rm -f /tmp/${DMG_NAME}.tmp.dmg
rm -rf "${BUILD_DIR}"

echo "✓ DMG created: ${DIST_DIR}/${DMG_NAME}.dmg"
ls -lh "${DIST_DIR}/${DMG_NAME}.dmg"
