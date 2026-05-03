-- Fixes for warnings from Supabase Database Advisors run after applying
-- 20260504120000_initial_schema.sql and 20260504120100_rls_and_helpers.sql.
--
-- Three classes of fix:
--
--   1. function_search_path_mutable on public.set_updated_at — add explicit
--      set search_path = '' to prevent search_path-shadowing attacks.
--
--   2. auth_rls_initplan (15x) — RLS policies that called auth.uid() inline.
--      Postgres re-evaluates that per row. Wrapping it as (select auth.uid())
--      lets the planner cache the result once per query.
--
--   3. multiple_permissive_policies (9x) — `FOR ALL` admin-write policies
--      overlapped with per-command (SELECT / INSERT / UPDATE) policies on the
--      same role+action. Postgres OR-combines permissive policies, so both ran
--      per row. Fix: drop the FOR ALL policies and replace each command with
--      a single combined policy.
--
-- Strategy: drop every affected policy and recreate it so the diff is
-- explicit. Idempotent via `drop policy if exists`.

-- ---------------------------------------------------------------------------
-- 1. set_updated_at: fix search_path
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2 + 3. RLS policies: rebuild with (select auth.uid()) and one policy per
--        (table, command, role).
-- ---------------------------------------------------------------------------

-- users -----------------------------------------------------------------
drop policy if exists users_self_select on public.users;
drop policy if exists users_co_member_select on public.users;
drop policy if exists users_system_admin_select on public.users;
drop policy if exists users_self_update on public.users;

create policy users_select on public.users
  for select to authenticated using (
    id = (select auth.uid())
    or exists (
      select 1
      from public.workspace_members me
      join public.workspace_members other
        on other.workspace_id = me.workspace_id
      where me.user_id = (select auth.uid())
        and other.user_id = users.id
    )
    or private.is_system_admin()
  );

create policy users_self_update on public.users
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- workspaces ------------------------------------------------------------
drop policy if exists workspaces_member_select on public.workspaces;
drop policy if exists workspaces_self_insert on public.workspaces;
drop policy if exists workspaces_owner_update on public.workspaces;
drop policy if exists workspaces_owner_delete on public.workspaces;

create policy workspaces_select on public.workspaces
  for select to authenticated using (
    private.is_workspace_member(id) or private.is_system_admin()
  );

create policy workspaces_insert on public.workspaces
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy workspaces_update on public.workspaces
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy workspaces_delete on public.workspaces
  for delete to authenticated using (
    owner_id = (select auth.uid()) or private.is_system_admin()
  );

-- workspace_members (no auth.uid() inline; just dropping & recreating for
-- consistency would be churn — leave as-is, only one policy per command).

-- workspace_invites: same — no auth.uid() inline, no overlapping policies.

-- meal_days -------------------------------------------------------------
drop policy if exists meal_days_member_select on public.meal_days;
drop policy if exists meal_days_manager_write on public.meal_days;

create policy meal_days_select on public.meal_days
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
  );

create policy meal_days_insert on public.meal_days
  for insert to authenticated with check (
    private.has_workspace_role(workspace_id, array['owner','admin','manager'])
  );

create policy meal_days_update on public.meal_days
  for update to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin','manager']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin','manager']));

create policy meal_days_delete on public.meal_days
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin','manager'])
  );

-- meal_entries ----------------------------------------------------------
drop policy if exists meal_entries_member_select on public.meal_entries;
drop policy if exists meal_entries_self_insert on public.meal_entries;
drop policy if exists meal_entries_self_update on public.meal_entries;
drop policy if exists meal_entries_manager_write on public.meal_entries;

create policy meal_entries_select on public.meal_entries
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
  );

create policy meal_entries_insert on public.meal_entries
  for insert to authenticated with check (
    private.is_workspace_member(workspace_id)
    and (
      user_id = (select auth.uid())
      or private.has_workspace_role(workspace_id, array['owner','admin','manager'])
    )
  );

