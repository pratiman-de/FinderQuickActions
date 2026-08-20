#!/bin/bash
set -e

echo "=== Building FinderQuickActions ==="

# Clean build directory
rm -rf build
mkdir -p build/module-cache
mkdir -p build/FinderQuickActions.app/Contents/MacOS
mkdir -p build/FinderQuickActions.app/Contents/Resources
mkdir -p build/FinderQuickActions.app/Contents/PlugIns
mkdir -p build/FinderQuickActionsExtension.appex/Contents/MacOS

# 1. Compile Host Application
echo "Compiling Host Application..."
xcrun swiftc \
  -sdk $(xcrun --show-sdk-path -sdk macosx) \
  -target arm64-apple-macos14.0 \
  -module-cache-path build/module-cache \
  -o build/FinderQuickActions.app/Contents/MacOS/FinderQuickActions \
  FinderQuickActions/Preferences.swift \
  FinderQuickActions/SettingsView.swift \
  FinderQuickActions/FinderQuickActionsApp.swift
chmod +x build/FinderQuickActions.app/Contents/MacOS/FinderQuickActions

# Write Host App Info.plist
echo "Writing Host App Info.plist..."
cat <<EOF > build/FinderQuickActions.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.FinderQuickActions</string>
    <key>CFBundleName</key>
    <string>FinderQuickActions</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>FinderQuickActions</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Copy Icon if it exists
if [ -f "AppIcon.icns" ]; then
    echo "Copying AppIcon.icns to Resources..."
    cp AppIcon.icns build/FinderQuickActions.app/Contents/Resources/
fi

# 2. Compile Finder Sync Extension
echo "Compiling Finder Sync Extension..."
xcrun swiftc \
  -sdk $(xcrun --show-sdk-path -sdk macosx) \
  -target arm64-apple-macos14.0 \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -module-cache-path build/module-cache \
  -o build/FinderQuickActionsExtension.appex/Contents/MacOS/FinderQuickActionsExtension \
  FinderSyncExtension/FinderSync.swift
chmod +x build/FinderQuickActionsExtension.appex/Contents/MacOS/FinderQuickActionsExtension

# Copy Extension Info.plist
cp FinderSyncExtension/Info.plist build/FinderQuickActionsExtension.appex/Contents/Info.plist

# 3. Create Sandbox Entitlements for the Extension
echo "Creating Entitlements..."
cat <<EOF > build/entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF

# 4. Code Sign Extension
echo "Signing Extension..."
codesign -f -s - --entitlements build/entitlements.plist build/FinderQuickActionsExtension.appex

# Move Extension to Host App PlugIns folder
mv build/FinderQuickActionsExtension.appex build/FinderQuickActions.app/Contents/PlugIns/

# 5. Code Sign Host App
echo "Signing Host App..."
codesign -f -s - build/FinderQuickActions.app

# 6. Install to Applications folder
INSTALL_DIR="/Applications"
echo "Attempting to install to $INSTALL_DIR..."
if [ -w "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR/FinderQuickActions.app"
    cp -R build/FinderQuickActions.app "$INSTALL_DIR/FinderQuickActions.app"
    TARGET_APP="$INSTALL_DIR/FinderQuickActions.app"
else
    echo "$INSTALL_DIR is not writable. Installing to ~/Applications..."
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/FinderQuickActions.app"
    cp -R build/FinderQuickActions.app "$HOME/Applications/FinderQuickActions.app"
    TARGET_APP="$HOME/Applications/FinderQuickActions.app"
fi

# 7. Register & Enable via PlugInKit
echo "Registering plugin via pluginkit..."
pluginkit -r "$TARGET_APP/Contents/PlugIns/FinderQuickActionsExtension.appex" || true
pluginkit -a "$TARGET_APP/Contents/PlugIns/FinderQuickActionsExtension.appex"
pluginkit -e use -i com.yourcompany.FinderQuickActions.Extension

echo "=== Build and Installation Complete! ==="
echo "The application is installed at: $TARGET_APP"
echo "Please follow these steps to activate:"
echo "1. Run the application: open $TARGET_APP"
echo "2. Open System Settings -> Extensions -> Finder Extensions, and ensure 'FinderQuickActions' is checked."
echo "3. Hold 'Option', right-click the Finder icon in your Dock, and select 'Relaunch'."
