# Plan 06 — UWorld-style QBanks, log

## Goal

Purchasable QBanks (course-attached or separate), chapter/system/topic
organization with filtering, UWorld-style review (adjustable reveal,
explanations, peer percentages), a real quiz generator, and quiz progress
with resume on the Progress screen. Backend adjusted for all of it.

## Progress

- Created `Plan/06-qbank-uworld.md` (Status ACTIVE) and this log.
- Next: backend models + migration.
## Interrupts (done, committed `a52d936`, deployed, verified live)

- **Phone not editable:** removed from app profile editor; `UserUpdate`
  drops phone (tampered clients can't PUT it); new `UserAdminUpdate` keeps
  admin correction path. Register still collects phone (watermark identity).
- **No streaming/files without ownership:** `GET /materials/{id}` and
  `GET /lessons/{id}/materials` now enforce `check_lesson_access` (were
  auth-only; enumerable IDs leaked file URLs). Videos/raw/proxy were
  already gated; `/uploads` static URLs stay unguessable-UUID (documented
  tradeoff). Verified live: 403/403 as non-owner, 200 as owner, test
  artifacts cleaned up.
- **Redeem-code E2E (dashboard + client):** verified live end-to-end
  (create as instructor -> redeem as student -> access granted -> used-up
  400 -> bogus 404 -> deactivate) and codified in `test_api.py` as a true
  two-user flow (was self-validate-as-admin): 22/22 green.
