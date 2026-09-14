# Plan 02 — Backend hardening: auth, answer leaks, 500s, secrets

Status: **ACTIVE**

Scope: `main-server/` and `video-server/` (backend). Fixes the security and
correctness issues found during Plan 01's audit, in severity order. The
Flutter app + dashboard contracts stay source-compatible (no breaking route
changes; response shapes only get *less* leaky where clients shouldn't have
had the data anyway).

## Steps

1. Plan + log files, commit.
2. **P0 — Video server auth:** require the internal token on every
   `/internal/videos/*` route. Today the video server is publicly exposed with
   zero auth: anyone can list videos, download raw originals, fetch AES-128
   keys, and upload. Verify main server sends the token.
3. **P0 — Answer leaks:** `GET /quizzes/{id}/questions` and
   `GET /qbanks/{id}/questions` return `correct_answer` to students. Strip
   answers (and explanations) for non-instructor callers; keep them in the
   submit/result responses the client needs for review.
4. **P1 — `GET /users/me/courses` 500:** `db.get(course_id, course_id)` →
   `db.get(Course, course_id)`.
5. **P1 — `qbanks.py` 500 on empty session:** nonexistent
   `HTTP_400_BAD_USER_INPUT` → `HTTP_400_BAD_REQUEST`.
6. **P1 — `/misc/upload` broken URLs:** mount static serving for `uploads/`
   so returned material/enrollment URLs actually resolve.
7. **P1 — Secrets:** rotate dev JWT secret + internal token; generate strong
   values, update `.env`/config, keep code defaults as non-working
   placeholders.
8. **P2 — Password hashing:** upgrade from plain SHA-256 to bcrypt
   (incremental: verify legacy SHA-256 and rehash on login; new hashes bcrypt).
9. **P2 — MUX job records:** persist a real `TranscodeJob` for MUX transcodes
   so the dashboard job list/status works (was a fake random-UUID response).
10. Verification: pytest + API smoke for each fix; commit per step; mark
    DONE, log, report.

## Verification

- `main-server`: `.venv/bin/python test_api.py` (or pytest) — green; boot
  check `/health`.
- `video-server`: `.venv/bin/python test_api.py` — green; boot check.
- Manual curl: internal routes without token → 401; with token → 200.
- Questions endpoints as student → no `correct_answer`; as instructor → has it.
- `/users/me/courses` returns 200 for a user with course access.
- `/misc/upload` returns a URL that downloads the file.
- Login with a legacy SHA-256 hash still works and upgrades to bcrypt.