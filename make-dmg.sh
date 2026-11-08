#!/bin/bash
# Compila o Lumink em release e gera build/Lumink.dmg, com o app e um atalho
# para Aplicativos (arrastar para instalar). O DMG não vai para o git (.gitignore).
# Uso: ./make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh release

APP="build/Lumink.app"
DMG="build/Lumink.dmg"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "▸ Gerando ${DMG} (versão ${VERSION})…"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet \
    -volname "Lumink ${VERSION}" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov "$DMG"

echo "✓ Pronto: $DMG ($(du -h "$DMG" | cut -f1))"
