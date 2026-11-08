#!/bin/bash
# Compila o Lumink e monta build/Lumink.app.
# Uso: ./build-app.sh [debug|release]   (padrão: release)
#
# Usa o `swiftc` diretamente (só precisa das Command Line Tools). Se você tiver
# o Xcode, também pode abrir o Package.swift nele.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="build/Lumink.app"
ARCH="$(uname -m)"
OPT=(-O)
[[ "$CONFIG" == "debug" ]] && OPT=(-Onone -g)

echo "▸ Compilando ($CONFIG, $ARCH)…"
mkdir -p build
SOURCES=()
while IFS= read -r -d '' f; do SOURCES+=("$f"); done < <(find Sources/Lumink -name '*.swift' -print0)
compile() {
    swiftc "${OPT[@]}" \
        -parse-as-library \
        -module-name Lumink \
        -swift-version 5 \
        -target "$ARCH-apple-macos14.0" \
        -sdk "$1" \
        "${SOURCES[@]}" \
        -o build/Lumink
}

# SDK: $KP_SDK, senão o padrão do sistema. Em algumas instalações só das Command
# Line Tools o SDK mais novo exige plugins de macro do SwiftUI que só vêm com o
# Xcode; nesse caso tentamos os outros SDKs instalados, do mais novo ao mais antigo.
CANDIDATES=()
[[ -n "${KP_SDK:-}" ]] && CANDIDATES+=("$KP_SDK")
CANDIDATES+=("$(xcrun --show-sdk-path --sdk macosx)")
SDK_DIR="$(dirname "${CANDIDATES[${#CANDIDATES[@]}-1]}")"
while IFS= read -r sdk; do CANDIDATES+=("$sdk"); done < <(ls -d "$SDK_DIR"/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV)

BUILT=0
LOG="build/compile.log"
for sdk in "${CANDIDATES[@]}"; do
    if compile "$sdk" 2>"$LOG"; then
        echo "  SDK: $sdk"; BUILT=1; break
    fi
    if ! grep -qE "SwiftUIMacros|not supported by the compiler|redefinition of module" "$LOG"; then
        cat "$LOG"; exit 1          # erro de código de verdade: não adianta trocar de SDK
    fi
    echo "  SDK incompatível, tentando outro: $(basename "$sdk")"
done
if [[ $BUILT == 0 ]]; then cat "$LOG"; echo "✗ Nenhum SDK compatível."; exit 1; fi
grep -E "warning:" "$LOG" | head -20 || true

echo "▸ Montando ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/Lumink "$APP/Contents/MacOS/Lumink"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Assinatura ad-hoc, sem App Sandbox (o app chama ferramentas externas).
codesign --force --sign - "$APP" >/dev/null
echo "✓ Pronto: $APP"
echo "  Abra com: open $APP"
