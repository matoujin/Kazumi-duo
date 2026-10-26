#!/usr/bin/env bash
# Patch an unsigned Runner.app so iOS 27.1 / LiveContainer treat it as built
# with the iOS 27.1 SDK (native edge-to-edge on iPhone Duo inner + outer).
#
# When the GitHub-hosted macOS runner ships an older Xcode, apps otherwise run
# in letterboxed compatibility mode. LiveContainer's spoofSDKVersion and iOS
# itself key off Info.plist DT* metadata and the Mach-O LC_BUILD_VERSION sdk.
#
# Usage: ios_patch_sdk_version.sh <path-to-Runner.app>
set -euo pipefail

APP="${1:?usage: $0 <Runner.app>}"
PLIST="${APP}/Info.plist"
SDK_NAME="iphoneos27.1"
SDK_VERSION="27.1"
# LC_BUILD_VERSION sdk encoding: major<<16 | minor<<8 | patch  → 27.1.0
SDK_HEX="0x001B0100"
XCODE_VERSION="2710"
XCODE_BUILD="27B100"
PLATFORM_BUILD="25B5062a"

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

echo "Patching Info.plist SDK metadata → ${SDK_NAME} / ${SDK_VERSION}"
plist_set "DTSDKName" string "$SDK_NAME"
plist_set "DTPlatformName" string "iphoneos"
plist_set "DTPlatformVersion" string "$SDK_VERSION"
plist_set "DTSDKBuild" string "$PLATFORM_BUILD"
plist_set "DTXcode" string "$XCODE_VERSION"
plist_set "DTXcodeBuild" string "$XCODE_BUILD"
plist_set "DTCompiler" string "com.apple.compilers.llvm.clang.1_0"
plist_set "DTPlatformBuild" string "$PLATFORM_BUILD"
# Multitasking / foldable live resize (must not require exclusive full screen).
if /usr/libexec/PlistBuddy -c "Print :UIRequiresFullScreen" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen false" "$PLIST"
else
  /usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool false" "$PLIST"
fi

patch_macho() {
  local binary="$1"
  if [[ ! -f "$binary" ]]; then
    return 0
  fi
  # Skip non-Mach-O files.
  if ! file "$binary" | grep -q "Mach-O"; then
    return 0
  fi

  local minos
  minos="$(vtool -show-build "$binary" 2>/dev/null | awk '/minos/{print $2; exit}' || true)"
  if [[ -z "${minos}" ]]; then
    minos="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST" 2>/dev/null || echo "13.0")"
  fi

  local tmp="${binary}.sdkpatch"
  if vtool -set-build-version ios "$minos" "$SDK_VERSION" -replace -output "$tmp" "$binary" 2>/dev/null; then
    mv "$tmp" "$binary"
    chmod +x "$binary"
    echo "  LC_BUILD_VERSION sdk=${SDK_VERSION} (minos=${minos}): ${binary#"$APP"/}"
  else
    rm -f "$tmp"
    # Fallback: older vtool may need numeric sdk / platform tool.
    if command -v xcrun >/dev/null 2>&1; then
      echo "  warn: vtool replace failed for ${binary#"$APP"/}; leaving binary unchanged" >&2
    fi
  fi
}

echo "Patching Mach-O LC_BUILD_VERSION sdk → ${SDK_VERSION} (${SDK_HEX})"
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

echo "SDK patch complete for $APP"
