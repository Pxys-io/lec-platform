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
- **Player 401 root cause (user-reported, fixed + deployed).**
  - Debug prints added to the app (`player_debug.dart` + instrumented
    `_loadAndPlay`); user logs showed a VALID token but a 17-line cached
    playlist with no proxy/key URLs.
  - Two layers: (a) stale poisoned temp cache (pre-proxy direct URLs, dead
    since Plan 02 auth) — fixed with playlist validation + versioned cache
    keys + legacy purge (committed `7d1b638`); (b) the REAL bug: my Plan 02
    proxy-rewrite regex never matched anything (full origins with scheme
    inside an alternation already prefixed with `https?://` = double-scheme
    requirement). Local-storage videos (segment URLs built from the video
    server's own base) passed through raw → 401 on every segment. R2 videos
    worked, which is why verification passed.
  - Fix: host-agnostic `rewrite_video_server_urls_to_proxy` (match the
    `/internal/videos/` path, skip already-proxied, leave R2 URLs alone),
    applied to both playlist proxies (committed `e19fd70`, deployed).
  - Verified: failing lesson now returns proxied segments; segment fetch
    200 with `?token=`, 401 without (correct).
- Next: resume Plan 05 steps (dashboard auto-refresh, ENCRYPTION_KEY).
- **User-reported trio (fixed, committed `f9b447b`, debug APK builds).**
  - **Auto-advance:** player now shows an "Up next" card with 10s auto-play
    countdown once max position reaches >=90% — seek-proof (driven by
    `WatchProgressTracker.isComplete`, not natural completion). Flushes the
    final report BEFORE navigating so `previous_lesson` gates are satisfied.
    Quiz-gated next lessons show the card without autoplay (backend would
    403). Last lesson: no card. Quiz-only next lessons load the quiz and
    replace the route. `courseId` added to the player route; passed from
    course detail / home / progress (downloads play without it = no advance).
  - **Continue watching:** was empty because home never reloaded stats after
    playback (shell branch preserves state; loadStats ran only at startup +
    pull-to-refresh). Player dispose now chains flush-then-`StatsCubit`
    reload, so continue-watching picks up the session on return. Backend
    flow verified on prod (report 45% → listed; 95% → correctly filtered as
    completed).
  - **Enroll on owned courses:** `CourseRepository.getMyCourses` +
    `CourseLoaded.ownedIds`; course detail hides the Enroll bottom sheet when
    owned and shows an "Enrolled" badge. Also re-merged the server-WIP
    materials support in course detail with restored `Lesson` typing.
- **Lessons stay Locked after Play-next (user-reported, fixed `31e650f`,
  deployed, APK builds).**
  - Root cause: the app decided locked-ness from `lockType != 'none'` alone
    and NEVER evaluated whether the gate was satisfied — every gated lesson
    showed the lock icon + locked dialog forever, even with 100% watched.
    Play-next worked only because it bypasses the list UI straight to the
    player (backend gate passes).
  - Fix: `LessonResponse.is_locked` computed server-side per user via
    `check_lesson_access` (same logic that guards playback); Flutter `Lesson`
    parses it (falls back to lockType when absent) and course detail uses
    `lesson.isLocked` for icon + tap.
  - Verified live on prod: Cardiology Essentials shows is_locked=False for
    satisfied gates, True only where the previous lesson is truly incomplete.
- **Quiz ElevatedButton crash + blank PDFs (user-reported, fixed).**
  - Crash: app theme sets `minimumSize: Size(double.infinity, 50)` on ALL
    elevated buttons; any ElevatedButton placed directly in a Row (quiz
    Next/End, quiz submit dialog, locked-lesson dialog, qbank submit dialog)
    gets infinite width → layout explosion. Fixed with finite local
    `styleFrom(minimumSize:)` on all 5 Row-placed buttons (Column/Container
    placements are safe and untouched).
  - Blank PDFs: NOT a viewer bug — my earlier server-side placeholder PDFs
    were empty shells with no content stream (render as blank, zero errors).
    Replaced all three sample PDFs with real single-page text PDFs (valid
    xref, Helvetica content); verified structurally + served with content.
- **Results-screen Retake crash + quiz progress persistence (fixed `05963fa`).**
  - The crash recurred on the results screen (`ElevatedButton.icon` in a
    Row) — whack-a-mole patching wasn't enough. Systemic fix: theme default
    is now finite (`Size(64, 50)`); the 5 full-bleed buttons (login, register,
    logout, enroll sheet, onboarding) got explicit `SizedBox(width:
    double.infinity)` wrappers. The bug class is dead: any future
    ElevatedButton in a Row is safe by default.
  - Quiz progress now auto-saves (answers + index to SharedPreferences on
    every answer/navigation), restores automatically with a snackbar when the
    quiz is reopened, clears on submit/retake, and has a reset action (top
    bar) with confirm.
- **Design taste pass (`@design-taste-frontend`, committed `1a43519`).**
  - Declared read: student mobile edtech app, Material 3, dials 4/3/5.
    Full landing-page patterns N/A per the skill's own Section 13; applied
    the product-UI subset only.
  - Inter → Outfit app-wide (kills the top AI-tell; same GoogleFonts API).
  - Semibold CTA labels (white-on-secondary passes large-text contrast).
  - Documented the shape scale (containers 16-24, buttons pill 30,
    adornments 4-8) in the theme file.
  - Copy self-audit: sentence-case auth headlines, dropped the invented
    "Learn. Engage. Complete." backronym, removed the fabricated 4.8 course
    rating + placeholder instructor name, course cards show tags instead of
    raw visibility codes, zero em-dashes in visible copy.
  - Verified: no UI emoji, single Lucide icon family, one locked palette,
    empty/loading/error states already covered by shared widgets.
  - Honest limitation: no screenshot verification available in this
    environment — visual check left to the user on-device.
- **Downloads stall + offline localhost + continue-watching crash (fixed).**
  - Continue-watching `List<Map>.from` cast crash: `_replaceLocalhostInJson`
    produced `Map<dynamic,dynamic>` (only surfaced once items existed).
    Fixed systemically in ApiClient (rebuild as `Map<String,dynamic>`) +
    hardened `getContinueWatching`.
  - Download stalls: Dio had zero timeouts (a hung segment froze progress
    forever) and zero retries (one flake killed the download silently).
    Now 20s connect / 120s receive timeouts, 3 attempts with backoff,
    throttled progress emits, `[DOWNLOAD]` logs, and failures surface in the
    Downloads screen instead of vanishing.
  - Offline playback no longer needs the localhost server: clear-format
    downloads play directly from files (works on iOS where no local server
    is assumed); local server kept only for legacy-format fallback.
    Android `usesCleartextTraffic` + iOS `NSAllowsLocalNetworking` added for
    that fallback path.
- **Encrypted-at-rest downloads (built, `hls-enc-v1`).**
  - Segments stored EXACTLY as received (server AES-128 ciphertext, never
    decrypted on device); each playlist key fetched once with auth into a
    local `key_N.bin`; playlist keeps EXT-X-KEY with local URIs + original
    per-segment IVs. Zero crypto code at download beyond what existed.
  - Playback is pure file:// with relative refs — no server, no token, both
    platforms. Downloads screen shows a lock badge on encrypted items.
  - Honest limits: key file sits beside the segments (offline play without a
    server requires it) — stops casual copy-play cold; a determined user
    with the whole folder can reassemble (true of any non-hardware-DRM
    offline). Leak-tracing remains watermarks + screenshot blocking. Caveat:
    if the server ever rotates a video key, old downloads need re-download.- **Continue Learning empty though videos started (user-reported, fixed
  `6ff2ec3`, deployed, verified 200/200).**
  - Debug path: prod DB showed the user's reports DO arrive; `/stats/
    continue-watching` returns 2 items; but `/stats/overview` **500s for
    every student** (student branch omits required `new_users_this_month` +
    `active_users_this_month`; `total_quizzes` not even in schema). One
    `loadStats` failure blanked the whole home, hiding the working list.
  - Fix: schema defaults for those fields (+ added `total_quizzes`, passed
    from the student branch); `StatsCubit.loadStats` now fetches overview +
    continue-watching independently (partial failure degrades, never blanks);
    `[STATS]` logs on loads + `[PLAYER] watch-report ok/FAILED` on every
    report so this class of issue is visible in logcat next time.
  - Note for user: videos watched past 90% correctly disappear from the
    list (backend in-progress-only rule); the 2 items visible now are older
    0% rows. New watches will appear after exiting the player (or
    pull-to-refresh).
- **Zombie 20% downloads (user-reported, fixed `e4ad0c3`).**
  - The course tile requests 1080p; videos with lower max trigger the cubit's
    404 fallback (e.g. 360p). The first progress callback replaced the item's
    resolution while matching still used the requested one — later updates,
    completion-removal, and cancel all missed → "20% downloading..." stuck
    forever with a dead cancel button, even though bytes finished (5/5).
  - Fix: per-download effective-resolution map, locked in (with a state sync
    emit) the moment the fallback resolves; progress/removal/cancel all match
    on it. Stuck items are memory-only state, so a fresh app start clears any
    existing zombies.
- **Enroll button fixes (user-reported, fixed).**
  - Public courses (and "default"-tagged ones) need no enrollment at all —
    backend grants access without it. Enroll button now hidden for those +
    owned courses (Enrolled badge covers owned).
  - Button moved from Scaffold bottomSheet into the scrollable body under
    the description: always reachable, never clipped by device chrome.
- **Resume never seeks though tracking works (user-reported, fixed,
  verified by user).**
  - Debug path: `[STORE]` tagging proved tick/dispose saves all landed;
    yet every open read `(0, dur)`. Root cause: the screen's OWN first
    listener tick (pos 0 during `initialize()`) wrote `(0, dur)` BEFORE
    `_applyResumePosition` read the store — resume read its own clobber,
    not the previous session. Queued behind a parallel session's
    overlapping work, resolved together: snapshot position in
    `_initializePlayer` before any controller/listener exists; sub-second
    saves banned; server `last_position` fallback via warmed stats;
    zero-never-overwrites guard + boot tags + write-ok logging kept as
    defense in depth; pending-seek (apply on valid duration) kept for HLS
    timing. User confirmed: works.
- **Device count in Profile settings (built + deployed).**
  - New self-service endpoints `GET /users/me/devices` (count+limit+list)
    and `DELETE /users/me/devices/{device_id}` (placed before `/{user_id}`
    routes to avoid collision). Profile shows "N of M devices used" row +
    bottom sheet with per-device type/last-active, "This device" badge, and
    remove-with-confirm for others. Verified live (list/delete/404).
  - Deploy note: first restart raced the git pull (ImportError on a
    half-written tree); clean restart fixed it. Lesson: pull, verify import,
    then restart.
