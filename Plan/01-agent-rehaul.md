# Plan 01 — Agent (Flutter) rehaul: UX, bugs, architecture + MUX playback compatibility

Status: **ACTIVE**

Scope: `agent/` (Flutter app) only. The app "sucks" for three reasons the
user named: UI/UX is ugly/clunky, flows are buggy, architecture is messy.
Additionally the app must be fully compatible with the MUX transcode pipeline
(fMP4 HLS + AES-128 + dynamic watermarks, all proxied through main server).
Backend API routes/models are FROZEN — the app must conform to them, not the
other way around.

## Steps

1. Plan + log files + root AGENTS.md (PharmX structure), commit.
2. Architecture audit: map every screen/cubit/repository/model against the
   main-server schemas; list contract mismatches, dead code, duplicated
   state, and broken flows. Log findings.
3. Core plumbing: fix `ApiClient` (timeouts, retry, 401 refresh, remove
   request/response body debug printing), token storage, error surfaces.
4. Contract alignment: correct Flutter models to match backend exactly
   (field names, enums, nullability) — update all consumers in the same
   commit.
5. MUX playback compatibility: verify HLS playback (fMP4, EXT-X-MAP,
   AES-128 keys, overlay + break watermarks) through the main-server proxy;
   fix player token injection, error UI, retry, and resolution fallback.
6. Offline downloads: MAP/KEY handling, encryption strip at download,
   self-contained playlists, local server serving init + correct MIME for
   fMP4/TS, resume/versioning.
7. Design system: theme, colors, typography, shared components (cards,
   buttons, skeletons, empty/error states, badges) applied across screens.
8. Screen-by-screen UX rehaul: home, discover, course detail, lesson,
   video player, quiz, qbank, downloads, profile, chat/inbox, comments,
   admin, panic mode.
9. Flow bug-fix pass: auth (login/register/OTP/refresh), course locks
   (none/previous/quiz), progress + continue watching, quiz sessions,
   comments/messages/reports, certificates.
10. Verification: `flutter analyze` clean, `flutter test` green, APK build
    succeeds, manual smoke on emulator/device against prod API. Mark DONE,
    log, report.

## Verification

- `cd agent && flutter analyze` — zero errors.
- `cd agent && flutter test` — all tests pass.
- `cd agent && flutter build apk --debug` (or `build-apk.sh`) — build succeeds.
- Manual smoke: login → browse → play video (watermarked, encrypted) →
  download → offline play → quiz → course lock progression — on emulator
  against the prod API (`https://main.lec.pxysio.top/api/v1`).