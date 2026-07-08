#!/bin/bash
set -e

# Default ports
MAIN_SERVER_PORT=8000
VIDEO_SERVER_PORT=8001
DASHBOARD_PORT=5173
LOCAL_MODE=0
AUTO_CONFIRM=0
PROD_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      LOCAL_MODE=1
      shift
      ;;
    --prod)
      PROD_MODE=1
      shift
      ;;
    --yes|-y)
      AUTO_CONFIRM=1
      shift
      ;;
    --main-port)
      MAIN_SERVER_PORT="$2"
      shift 2
      ;;
    --video-port)
      VIDEO_SERVER_PORT="$2"
      shift 2
      ;;
    --dashboard-port)
      DASHBOARD_PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

is_port_in_use() { lsof -i :"$1" > /dev/null 2>&1; }

ALL_PORTS=($MAIN_SERVER_PORT $VIDEO_SERVER_PORT $DASHBOARD_PORT)
SERVER_PORTS=($MAIN_SERVER_PORT $VIDEO_SERVER_PORT)
SOMETHING_RUNNING=0
for p in "${ALL_PORTS[@]}"; do
    is_port_in_use "$p" && SOMETHING_RUNNING=1
done

if [ "$SOMETHING_RUNNING" -eq 1 ]; then
    echo "═══ Ports in use ═══"
    for p in "${ALL_PORTS[@]}"; do
        if is_port_in_use "$p"; then
            pid=$(lsof -ti :"$p" 2>/dev/null)
            name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            echo "  Port $p — PID $pid ($name)"
        fi
    done

    REPLY="y"
    if [ $AUTO_CONFIRM -eq 0 ]; then
        echo -n "Kill them and restart? [Y/n]: "
        read -r REPLY
    fi

    if [[ "$REPLY" =~ ^[Yy]?$ ]]; then
        echo "Killing processes..."
        for p in "${ALL_PORTS[@]}"; do
            lsof -ti :"$p" 2>/dev/null | xargs -r kill 2>/dev/null || true
        done
        sleep 2
        echo "Done."
    else
        echo "Exiting — ports already in use."
        exit 1
    fi
fi

echo "╔═══════════════════╗"
echo "║     LEC — System Setup & Start       ║"
echo "║     Local Mode: $([ $LOCAL_MODE -eq 1 ] && echo "YES" || echo "NO")"
echo "╚═══════════════════╝"

# ─── Re-transcode HLS prompt ───
if [ "$PROD_MODE" -eq 0 ]; then
    REPLY="n"
    if [ $AUTO_CONFIRM -eq 0 ]; then
        echo -n "Re-transcode HLS from source? [y/N]: "
        read -r REPLY
    fi

    if [[ "$REPLY" =~ ^[Yy] ]]; then
        echo "⚠️  Forcing full pre-transcode (deleting cached template)"
        rm -rf video-server/storage/videos/_template_360p
    fi

    # Kill any old cloudflared
    pkill -f "cloudflared tunnel" 2>/dev/null || true

    # Clean old DBs, video ID mapping, and video storage (keep template cache)
    rm -f main-server/lec_main.db video-server/video_server.db video_ids.json
    find video-server/storage/videos -mindepth 1 -maxdepth 1 ! -name '_template_360p' -exec rm -rf {} + 2>/dev/null || true
else
    echo "  ⏭️  Skipping DB/seed cleanup (--prod mode)"
fi

# ─── Cloudflared binary ───
if [ "$LOCAL_MODE" -eq 0 ]; then
    echo ""
    echo "▸ [1/8] Cloudflared binary"
    CLOUDFLARED_BIN="$(dirname "$0")/cloudflared"
    if [ ! -f "$CLOUDFLARED_BIN" ]; then
        echo "  Downloading..."
        curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o "$CLOUDFLARED_BIN" && chmod +x "$CLOUDFLARED_BIN"
    fi
    echo "  ✅ cloudflared ready"
