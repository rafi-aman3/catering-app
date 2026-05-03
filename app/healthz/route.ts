import { NextResponse } from "next/server";

import { env } from "@/lib/env";

export const dynamic = "force-dynamic";

export async function GET() {
  // Importing `env` runs the Zod check; if env is misconfigured, this 500s.
  // That's the point — /healthz fails loudly when something is broken.
  void env.NEXT_PUBLIC_SUPABASE_URL;

  return NextResponse.json({
    status: "ok",
    env: "loaded",
    db: "skipped", // wired in M0 phase 3 once the Supabase client lands
    time: new Date().toISOString(),
  });
}
