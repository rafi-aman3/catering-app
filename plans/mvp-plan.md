# MVP Implementation Plan

> Source of truth for *what* to build: [`SPEC.md`](../SPEC.md). This document is the *how* and *in-what-order*.
>
> Target: ship Phase 1 in 4–6 weeks for internal (J&J catering) use.

---

## Guiding Principles

1. **Read the docs first.** Next.js 16.2.4 is installed — it has breaking changes vs. anything in training data. Before writing any Next.js / React code, read the relevant guide in `node_modules/next/dist/docs/`. Heed deprecation notices.
2. **Spec is the contract.** If a decision is in `SPEC.md` § 13 (Resolved Decisions), don't relitigate it. If something is missing or ambiguous, raise it before coding.
3. **Vertical slices over horizontal layers.** Ship the daily-poll loop end-to-end (DB → API → UI → cron → notification) before adding the next feature. Don't build a beautiful settings page while the core poll doesn't work.
4. **Multi-tenant from day one.** Every workspace-scoped query goes through `workspace_id` + RLS, even when there's only one workspace. Don't bolt isolation on later.
5. **Mobile-first.** The daily poll is used from a phone — design it for thumb-reach first, then scale up.
6. **Test what's expensive to get wrong.** Billing math, RLS isolation, and cutoff/auto-skip logic must have tests. UI polish does not.

---

## Milestone Plan

Six milestones, ordered so each one delivers something usable. Treat the week numbers as a budget guide, not a deadline — the order matters more than the calendar.

### M0 — Foundations (Week 1)

**Goal:** A logged-in user can see an empty workspace.

- [ ] Configure Supabase project (Postgres + Auth + Storage). Capture env vars in `.env.local` and `.env.example`.
- [ ] Wire Supabase SSR auth into Next.js (server client, browser client, middleware). Use the official guide for the installed Next.js version.
- [ ] Add Tailwind config and shadcn/ui registry. Install Lucide.
- [ ] Set up Zod, React Hook Form, TanStack Query, Zustand.
- [ ] Set up linting + a minimal CI (`pnpm lint`, `pnpm build`, type check).
- [ ] Add Sentry + PostHog (no-op in dev, real in prod).
- [ ] Create core tables from `SPEC.md` § 7 via migration files (one migration per logical change, never edit a committed migration).
- [ ] Enable RLS on every workspace-scoped table; write the baseline policies ("user is a member of workspace_id").
- [ ] Add a `/healthz` route that pings the DB.

**Done when:** A new user can sign up, log in, and see a placeholder dashboard. RLS is on. CI is green.

### M1 — Workspace Lifecycle (Week 2)

**Goal:** A user can create a workspace, invite teammates, and switch between workspaces.

- [ ] "Create or join workspace" onboarding screen.
- [ ] Workspace creation form (name, timezone, currency [BDT default], working days, default meal price, cutoff time [10:00 default], bill due config).
- [ ] Workspace switcher in the app shell.
- [ ] Invite-by-link flow with **24-hour token expiry** and admin-side regeneration.
- [ ] Invite-by-email flow (Resend).
- [ ] Workspace settings page with the same fields as creation. Currency lockout once any payment/adjustment/meal_entry exists.
- [ ] Member list with role display.
- [ ] Audit-log writer utility (record actor, action, target, metadata).

**Done when:** Two users can join the same workspace via an invite link, see each other in the member list, and switch between workspaces if they belong to more than one.

### M2 — Daily Poll Loop (Weeks 2–3)

**Goal:** The core daily-attendance flow works end-to-end with cutoff enforcement.

- [ ] Member-facing "Today" screen: Catering / Custom / Skip with optimistic update.
- [ ] Server action to upsert `meal_entries`. Reject writes when `meal_days.status != 'open'` or after cutoff.
- [ ] Per-day live count using Supabase Realtime.
- [ ] Guest count `+1` control on the entry.
- [ ] Edit-own-response before cutoff; read-only after.
- [ ] Vercel Cron job that runs at the workspace cutoff time and:
  - Inserts `skip` entries for any member with no entry (recurring schedule overrides if present in M5+; for now, plain auto-skip).
  - Sets `meal_days.status = 'locked'`.
- [ ] Holiday flag on `meal_days`; auto-skip the day if `is_holiday = true`.
- [ ] Admin "lock day now" / "unlock" override (manager+).

**Done when:** A member can mark today, edits are rejected after the cutoff, and unmarked members are auto-skipped on schedule. RLS prevents seeing entries from other workspaces.

### M3 — Custom Orders + Admin Dashboard (Week 3)

**Goal:** Workspace admin can run the morning workflow.

- [ ] "Custom" entry opens a form: item name, source, estimated price, notes.
- [ ] Saved-favorites quick reuse for a member.
- [ ] Admin dashboard: today's summary (catering / custom / skip counts), tomorrow's preview, pending custom orders list.
- [ ] Custom order status flow: Requested → Ordered → Delivered → Confirmed (admin-only transitions).
- [ ] Admin updates `final_price` on Confirmed.
- [ ] Print-friendly daily order sheet (`/print/[date]`).
- [ ] Quick actions: lock day, override an entry (with audit log).

**Done when:** Admin can run the J&J morning routine without leaving the dashboard.

### M4 — Billing + Payments (Week 4)

**Goal:** A correct monthly bill comes out the other end.

- [ ] Pure billing function (no DB, no React) that takes `(member, range, meal_days, meal_entries, custom_orders, adjustments)` and returns a structured bill. **Heavy unit tests here** — this is the function we cannot get wrong.
- [ ] Billing page: per-workspace monthly view with member breakdown.
- [ ] Custom date range billing.
- [ ] Bill PDF export (`react-pdf`).
- [ ] Mark dues as paid / partial paid; record method (cash, bKash, bank, other).
- [ ] Payment history per member.
- [ ] Outstanding balance with aging based on workspace `bill_due_config`.
- [ ] Manual adjustment entry (positive or negative, with reason).
- [ ] "Bill ready" email notification.