else
    echo ""
    echo "▸ [1/8] Skipping Cloudflared (Local Mode)"
fi

# ─── Write temporary localhost .env files ───
echo ""
if [ "$PROD_MODE" -eq 1 ]; then
    echo "▸ [2/8] Preserving existing .env files (--prod mode)"
else
    echo "▸ [2/8] Generating .env (localhost first)"

    cat > main-server/.env << MAINENV
MAIN_SERVER_HOST=0.0.0.0
MAIN_SERVER_PORT=$MAIN_SERVER_PORT
MAIN_SERVER_DEBUG=true
MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
DATABASE_URL=sqlite:///./lec_main.db
JWT_SECRET_KEY=dev-secret-key-change-in-production-abc123xyz
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT
VIDEO_SERVER_INTERNAL_URL=http://localhost:$VIDEO_SERVER_PORT
VIDEO_SERVER_INTERNAL_TOKEN=dev-internal-token
CORS_ORIGINS=http://localhost:3000,http://localhost:$DASHBOARD_PORT
MAINENV

    MUX_EXISTING=""
    if [ -f video-server/.env ]; then
        MUX_EXISTING=$(grep -E '^MUX_' video-server/.env || true)
    fi

    cat > video-server/.env << VIDENV
VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT
MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
DATABASE_URL=sqlite:///./video_server.db
VIDEO_STORAGE_PATH=./storage/videos
VIDEO_STORAGE_TYPE=local
WATERMARK_DURATION_SECONDS=1
WATERMARK_POSITION=bottom-right
WATERMARK_OPACITY=0.7
SECRET_KEY=video-server-secret-key-change-in-production
VIDENV

    if [ -n "$MUX_EXISTING" ]; then
        echo "$MUX_EXISTING" >> video-server/.env
    fi

    echo "  ✅ .env files written (localhost)"
fi

# ─── Start servers ───
echo ""
echo "▸ [3/8] Starting servers"

# Start video server first (need it to seed videos)
cd video-server
if [ ! -d ".venv" ]; then uv venv; fi
uv pip install -q -r requirements.txt 2>/dev/null || true
echo "  Starting video server on port $VIDEO_SERVER_PORT..."
nohup .venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $VIDEO_SERVER_PORT > ../video_server.log 2>&1 &
cd ..

echo "  Waiting for video server to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
until curl -s http://localhost:$VIDEO_SERVER_PORT/health > /dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "  ❌ Video server failed to start."
        exit 1
    fi
    sleep 1
done

if [ "$PROD_MODE" -eq 0 ]; then
    echo "  Seeding test videos..."
    cd video-server
    export VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT
    export MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
    .venv/bin/python3 ../seed_videos.py 2>&1 || true
    cd ../
    echo "  ✅ video_ids.json written with fresh IDs"

    # Now seed main-server database (uses fresh video_ids.json)
    cd main-server
    if [ ! -d ".venv" ]; then uv venv; fi
    uv pip install -q -r requirements.txt 2>/dev/null || true
    echo "  Seeding main server data..."
    export VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT
    export MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
    .venv/bin/python3 seed_data.py
    cd ..
else
    echo "  ⏭️  Skipping seed (--prod mode)"
fi

echo "  Starting main server on port $MAIN_SERVER_PORT..."
cd main-server
nohup .venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $MAIN_SERVER_PORT > ../main_server.log 2>&1 &
cd ..

sleep 3

# ─── Start Dashboard ───
echo ""
echo "▸ [4/8] Starting Dashboard"
cd dashboard
if [ ! -d "node_modules" ]; then npm install --silent; fi
nohup npx vite --host 0.0.0.0 --port $DASHBOARD_PORT > ../dashboard.log 2>&1 &
cd ..
sleep 3

# Verify all running
for p in "${ALL_PORTS[@]}"; do
    if is_port_in_use "$p"; then
        echo "  ✅ Port $p — OK"
    else
        echo "  ❌ Port $p — NOT RUNNING"
        exit 1
    fi
