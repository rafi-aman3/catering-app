// Server-side instrumentation. Runs once when the Next.js server boots.
// See node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/instrumentation.md.
//
// Sentry is wired as a no-op: if SENTRY_DSN isn't set we don't init the SDK
// and onRequestError becomes a noop. This lets the app boot without Sentry
// configured (M0) and start reporting once the DSN lands in env.

import type { Instrumentation } from "next";

export async function register() {
  if (!process.env.SENTRY_DSN) return;

  const Sentry = await import("@sentry/nextjs");

  if (process.env.NEXT_RUNTIME === "nodejs") {
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      tracesSampleRate: 0.1,
    });
  }

  if (process.env.NEXT_RUNTIME === "edge") {
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      tracesSampleRate: 0.1,
    });
  }
}

export const onRequestError: Instrumentation.onRequestError = async (
  err,
  request,
  context,
) => {
  if (!process.env.SENTRY_DSN) return;
  const Sentry = await import("@sentry/nextjs");
  Sentry.captureRequestError(err, request, context);
};
