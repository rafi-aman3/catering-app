# Catering App

A multi-tenant web app to manage office catering — daily lunch attendance, custom orders from outside the catering, and monthly billing. Built so any office can run their own workspace.

The first real-world rollout is internal (J&J catering). Architecture is multi-tenant from day one.

## Status

**Phase 1 — MVP under construction.** See [`plans/mvp-plan.md`](./plans/mvp-plan.md) for the milestone-by-milestone plan.

## Documentation

| Doc | Purpose |
| --- | --- |
| [`SPEC.md`](./SPEC.md) | Product spec — *what* we're building. Resolved decisions live in § 13. |
| [`plans/mvp-plan.md`](./plans/mvp-plan.md) | Implementation plan — *how* and *in what order*. |
| [`LOCAL_DEV_SETUP.md`](./LOCAL_DEV_SETUP.md) | Get the app running locally with Supabase. |
| [`.claude/git-workflow.md`](./.claude/git-workflow.md) | Branching, commits, PRs, migrations, secrets. |
| [`AGENTS.md`](./AGENTS.md) / [`CLAUDE.md`](./CLAUDE.md) | Guidance for AI coding agents working in this repo. |

## Stack

- **Next.js 16** (App Router) + TypeScript
- **Supabase** — Postgres, Auth, Realtime, Storage
- **Tailwind v4** + **shadcn/ui** + **Lucide**
- **TanStack Query** + **Zustand**
- **React Hook Form** + **Zod**
- **Vercel** + **Vercel Cron**
- **Resend** (email), **Web Push** (PWA)
- **Sentry** + **PostHog**
- **pnpm** as package manager

See [`SPEC.md`](./SPEC.md) § 5 for the full list and rationale.

## Quick Start

```bash
pnpm install
cp .env.example .env.local   # then fill in Supabase keys
pnpm dev
```

Open <http://localhost:3000>.

For the full setup — Supabase project, migrations, optional local Supabase via CLI — see [`LOCAL_DEV_SETUP.md`](./LOCAL_DEV_SETUP.md).

## Scripts

| Command | What it does |
| --- | --- |
| `pnpm dev` | Start the Next.js dev server |
| `pnpm build` | Production build |
| `pnpm start` | Run the production build locally |
| `pnpm lint` | ESLint |

## Contributing

- Read [`SPEC.md`](./SPEC.md) and the relevant section of [`plans/mvp-plan.md`](./plans/mvp-plan.md) before starting work.
- Follow the conventions in [`.claude/git-workflow.md`](./.claude/git-workflow.md): Conventional Commits, short-lived feature branches, squash-merge PRs.
- Migrations are append-only. Never edit a committed migration; add a new one.
- For UI changes, exercise the feature manually in the browser (mobile viewport for daily-poll surfaces) before opening the PR.

## License

Internal / unlicensed for now. License decision deferred until the platform opens to external workspaces (Phase 2+).
