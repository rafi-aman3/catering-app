-- Row-level security: workspace isolation as second line of defense.
-- App code is the first line; RLS catches mistakes the app misses.
-- See SPEC § 6.2 and § 10.2.
--
-- Architecture decision: SECURITY DEFINER helpers and triggers live in a
-- dedicated `private` schema. Putting them in `public` would expose them via
-- PostgREST and let a malicious client probe their behavior directly.
-- Policies and triggers below reference them by qualified name.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER, in private)
-- ---------------------------------------------------------------------------

create or replace function private.is_workspace_member(_workspace_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.workspace_members
    where workspace_id = _workspace_id
      and user_id = auth.uid()
  );
$$;

create or replace function private.has_workspace_role(_workspace_id uuid, _roles text[])
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.workspace_members
    where workspace_id = _workspace_id
      and user_id = auth.uid()
      and role = any(_roles)
  );
$$;

create or replace function private.is_system_admin()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select coalesce(
    (select is_system_admin from public.users where id = auth.uid()),
    false
  );
$$;

-- Authenticated users need EXECUTE on these for RLS policy evaluation, plus
-- USAGE on the schema to reach them. They get no other access to `private`.
grant usage on schema private to authenticated;
grant execute on function private.is_workspace_member(uuid) to authenticated;
grant execute on function private.has_workspace_role(uuid, text[]) to authenticated;
grant execute on function private.is_system_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Trigger: mirror auth.users into public.users on signup.
-- ---------------------------------------------------------------------------

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Trigger: when a workspace is created, auto-add the owner as a member with
-- role='owner'. Bypasses workspace_members RLS via SECURITY DEFINER.
-- ---------------------------------------------------------------------------

create or replace function private.handle_new_workspace()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.workspace_members (workspace_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;

create trigger on_workspace_created
  after insert on public.workspaces
  for each row execute function private.handle_new_workspace();

-- ---------------------------------------------------------------------------
-- Enable RLS on every public table.
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.workspace_invites enable row level security;
alter table public.meal_days enable row level security;
alter table public.meal_entries enable row level security;
alter table public.custom_orders enable row level security;
alter table public.recurring_schedules enable row level security;
alter table public.payments enable row level security;
alter table public.adjustments enable row level security;
alter table public.audit_logs enable row level security;

-- ---------------------------------------------------------------------------
-- users (public profiles)
-- ---------------------------------------------------------------------------

create policy users_self_select on public.users
  for select to authenticated using (id = auth.uid());

-- Co-members of any of my workspaces can see my profile (for member lists).
create policy users_co_member_select on public.users
  for select to authenticated using (
    exists (
      select 1
      from public.workspace_members me
      join public.workspace_members other
        on other.workspace_id = me.workspace_id
      where me.user_id = auth.uid()
        and other.user_id = users.id
    )
  );

create policy users_system_admin_select on public.users
  for select to authenticated using (private.is_system_admin());

-- Users can update their own profile. is_system_admin column is locked via
-- the column-level revoke in migration 0001 — no with-check gymnastics needed.
create policy users_self_update on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Inserts come exclusively from the SECURITY DEFINER trigger; no policy needed.

-- ---------------------------------------------------------------------------
-- workspaces
-- ---------------------------------------------------------------------------

create policy workspaces_member_select on public.workspaces
  for select to authenticated using (
    private.is_workspace_member(id) or private.is_system_admin()
  );

-- Authenticated users can create a workspace, naming themselves as owner.
create policy workspaces_self_insert on public.workspaces
  for insert to authenticated with check (owner_id = auth.uid());

create policy workspaces_owner_update on public.workspaces
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy workspaces_owner_delete on public.workspaces
  for delete to authenticated
  using (owner_id = auth.uid() or private.is_system_admin());

-- ---------------------------------------------------------------------------
-- workspace_members
-- ---------------------------------------------------------------------------

create policy workspace_members_member_select on public.workspace_members
  for select to authenticated using (
    private.is_workspace_member(workspace_id) or private.is_system_admin()
  );

create policy workspace_members_admin_insert on public.workspace_members
  for insert to authenticated with check (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

create policy workspace_members_admin_update on public.workspace_members
  for update to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin']));

create policy workspace_members_admin_delete on public.workspace_members
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

-- ---------------------------------------------------------------------------
-- workspace_invites
-- ---------------------------------------------------------------------------

create policy workspace_invites_admin_select on public.workspace_invites
  for select to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin'])
    or private.is_system_admin()
  );

create policy workspace_invites_admin_insert on public.workspace_invites
  for insert to authenticated with check (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

create policy workspace_invites_admin_update on public.workspace_invites
  for update to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin']));

create policy workspace_invites_admin_delete on public.workspace_invites
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

-- ---------------------------------------------------------------------------
-- meal_days
-- ---------------------------------------------------------------------------

create policy meal_days_member_select on public.meal_days
  for select to authenticated using (private.is_workspace_member(workspace_id));

create policy meal_days_manager_write on public.meal_days
  for all to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin','manager']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin','manager']));

