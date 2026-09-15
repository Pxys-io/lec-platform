# Plan 07 — v1 dashboard revival: port v2-only features, make v1 live

Status: **ACTIVE**

Scope: `dashboard/` (v1). The user finds v2 awful and wants v1 back as the
running dashboard. v1 is already richer in most areas (resumable upload,
preview player, full quiz/qbank/enrollment/certificates/lessons); the
v2-only gaps to port are small but include a critical bug:

1. **Users ban is BROKEN in v1** — sends `?days=`, backend requires
   `?ban_duration_days=` → every ban 422s. Fix param + add duration select
   (v2 has 1/7/30/365d).
2. **Settings server-mode editor (v2-only)** — v1 Settings is env-config
   only; add server_mode/download_policy/mode_mismatch_action editor hitting
   the (newer-than-v1) `/misc/server-mode` routes.
3. **Verify v1 against current backend** — v1 predates video-server auth,
   proxy rewrite, quiz grading, is_locked, MUX jobs. All additive/proxy-side
   so v1 should work unchanged, but verify by building + smoke-testing every
   page against prod API.
4. **Make v1 live** — `npm run build` in `dashboard/`, rsync `dist/` to
   `ec2r:/root/repos/lec/dashboard/dist/`, verify the live bundle + key
   pages. Stop the pointless v1 `:5173` dev service? NO — keep running until
   v1-live is confirmed, then decide.
5. Docs: root AGENTS.md + dashboard-v2/AGENTS.md updated (v1 live, v2 frozen).

## Verification

- `cd dashboard && npm run build` — tsc + vite clean.
- Live: bundle title/markup is v1; login works; Users ban with duration;
  Settings server-mode save persists; Videos upload/preview/transcode;
  Quizzes/QBanks/Enrollment/Certificates/Lessons pages load.
- `git log` shows per-feature microcommits.