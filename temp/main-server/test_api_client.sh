#!/bin/bash

BASE_URL="${BASE_URL:-http://localhost:8000}"
API_PREFIX="$BASE_URL/api/v1"

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

log_info() {
    echo -e "${YELLOW}INFO${NC}: $1"
}

echo "=========================================="
echo "LEC Main Server API Test Script"
echo "=========================================="
echo "Testing against: $BASE_URL"
echo "Starting tests..."
echo ""

log_test "Root Endpoint"
RESP=$(curl -s "$BASE_URL/")
if echo "$RESP" | grep -q "LEC Main Server API"; then
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

log_test "Login as Admin"
RESP=$(curl -s -X POST "$API_PREFIX/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@lec.com","password":"admin123"}')
TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
if [ -n "$TOKEN" ]; then
    log_pass "Login successful"
    ADMIN_TOKEN="$TOKEN"
else
    log_fail "Login failed" "$RESP"
    ADMIN_TOKEN=""
fi

if [ -z "$ADMIN_TOKEN" ]; then
    log_info "Cannot proceed without admin token. Exiting."
    exit 1
fi

log_test "Get Current User"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/auth/me")
if echo "$RESP" | grep -q "admin@lec.com"; then
    log_pass "Get current user works"
else
    log_fail "Get current user failed" "$RESP"
fi

log_test "Create Course"
RESP=$(curl -s -X POST "$API_PREFIX/courses" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Course","description":"Test description","visibility":"public","tags":["test"]}')
COURSE_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$COURSE_ID" ]; then
    log_pass "Create course works (ID: $COURSE_ID)"
else
    log_fail "Create course failed" "$RESP"
fi

log_test "List Courses"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/courses")
if echo "$RESP" | grep -q "Test Course"; then
    log_pass "List courses works"
else
    log_fail "List courses failed" "$RESP"
fi

log_test "Get Course"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/courses/$COURSE_ID")
if echo "$RESP" | grep -q "Test Course"; then
    log_pass "Get course works"
else
    log_fail "Get course failed" "$RESP"
fi

log_test "Create Lesson"
RESP=$(curl -s -X POST "$API_PREFIX/lessons" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Test Lesson\",\"description\":\"Test lesson\",\"course_id\":\"$COURSE_ID\",\"order\":1,\"is_published\":true}")
LESSON_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$LESSON_ID" ]; then
    log_pass "Create lesson works (ID: $LESSON_ID)"
else
    log_fail "Create lesson failed" "$RESP"
fi

log_test "Get Lesson"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/lessons/$LESSON_ID")
if echo "$RESP" | grep -q "Test Lesson"; then
    log_pass "Get lesson works"
else
    log_fail "Get lesson failed" "$RESP"
fi

log_test "Create Quiz"
RESP=$(curl -s -X POST "$API_PREFIX/quizzes" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Test Quiz\",\"description\":\"Test quiz\",\"lesson_id\":\"$LESSON_ID\"}")
QUIZ_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$QUIZ_ID" ]; then
    log_pass "Create quiz works (ID: $QUIZ_ID)"
else
    log_fail "Create quiz failed" "$RESP"
fi

log_test "Create Question"
RESP=$(curl -s -X POST "$API_PREFIX/quizzes/$QUIZ_ID/questions" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"type":"multiple_choice","question":"What is 2+2?","options":["3","4","5","6"],"correct_answer":"4","points":1.0,"order":1}')
QUESTION_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$QUESTION_ID" ]; then
    log_pass "Create question works (ID: $QUESTION_ID)"
else
    log_fail "Create question failed" "$RESP"
fi

log_test "Get Quiz"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/quizzes/$QUIZ_ID")
if echo "$RESP" | grep -q "Test Quiz"; then
    log_pass "Get quiz works"
else
    log_fail "Get quiz failed" "$RESP"
fi

log_test "Submit Quiz"
RESP=$(curl -s -X POST "$API_PREFIX/quizzes/$QUIZ_ID/submit" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"answers\":{\"$QUESTION_ID\":\"4\"}}")
if echo "$RESP" | grep -q "score"; then
    log_pass "Submit quiz works"
else
    log_fail "Submit quiz failed" "$RESP"
fi

log_test "Create Access Code"
RESP=$(curl -s -X POST "$API_PREFIX/codes" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"course_id\":\"$COURSE_ID\",\"access_type\":\"full\",\"access_duration\":30}")
CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',''))" 2>/dev/null)
if [ -n "$CODE" ]; then
    log_pass "Create access code works (Code: $CODE)"
else
    log_fail "Create access code failed" "$RESP"
fi

log_test "List Access Codes"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/codes")
if echo "$RESP" | grep -q "$CODE"; then
    log_pass "List access codes works"
else
    log_fail "List access codes failed" "$RESP"
fi

log_test "Get Stats Overview"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/stats/overview")
if echo "$RESP" | grep -q "total_users"; then
    log_pass "Get stats overview works"
else
    log_fail "Get stats overview failed" "$RESP"
fi

log_test "Get Course Stats"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/stats/courses/$COURSE_ID")
if echo "$RESP" | grep -q "course_id"; then
    log_pass "Get course stats works"
else
    log_fail "Get course stats failed" "$RESP"
fi

log_test "Get Video Manifest (no video)"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/videos/$LESSON_ID/manifest")
if echo "$RESP" | grep -q "No video for this lesson"; then
    log_pass "Get video manifest (no video) works"
else
    log_fail "Get video manifest failed" "$RESP"
fi

log_test "Create Report"
RESP=$(curl -s -X POST "$API_PREFIX/reports" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"target_type":"lesson","target_id":"test","reason":"test","description":"test report"}')
REPORT_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -n "$REPORT_ID" ]; then
    log_pass "Create report works"
else
    log_fail "Create report failed" "$RESP"
fi

log_test "List Reports"
RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/reports")
if echo "$RESP" | grep -q "test report"; then
    log_pass "List reports works"
else
    log_fail "List reports failed" "$RESP"
fi

log_test "Record Watch History"
RESP=$(curl -s -X POST "$API_PREFIX/stats/watch" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"lesson_id\":\"$LESSON_ID\",\"watch_time\":100,\"completion_percentage\":50,\"last_position\":60}")
if echo "$RESP" | grep -q "watch_time"; then
    log_pass "Record watch history works"
else
    log_fail "Record watch history failed" "$RESP"
fi

log_test "Update User"
ME_RESP=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_PREFIX/auth/me")
USER_ID=$(echo "$ME_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
RESP=$(curl -s -X PUT "$API_PREFIX/users/$USER_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"first_name":"Admin","last_name":"User"}')
if echo "$RESP" | grep -q "Admin"; then
    log_pass "Update user works"
else
    log_fail "Update user failed" "$RESP"
fi

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo -e "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
RATE=$(python3 -c "print(f'{$PASSED * 100 / $TOTAL:.1f}')")
echo -e "Success rate: ${RATE}%"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi
exit 0