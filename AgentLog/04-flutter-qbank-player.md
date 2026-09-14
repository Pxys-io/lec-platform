# Plan 04 — Flutter QBank sessions + player decomposition, log

## Goal

Make QBank sessions actually usable in the Flutter app (currently tapping a
session does nothing and question content is missing), and decompose the
898-line video player monolith into focused widgets without changing behavior.

## Progress

- Created `Plan/04-flutter-qbank-player.md` (Status ACTIVE) and this log.
- **Step 2 — audit: DONE.** `questions_json` stores only question IDs (not
  content); submit returned no per-question grading; tutor mode had no
  feedback path. Player screen was 828 lines with UI inline.
- **Step 3 — backend: DONE.**
  - `POST /qbanks/sessions/{id}/check` — per-question tutor check
    (correct/correct_answer/explanation; question must belong to the session;
    student-owner only). No whole-set leak.
  - `POST /qbanks/sessions/{id}/submit` now returns per-question grading
    (`QBankSessionSubmitResponse` with `questions[]`), mirroring the quiz fix.
- **Step 4 — session screen: DONE.** `qbank_session_screen.dart`: question
  navigation, flag, tutor mode (tap → auto-check → inline feedback), timed
  mode (collect → submit), submit confirm, results with per-question review
  from submit grading, retake.
- **Step 5 — wiring: DONE.** QBank screen: recent-session tap resolves full
  questions (GET /qbanks/{id}/questions filtered by session IDs — answers
  stripped server-side) and opens the session; "Start Session" navigates into
  the new session. `QBankSession` model now parses question-ID lists.
- **Step 6 — player decomposition: DONE.** Extracted `PlayerErrorView`,
  `PlayerOverlays` (watermark/top bar/mismatch banner/download progress), and
  `showQualityPicker` into `player/widgets/`. Screen 828 → 595 lines; all
  state orchestration (load, auto-quality, download, timers) stays in the
  screen. Behavior unchanged.
- **Step 7 — verification + deploy: DONE.**
  - `flutter analyze`: 0 errors.
  - `flutter build apk --debug`: builds.
  - main-server tests: 18/18.
  - Smoke: create session → check (correct=false + explanation) → submit
    (score + graded questions) all 200.
  - Server: pulled to b0449f7, `lec-main` restarted, healthy.
- **Plan 04 DONE.** QBank practice is now a real feature; player is
  decomposed.