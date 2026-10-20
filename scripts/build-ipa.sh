#!/bin/bash
#
# build-ipa.sh
# AdShield IPA Build Script
#
# Usage:
#   ./scripts/build-ipa.sh [debug|release]
#
# Prerequisites:
#   - macOS with Xcode 14+ installed
#   - Valid Apple Developer account
#   - Team ID, signing certificate, and provisioning profile configured
#

set -euo pipefail

# Configuration (replace placeholders before use)
TEAM_ID="${TEAM_ID:-YOUR_TEAM_ID}"
BUNDLE_ID="${BUNDLE_ID:-com.YOUR_ORG.AdShield}"
EXTENSION_BUNDLE_ID="${BUNDLE_ID}.DNSProxy"
APP_GROUP_ID="${APP_GROUP_ID:-group.com.YOUR_ORG.AdShield}"
PROVISIONING_PROFILE_APP="${PROVISIONING_PROFILE_APP:-YOUR_APP_PROVISIONING_PROFILE}"
PROVISIONING_PROFILE_EXT="${PROVISIONING_PROFILE_EXT:-YOUR_EXTENSION_PROVISIONING_PROFILE}"
CERTIFICATE_NAME="${CERTIFICATE_NAME:-Apple Development: YOUR_NAME (YOUR_TEAM_ID)}"

# Build configuration
BUILD_CONFIG="${1:-release}"
SCHEME="AdShield"
PROJECT="AdShield.xcodeproj"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/AdShield.xcarchive"
EXPORT_PATH="${BUILD_DIR}/exported"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== AdShield IPA Build Script ===${NC}"
echo "Build configuration: ${BUILD_CONFIG}"
echo ""

# Validate prerequisites
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

if [ "${TEAM_ID}" = "YOUR_TEAM_ID" ]; then
    echo -e "${YELLOW}Warning: TEAM_ID is not configured. Set the TEAM_ID environment variable.${NC}"
    echo "Example: TEAM_ID=ABCD123456 ./scripts/build-ipa.sh"
fi

# Clean build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 1: Archive
echo -e "${GREEN}[1/3] Creating archive...${NC}"
xcodebuild archive \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${BUILD_CONFIG}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=iOS" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_IDENTITY="${CERTIFICATE_NAME}" \
    PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_APP}" \
    | tee "${BUILD_DIR}/archive.log"

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}Archive failed. Check ${BUILD_DIR}/archive.log${NC}"
    exit 1
fi

echo -e "${GREEN}Archive created: ${ARCHIVE_PATH}${NC}"

# Step 2: Create export options plist
echo -e "${GREEN}[2/3] Preparing export options...${NC}"

cat > "${BUILD_DIR}/exportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID}</key>
        <string>${PROVISIONING_PROFILE_APP}</string>
        <key>${EXTENSION_BUNDLE_ID}</key>
        <string>${PROVISIONING_PROFILE_EXT}</string>
    </dict>
</dict>
</plist>
EOF

# Step 3: Export IPA
echo -e "${GREEN}[3/3] Exporting IPA...${NC}"

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${BUILD_DIR}/exportOptions.plist" \
    -exportPath "${EXPORT_PATH}" \
    | tee "${BUILD_DIR}/export.log"

# Find and display the IPA
IPA_FILE=$(find "${EXPORT_PATH}" -name "*.ipa" | head -n 1)

if [ -f "${IPA_FILE}" ]; then
    echo ""
    echo -e "${GREEN}=== Build Successful ===${NC}"
    echo "IPA: ${IPA_FILE}"
    ls -lh "${IPA_FILE}"
    echo ""
    echo "Install methods:"
    echo "  1. Xcode: Window > Devices and Simulators > Drag IPA to device"
    echo "  2. Apple Configurator 2"
    echo "  3. AltStore / SideStore (sideloading)"
    echo "  4. TestFlight (after App Store upload)"
else
    echo -e "${RED}Export failed. Check ${BUILD_DIR}/export.log${NC}"
    exit 1
fi
