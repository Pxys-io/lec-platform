# Plan 01 — Agent (Flutter) rehaul, log

## Goal

Rehaul the Flutter agent app: fix ugly/clunky UX, buggy flows, and messy
architecture; make playback fully compatible with the MUX transcode pipeline
(fMP4 HLS + AES-128 + dynamic watermarks via main-server proxy). Backend API
is frozen; the app conforms to it.

## Progress

- Created root `AGENTS.md` (PharmX structure: Context / How to work /
  Non-negotiable rules / Commands), `Plan/01-agent-rehaul.md` (Status ACTIVE),
  and this log.
- Synced local master to the remote EC2 state (`ec2r/main` = 358b30d),
  which includes the MUX fMP4-first HLS work (e6053ba), quiz rewrite
  (4d6df6c), and origin-matched break audio (358b30d). Local pre-sync state
  preserved on branch `backup/local-pre-sync-20260914`.
- Flutter toolchain verified: Flutter 3.38.2 / Dart 3.10.0 (matches
  pubspec SDK ^3.10.0).
- Git plumbing: local `origin` repointed to the canonical repo
  `github.com/Pxys-io/lec-platform.git` (was stale `lec.git`); local branch
  renamed `master` → `main` to match upstream; `main` now tracks
  `origin/main` and pushes cleanly. Pre-sync state preserved on
  `backup/local-pre-sync-20260914`.
- Repo hygiene: untracked 72 stray `.dart_tool/` build artifacts + committed
  `agent/pubspec.lock` (per dashboard-v2/AGENTS.md convention); added
  `agent/.dart_tool/`, `agent/pubspec.lock`, `.nvimlog` to root .gitignore.
- **Step 2 — architecture audit (in progress).** Baseline measured:
  - `flutter analyze`: 0 errors, 14 warnings, 79 infos. Warnings include dead
    code in `video_player_screen.dart` (debugMode=false branches), unused
    imports/fields (`_videoStreamUrl`, `_downloadPolicy`), deprecated
    `withOpacity`.
  - `flutter test`: 7 failures — `backend_test.dart` is an integration suite
    requiring a live main server on :8000 (connection refused); `e2e_video_test.dart`
    crashes the tester (needs video server). Not unit-testable as-is.
  - Found architecture/UX problems (first pass):
    - `video_player_screen.dart` is an 898-line monolith (playback, quality,
      download, watermark overlay, comments, mode-mismatch all in one State).
    - `api_client.dart` prints FULL request/response bodies to console in
      production (data leak + noise); no timeouts, no retry, no refresh-token
      flow; `_videoStreamUrl`/`_videoServerUrl` hardcoded via dart-define.
    - `home_screen.dart`: dead `onPressed: () {}` (flame button), hardcoded
      "14 Days" streak, "Resume" button with commented-out navigation,
      pravatar.cc placeholder avatar, untyped `lastItem['progress']` maps.
    - `course_detail_screen.dart`: `dynamic lesson` params, no typing.
    - Router: `/downloads` is a top-level route but no bottom-nav entry;
      `/admin` reachable by any role (no role gate at route level).
    - MUX compatibility: `video_downloader.dart` is already fMP4/AES-128 aware
      (EXT-X-MAP + KEY strip, clear self-contained playlists, .fmt marker);
      `video_player_screen` injects fresh ?token= into proxy URIs. Playback
      path plays remote playlists via a local file copy — works but fragile.
- **Steps 3–8 progress (executed, all committed + pushed):**
  - Step 3 core plumbing: ApiClient reworked (connect/receive timeouts,
    gated debug logging — no more body/JWT printing in prod, automatic 401
    refresh with shared in-flight lock + single retry, removed unused
    `_videoStreamUrl`); refresh token persisted via hydrated auth state;
    AuthCubit wires `onRefresh`; AuthState debug print removed.
  - Step 4 contracts: QBankSession/QBankEnrollment decode JSON-string fields
    (config_json/questions_json/answers_json/form_data_json — were silently
    empty → "0 Questions"); User gains `phone`; Material gains `fileSize`.
  - Step 5 MUX playback: added WatchProgressTracker — the app NEVER reported
    `/stats/watch` before, so continue-watching, watch analytics, and
    `previous_lesson` locks (require >=90%) were dead. Now reported every 15s
    + on dispose. Player got a proper error state with Retry UI (was bare
    spinner + snackbar).
  - Step 6 offline: verified downloader + local server already MUX-ready
    (no changes needed).
  - Step 7 design system: `widgets/app_widgets.dart` (AppSectionHeader,
    AppEmptyState, AppErrorState, AppStatCard, AppStatusBadge, AppSkeletonList,
    AppCourseCard); fixed deprecated `withOpacity`; rebranded splash + app
    title "beIN Med" → "LEC".
  - Step 8 screens: Home (real continue-watching with completion_percentage,
    working Resume, initials avatar, skeletons/empty/error, removed fake
    streak + dead flame button), Discover (working search + tag filters,
    removed dead medical chips), Progress (real stats + continue-watching,
    removed fake chart/timeline), Profile (working edit-profile dialog,
    cert details dialog, removed dead items), Login (validation, removed dead
    Forgot/Google), Register (fixed name/phone fields — name was silently
    dropped by backend), Admin (removed dead quick actions + unused imports),
    removed unreachable OTP screen (no backend), cleaned dead debug overlays
    in player + unused test import.
  - Analyzer: 93 → 78 issues, 0 errors.
  - Follow-ups: course-detail lesson helpers typed (`Lesson`/`List<Lesson>`)
    — surfaced and fixed real null-safety bugs; register screen now sends
    backend fields (first/last name, phone) — the full_name/institution/
    specialty fields were silently dropped by the backend so names were lost;
    profile "Admin Dashboard" entry restricted to admin/super_admin;
    onboarding copy rebranded. Analyzer now 77 issues, 0 errors.
- **Step 10 — verification (in progress).**
  - `flutter analyze`: 77 issues (baseline 93), **0 errors**, 0 warnings in
    app code (remaining are info-level lints in tests + a couple of dead-code
    leftovers already removed).
  - `flutter build apk --debug`: **success** (Gradle assembleDebug).
  - `flutter test test/backend_test.dart` against a locally-seeded main
    server: **6/6 passed** (register/login/courses/lessons/quiz/video/logout;
    quiz+video sub-tests skip when the seeded lesson has none attached —
    expected).
  - `e2e_video_test.dart`: requires `setup.sh --local` full orchestration
    (video server :9001 + cloudflared + fresh DBs); fails in this sandbox
    because the video server won't boot here — pre-existing environment
    limitation, not a rehaul regression.
  - Release APK build running as final CI-equivalent check.
- Next: mark DONE once release build passes; final report.