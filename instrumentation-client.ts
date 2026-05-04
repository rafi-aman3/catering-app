// Client-side instrumentation. Runs after HTML loads, before React hydration.
// See node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/instrumentation-client.md.
//
// Both Sentry and PostHog init are gated on env vars so missing keys = no-op.

import * as Sentry from "@sentry/nextjs";
import posthog from "posthog-js";

if (process.env.NEXT_PUBLIC_SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0,
    replaysOnErrorSampleRate: 1.0,
  });
}

if (process.env.NEXT_PUBLIC_POSTHOG_KEY) {
  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY, {
    api_host:
      process.env.NEXT_PUBLIC_POSTHOG_HOST ?? "https://us.i.posthog.com",
    // Pageviews are captured by components/posthog-pageview.tsx so router
    // transitions in the App Router don't get missed.
    capture_pageview: false,
    capture_pageleave: true,
  });
}

export const onRouterTransitionStart = process.env.NEXT_PUBLIC_SENTRY_DSN
  ? Sentry.captureRouterTransitionStart
  : undefined;
