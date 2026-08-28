#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/agent"

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
err()  { echo -e "${RED}[ERR]${NC}  $1"; }

# ── Defaults (production server) ──
VARIANT="${1:-release}"
API_URL="${API_BASE_URL:-https://main.lec.pxysio.top/api/v1}"
VIDEO_URL="${VIDEO_SERVER_URL:-https://video.lec.pxysio.top}"
VIDEO_STREAM="${VIDEO_STREAM_URL:-https://video.lec.pxysio.top}"
ENCRYPT_KEY="${ENCRYPTION_KEY:-my_32_char_super_secret_key_!!!!}"

info "Building LEC APK (${VARIANT})"
info "  API_URL        = ${API_URL}"
info "  VIDEO_URL      = ${VIDEO_URL}"
info "  VIDEO_STREAM   = ${VIDEO_STREAM}"
info "  ENCRYPT_KEY    = ${ENCRYPT_KEY:0:8}..."

# ── Get deps if needed ──
if [ ! -d ".dart_tool" ]; then
  info "Getting Flutter dependencies..."
  flutter pub get
fi

# ── Build with dart-define ──
info "Building ${VARIANT} APK..."
flutter build apk \
  "--${VARIANT}" \
  --dart-define=API_BASE_URL="${API_URL}" \
  --dart-define=VIDEO_SERVER_URL="${VIDEO_URL}" \
  --dart-define=VIDEO_STREAM_URL="${VIDEO_STREAM}" \
  --dart-define=ENCRYPTION_KEY="${ENCRYPT_KEY}"

APK_PATH="build/app/outputs/flutter-apk/app-${VARIANT}.apk"
# Flutter names it app-release.apk or app-debug.apk
if [ ! -f "$APK_PATH" ]; then
  APK_PATH=$(find build/app/outputs/flutter-apk/ -name "*.apk" -print -quit 2>/dev/null || true)
fi

if [ -f "$APK_PATH" ]; then
  SIZE=$(du -h "$APK_PATH" | cut -f1)
  ok "✅ APK ready: ${APK_PATH} (${SIZE})"
else
  err "APK not found in build/app/outputs/flutter-apk/"
  exit 1
fi
