# Plan 05 — Backend + dashboard hardening round 2, log

## Goal

Clean up the remaining backend/dashboard rough edges: copy-pasted video
ownership checks, broken pagination in `list_manage_videos`, dashboard
session expiry (no auto-refresh), fragile dashboard selectors, and the
hardcoded `ENCRYPTION_KEY` placeholder in build tooling.

## Progress

- Created `Plan/05-hardening-round2.md` (Status ACTIVE) and this log.
- **Step 3 — ownership refactor + pagination: DONE** (committed).
- **CRITICAL INCIDENT — app hang + videos 500 + PDFs 404 (user-reported,
  fixed + deployed).**
  - **App hang (Flutter):** my Plan 01 auto-refresh deadlocked when tokens
    were stale (post-JWT-rotation): refresh POST 401s → re-enters the same
    in-flight `_refreshOnce` future → hangs forever (home infinite load,
    logout dead). Fix: `skipRefresh` flag — the refresh request never
    re-enters the refresh path (committed `11652d1`). **User must
    `flutter run` fresh / clear app data (or just log in again) — old builds
    still have the deadlock.**
  - **Videos 500:** video-server SQLite pool exhausted — the cache cleanup
    worker leaked one DB connection every 5 min (`next(get_db())` never
    closed); 14h uptime → pool drained → every manifest waits 30s and dies.
    Fix: close the session; engine gets WAL + busy_timeout + check_same_thread
    + pool 20 (committed). Verified manifest 200 in 6ms.
  - **PDFs 404:** two compounding causes — (a) my upload-dir fix pointed
    `misc.py` at `<repo>/uploads` while the static mount serves
    `<repo>/main-server/uploads` (fixed to match); (b) seeded materials
    reference sample PDFs that never existed on the server — created minimal
    valid PDFs on prod. Verified 200 via nginx.
  - Full prod chain verified end-to-end: login → courses (13) → lessons →
    manifest 200 (1080p/720p/480p/270p) → playlist 200 (VERSION:7,
    EXT-X-MAP, per-segment AES keys) → R2 segment 200, key proxy 401 without
    auth (correct).
- Next: resume Plan 05 steps (dashboard auto-refresh, ENCRYPTION_KEY).