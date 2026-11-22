#!/bin/zsh
# Build an all-in-one .pkg: Google Remote Voice.app + RemoteBuddyMic.driver.
# Requires Xcode Command Line Tools (swiftc). Builds into build/ only —
# it does NOT install or modify anything on the build machine.
#
#   ./Packaging/build-pkg.sh
#   PKG_VERSION=1.0.1 PKG_IDENTIFIER=com.example.grv ./Packaging/build-pkg.sh
#
# Output: build/GoogleRemoteVoice-Enhanced-<version>.pkg
# Note: the app is ad-hoc signed (unnotarized). End users open it via right-click > Open.
set -e
cd "$(dirname "$0")/.."

VERSION="${PKG_VERSION:-1.0.0}"
IDENTIFIER="${PKG_IDENTIFIER:-com.googleremotevoice.enhanced}"
mkdir -p build

echo "== 1/5 构建 App =="
./build.sh
APP="build/Google Remote Voice.app"
[ -d "$APP" ] || { echo "构建失败：找不到 $APP"; exit 1; }

echo "== 2/5 组装 payload =="
PAYLOAD="$(mktemp -d build/payload.XXXXXX)"
mkdir -p "$PAYLOAD/Applications" "$PAYLOAD/Library/Audio/Plug-Ins/HAL"
cp -R "$APP" "$PAYLOAD/Applications/Google Remote Voice.app"
cp -R "Packaging/Vendor/RemoteBuddyMic.driver" "$PAYLOAD/Library/Audio/Plug-Ins/HAL/RemoteBuddyMic.driver"
xattr -cr "$PAYLOAD" 2>/dev/null || true

echo "== 3/5 component pkg =="
COMPONENT="build/GoogleRemoteVoice-component.pkg"
pkgbuild --root "$PAYLOAD" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location "/" \
  --scripts "Packaging/scripts" \
  "$COMPONENT"

echo "== 4/5 product archive =="
FINAL="build/GoogleRemoteVoice-Enhanced-$VERSION.pkg"
productbuild --distribution "Packaging/Resources/distribution.xml" \
  --package-path "build" \
  --resources "Packaging/Resources" \
  "$FINAL"

echo "== 5/5 完成 =="
echo "✅ $FINAL"
echo "   安装：双击 pkg（会装 App + 虚拟麦驱动，并短暂重启 CoreAudio）"
echo "   临时 payload 留在 $PAYLOAD（build/ 已 gitignore，可手动清理）"