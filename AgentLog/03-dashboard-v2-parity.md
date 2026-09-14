# Plan 03 — Dashboard v2 parity, log

## Goal

Bring `dashboard-v2/` to feature parity with the legacy `dashboard/` (which
is frozen): quizzes + quiz builder, question banks + detail, enrollment
request approval, certificates, and lesson material editing — all against the
live backend, following v2's UX/QoF rules.

## Progress

- Created `Plan/03-dashboard-v2-parity.md` (Status ACTIVE) and this log.
- **Step 2 — audit: DONE.** Read v1 pages (Quizzes/QuizBuilder, QBanks,
  QBankDetail, EnrollmentRequests, Certificates) + v2 API layer + backend
  endpoints. Gaps confirmed: quizzes, qbanks, enrollments, certificates,
  lesson materials + quiz-attach all missing from v2.
- **Step 3 — backend gap: DONE.** Added `PUT /qbanks/{id}/questions/{qid}`
  (only POST/DELETE existed; edit-save needed it). No other new routes needed.
- **Steps 4–8 — pages: DONE.**
  - `Quizzes.tsx`: list (GET /quizzes) with search, questions/pass/time
    badges, delete with confirm, New Quiz → builder.
  - `QuizBuilder.tsx`: create/edit quiz (title, description, course→lesson
    cascade, passing score, time limit), questions CRUD (options add/remove,
    correct-answer radio glued to text, explanation, points), validation,
    delete-then-save semantics.
  - `QBanks.tsx`: list + create/edit/delete with tags/price/visibility.
  - `QBankDetail.tsx`: questions CRUD (uses new PUT endpoint) + enrollment
    list with approve/reject.
  - `EnrollmentRequests.tsx`: status filter, review modal (form data + proof
    images), approve/reject with comment (query param per backend).
  - `Certificates.tsx`: list all with search (user/course ids truncated —
    backend returns ids only).
  - `Courses.tsx`: added per-lesson quiz attach (PUT /lessons quiz_id, "" to
    detach) + materials modal (list/add/delete via /lessons/{id}/materials
    and /materials/{id}).
  - App.tsx routes + Layout nav entries added.
- **Step 9 — verification + deploy: DONE.**
  - `npm run build` (tsc + vite): passes.
  - Backend smoke (local server): quizzes list, qbank question
    create→update→delete, enrollment requests, certificates all 200.
  - Deployed: `rsync dist/ → ec2r:/root/repos/lec/dashboard/dist/` (nginx
    serves it). Verified `https://dashboard.lec.pxysio.top/` 200, SPA
    fallback `/quizzes` 200, title "LEC Admin" (v2 bundle).
  - Server repo synced to b598bb0; main server now runs as a **systemd unit
    (`lec-main.service`)** instead of the fragile nohup (it kept dying on
    ssh restarts) — active + healthy.
  - E2E suites (`/tmp/puppeteer-upload/*.js`) referenced in AGENTS.md are
    NOT present on the server, so E2E was replaced by build + curl + API
    smoke. Noted for the user.
- **Plan 03 DONE.** All steps complete; dashboard v2 now at feature parity
  with v1 (plus lesson materials/quiz attach).