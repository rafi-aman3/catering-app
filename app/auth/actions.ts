"use server";

import { redirect } from "next/navigation";

import { env } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

// Where OAuth providers and magic-link emails redirect back to. Must match the
// allowed redirect URLs configured in the Supabase project (Auth → URL config).
const callbackUrl = `${env.NEXT_PUBLIC_APP_URL}/auth/callback`;

function loginRedirect(message: string): never {
  redirect(`/login?error=${encodeURIComponent(message)}`);
}

function signUpRedirect(message: string): never {
  redirect(`/sign-up?error=${encodeURIComponent(message)}`);
}

export async function signInWithPassword(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  if (!email || !password) loginRedirect("Email and password are required");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) loginRedirect(error.message);

  redirect("/dashboard");
}

export async function signUpWithPassword(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  if (!email || !password) signUpRedirect("Email and password are required");
  if (password.length < 8) signUpRedirect("Password must be at least 8 characters");

  const supabase = await createClient();
  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: { emailRedirectTo: callbackUrl },
  });
  if (error) signUpRedirect(error.message);

  redirect(`/auth/check-email?email=${encodeURIComponent(email)}`);
}

export async function signInWithMagicLink(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  if (!email) loginRedirect("Email is required");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: callbackUrl },
  });
  if (error) loginRedirect(error.message);

  redirect(`/auth/check-email?email=${encodeURIComponent(email)}`);
}

export async function signInWithGoogle() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: callbackUrl },
  });
  if (error || !data.url) loginRedirect(error?.message ?? "OAuth init failed");

  redirect(data.url);
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
