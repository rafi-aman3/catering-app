# Local Development Setup

Get the catering app running on your machine, talking to Supabase.

There are two ways to develop locally:

- **Cloud Supabase (recommended for first-time setup)** — fastest path. Use a free Supabase project as your dev database.
- **Local Supabase via CLI** — runs a full Supabase stack in Docker on your machine. Best when you're iterating heavily on migrations or want to work offline.

Pick one and follow the matching section below.

---

## 1. Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Node.js | 20 LTS or newer | Use `nvm` or `fnm` to manage versions |
| pnpm | 9.x | `corepack enable && corepack prepare pnpm@latest --activate` |
| Git | any recent | |
| A Supabase account | — | Free tier is fine. Sign up at <https://supabase.com>. |
| Docker Desktop *(optional)* | latest | Only required if you choose Local Supabase via CLI |
| Supabase CLI *(optional)* | latest | `brew install supabase/tap/supabase` — only required for Local Supabase |

---

## 2. Clone & Install

```bash
git clone https://github.com/rafi-aman3/catering-app.git
cd catering-app
pnpm install
```

---

## 3. Environment Variables

Copy the example file and fill in the values from your Supabase project (see § 4 or § 5).

```bash
cp .env.example .env.local
```

Required variables (keep this list in sync with `.env.example`):

| Variable | Where it comes from | Notes |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API | Public, exposed to the browser |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase → Project Settings → API → API keys | Public, exposed to the browser. (Replaces the legacy "anon" key; legacy anon JWT also works.) |
| `SUPABASE_SECRET_KEY` | Supabase → Project Settings → API → API keys | **Server only.** Never `NEXT_PUBLIC_*`. Used by `/system` routes and server-side admin operations. (Replaces the legacy "service_role" key; legacy service_role JWT also works.) |
| `RESEND_API_KEY` | <https://resend.com> dashboard | Optional in early dev — emails will no-op without it |
| `SENTRY_DSN` *(optional)* | Sentry project | Leave blank in dev |
| `NEXT_PUBLIC_POSTHOG_KEY` *(optional)* | PostHog project | Leave blank in dev |

Never commit `.env.local`. It is git-ignored. If you add a new env var, update `.env.example` in the same PR.

---

## 4. Option A — Cloud Supabase (recommended)

### 4.1 Create a Supabase project

1. Go to <https://supabase.com/dashboard> → **New project**.
2. Pick a region close to you. Set a strong DB password (save it in a password manager).
3. Wait for the project to provision (~1 minute).

### 4.2 Grab keys and put them in `.env.local`

Project Settings → **API**:

- Project URL → `NEXT_PUBLIC_SUPABASE_URL`
- Publishable key (`sb_publishable_…`) → `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- Secret key (`sb_secret_…`) → `SUPABASE_SECRET_KEY`

(On legacy projects, the `anon` and `service_role` JWTs map to the same env vars and still work.)

### 4.3 Apply migrations

Once we add migrations to `supabase/migrations/` (per the MVP plan, M0):

```bash
# link this repo to your Supabase project
pnpm dlx supabase link --project-ref <your-project-ref>

# push all migrations
pnpm dlx supabase db push
```

The `<project-ref>` is the slug in your project URL (e.g., `abcdefgh` from `https://abcdefgh.supabase.co`).

### 4.4 Configure Auth providers

In the Supabase dashboard:

- **Authentication → Providers → Email** — enable email/password and magic link.
- **Authentication → Providers → Google** — add a Google OAuth client (see [Supabase docs](https://supabase.com/docs/guides/auth/social-login/auth-google)).
- **Authentication → URL Configuration** → Site URL: `http://localhost:3000` for dev. Add additional redirect URLs as you deploy preview/prod.

---

## 5. Option B — Local Supabase via CLI

Use this when you want a self-contained dev environment in Docker.

### 5.1 Start the local stack

```bash
# from the repo root
pnpm dlx supabase start
```

The first run pulls Docker images and takes a few minutes. When it finishes, the CLI prints local URLs and keys — copy them into `.env.local`:

- `API URL` → `NEXT_PUBLIC_SUPABASE_URL`
- `anon key` → `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `service_role key` → `SUPABASE_SECRET_KEY`

To stop it later: `pnpm dlx supabase stop`. To reset state: `pnpm dlx supabase db reset`.

### 5.2 Apply migrations

`supabase start` automatically applies migrations from `supabase/migrations/` on boot.

To re-run from scratch after schema changes:

```bash
pnpm dlx supabase db reset
```

To create a new migration after editing the schema:

```bash
pnpm dlx supabase migration new <descriptive_name>
```

> **Reminder:** migrations are append-only. Never edit a committed migration — write a new one.

### 5.3 Studio UI

A local Supabase Studio runs at <http://localhost:54323> — handy for browsing tables, running SQL, and inspecting auth users.

---

## 6. Run the App

```bash
pnpm dev
```

Open <http://localhost:3000>. The dev server hot-reloads on file changes.

---

## 7. Common Tasks

| Task | Command |
| --- | --- |
| Lint | `pnpm lint` |
| Production build | `pnpm build` |
| Run production build locally | `pnpm start` |
| Add a Supabase migration | `pnpm dlx supabase migration new <name>` |
| Apply migrations to cloud project | `pnpm dlx supabase db push` |
| Reset local Supabase DB | `pnpm dlx supabase db reset` |

---

## 8. Troubleshooting

**`SUPABASE_URL is undefined` at runtime.** You haven't created `.env.local` or you ran `pnpm dev` from a different directory. Restart the dev server after editing env vars — Next.js only reads them at boot.

**RLS denies every query.** RLS is enabled on every workspace-scoped table by default. While developing, check that you're authenticated as a user who is a member of the workspace you're querying. The service-role key bypasses RLS but should only be used in server-side `/system` code.

**Auth emails never arrive in cloud Supabase.** The free tier rate-limits the built-in SMTP provider. For dev, either use magic-link via the auth events log, or configure a real SMTP provider in Supabase → Auth → Email.

**Local Supabase fails to start with a port conflict.** Another stack (or a previous run) is holding ports 54321–54327. Run `pnpm dlx supabase stop --no-backup` and retry.

**Next.js says an API has changed / is removed.** This repo runs Next.js 16, which has breaking changes vs older versions. Read the relevant guide in `node_modules/next/dist/docs/` before adopting an API from older docs or training data.

---

## 9. Where to Go Next

- Read [`SPEC.md`](./SPEC.md) for product behavior, especially § 13 (Resolved Decisions).
- Read [`plans/mvp-plan.md`](./plans/mvp-plan.md) for the milestone you're working on.
- Read [`.claude/git-workflow.md`](./.claude/git-workflow.md) before opening your first PR.
