#!/bin/bash

BASE_URL="${BASE_URL:-http://localhost:8001}"
API_PREFIX="$BASE_URL/api/v1/internal/videos"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

log_test() {
    TOTAL=$((TOTAL + 1))
    echo -e "\n=== Test: $1 ==="
}

log_pass() {
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}PASS${NC}: $1"
}

log_fail() {
    FAILED=$((FAILED + 1))
    echo -e "${RED}FAIL${NC}: $1"
    if [ -n "$2" ]; then
        echo -e "  Response: $2"
    fi
}

echo "=========================================="
echo "LEC Video Server API Test Script"
echo "=========================================="
echo "Testing against: $BASE_URL"
echo ""

log_test "Root Endpoint"
RESP=$(curl -s "$BASE_URL/")
if echo "$RESP" | grep -q "LEC Video Server API"; then
    log_pass "Root endpoint works"
else
    log_fail "Root endpoint failed" "$RESP"
fi

log_test "Health Check"
RESP=$(curl -s "$BASE_URL/health")
if echo "$RESP" | grep -q "healthy"; then
    log_pass "Health check works"
else
    log_fail "Health check failed" "$RESP"
fi

log_test "Create Video"
RESP=$(curl -s -X POST "$API_PREFIX" \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Video","description":"Test description","original_filename":"test.mp4","original_path":"/uploads/test.mp4","watermark_enabled":true,"watermark_segments":10,"watermark_text":"Test User"}')
VIDEO_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$VIDEO_ID" ]; then
    log_pass "Create video works (ID: $VIDEO_ID)"
else
    log_fail "Create video failed" "$RESP"
fi

log_test "Get Video"
RESP=$(curl -s "$API_PREFIX/$VIDEO_ID")
if echo "$RESP" | grep -q "Test Video"; then
    log_pass "Get video works"
else
    log_fail "Get video failed" "$RESP"
fi

log_test "Update Video"
RESP=$(curl -s -X PUT "$API_PREFIX/$VIDEO_ID" \
    -H "Content-Type: application/json" \
    -d '{"title":"Updated Video","status":"ready"}')
if echo "$RESP" | grep -q "Updated Video"; then
    log_pass "Update video works"
else
    log_fail "Update video failed" "$RESP"
fi

log_test "Get Video Status"
RESP=$(curl -s "$API_PREFIX/$VIDEO_ID/status")
if echo "$RESP" | grep -q "ready"; then
    log_pass "Get video status works"
else
    log_fail "Get video status failed" "$RESP"
fi

log_test "Get Video Manifest (no resolutions)"
RESP=$(curl -s "$API_PREFIX/$VIDEO_ID/manifest")
if echo "$RESP" | grep -q "No ready resolutions found"; then
    log_pass "Get manifest (empty) works"
else
    log_fail "Get manifest failed" "$RESP"
fi

log_test "Get Video Stream (no resolution)"
RESP=$(curl -s "$API_PREFIX/$VIDEO_ID/stream")
if echo "$RESP" | grep -q "Resolution not ready"; then
    log_pass "Get stream (empty) works"
else
    log_fail "Get stream failed" "$RESP"
fi

log_test "Delete Video"
RESP=$(curl -s -X DELETE "$API_PREFIX/$VIDEO_ID")
if echo "$RESP" | grep -q "deleted successfully"; then
    log_pass "Delete video works"
else
    log_fail "Delete video failed" "$RESP"
fi

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
RATE=$(python3 -c "print(f'{$PASSED * 100 / $TOTAL:.1f}')")
echo -e "Success rate: ${RATE}%"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi
exit 0