create policy meal_entries_update on public.meal_entries
  for update to authenticated
  using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = (select auth.uid())
      or private.has_workspace_role(workspace_id, array['owner','admin','manager'])
    )
  )
  with check (
    private.is_workspace_member(workspace_id)
    and (
      user_id = (select auth.uid())
      or private.has_workspace_role(workspace_id, array['owner','admin','manager'])
    )
  );

-- Members shouldn't delete their submitted entries; admins/managers may.
create policy meal_entries_delete on public.meal_entries
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin','manager'])
  );

-- custom_orders ---------------------------------------------------------
drop policy if exists custom_orders_member_select on public.custom_orders;
drop policy if exists custom_orders_self_insert on public.custom_orders;
drop policy if exists custom_orders_manager_write on public.custom_orders;

create policy custom_orders_select on public.custom_orders
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
  );

create policy custom_orders_insert on public.custom_orders
  for insert to authenticated with check (
    private.is_workspace_member(workspace_id)
    and (
      private.has_workspace_role(workspace_id, array['owner','admin','manager'])
      or exists (
        select 1 from public.meal_entries me
        where me.id = meal_entry_id and me.user_id = (select auth.uid())
      )
    )
  );

create policy custom_orders_update on public.custom_orders
  for update to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin','manager']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin','manager']));

create policy custom_orders_delete on public.custom_orders
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin','manager'])
  );

-- recurring_schedules ---------------------------------------------------
drop policy if exists recurring_schedules_self_select on public.recurring_schedules;
drop policy if exists recurring_schedules_self_write on public.recurring_schedules;

create policy recurring_schedules_select on public.recurring_schedules
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = (select auth.uid())
      or private.has_workspace_role(workspace_id, array['owner','admin','manager'])
    )
  );

create policy recurring_schedules_insert on public.recurring_schedules
  for insert to authenticated with check (
    private.is_workspace_member(workspace_id)
    and user_id = (select auth.uid())
  );

create policy recurring_schedules_update on public.recurring_schedules
  for update to authenticated
  using (
    private.is_workspace_member(workspace_id)
    and user_id = (select auth.uid())
  )
  with check (
    private.is_workspace_member(workspace_id)
    and user_id = (select auth.uid())
  );

create policy recurring_schedules_delete on public.recurring_schedules
  for delete to authenticated using (
    private.is_workspace_member(workspace_id)
    and user_id = (select auth.uid())
  );

-- payments --------------------------------------------------------------
drop policy if exists payments_self_select on public.payments;
drop policy if exists payments_admin_write on public.payments;

create policy payments_select on public.payments
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = (select auth.uid())
      or private.has_workspace_role(workspace_id, array['owner','admin'])
    )
  );

create policy payments_insert on public.payments
  for insert to authenticated with check (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

create policy payments_update on public.payments
  for update to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin']));

create policy payments_delete on public.payments
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

-- adjustments -----------------------------------------------------------
drop policy if exists adjustments_self_select on public.adjustments;
drop policy if exists adjustments_admin_write on public.adjustments;

create policy adjustments_select on public.adjustments
  for select to authenticated using (
    private.is_workspace_member(workspace_id)
    and (
      user_id = (select auth.uid())
      or private.has_workspace_role(workspace_id, array['owner','admin'])
    )
  );

create policy adjustments_insert on public.adjustments
  for insert to authenticated with check (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

create policy adjustments_update on public.adjustments
  for update to authenticated
  using (private.has_workspace_role(workspace_id, array['owner','admin']))
  with check (private.has_workspace_role(workspace_id, array['owner','admin']));

create policy adjustments_delete on public.adjustments
  for delete to authenticated using (
    private.has_workspace_role(workspace_id, array['owner','admin'])
  );

-- audit_logs ------------------------------------------------------------
-- Single SELECT policy already, no auth.uid() inline. Untouched.
