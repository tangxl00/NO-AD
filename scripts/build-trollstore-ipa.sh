#!/bin/bash
#
# build-trollstore-ipa.sh
# AdShield Unsigned IPA Build Script for TrollStore
#
# Usage:
#   ./scripts/build-trollstore-ipa.sh [debug|release]
#
# Prerequisites:
#   - macOS with Xcode 14+ installed
#   - No Apple Developer account required
#   - TrollStore installed on target iOS device
#
# This script builds an UNSIGNED IPA that can be installed via TrollStore.
# TrollStore handles signature and entitlements automatically on installation.
#

set -euo pipefail

# Build configuration
BUILD_CONFIG="${1:-release}"
SCHEME="AdShield"
PROJECT="AdShield.xcodeproj"
APP_NAME="AdShield"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
IPA_PATH="${BUILD_DIR}/${APP_NAME}-unsigned.ipa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== AdShield Unsigned IPA Build Script (TrollStore) ===${NC}"
echo "Build configuration: ${BUILD_CONFIG}"
echo ""

# Validate prerequisites
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Clean build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 1: Archive (no code signing)
echo -e "${GREEN}[1/3] Creating unsigned archive...${NC}"
xcodebuild archive \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${BUILD_CONFIG}" \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=iOS" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    | tee "${BUILD_DIR}/archive.log"

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}Archive failed. Check ${BUILD_DIR}/archive.log${NC}"
    exit 1
fi

echo -e "${GREEN}Archive created: ${ARCHIVE_PATH}${NC}"

# Verify extension is embedded
EXTENSION_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app/PlugIns/AdShieldExtension.appex"
if [ -d "$EXTENSION_PATH" ]; then
    echo -e "${GREEN}Extension verified in archive.${NC}"
else
    echo -e "${YELLOW}WARNING: Extension not found at expected path. Searching...${NC}"
    find "${ARCHIVE_PATH}" -name "*.appex" || true
fi

# Step 2: Package IPA
echo -e "${GREEN}[2/3] Packaging unsigned IPA...${NC}"

mkdir -p "${BUILD_DIR}/Payload"
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${BUILD_DIR}/Payload/"

cd "${BUILD_DIR}"
zip -r "${APP_NAME}-unsigned.ipa" Payload
cd ..

# Step 3: Verify
echo -e "${GREEN}[3/3] Verifying IPA...${NC}"

if [ -f "${IPA_PATH}" ]; then
    echo ""
    echo -e "${GREEN}=== Build Successful ===${NC}"
    echo "IPA: ${IPA_PATH}"
    ls -lh "${IPA_PATH}"
    echo ""
    echo "Install methods:"
    echo "  1. TrollStore (recommended): Open TrollStore on device, tap +, select this IPA"
    echo "  2. TrollStore via URL: Host IPA on local server, open URL in TrollStore"
    echo ""
    echo "Note: This IPA is UNSIGNED. It can only be installed via TrollStore."
    echo "      Standard sideloading tools (AltStore, SideStore) require a signed IPA."
else
    echo -e "${RED}Packaging failed.${NC}"
    exit 1
fi