**Done when:** End-of-month bill matches a hand-calculated bill for a fixture month. Partial payments age correctly.

### M5 — Polish, PWA, System Admin (Week 5)

**Goal:** Ready for daily real-world use by our office.

- [ ] PWA manifest + service worker (offline shell, install prompt). Test on iOS Safari and Android Chrome.
- [ ] Push notifications (Web Push): morning reminder, cutoff approaching, bill ready, custom order status.
- [ ] Dark mode.
- [ ] Recurring schedules (members can set "I always eat Sun/Mon/Wed"). Auto-skip cron honors this.
- [ ] Bulk mark for date range ("on leave").
- [ ] Ownership transfer flow (with password re-entry).
- [ ] Workspace soft-delete with 30-day retention (status + scheduled hard-delete job).
- [ ] `/system` routes: workspace list, suspend/restore, soft-delete, user search, audit log viewer. Middleware returns **404** (not 403) when `is_system_admin = false`.
- [ ] 2FA enforcement gate before `/system` access.
- [ ] Onboarding tutorial + feedback button.

**Done when:** Our office could start using it Monday morning.

### M6 — Hardening & Internal Rollout (Week 6)

**Goal:** Real users hit it; we don't bleed.

- [ ] Load a month of test data; verify billing, RLS, and cutoff behavior across timezones.
- [ ] Rate-limit auth endpoints.
- [ ] CSRF posture review (SameSite cookies on all auth + write endpoints).
- [ ] Sentry alerts wired to a real channel.
- [ ] PostHog dashboards: daily check-in completion rate, custom-order rate, billing-accuracy proxy (count of manual adjustments).
- [ ] Backup verification (restore one to a scratch project).
- [ ] Rollout: invite the office, run shadow-mode for one week alongside WhatsApp, then switch over.

**Done when:** Office uses the app for daily lunch instead of WhatsApp. We're tracking the success metrics from `SPEC.md` § 12.

---

## Cross-Cutting Concerns

### Repository Conventions
- TypeScript strict mode; no `any` without a `// reason: ...` comment.
- Server-only files marked with `import 'server-only'`. Never import the service-role Supabase client into a client component.
- Server Actions for mutations; route handlers for webhooks and cron only.
- Forms use React Hook Form + Zod with the same Zod schema reused server-side for validation.
- One migration file per change. Never edit a committed migration; add a new one.

### Testing Strategy
Tests cluster around three things, in priority order:
1. **Billing math** — pure function, fixture-driven, dozens of cases.
2. **RLS isolation** — integration tests that log in as user A and try to read user B's workspace.
3. **Cutoff and auto-skip** — time-controlled tests of the cron behavior.

UI is exercised by manually using the feature in the browser before calling work done (per repo guidance — type-checking is not feature-checking).

### Environment & Secrets
- `.env.example` lists every variable; `.env.local` is git-ignored.
- Supabase service-role key only in Vercel server env, never NEXT_PUBLIC.
- Secrets rotation plan documented in `.claude/git-workflow.md`.

### Observability
- Sentry: client + server.
- PostHog: capture `meal_entry_created`, `cutoff_auto_skip`, `bill_generated`, `payment_recorded`. Avoid PII in event properties.
- Audit log written for every privileged action (member role changes, locks, payments, adjustments, deletes, transfers).

---

## Risks & Mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| Next.js 16 differs from training-data Next.js | Wrong APIs silently compile but break at runtime | Read `node_modules/next/dist/docs/` before each new feature; treat installed version as authoritative |
| RLS misconfigured | Cross-workspace data leak | Default-deny policies; integration test for every workspace-scoped table |
| Timezone drift | Cutoff fires at the wrong time | Store workspace timezone; compute cutoff in workspace TZ, not UTC; test across DST boundaries |
| Billing math regression | Loss of trust on day one | Pure function with fixture tests; don't refactor without expanding the fixtures |
| PWA push on iOS | Apple has strict requirements | Test on iOS early; have email fallback for every notification |
| Cron-job missed run | Auto-skip doesn't happen, day stays open | Idempotent cron; backfill check on next run; alert if no run in last 25 hours |

---

## Resolved Questions

(Previously open; resolved 2026-05-03. Mirrored into `SPEC.md` § 13.)

- [x] **Mid-month working-day changes apply forward only.** A change to `workspaces.working_days` does not retroactively affect already-generated `meal_days` or past entries. New `meal_days` from the change date onward use the new working-day set.
- [x] **Guest meals (`+1`) are billed to the host.** Each guest counts as a meal at the day's `meal_price` (or workspace default), added to the host's bill in the same line item / breakdown.
- [x] **Day-specific pricing stays on `meal_days.meal_price`.** Single nullable column; null means "use workspace default". A separate pricing-rules table is deferred until a real recurring-rule requirement appears.
- [x] **Sole-owner accounts cannot self-delete.** If a user is the only owner of any workspace, account deletion is blocked with a clear error pointing them to Transfer Ownership. After transfer, deletion proceeds normally.

---

## Definition of Done (per task)

A task is done when:
1. Code is merged to `main` via a reviewed PR.
2. Tests for the relevant cluster (billing / RLS / cutoff) pass.
3. The feature was exercised manually in the browser (mobile viewport included if user-facing).
4. Sentry shows no new errors in the 24 hours after merge.
5. The corresponding spec section is still accurate; if not, the spec is updated in the same PR.
