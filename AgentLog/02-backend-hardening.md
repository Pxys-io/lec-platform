# Plan 02 — Backend hardening, log

## Goal

Close the backend security/correctness gaps found during Plan 01: video
server has zero auth (public raw originals + AES keys), quiz/qbank answers
leak to students, `/users/me/courses` 500s, `/misc/upload` returns 404 URLs,
dev secrets in prod, plain SHA-256 passwords, fake MUX job records.

## Progress

- Created `Plan/02-backend-hardening.md` (Status ACTIVE) and this log.
- Next: P0 video-server auth (step 2).