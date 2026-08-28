# LEC Dashboard v2 — agent notes

Vite + React 19 + TS admin dashboard. No UI libs — hand-rolled CSS in `src/styles.css`.
Deploy: `npm run build` → rsync `dist/` to `ec2r:/root/repos/lec/dashboard/dist/` (nginx serves it with `/api/` proxied to main-server :8000).

## UX / QoF rules (stupid-UX is a bug — treat it like one)
- Every visible button/link/toggle MUST have a real, working handler wired to a backend effect. NEVER ship a no-op, placeholder, `() => {}`, or "TODO" click target — if the action can't be implemented yet, don't render the control at all.
- Never add a control you haven't clicked and verified end-to-end (side effect actually persisted server-side). Dead UI is worse than missing UI. (Real case: a "Lessons" button shipped as `onClick={() => setX(false)}` — did nothing, users clicked it, nothing happened.)
- Use the right widget, not a lazy text box: enumerable values → dropdown/segmented control; yes-no → checkbox/toggle; bounded numeric → slider/stepper; color → color picker; entity refs → searchable select (with grouping when >~8 items). Free-text only for genuinely free-form values (titles, URLs, descriptions).
- Show state, not raw codes: human words for statuses/roles/durations/dates (e.g. "Queued", "3h ago", "10m 32s"), badges with counts, empty states, disable-until-valid on forms.
- Every destructive action needs confirm; every save needs visible feedback (toast + refetch).
- When a page manages N entities, verify N-side effects: create/edit/delete each, not just the happy path.
- After any UI change, run the E2E suite (Puppeteer on ec2r, `/tmp/puppeteer-upload/*.js`) — a passing build is not a passing feature. Suites: `dash2_e2e.js` (navigation), `endpoints_e2e.js` (81 endpoint checks), `qol_e2e.js` (widget persistence), `scope_e2e.js` (instructor scoping + SearchSelect).

## Gotchas learned the hard way
- Backend `PUT /lessons` treats `video_id: null` as "don't touch" — send `video_id: ""` to detach.
- Backend `POST /users/{id}/ban` takes `?ban_duration_days=` query param, not body.
- Stats labels are CSS-uppercased — `innerText` returns "TOTAL USERS"; make E2E text matching case-insensitive.
- React controlled inputs: setting `el.value` directly does NOT update state — reload the page or use native setters + input events.
- Instructor scoping is enforced client-side in `Courses.tsx` (filter `instructor_id === user.id`); `/videos/manage` is already scoped server-side.
- `.dart_tool/`, `pubspec.lock`, `.nvimlog`, generated plugin files must stay gitignored.
