# Plan 05 — Backend + dashboard hardening round 2

Status: **ACTIVE**

Scope: `main-server/` + `dashboard-v2/` + build tooling. Follow-ups from the
Plan 01 audit that weren't covered by Plans 02–04:

1. **`misc.py` video-ownership copy-paste** — ~6 near-identical
   instructor-can-only-touch-own-videos blocks; extract one helper.
2. **`list_manage_videos` pagination bug** — fetches 500 then slices
   `[skip:skip+limit]` after local filtering (wrong counts/offsets).
3. **Dashboard session expiry** — v2 has no refresh flow; users are logged
   out the moment the access token expires. Wire auto-refresh like the
   Flutter app.
4. **Dashboard fragile bits** — `Users.tsx` ban duration read via
   `document.querySelector`; `Courses.tsx` `attachVideo` convoluted
   course-id expression.
5. **`ENCRYPTION_KEY` placeholder** — build-apk.sh + GitHub workflow hardcode
   `my_32_char_super_secret_key_!!!!`; make them read a real key from env
   (stable across builds of a release; existing installs keep their key).

## Steps

1. Plan + log files, commit.
2. Audit: read the ownership blocks + `list_manage_videos`, dashboard
   `auth.tsx`/`api.ts`/`Users.tsx`/`Courses.tsx`, build-apk.sh + workflow.
3. Backend: extract `get_owned_video_or_403` helper; apply to all ownership
   blocks; fix `list_manage_videos` pagination.
4. Dashboard: auto-refresh on 401 (persist refresh token, single-flight,
   retry once); fix Users ban select; fix Courses attachVideo.
5. Build tooling: `ENCRYPTION_KEY` from env in build-apk.sh + workflow with
   clear error when missing.
6. Verify: main-server tests, `npm run build`, boot checks. Deploy backend +
   dashboard. Mark DONE, log, report.

## Verification

- `main-server`: `.venv/bin/python test_api.py` green.
- `dashboard-v2`: `npm run build` green; manual: let token expire → next
  action auto-refreshes (no logout).
- `bash -n build-apk.sh`; workflow YAML parses.
- Deployed: server `lec-main` restarted; dashboard dist rsynced.