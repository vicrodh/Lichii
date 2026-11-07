#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
preset=${1:-steam-deck}
case "$preset" in
  steam-deck|steam-deck-baseline|steam-deck-train|steam-deck-pgo) ;;
  *) echo "Unknown Steam Deck preset: $preset" >&2; exit 2 ;;
esac
: "${QT_ROOT_DIR:?Set QT_ROOT_DIR to the Qt 6.8.3 installation}"
cd "$root"

build="$root/build/$preset"
tools="${RUNNER_TEMP:-$root/build}/linuxdeploy"
appdir="$build/AppDir"
output="$root/dist/steam-deck/$preset"
mkdir -p "$tools" "$appdir/usr/bin" "$output"

gh release download continuous --repo linuxdeploy/linuxdeploy \
  --pattern linuxdeploy-x86_64.AppImage --dir "$tools" --clobber
gh release download continuous --repo linuxdeploy/linuxdeploy-plugin-qt \
  --pattern linuxdeploy-plugin-qt-x86_64.AppImage --dir "$tools" --clobber
chmod +x "$tools/linuxdeploy-x86_64.AppImage" "$tools/linuxdeploy-plugin-qt-x86_64.AppImage"
cp dist/lichii.png "$build/io.github.zortos293.lichii.png"
cp "$build/bin/nx2_switches.txt" "$appdir/usr/bin/"

export APPIMAGE_EXTRACT_AND_RUN=1
export QMAKE="$QT_ROOT_DIR/bin/qmake"
export EXTRA_QT_MODULES=waylandcompositor
export EXTRA_PLATFORM_PLUGINS='libqwayland-egl.so;libqwayland-generic.so'
export ARCH=x86_64
export LDAI_VERSION="deck-${GITHUB_RUN_NUMBER:-local}-$(git rev-parse --short HEAD)"
export LDAI_OUTPUT="$output/lichii-$preset-x86_64.AppImage"
export OUTPUT="$LDAI_OUTPUT"
"$tools/linuxdeploy-x86_64.AppImage" --appdir "$appdir" \
  --executable "$build/bin/lichii" \
  --executable "$build/bin/eden-cli" \
  --desktop-file dist/io.github.zortos293.lichii.desktop \
  --icon-file "$build/io.github.zortos293.lichii.png" \
  --plugin qt --output appimage
test -s "$LDAI_OUTPUT"
chmod +x "$LDAI_OUTPUT"
cp "$build/build-info.json" "$output/"
cp tools/steam-deck/train-pgo.sh tools/steam-deck/merge-pgo.sh "$output/"
cp docs/SteamDeck.md "$output/README.md"
(
  cd "$output"
  sha256sum "${LDAI_OUTPUT##*/}" > SHA256SUMS
)
tar -czf "$root/dist/steam-deck/lichii-$preset-x86_64.tar.gz" -C "$output" .