done

PUBLIC_URL_MAIN="http://localhost:$MAIN_SERVER_PORT"
PUBLIC_URL_VIDEO="http://localhost:$VIDEO_SERVER_PORT"

# ─── Start cloudflared tunnels ───
if [ "$LOCAL_MODE" -eq 0 ]; then
    echo ""
    echo "▸ [5/8] Starting Cloudflare Tunnels"

    # Clean old tunnel logs to avoid stale URL matches
    rm -f cloudflared_main.log cloudflared_video.log

    echo "  Starting tunnel for Main Server..."
    nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$MAIN_SERVER_PORT" > cloudflared_main.log 2>&1 &

    echo "  Starting tunnel for Video Server..."
    nohup "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$VIDEO_SERVER_PORT" > cloudflared_video.log 2>&1 &

    echo "  Waiting for tunnel URLs..."
    PUBLIC_URL_MAIN=""
    PUBLIC_URL_VIDEO=""
    for i in $(seq 1 15); do
        if [ -z "$PUBLIC_URL_MAIN" ]; then
            PUBLIC_URL_MAIN=$(grep -o 'https://.*\.trycloudflare\.com' cloudflared_main.log 2>/dev/null | head -1)
        fi
        if [ -z "$PUBLIC_URL_VIDEO" ]; then
            PUBLIC_URL_VIDEO=$(grep -o 'https://.*\.trycloudflare\.com' cloudflared_video.log 2>/dev/null | head -1)
        fi
        if [ -n "$PUBLIC_URL_MAIN" ] && [ -n "$PUBLIC_URL_VIDEO" ]; then
            break
        fi
        sleep 2
    done

    if [ -z "$PUBLIC_URL_MAIN" ] || [ -z "$PUBLIC_URL_VIDEO" ]; then
        echo "  ❌ Tunnel failed, using localhost"
        PUBLIC_URL_MAIN="http://localhost:$MAIN_SERVER_PORT"
        PUBLIC_URL_VIDEO="http://localhost:$VIDEO_SERVER_PORT"
    else
        echo "  ✅ Main Server: $PUBLIC_URL_MAIN"
        echo "  ✅ Video Server: $PUBLIC_URL_VIDEO"
    fi

    # ─── Update .env with real URLs and restart servers ───
    if [ "$PROD_MODE" -eq 0 ]; then
        echo ""
        echo "▸ [6/8] Updating .env with tunnel URLs & restarting"

        cat > main-server/.env << MAINENV
MAIN_SERVER_HOST=0.0.0.0
MAIN_SERVER_PORT=$MAIN_SERVER_PORT
MAIN_SERVER_DEBUG=true
MAIN_SERVER_URL=$PUBLIC_URL_MAIN
DATABASE_URL=sqlite:///./lec_main.db
JWT_SECRET_KEY=dev-secret-key-change-in-production-abc123xyz
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
VIDEO_SERVER_BASE_URL=$PUBLIC_URL_VIDEO
VIDEO_SERVER_INTERNAL_URL=http://localhost:$VIDEO_SERVER_PORT
VIDEO_SERVER_INTERNAL_TOKEN=dev-internal-token
CORS_ORIGINS=http://localhost:3000,http://localhost:$DASHBOARD_PORT,$PUBLIC_URL_MAIN,$PUBLIC_URL_VIDEO
MAINENV

    MUX_EXISTING=""
    if [ -f video-server/.env ]; then
        MUX_EXISTING=$(grep -E '^MUX_' video-server/.env || true)
    fi

    cat > video-server/.env << VIDENV
VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT
MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
DATABASE_URL=sqlite:///./video_server.db
VIDEO_STORAGE_PATH=./storage/videos
VIDEO_STORAGE_TYPE=local
WATERMARK_DURATION_SECONDS=1
WATERMARK_POSITION=bottom-right
WATERMARK_OPACITY=0.7
SECRET_KEY=video-server-secret-key-change-in-production
VIDENV

    if [ -n "$MUX_EXISTING" ]; then
        echo "$MUX_EXISTING" >> video-server/.env
    fi

        echo "  Restarting servers to pick up tunnel URLs..."
        for p in "${SERVER_PORTS[@]}"; do
            lsof -ti :"$p" 2>/dev/null | xargs -r kill 2>/dev/null || true
        done
        sleep 2

        echo "  Restarting video server..."
        cd video-server
        nohup .venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $VIDEO_SERVER_PORT > ../video_server.log 2>&1 &
        cd ..
        sleep 3

        echo "  Restarting main server..."
        cd main-server
        nohup .venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $MAIN_SERVER_PORT > ../main_server.log 2>&1 &
        cd ..
        sleep 3
    else
        echo ""
        echo "▸ [6/8] Preserving .env and running servers (--prod mode)"
    fi
else
    echo ""
    echo "▸ [5/8] Skipping Tunnels (Local Mode)"
    echo "▸ [6/8] Skipping Restart (Local Mode)"
fi

# ─── Update Flutter app base URL ───
echo ""
echo "▸ [7/8] Updating Flutter app base URL..."
FLUTTER_MAIN="agent/lib/main.dart"
if [ -f "$FLUTTER_MAIN" ]; then
    NEW_URL="$PUBLIC_URL_MAIN/api/v1"
    # Update both cloudflare and localhost patterns to current selection
    sed -i "s|https://.*\.trycloudflare\.com/api/v1|$NEW_URL|g" "$FLUTTER_MAIN"
    sed -i "s|http://localhost:[0-9]*/api/v1|$NEW_URL|g" "$FLUTTER_MAIN"
    echo "  ✅ Flutter app URL → $NEW_URL"
fi

# ─── Run smoke test ───
echo ""
echo "▸ [8/8] Smoke test & E2E test..."

sleep 2
SMOKE=$(curl -s -o /dev/null -w "%{http_code}" \
    http://localhost:$MAIN_SERVER_PORT/api/v1/auth/login \
    -X POST -H "Content-Type: application/json" \
    -d '{"email":"admin@lec.com","password":"admin123"}' 2>/dev/null)

if [ "$SMOKE" = "200" ]; then
    echo "  ✅ Local login works (HTTP $SMOKE)"
else
    echo "  ❌ Local login returned HTTP $SMOKE"
fi

# ─── End-to-end test ───
echo ""
echo "  Running end-to-end test..."
SCRIPT_DIR="$(dirname "$0")"
set +e
"$SCRIPT_DIR/main-server/.venv/bin/python3" "$SCRIPT_DIR/test_e2e.py" \
    --main-url "$PUBLIC_URL_MAIN" \
    --video-url "$PUBLIC_URL_VIDEO" 2>&1
E2E_EXIT=$?
set -e
if [ "$E2E_EXIT" -eq 0 ]; then
    echo "  ✅ End-to-end test PASSED"
else
    echo "  ❌ End-to-end test FAILED (exit $E2E_EXIT)"
fi

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║            ALL SYSTEMS GO             ║"
echo "╠═══════════════════════════════════════╣"
if [ "$LOCAL_MODE" -eq 0 ]; then
    echo "║  Main  → $PUBLIC_URL_MAIN"
    echo "║  Video → $PUBLIC_URL_VIDEO"
    echo "║"
fi
echo "║  Local:"
echo "║    http://localhost:$MAIN_SERVER_PORT  (main)"
echo "║    http://localhost:$VIDEO_SERVER_PORT  (video)"
echo "║    http://localhost:$DASHBOARD_PORT  (dashboard)"
echo "╠═══════════════════════════════════════╣"
echo "║  admin@lec.com      / admin123        ║"
echo "║  instructor@lec.com / instructor123   ║"
echo "║  student@lec.com    / student123      ║"
echo "╚═══════════════════════════════════════╝"
