# Plan 07 — v1 revival, log

## Goal

Port v2-only features into v1 (`dashboard/`) and make v1 the live dashboard.
v1 is already richer (resumable chunked upload with localStorage resume,
watermarked preview player, full quiz/qbank/enrollment/certificates/lesson
editing); v2's only real leads are the Settings server-mode editor and the
working Users ban flow (v1's ban call is broken: wrong query param).

## Progress

- Created `Plan/07-v1-revival.md` (Status ACTIVE) and this log.
- Diff summary (v2 vs v1, page by page):
  - Videos: v1 superior (resume upload, preview player, per-res badges,
    queue position). v2 adds only transcode_method chip/created_at — skip.
  - Users: v1 HAS create/role/ban/unban/devices-detail, but ban sends
    `?days=` (backend: `?ban_duration_days=`) → broken. Port duration
    select + fix param.
  - Codes/Reports/Panic: parity (generate/deactivate, resolve, full CRUD).
  - Settings: v1 = env-config editor only; v2 = server-mode editor only.
    Port server-mode section into v1 (keep env-config).
  - Home: v1 stats richer (weekly active). No port.
  - Courses/Lessons/Quizzes/QBanks/Enrollment/Certificates: v1 full. No port.
- Next: fix v1 ban, add server-mode to v1 Settings.