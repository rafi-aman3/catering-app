-- Lock down public.rls_auto_enable() — a Supabase-provided SECURITY DEFINER
-- helper that auto-enables RLS on newly created tables. It's flagged by
-- advisors because anon and authenticated have EXECUTE via PostgREST
-- (/rest/v1/rpc/rls_auto_enable).
--
-- We don't need it: every migration we write enables RLS explicitly, so
-- there's no scenario where this app calls it. Revoking EXECUTE silences the
-- warnings without removing the function — Supabase tooling can still invoke
-- it as service_role if needed.
--
-- Defensive: only revoke if the function exists. If a future Supabase change
-- removes it, this migration becomes a harmless no-op.

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rls_auto_enable'
  ) then
    revoke execute on function public.rls_auto_enable() from anon;
    revoke execute on function public.rls_auto_enable() from authenticated;
    revoke execute on function public.rls_auto_enable() from public;
  end if;
end
$$;
