# Plan 04 — Flutter QBank sessions + player decomposition

Status: **DONE**

Scope: `agent/` (Flutter). Two work items from the Plan 01 audit that were
left as follow-ups:
1. **QBank sessions are dead** — tapping a recent session does nothing
   (commented out), and `questions_json` stores only question IDs, so the app
   has no question content to render. Build a real QBank session screen
   (tutor/timed, submit, results) and wire the session questions from the
   qbank's question list by ID (answers stay server-side until submit).
2. **The video player is an 898-line monolith** — split it into focused
   widgets/services with identical behavior, then verify.

## Steps

1. Plan + log files, commit.
2. Audit: read `qbank_screen.dart`, `qbank_cubit.dart`, `quiz_repository.dart`
   QBank session methods, backend `submit_qbank_session`, and the player
   screen's current structure. Confirm the session questions source.
3. Backend (if needed): make QBank session submit return per-question grading
   (mirroring the quiz submit fix) so the app can render review.
4. QBank session screen: question-by-question UI (tutor feedback / timed
   countdown), answer persistence, submit → results with review, retake.
5. Wire QBank screen: tapping a recent session opens the session screen
   (resume if in progress); creating a session navigates into it.
6. Player decomposition: extract error view, quality picker, overlays, and
   download progress into widgets; keep player state orchestration in the
   screen. Behavior unchanged.
7. Verification: `flutter analyze` clean, debug + release APK build, backend
   integration tests still green. Mark DONE, log, report.

## Verification

- `cd agent && flutter analyze` — 0 errors.
- `cd agent && flutter build apk --debug` — builds.
- Backend: `POST /qbanks/{id}/sessions` + `POST /qbanks/sessions/{id}/submit`
  return grading; main-server tests pass.
- Manual: create QBank session → answer questions → submit → review shows
  correct answers/explanations; video player still plays (code path
  unchanged by refactor).