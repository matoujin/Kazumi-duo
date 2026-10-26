#!/usr/bin/env bash
# Patch an unsigned Runner.app so iOS 27.1 / LiveContainer treat it as built
# with the iOS 27.1 SDK (native edge-to-edge on iPhone Duo inner + outer).
#
# When the GitHub-hosted macOS runner ships an older Xcode, apps otherwise run
# in letterboxed compatibility mode. LiveContainer's spoofSDKVersion and iOS
# itself key off Info.plist DT* metadata and the Mach-O LC_BUILD_VERSION sdk.
#
# Also strips legacy launch-storyboard artifacts that lock SpringBoard into a
# 375×667 compatibility window on iPhone Duo (Apple Checklist #1).
#
# Usage: ios_patch_sdk_version.sh <path-to-Runner.app>
set -euo pipefail

APP="${1:?usage: $0 <Runner.app>}"
PLIST="${APP}/Info.plist"
SDK_NAME="iphoneos27.1"
SDK_VERSION="27.1"
# LC_BUILD_VERSION sdk encoding: major<<16 | minor<<8 | patch  → 27.1.0
SDK_HEX="0x001B0100"
# LC_BUILD_VERSION minos encoding: 16.1.0
MINOS_VERSION="16.1"
MINOS_HEX="0x00100100"
BUNDLE_ID="com.example.kazumi.duo"
XCODE_VERSION="2710"
# Official iPhoneOS27.1.sdk / Xcode 27.1 build identifiers.
XCODE_BUILD="27A9275"
PLATFORM_BUILD="24A94232"

if [[ ! -d "$APP" ]]; then
  echo "error: Runner.app not found at $APP" >&2
  exit 1
fi
if [[ ! -f "$PLIST" ]]; then
  echo "error: Info.plist missing in $APP" >&2
  exit 1
fi

plist_set() {
  local key="$1"
  local type="$2"
  local value="$3"
  if /usr/libexec/PlistBuddy -c "Print :${key}" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :${key} ${type} ${value}" "$PLIST"
  fi
}

plist_delete() {
  local key="$1"
  if /usr/libexec/PlistBuddy -c "Print :${key}" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Delete :${key}" "$PLIST"
    echo "Removed :${key} from Info.plist"
  fi
}

echo "Patching Info.plist SDK metadata → ${SDK_NAME} / ${SDK_VERSION}"
plist_set "DTSDKName" string "$SDK_NAME"
plist_set "DTPlatformName" string "iphoneos"
plist_set "DTPlatformVersion" string "$SDK_VERSION"
plist_set "DTSDKBuild" string "$PLATFORM_BUILD"
plist_set "DTXcode" string "$XCODE_VERSION"
plist_set "DTXcodeBuild" string "$XCODE_BUILD"
plist_set "DTCompiler" string "com.apple.compilers.llvm.clang.1_0"
plist_set "DTPlatformBuild" string "$PLATFORM_BUILD"
plist_set "MinimumOSVersion" string "$MINOS_VERSION"
plist_set "CFBundleIdentifier" string "$BUNDLE_ID"

# iOS 27.1 requires UIRequiresFullScreen to be absent (not set to false).
plist_delete "UIRequiresFullScreen"

# Legacy launch storyboard/images force SplashBoard into a 375×667 window.
# Keep only UILaunchScreen = {} so SpringBoard uses the modern path.
plist_delete "UILaunchStoryboardName"
plist_delete "UILaunchImageFile"
plist_delete "UILaunchImages"
if ! /usr/libexec/PlistBuddy -c "Print :UILaunchScreen" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :UILaunchScreen dict" "$PLIST"
fi

# Drop compiled LaunchScreen.storyboardc if Flutter/Xcode still copied it.
rm -rf "${APP}/Base.lproj/LaunchScreen.storyboardc"
rm -rf "${APP}/LaunchScreen.storyboardc"
# Also remove any leftover launch image catalogs that pin old sizes.
rm -rf "${APP}/Base.lproj/LaunchImage.imageset" 2>/dev/null || true
find "${APP}" -type d -name 'LaunchScreen.storyboardc' -prune -exec rm -rf {} + 2>/dev/null || true
echo "Removed LaunchScreen.storyboardc (if present)"

patch_macho() {
  local binary="$1"
  if [[ ! -f "$binary" ]]; then
    return 0
  fi
  # Skip non-Mach-O files.
  if ! file "$binary" | grep -q "Mach-O"; then
    return 0
  fi

  local tmp="${binary}.sdkpatch"
  # Always stamp minos=16.1 + sdk=27.1 (do not preserve older minos).
  if vtool -set-build-version ios "$MINOS_VERSION" "$SDK_VERSION" -replace -output "$tmp" "$binary" 2>/dev/null; then
    mv "$tmp" "$binary"
    chmod +x "$binary"
    echo "  LC_BUILD_VERSION sdk=${SDK_VERSION} (${SDK_HEX}) minos=${MINOS_VERSION} (${MINOS_HEX}): ${binary#"$APP"/}"
  else
    rm -f "$tmp"
    if command -v xcrun >/dev/null 2>&1; then
      echo "  warn: vtool replace failed for ${binary#"$APP"/}; leaving binary unchanged" >&2
    fi
  fi
}

echo "Patching Mach-O LC_BUILD_VERSION minos=${MINOS_VERSION} sdk=${SDK_VERSION}"
# Main executable
if [[ -f "${APP}/Runner" ]]; then
  patch_macho "${APP}/Runner"
fi
# Embedded frameworks / dylibs (LiveContainer may inspect any of them)
if [[ -d "${APP}/Frameworks" ]]; then
  while IFS= read -r -d '' macho; do
    patch_macho "$macho"
  done < <(find "${APP}/Frameworks" -type f \( -name "*.dylib" -o -perm -111 \) -print0 2>/dev/null)
  while IFS= read -r -d '' fw; do
    name="$(basename "$fw" .framework)"
    patch_macho "${fw}/${name}"
  done < <(find "${APP}/Frameworks" -type d -name "*.framework" -print0 2>/dev/null)
fi

echo "SDK patch complete for $APP (bundle id=${BUNDLE_ID})"
