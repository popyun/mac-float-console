#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"
configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    print -u2 "Usage: scripts/build-app.sh [release|debug]"
    exit 1
fi

mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$project_dir/.build/module-cache"
swift_options=(--cache-path "$project_dir/.build/swiftpm-cache"
               --config-path "$project_dir/.build/swiftpm-config"
               --security-path "$project_dir/.build/swiftpm-security")
swift build -c "$configuration" "${swift_options[@]}" --disable-sandbox \
    -Xswiftc -module-cache-path -Xswiftc "$project_dir/.build/module-cache"
binary_dir="$(swift build -c "$configuration" "${swift_options[@]}" --show-bin-path)"
app_dir="$project_dir/dist/系统控制台.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/MacConsole" "$app_dir/Contents/MacOS/MacConsole"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>MacConsole</string>
    <key>CFBundleIdentifier</key><string>local.macconsole.preview</string>
    <key>CFBundleName</key><string>系统控制台</string>
    <key>CFBundleDisplayName</key><string>系统控制台</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.9.0</string>
    <key>CFBundleVersion</key><string>9</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$project_dir/dist/系统控制台-preview.zip"
print "Built: $app_dir"
