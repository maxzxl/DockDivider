#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-debug}"
if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
    print -u2 "Usage: scripts/build.sh [debug|release]"
    exit 2
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift_options=(--cache-path .build/cache --config-path .build/config --security-path .build/security)
swift build "${swift_options[@]}" -c "$configuration" --product DockDivider
swift build "${swift_options[@]}" -c "$configuration" --product DividerLauncher
binary_path="$(swift build "${swift_options[@]}" -c "$configuration" --show-bin-path)"
app_path="$PWD/build/DockDivider.app"
mkdir -p "$PWD/build"
staging_root="$(mktemp -d "$PWD/build/.staging-XXXXXX")"
staged_app="$staging_root/DockDivider.app"
function cleanup {
    if [[ ! -d "$app_path" && -d "$staging_root/previous.app" ]]; then
        mv "$staging_root/previous.app" "$app_path"
    fi
    rm -rf "$staging_root"
}
trap cleanup EXIT
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
cp "$binary_path/DockDivider" "$staged_app/Contents/MacOS/DockDivider"
cp "$binary_path/DividerLauncher" "$staged_app/Contents/Resources/DividerLauncher"
cp Resources/Info.plist "$staged_app/Contents/Info.plist"
cp Resources/DockDivider.icns "$staged_app/Contents/Resources/DockDivider.icns"
cp -R "$binary_path/DockDivider_DockDividerApp.bundle" "$staged_app/Contents/Resources/"
cp -R DockDividerApp/Resources/{en,de}.lproj "$staged_app/Contents/Resources/"
# With full Xcode, compile the layered icon so macOS supplies Liquid Glass effects.
if actool_path="$(xcrun --find actool 2>/dev/null)"; then
    "$actool_path" Resources/AppIcon.icon --compile "$staged_app/Contents/Resources" \
        --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon \
        --output-partial-info-plist "$staging_root/icon-info.plist"
    # PlistBuddy Merge skips existing keys; generated icon metadata must win.
    for icon_key in CFBundleIconFile CFBundleIconName; do
        if /usr/libexec/PlistBuddy -c "Print :$icon_key" "$staging_root/icon-info.plist" >/dev/null 2>&1; then
            /usr/libexec/PlistBuddy -c "Delete :$icon_key" "$staged_app/Contents/Info.plist" >/dev/null 2>&1 || true
        fi
    done
    /usr/libexec/PlistBuddy -c "Merge $staging_root/icon-info.plist" "$staged_app/Contents/Info.plist"
else
    print "Icon: ICNS fallback (layered Liquid Glass compilation needs full Xcode)."
fi
codesign --force --sign - --timestamp=none "$staged_app/Contents/Resources/DividerLauncher"
codesign --force --sign - --timestamp=none "$staged_app"
codesign --verify --strict "$staged_app"
if [[ -d "$app_path" ]]; then mv "$app_path" "$staging_root/previous.app"; fi
mv "$staged_app" "$app_path"
# Retire the old output name only after the replacement has built and verified.
if [[ -d "$PWD/build/Dock Divider.app" ]]; then
    mv "$PWD/build/Dock Divider.app" "$staging_root/legacy-name.app"
fi
print "Built: $app_path"
