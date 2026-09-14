# Plan 02 — Backend hardening, log

## Goal

Close the backend security/correctness gaps found during Plan 01: video
server has zero auth (public raw originals + AES keys), quiz/qbank answers
leak to students, `/users/me/courses` 500s, `/misc/upload` returns 404 URLs,
dev secrets in prod, plain SHA-256 passwords, fake MUX job records.

## Progress

- Created `Plan/02-backend-hardening.md` (Status ACTIVE) and this log.
- **Step 2 — P0 video-server auth: DONE.**
  - `video-server/app/core/security.py`: `require_internal_token` gate
    (HTTPBearer, compares `INTERNAL_AUTH_TOKEN`; empty = dev-off).
  - All `/internal/videos/*` routes now require it (router-level dependency).
  - Main server now sends the token on the 3 proxy call sites that lacked it
    (manifest, playlist, generic proxy) and rewrites EVERY video-server origin
    (not just localhost:8001) to the authenticated main-server proxy.
  - Verified: no token → 401, correct token → 200, wrong token → 401.
- **Step 3 — P0 answer leaks: DONE.**
  - `GET /quizzes/{id}/questions` + `GET /qbanks/{id}/questions` strip
    `correct_answer`/`explanation` for students (kept for instructors/admins).
  - `POST /quizzes/{id}/submit` now returns per-question grading
    (new `QuizSubmitResponse`/`QuizQuestionResult` schemas) so review works
    without answers leaking via GET.
  - Flutter quiz screen uses the submit-response grading for the review UI
    (falls back to in-memory for legacy responses).
  - Verified: student GET → empty answers; instructor GET → answers; submit →
    per-question correct/explanation/is_correct.
- **Step 4 — `/users/me/courses` 500: DONE.** `db.get(course_id, course_id)`
  → `db.get(Course, course_id)`. Verified 200 + 3 courses.
- **Step 5 — qbanks 500: DONE.** Nonexistent `HTTP_400_BAD_USER_INPUT` →
  `HTTP_400_BAD_REQUEST` (empty-subject session).
- **Step 6 — `/misc/upload` 404 URLs: DONE.** Mounted StaticFiles at
  `/uploads`; upload dir resolved from `__file__` (CWD-proof); file-type
  allowlist; URL built from request base. Merged with the server's own
  uncommitted version of the same fix. Verified upload → URL → 200 download.
- **Step 7 — secrets: DONE.**
  - Code defaults: `VIDEO_SERVER_INTERNAL_TOKEN` now empty (no working dev
    default); video-server `INTERNAL_AUTH_TOKEN` empty default.
  - `setup.sh` generates strong `openssl rand` JWT + internal token for every
    written .env (dev + tunnel sections).
  - Local + server .env rotated to fresh strong values; services restarted.
  - NOTE: JWT rotation invalidates existing sessions → users re-login once.
- **Step 8 — bcrypt passwords: DONE.**
  - `security.py`: bcrypt for new hashes (direct `bcrypt` pkg, not passlib —
    passlib 1.7.4 is incompatible with bcrypt>=4.1), legacy SHA-256 verified
    and upgraded in-place on successful login (no lockout).
  - `seed_data.py` now seeds bcrypt. Verified: legacy login works + hash
    becomes `$2b$12$...`; new registrations bcrypt; re-login 200.
- **Step 9 — real MUX job records: DONE.**
  - `mux_transcode` creates/updates a real `TranscodeJob` (running →
    completed/error, progress 5→100, resolutions_completed, error_message).
  - `start_transcode`/`complete_upload`/`upload_video` create real job rows
    (no more fake random-UUID response).
  - Fixed the video-server test suite: wrong API prefix (`/api/v1/internal/...`
    vs `/internal/...`) was causing 12 pre-existing failures; added auth
    headers; MUX job status expectation. **24/24 pass** (was 12/24).
- **Step 10 — verification + deploy: DONE.**
  - main-server `test_api.py`: **18/18 pass**.
  - video-server `test_api.py`: **24/24 pass**.
  - Flutter `flutter analyze`: 0 errors.
  - Deployed to EC2 (`ec2r`): server repo synced to origin/main (WIP on
    `wip-server-local` branch, restored agent/dashboard changes on main),
    .env rotated (JWT + internal token), video server restarted via systemd,
    main server restarted via setsid/nohup. Verified live: main+video health
    OK, video internal 401 without token / 200 with, login works.
- **Plan 02 DONE.** All 10 steps complete and deployed.