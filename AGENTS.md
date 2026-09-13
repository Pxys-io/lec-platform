# AGENTS.md — LEC

Guidance for AI agents working in this repository.

## Context

LEC is an online education platform: courses with lessons, video lectures,
PDF materials, quizzes, Q-banks, access codes, comments/messages, reports,
and per-user watch analytics. Four systems live here:

1. **Main server** — `main-server/` (FastAPI + SQLModel). Auth (JWT), users,
   courses, lessons, materials, quizzes, qbanks, enrollment, access codes,
   reports, stats, messages, certificates, panic mode, and the video proxy.
   The only server the Flutter app and dashboard talk to.
2. **Video server** — `video-server/` (FastAPI). Video ingest, **MUX
   transcoding** (default), R2/local storage, HLS serving, AES-128 segment
   encryption, and dynamic per-user watermarks (overlay + break-screen).
   Internal-only API under `/internal/videos/*`; the Flutter app NEVER talks
   to it directly — everything goes through the main server proxy.
3. **Agent app** — `agent/` (Flutter). Student/instructor/admin client.
   Consumes only main-server APIs; video playback via HLS manifests proxied
   through main server.
4. **Admin dashboard** — `dashboard-v2/` (Vite + React 19 + TS, hand-rolled
   CSS). Admin/instructor console. `dashboard/` is the legacy v1 — do not
   touch it; it exists only for reference.

Full product requirements: `Specs.md`. Per-component architecture specs live
in each component's own `Agents.md`/`AGENTS.md` (agent/, main-server/,
video-server/, dashboard-v2/).

## How to work

1. **Read the active plan first.** Plans live in `Plan/`. The active one is the
   highest-numbered file whose Status is `ACTIVE`. Follow its steps in order.
2. **Log progress.** Before starting a plan and after each step, append to the
   matching `AgentLog/` file: what was done, what was verified, deviations,
   next step.
3. **Microcommit + push.** Commit after EVERY plan step (and subfeature) with
   message `todo-done: <what was done>` and push to origin.
4. **Verify before committing.** Run the plan's verification commands
   (pytest for servers, `flutter analyze`/build for the app, `npm run build`
   + E2E for the dashboard).
5. **When a plan is complete:** mark its Status as `DONE` in `Plan/`, note it
   in `AgentLog/`, and report a summary. Start a new plan file (next number)
   for follow-up work.
6. **Keep moving.** After finishing a step, jump to the next step without
   asking for confirmation.

## Non-negotiable rules

- **Model/route freeze:** the core models, API routes, and names defined in
  the component `Agents.md` specs are fixed. Any change must be discussed and
  approved by the lead architect.
- **Video only through Main Server:** the Flutter app and dashboard never call
  the video server directly. All HLS manifests, segments, keys, and watermark
  URLs are proxied/served through main server with token injection.
- **MUX-first transcoding:** new uploads transcode via MUX direct upload
  (fMP4 output); local ffmpeg transcoding is a fallback only when MUX is
  disabled. Playlists must remain fMP4-safe (EXT-X-VERSION 7, EXT-X-MAP,
  correct video/mp4 MIME, stored target_duration).
- **Watermarks:** every video carries dynamic per-user watermarks (overlay or
  break-screen), generated in the origin container (fMP4 for MUX, TS for
  local). Never mix containers in one playlist.
- **Encryption:** HLS segments are AES-128 encrypted; keys are served only
  through the proxied `/key` endpoint with per-segment IVs. Offline downloads
  strip encryption at download time into clear, self-contained playlists.
- **Access control:** course/lesson access is enforced server-side; lesson
  locks (none/previous/quiz) are evaluated live, never from stale flags.
- **Dashboard UX:** every visible control must have a real, verified backend
  effect (no no-op/placeholder click targets); destructive actions need
  confirm; E2E suites must pass before committing dashboard changes.
- **Contracts:** the Flutter models and dashboard API layer must match the
  main-server schemas exactly (field names, enums, nullability). If the
  backend changes a contract, update all consumers in the same commit.
- **IDs:** UUID v4. **Timestamps:** ISO 8601 UTC strings.
- Don't add code comments unless asked. Keep commits small and per-feature.
- Never commit `.env` files, secrets, `*.db`, build artifacts, or `storage/`.

## Commands

- Main server: `cd main-server && .venv/bin/uvicorn app.main:app --reload --port 8000`, tests `.venv/bin/python test_api.py` (or `pytest`)
- Video server: `cd video-server && .venv/bin/uvicorn app.main:app --reload --port 8001`, tests `.venv/bin/python test_api.py`
- Agent app: `cd agent && flutter pub get && flutter run`, checks `flutter analyze`
- Dashboard: `cd dashboard-v2 && npm run dev`, build `npm run build`, deploy via rsync `dist/` to `ec2r:/root/repos/lec/dashboard/dist/`
- E2E (dashboard, on ec2r): `/tmp/puppeteer-upload/*.js` — `dash2_e2e.js`, `endpoints_e2e.js`, `qol_e2e.js`, `scope_e2e.js`
- Production: main server on EC2 (`ec2r`), cloudflared tunnels for public URLs (see `tunnel.conf`).