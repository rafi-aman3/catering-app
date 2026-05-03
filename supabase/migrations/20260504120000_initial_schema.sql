-- Initial schema for the catering app.
-- Source of truth: SPEC.md § 7. Deviations from the spec are noted inline.
--
-- Conventions:
--   * UUID PKs via gen_random_uuid() (pgcrypto, available in Supabase by default).
--   * timestamptz everywhere (never plain timestamp).
--   * Money columns: numeric(12,2). Big enough for any currency we'd see.
--   * Status / role / type fields use text + CHECK rather than Postgres enums,
--     because enums are painful to evolve (no remove-value, no rename without
--     dance). Trade-off: slightly weaker DB-level typing; we make up for it
--     with TS types generated from the schema later.
--   * Workspace-scoped tables carry a denormalized workspace_id even when it's
--     reachable via a join. Makes RLS policies uniform and fast.
--
-- Privileged code (SECURITY DEFINER functions, triggers that bypass RLS) lives
-- in the `private` schema, created in 20260504120100_rls_and_helpers.sql.
-- Putting it in `public` would expose it via PostgREST.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Users (profiles, mirroring auth.users)
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text,
  phone text,
  photo_url text,
  is_system_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Workspaces
-- ---------------------------------------------------------------------------

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references public.users(id),
  timezone text not null default 'Asia/Dhaka',
  currency text not null default 'BDT',
  working_days text[] not null default array['sun','mon','tue','wed','thu'],
  meal_cutoff_time time not null default '10:00',
  custom_order_cutoff_time time not null default '10:00',
  default_meal_price numeric(12,2) not null,
  bill_due_config jsonb not null default '{"type":"day_of_next_month","day":5}'::jsonb,
  status text not null default 'active'
    check (status in ('active','suspended','deleted')),
  created_at timestamptz not null default now()
);

create index workspaces_owner_id_idx on public.workspaces (owner_id);

-- ---------------------------------------------------------------------------
-- Workspace members
-- One row per (workspace, user). The 'owner' role row exists alongside
-- workspaces.owner_id; SPEC § 2.2 — "exactly one owner per workspace".
-- ---------------------------------------------------------------------------

create table public.workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','manager','member')),
  joined_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);

create index workspace_members_user_id_idx on public.workspace_members (user_id);
create index workspace_members_workspace_id_idx on public.workspace_members (workspace_id);

-- Exactly one owner-role row per workspace.
create unique index workspace_members_one_owner_per_workspace
  on public.workspace_members (workspace_id) where role = 'owner';

-- ---------------------------------------------------------------------------
-- Workspace invites — 24-hour expiry per SPEC § 13.4
-- ---------------------------------------------------------------------------

create table public.workspace_invites (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  email text,
  token text not null unique,
  invited_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  accepted_at timestamptz
);

create index workspace_invites_workspace_id_idx on public.workspace_invites (workspace_id);
create index workspace_invites_token_idx on public.workspace_invites (token);

-- ---------------------------------------------------------------------------
-- Meal days
-- ---------------------------------------------------------------------------

create table public.meal_days (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  date date not null,
  status text not null default 'open'
    check (status in ('open','locked','closed')),
  meal_price numeric(12,2),
  is_holiday boolean not null default false,
  created_at timestamptz not null default now(),
  unique (workspace_id, date)
);

create index meal_days_workspace_id_idx on public.meal_days (workspace_id);

-- ---------------------------------------------------------------------------
-- Meal entries
-- workspace_id is denormalized for RLS / query simplicity.
-- ---------------------------------------------------------------------------

create table public.meal_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  meal_day_id uuid not null references public.meal_days(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null check (type in ('catering','custom','skip')),
  guest_count integer not null default 0 check (guest_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (meal_day_id, user_id)
);

create index meal_entries_meal_day_id_idx on public.meal_entries (meal_day_id);
create index meal_entries_user_id_idx on public.meal_entries (user_id);
create index meal_entries_workspace_id_idx on public.meal_entries (workspace_id);

-- ---------------------------------------------------------------------------
-- Custom orders
-- ---------------------------------------------------------------------------

create table public.custom_orders (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  meal_entry_id uuid not null unique references public.meal_entries(id) on delete cascade,
  item_name text not null,
  source text,
  estimated_price numeric(12,2),
  final_price numeric(12,2),
  notes text,
  status text not null default 'requested'
    check (status in ('requested','ordered','delivered','confirmed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index custom_orders_workspace_id_idx on public.custom_orders (workspace_id);

-- ---------------------------------------------------------------------------
-- Recurring schedules
-- ---------------------------------------------------------------------------

create table public.recurring_schedules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  days_of_week text[] not null,
  default_type text not null check (default_type in ('catering','custom','skip')),
  created_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);

create index recurring_schedules_workspace_id_idx on public.recurring_schedules (workspace_id);

-- ---------------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------------

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  method text not null check (method in ('cash','bkash','bank','other')),
  note text,
  paid_on date not null,
  recorded_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

create index payments_workspace_user_idx on public.payments (workspace_id, user_id);
create index payments_paid_on_idx on public.payments (paid_on);

-- ---------------------------------------------------------------------------
-- Adjustments (manual debit/credit, can be negative)
-- ---------------------------------------------------------------------------

create table public.adjustments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  amount numeric(12,2) not null,
  reason text not null,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

create index adjustments_workspace_user_idx on public.adjustments (workspace_id, user_id);

-- ---------------------------------------------------------------------------
-- Audit logs
-- workspace_id is nullable for system-wide actions. RLS will scope to workspace
-- members when set; only system admins can read null-workspace rows.
-- ---------------------------------------------------------------------------

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references public.workspaces(id) on delete set null,
  actor_user_id uuid references public.users(id) on delete set null,
  action text not null,
  target_type text,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_workspace_id_created_idx
  on public.audit_logs (workspace_id, created_at desc);
create index audit_logs_actor_idx on public.audit_logs (actor_user_id);

-- ---------------------------------------------------------------------------
-- updated_at trigger function — plain (no SECURITY DEFINER), safe in public.
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger meal_entries_set_updated_at
  before update on public.meal_entries
  for each row execute function public.set_updated_at();

create trigger custom_orders_set_updated_at
  before update on public.custom_orders
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- API access: explicit grants for the authenticated role.
-- RLS gates which rows; GRANTs gate which operations are even attempted.
-- anon gets nothing — every page that reads data requires login.
-- ---------------------------------------------------------------------------

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Block client-side privilege escalation: prevent users from editing their own
-- is_system_admin flag even though they can update other profile columns.
-- (RLS would also need the with-check clause; column-level grants are simpler.)
revoke update (is_system_admin) on public.users from authenticated;
