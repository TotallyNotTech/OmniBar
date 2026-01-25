#!/bin/bash

# 1. Ask the user for the new version
echo "--------------------------------------------------"
echo "OmniBar Build & Package Assistant"
echo "--------------------------------------------------"
echo -n "Enter the version you want to set (e.g., 1.2.0+1): "
read NEW_VERSION

if [ -z "$NEW_VERSION" ]; then
  echo "Error: No version entered. Exiting."
  exit 1
fi

# 2. Update the version in pubspec.yaml
# We use sed to find the line starting with "version:" and replace it.
# Note: The (-i '') syntax is specific to macOS.
echo "Updating pubspec.yaml to version $NEW_VERSION..."
sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

if [ $? -ne 0 ]; then
  echo "Error: Failed to update pubspec.yaml. Make sure you are in the project root."
  exit 1
fi

# 3. Run Flutter Build
echo "--------------------------------------------------"
echo "Running: flutter build macos --release"
echo "--------------------------------------------------"
flutter build macos --release

# Check if the build succeeded before continuing
if [ $? -ne 0 ]; then
  echo "Error: Flutter build failed. Exiting."
  exit 1
fi

# 4. Create DMG
# We remove the old DMG first to prevent errors if it already exists
if [ -f "OmniBar.dmg" ]; then
    echo "Removing previous OmniBar.dmg..."
    rm "OmniBar.dmg"
fi

echo "--------------------------------------------------"
echo "Creating DMG..."
echo "--------------------------------------------------"

create-dmg \
  --volname "OmniBar Installer" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --app-drop-link 600 185 \
  "OmniBar.dmg" \
  "./build/macos/Build/Products/Release/OmniBar.app"

echo "--------------------------------------------------"
echo "Done! Build completed for version $NEW_VERSION."
echo "--------------------------------------------------"