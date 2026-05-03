import "server-only";

import { createClient } from "@supabase/supabase-js";

import { env } from "@/lib/env";

// Service-role client. Bypasses RLS. Use ONLY from /system routes,
// scheduled jobs, and server-side admin operations — never from a regular
// user-facing route, or you defeat workspace isolation.
export function createAdminClient() {
  return createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
