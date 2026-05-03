@AGENTS.md

# Project: Catering Management System

A multi-tenant Next.js app to manage office catering, daily lunch polls, custom orders, and billing. v1 is internal-only (J&J catering use case); architecture is multi-tenant from day one.

## Required Reading Before Coding

1. [`SPEC.md`](./SPEC.md) — product spec. Source of truth for *what* to build, including resolved decisions in § 13. If behavior diverges, update the spec in the same PR.
2. [`plans/mvp-plan.md`](./plans/mvp-plan.md) — implementation plan. Source of truth for *how* and *in what order*.
3. [`.claude/git-workflow.md`](./.claude/git-workflow.md) — branching, commits, PRs, migrations, secrets.
4. **`node_modules/next/dist/docs/`** — the installed Next.js (16.2.4) is newer than training data. Read the relevant guide for the API you're about to use, *every time*. See `AGENTS.md`.

## Stack (see `SPEC.md` § 5 for the full list)

Next.js 16 (App Router) · TypeScript · Supabase (Postgres + Auth + Realtime + Storage) · Tailwind v4 + shadcn/ui · TanStack Query + Zustand · React Hook Form + Zod · Vercel + Vercel Cron · Resend · Sentry · PostHog.

Package manager: **pnpm**.

## Non-Negotiables

- **Multi-tenant from day one.** Every workspace-scoped query passes `workspace_id` and is protected by RLS. Default-deny policies; the service-role key is server-only and used only on `/system` routes.
- **`/system` routes return 404 (not 403)** for non-admins. Don't leak the existence of the admin panel.
- **Currency lockout.** Workspace currency cannot change once any payment, adjustment, or meal entry exists.
- **Cutoff defaults.** 10:00 AM workspace local time, both meal types. Auto-skip on no response.
- **Invite tokens expire in 24 hours.** Regenerable by admin.
- **Billing math is a pure function** with fixture-driven tests. Don't refactor it without expanding the fixtures first.
- **Migrations are append-only.** Never edit a committed migration; add a new one.
- **Secrets:** `.env.local` is git-ignored; update `.env.example` when adding a var; service-role keys never `NEXT_PUBLIC_*`.

## Workflow Reminders

- Use the dedicated tools (Read, Edit, Write) over Bash for file ops.
- For UI changes, exercise the feature manually in the browser (mobile viewport for daily-poll surfaces) before claiming the task done. Type-check is not feature-check.
- Tests cluster around three areas, in priority: billing math · RLS isolation · cutoff/auto-skip. UI polish is exercised manually, not unit-tested.
- Conventional Commits, squash-merge PRs, never `--no-verify`. See `.claude/git-workflow.md`.
