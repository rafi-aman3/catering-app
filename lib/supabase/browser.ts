"use client";

import { createBrowserClient } from "@supabase/ssr";

// Reads NEXT_PUBLIC_* directly because lib/env is server-only.
// Next inlines these at build time.
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
