@AGENTS.md

# Project: Catering Management System

A multi-tenant Next.js app to manage office catering, daily lunch polls, custom orders, and billing. v1 is internal-only (J&J catering use case); architecture is multi-tenant from day one.

## Required Reading Before Coding

1. [`SPEC.md`](./SPEC.md) — product spec. Source of truth for *what* to build, including resolved decisions in § 13. If behavior diverges, update the spec in the same PR.
2. [`plans/mvp-plan.md`](./plans/mvp-plan.md) — implementation plan. Source of truth for *how* and *in what order*.
3. [`.claude/git-workflow.md`](./.claude/git-workflow.md) — branching, commits, PRs, migrations, secrets.
4. **`node_modules/next/dist/docs/`** — the installed Next.js (16.2.4) is newer than training data. Read the relevant guide for the API you're about to use, *every time*. See `AGENTS.md`.
5. **Invoke the `supabase:supabase` skill** before any Supabase / Postgres / RLS / migrations work. It catches gotchas that don't show up in training data (security-definer placement, search-path attacks, advisor checks). The `supabase:supabase-postgres-best-practices` skill is the deeper Postgres-perf companion.

### Next.js 16 things to remember (the easy traps)

- Middleware was renamed: it lives at the project root as **`proxy.ts`** (not `middleware.ts`). The file conventions doc is `01-app/03-api-reference/.../proxy`. The guide is `01-app/02-guides/16-proxy.md`.
- App Router code lives at `app/` at the repo root (no `src/` folder in this project). Path alias `@/*` maps to `./*` (see `tsconfig.json`).
- Tailwind v4 is CSS-first (`@import "tailwindcss"` in `app/globals.css`, `@theme inline { ... }` for tokens). No `tailwind.config.js` by default.
- Use Server Actions for mutations and route handlers (`route.ts`) only for webhooks / cron / OAuth callbacks.

## Stack (see `SPEC.md` § 5 for the full list)

Next.js 16 (App Router) · TypeScript · Supabase (Postgres + Auth + Realtime + Storage) · Tailwind v4 + shadcn/ui · TanStack Query + Zustand · React Hook Form + Zod · Vercel + Vercel Cron · Resend · Sentry · PostHog.

Package manager: **pnpm**.

## Non-Negotiables

- **Multi-tenant from day one.** Every workspace-scoped query passes `workspace_id` and is protected by RLS. Default-deny policies; the secret (service-role) key is server-only and used only on `/system` routes.
- **`/system` routes return 404 (not 403)** for non-admins. Don't leak the existence of the admin panel.
- **Currency lockout.** Workspace currency cannot change once any payment, adjustment, or meal entry exists.
- **Cutoff defaults.** 10:00 AM workspace local time, both meal types. Auto-skip on no response.
- **Invite tokens expire in 24 hours.** Regenerable by admin.
- **Billing math is a pure function** with fixture-driven tests. Don't refactor it without expanding the fixtures first.
- **Migrations are append-only.** Never edit a committed migration; add a new one. Apply with `pnpm dlx supabase db push`; we don't run local Supabase (no Docker), so use `--linked` for advisors and other CLI commands that need a DB.
- **Secrets:** `.env.local` is git-ignored; update `.env.example` when adding a var. Supabase keys use the new naming: `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (browser-safe) and `SUPABASE_SECRET_KEY` (server-only, never `NEXT_PUBLIC_*`).
- **Env access:** server code imports the Zod-validated env from `lib/env.ts` (which has `import 'server-only'`). Client code reads `process.env.NEXT_PUBLIC_*` directly because `lib/env` would refuse to load there.

## Supabase clients (where to import what)

| File | Use from | Notes |
| --- | --- | --- |
| `lib/supabase/server.ts` (`createClient`, async) | RSCs, Route Handlers, Server Actions | Per-request; uses `next/headers` cookies. Never share across requests. |
| `lib/supabase/browser.ts` (`createClient`) | Client Components | Reads `process.env.NEXT_PUBLIC_*` directly. |
| `lib/supabase/admin.ts` (`createAdminClient`) | `/system` routes, scheduled jobs only | Bypasses RLS via the secret key. Never call from a normal user-facing route. |
| `lib/supabase/proxy.ts` (`updateSession`) | Called from `proxy.ts` at repo root | Refreshes the auth session cookie. **Don't add code between `createServerClient` and `getUser()`** — it desyncs auth state and produces sporadic logouts. |

## Database / RLS conventions (hard-learned in M0)

- **`SECURITY DEFINER` functions live in the `private` schema, never `public`.** Anything in `public` is reachable via PostgREST as `/rest/v1/rpc/<name>`. Helpers in use: `private.is_workspace_member`, `private.has_workspace_role`, `private.is_system_admin`. Triggers on `auth.users` and `public.workspaces` also live in `private`.
- **Every `SECURITY DEFINER` function sets `search_path = ''`** and fully qualifies every table reference (`public.workspace_members`, not `workspace_members`). Stops search-path-shadowing attacks.
- **RLS policies wrap auth functions in a subselect:** `(select auth.uid())`, never bare `auth.uid()`. Postgres caches the subselect once per query; the bare form re-evaluates per row and tanks performance at scale (advisor lint `auth_rls_initplan`).
- **One policy per (table, command, role).** No `FOR ALL` policies that overlap with command-specific ones — Postgres OR-combines permissive policies and runs both per row (advisor lint `multiple_permissive_policies`). Combine the conditions into a single policy per command instead.
- **Every public table has explicit `GRANT … TO authenticated`.** `anon` gets nothing — every reading page requires login.
- **Column-level `REVOKE`** is the cleanest way to lock specific columns (e.g. `users.is_system_admin`). Don't fight it with recursive `with check` clauses.
- **Conventions in migrations:** UUID PKs (`gen_random_uuid()`), `timestamptz` everywhere, `numeric(12,2)` for money, `text` + `CHECK` for enum-shaped columns (cheaper to evolve than Postgres enums), denormalized `workspace_id` on every workspace-scoped table for uniform RLS.
- **After every migration push, run `pnpm dlx supabase db advisors --linked`** and fix any new WARNs in a new migration.

## Workflow Reminders

- Use the dedicated tools (Read, Edit, Write) over Bash for file ops.
- For UI changes, exercise the feature manually in the browser (mobile viewport for daily-poll surfaces) before claiming the task done. Type-check is not feature-check.
- Tests cluster around three areas, in priority: billing math · RLS isolation · cutoff/auto-skip. UI polish is exercised manually, not unit-tested.
- Conventional Commits, squash-merge PRs, never `--no-verify`. See `.claude/git-workflow.md`.
