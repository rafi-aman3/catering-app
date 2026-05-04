"use client";

import { usePathname, useSearchParams } from "next/navigation";
import { Suspense, useEffect } from "react";
import posthog from "posthog-js";

// PostHog's auto-pageview capture doesn't see App Router client navigations.
// This component fires `$pageview` on every route change. Mounted from the root
// layout. It's a no-op when posthog-js wasn't initialized (no key in env).

function PageViewTracker() {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (!process.env.NEXT_PUBLIC_POSTHOG_KEY) return;
    if (!pathname) return;

    let url = window.origin + pathname;
    const qs = searchParams?.toString();
    if (qs) url += `?${qs}`;

    posthog.capture("$pageview", { $current_url: url });
  }, [pathname, searchParams]);

  return null;
}

// useSearchParams() forces dynamic rendering for the route it's called from.
// Wrapping in Suspense scopes that to this component, so the rest of the app
// keeps its static-rendering behavior.
export function PostHogPageView() {
  return (
    <Suspense fallback={null}>
      <PageViewTracker />
    </Suspense>
  );
}
