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
- Next: architecture audit (step 2) — map screens/cubits/repositories/models
  against main-server schemas; catalog contract mismatches and broken flows.