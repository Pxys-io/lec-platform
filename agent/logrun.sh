#!/usr/bin/env bash
# logrun.sh — flutter run with Android framework noise stripped.
#
# Usage:
#   ./logrun.sh [flutter run args...]
#
# Hot reload keys (r / R / q) still work: only stdout is filtered,
# stdin stays attached to the terminal. App logs ([PLAYER], [VIEWER]),
# Dart errors, and ExoPlayer errors all pass through.
#
# The filtered stream is ALSO saved to logs/run-<timestamp>.log (latest
# 5 runs kept) so logs can be reviewed after the session.
set -u
cd "$(dirname "$0")"

NOISE='BLASTBufferQueue|InputTransport|gralloc|Gralloc|GraphicBuffer|AHardwareBuffer|BufferQueue|VRI\[|WindowOnBackDispatcher|I18NHelper|shorebird|FlutterFileDialog|Choreographer|SurfaceFlinger|HwcComposer|Adreno|Mali|TrafficStats|OpenGLRenderer|libEGL|EGL_emulation'

LOGDIR="logs"
mkdir -p "$LOGDIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE="$LOGDIR/run-$STAMP.log"

echo "=== logrun $STAMP ===" > "$LOGFILE"
echo "=== args: $* ===" >> "$LOGFILE"
echo "=== saving filtered log to $LOGFILE (latest 5 kept) ==="

flutter run "$@" 2>&1 | grep --line-buffered -v -E "$NOISE" | tee -a "$LOGFILE"

# Prune to the latest 5 runs.
ls -1t "$LOGDIR"/run-*.log 2>/dev/null | tail -n +6 | xargs -r rm --
