import { NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const started = Date.now();

  // Cheapest reachability check: ask Supabase Auth for the current user.
  // For an unauthenticated /healthz hit we expect user=null, possibly with an
  // "auth session missing" error — that's fine, it still proves we reached
  // the Auth server. A thrown exception is a real connectivity problem.
  try {
    const supabase = await createClient();
    await supabase.auth.getUser();
  } catch (e) {
    return NextResponse.json(
      {
        status: "degraded",
        env: "loaded",
        db: "unreachable",
        error: e instanceof Error ? e.message : String(e),
        latencyMs: Date.now() - started,
        time: new Date().toISOString(),
      },
      { status: 503 },
    );
  }

  return NextResponse.json({
    status: "ok",
    env: "loaded",
    db: "ok",
    latencyMs: Date.now() - started,
    time: new Date().toISOString(),
  });
}