-- ---------------------------------------------------------------------------
-- meal_entries
-- ---------------------------------------------------------------------------

create policy meal_entries_member_select on public.meal_entries
  for select to authenticated using (private.is_workspace_member(workspace_id));

create policy meal_entries_self_insert on public.meal_entries
  for insert to authenticated with check (
    private.is_workspace_member(workspace_id) and user_id = auth.uid()
  );

create policy meal_entries_self_update on public.meal_entries
  for update to authenticated
  using (private.is_workspace_member(workspace_id) and user_id = auth.uid())
  with check (private.is_workspace_member(workspace_id) and user_id = auth.uid());

create policy meal_entries_manager_write on public.meal_entries
  for all to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin','manager']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin','manager']));

-- ---------------------------------------------------------------------------
-- custom_orders
-- ---------------------------------------------------------------------------

create policy custom_orders_member_select on public.custom_orders
  for select to authenticated using (private.is_workspace_member(workspace_id));

create policy custom_orders_self_insert on public.custom_orders
  for insert to authenticated with check (
    private.is_workspace_member(workspace_id)
    and exists (
      select 1 from public.meal_entries me
      where me.id = meal_entry_id and me.user_id = auth.uid()
    )
  );

create policy custom_orders_manager_write on public.custom_orders
  for all to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin','manager']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin','manager']));

-- ---------------------------------------------------------------------------
-- recurring_schedules — each member manages their own
-- ---------------------------------------------------------------------------

create policy recurring_schedules_self_select on public.recurring_schedules
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = auth.uid()
      or private.has_workspace_role(workspace_id, array['owner','admin','manager'])
    )
  );

create policy recurring_schedules_self_write on public.recurring_schedules
  for all to authenticated
  using (private.is_workspace_member(workspace_id) and user_id = auth.uid())
  with check (private.is_workspace_member(workspace_id) and user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- payments
-- ---------------------------------------------------------------------------

create policy payments_self_select on public.payments
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = auth.uid()
      or private.has_workspace_role(workspace_id, array['owner','admin'])
    )
  );

create policy payments_admin_write on public.payments
  for all to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin']));

-- ---------------------------------------------------------------------------
-- adjustments
-- ---------------------------------------------------------------------------

create policy adjustments_self_select on public.adjustments
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = auth.uid()
      or private.has_workspace_role(workspace_id, array['owner','admin'])
    )
  );

create policy adjustments_admin_write on public.adjustments
  for all to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin']));

-- ---------------------------------------------------------------------------
-- audit_logs — read-only from the app; inserts come from server code with
-- the secret key.
-- ---------------------------------------------------------------------------

create policy audit_logs_admin_select on public.audit_logs
  for select to authenticated using (
    (workspace_id is not null and private.has_workspace_role(workspace_id, array['owner','admin']))
    or private.is_system_admin()
  );
