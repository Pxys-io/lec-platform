#!/bin/bash
set -e

# Different ports for testing
MAIN_SERVER_PORT=9000
VIDEO_SERVER_PORT=9001
DASHBOARD_PORT=5174

is_port_in_use() { lsof -i :"$1" > /dev/null 2>&1; }

PORTS=($MAIN_SERVER_PORT $VIDEO_SERVER_PORT $DASHBOARD_PORT)
SOMETHING_RUNNING=0
for p in "${PORTS[@]}"; do
    is_port_in_use "$p" && SOMETHING_RUNNING=1
done

if [ "$SOMETHING_RUNNING" -eq 1 ]; then
    echo "═══ Test Ports in use ═══"
    for p in "${PORTS[@]}"; do
        if is_port_in_use "$p"; then
            pid=$(lsof -ti :"$p" 2>/dev/null)
            name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            echo "  Port $p — PID $pid ($name)"
        fi
    done
    echo -n "Kill them and restart? [Y/n]: "
    read -r REPLY
    if [[ "$REPLY" =~ ^[Yy]?$ ]]; then
        echo "Killing processes..."
        for p in "${PORTS[@]}"; do
            lsof -ti :"$p" 2>/dev/null | xargs -r kill 2>/dev/null || true
        done
        sleep 2
        echo "Done."
    else
        echo "Exiting — ports already in use."
        exit 1
    fi
fi

echo "╔═══════════════════════════════════════╗"
echo "║     LEC — TEST SETUP (Worktrees)       ║"
echo "╚═══════════════════════════════════════╝"

# Clean old test data in worktrees
rm -f main-server-wt/lec_main.db video-server-wt/video_server.db test_video_ids.json
find video-server-wt/storage/videos -mindepth 1 -maxdepth 1 ! -name '_template_360p' -exec rm -rf {} + 2>/dev/null || true

# ─── Write test .env files ───
echo ""
echo "▸ [1/5] Generating test .env"

cat > main-server-wt/.env << MAINENV
MAIN_SERVER_HOST=0.0.0.0
MAIN_SERVER_PORT=$MAIN_SERVER_PORT
MAIN_SERVER_DEBUG=true
MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
DATABASE_URL=sqlite:///./lec_main.db
JWT_SECRET_KEY=test-secret-key-123
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT/api/v1
VIDEO_SERVER_INTERNAL_TOKEN=test-token
CORS_ORIGINS=http://localhost:5174,http://localhost:3000
MAINENV

cat > video-server-wt/.env << VIDENV
VIDEO_SERVER_BASE_URL=http://localhost:$VIDEO_SERVER_PORT/api/v1
MAIN_SERVER_URL=http://localhost:$MAIN_SERVER_PORT
DATABASE_URL=sqlite:///./video_server.db
VIDEO_STORAGE_PATH=./storage/videos
VIDEO_STORAGE_TYPE=local
WATERMARK_DURATION_SECONDS=1
WATERMARK_POSITION=bottom-right
WATERMARK_OPACITY=0.7
SECRET_KEY=test-video-secret
VIDENV

echo "  ✅ test .env files written"

# ─── Start servers ───
echo ""
echo "▸ [2/5] Starting worktree servers"

export VIDEO_SERVER_PORT=$VIDEO_SERVER_PORT

# Start video server
cd video-server-wt
if [ ! -d ".venv" ]; then uv venv; fi
uv pip install -q -r requirements.txt 2>/dev/null || true
echo "  Starting video-server-wt on port $VIDEO_SERVER_PORT..."
nohup .venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $VIDEO_SERVER_PORT > ../test_video_server.log 2>&1 &
cd ..
sleep 3

echo "  Seeding test videos..."
python3 test_seed_videos.py 2>&1 || true
echo "  ✅ test_video_ids.json written"

# Start main server
cd main-server-wt
if [ ! -d ".venv" ]; then uv venv; fi
uv pip install -q -r requirements.txt 2>/dev/null || true
echo "  Seeding main-server-wt data..."
.venv/bin/python3 test_seed_data.py
echo "  Starting main-server-wt on port $MAIN_SERVER_PORT..."
nohup .venv/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port $MAIN_SERVER_PORT > ../test_main_server.log 2>&1 &
cd ..
sleep 3

# ─── Start Dashboard ───
echo ""
echo "▸ [3/5] Starting Dashboard"
cd dashboard
# Ensure dependencies are installed (might take a while if not done)
if [ ! -d "node_modules" ]; then npm install --silent; fi
echo "  Starting dashboard on port $DASHBOARD_PORT..."
nohup npx vite --config vite.config.test.ts --port $DASHBOARD_PORT --host 0.0.0.0 > ../test_dashboard.log 2>&1 &
cd ..
sleep 5

# Verify all running
for p in "${PORTS[@]}"; do
    if is_port_in_use "$p"; then
        echo "  ✅ Port $p — OK"
    else
        echo "  ❌ Port $p — NOT RUNNING"
        # exit 1 # Don't exit, maybe it just takes longer
    fi
done

# ─── Smoke test ───
echo ""
echo "▸ [4/5] Smoke test"

SMOKE=$(curl -s -o /dev/null -w "%{http_code}" \
    http://localhost:$MAIN_SERVER_PORT/api/v1/auth/login \
    -X POST -H "Content-Type: application/json" \
    -d '{"email":"admin@lec.com","password":"admin123"}' 2>/dev/null)

if [ "$SMOKE" = "200" ]; then
    echo "  ✅ Main server login works (HTTP $SMOKE)"
else
    echo "  ❌ Main server login failed (HTTP $SMOKE)"
fi

# ─── Display Info ───
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║          TEST ENVIRONMENT READY       ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Dashboard → http://localhost:5174    ║"
echo "║  Main API  → http://localhost:9000    ║"
echo "║  Video API → http://localhost:9001    ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Logs:                                ║"
echo "║    test_main_server.log               ║"
echo "║    test_video_server.log              ║"
echo "║    test_dashboard.log                 ║"
echo "╚═══════════════════════════════════════╝"
