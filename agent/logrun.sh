#!/usr/bin/env bash
# logrun.sh — flutter run with Android framework noise stripped.
#
# Usage:
#   ./logrun.sh [flutter run args...]
#
# Hot reload keys (r / R / q) still work: only stdout is filtered,
# stdin stays attached to the terminal. App logs ([PLAYER], [VIEWER]),
# Dart errors, and ExoPlayer errors all pass through.
set -u
cd "$(dirname "$0")"

NOISE='BLASTBufferQueue|InputTransport|gralloc|Gralloc|GraphicBuffer|AHardwareBuffer|BufferQueue|VRI\[|WindowOnBackDispatcher|I18NHelper|shorebird|FlutterFileDialog|Choreographer|SurfaceFlinger|HwcComposer|Adreno|Mali|TrafficStats|OpenGLRenderer|libEGL|EGL_emulation'

flutter run "$@" 2>&1 | grep --line-buffered -v -E "$NOISE"
