# Plan 03 — Dashboard v2 parity: quizzes, qbanks, enrollment, certificates

Status: **DONE**

Scope: `dashboard-v2/` (React admin console). v2 is missing major features
that v1 (`dashboard/`) had: quiz builder, question banks, enrollment-request
approval, certificates, and lesson material editing. v1 is "do not touch"
(reference only), so these get rebuilt in v2 against the live backend API,
following the v2 AGENTS.md UX/QoF rules (no dead controls, right widgets,
confirm destructive, E2E-verify).

## Steps

1. Plan + log files, commit.
2. Audit: read v1 pages (Quizzes/QuizBuilder, QBanks/QBankDetail,
   EnrollmentRequests, Certificates, LessonDetail/LessonEdit) + v2 API layer
   + backend endpoints; list exact gaps and API shapes.
3. Backend API gap check: confirm v2 needs no new endpoints (v1 used only
   existing routes). If a route is missing, add it backend-side.
4. Quizzes: v2 Quizzes list page + QuizBuilder (create/edit quiz, questions
   CRUD, correct answers as text, passing score, attach to lesson).
5. QBanks: v2 QBanks list + detail (questions CRUD, enrollment approve/reject).
6. Enrollment requests: list + approve/reject with comment (instructor-scoped).
7. Certificates: list all + view (admin/instructor).
8. Lesson materials: add/edit materials on lessons if missing.
9. Verification: `npm run build` + E2E suites on ec2r (`/tmp/puppeteer-upload/*.js`);
   mark DONE, log, report.

## Verification

- `cd dashboard-v2 && npm run build` — succeeds.
- E2E on ec2r: `dash2_e2e.js`, `endpoints_e2e.js`, `qol_e2e.js`, `scope_e2e.js`
  — all green before committing.
- Manual: create/edit/delete a quiz + questions; create a qbank + questions;
  approve/reject an enrollment request; view certificates.