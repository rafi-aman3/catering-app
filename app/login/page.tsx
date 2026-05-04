import Link from "next/link";

import {
  signInWithGoogle,
  signInWithMagicLink,
  signInWithPassword,
} from "@/app/auth/actions";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type SearchParams = Promise<{ error?: string }>;

export default async function LoginPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { error } = await searchParams;

  return (
    <div className="flex flex-1 items-center justify-center px-4 py-12">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Sign in</CardTitle>
          <CardDescription>
            Use your work email or continue with Google.
          </CardDescription>
        </CardHeader>

        <CardContent className="flex flex-col gap-6">
          {error ? (
            <p className="text-sm text-destructive" role="alert">
              {error}
            </p>
          ) : null}

          <form action={signInWithGoogle}>
            <Button type="submit" variant="outline" className="w-full">
              Continue with Google
            </Button>
          </form>

          <div className="relative text-center text-xs uppercase text-muted-foreground">
            <span className="bg-card px-2">or with email</span>
            <div className="absolute inset-x-0 top-1/2 -z-10 h-px -translate-y-1/2 bg-border" />
          </div>

          <form action={signInWithPassword} className="flex flex-col gap-3">
            <div className="flex flex-col gap-2">
              <Label htmlFor="login-email">Email</Label>
              <Input
                id="login-email"
                name="email"
                type="email"
                autoComplete="email"
                required
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="login-password">Password</Label>
              <Input
                id="login-password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
              />
            </div>
            <Button type="submit" className="w-full">
              Sign in
            </Button>
          </form>

          <form action={signInWithMagicLink} className="flex flex-col gap-3">
            <div className="flex flex-col gap-2">
              <Label htmlFor="magic-email">Or get a magic link</Label>
              <Input
                id="magic-email"
                name="email"
                type="email"
                autoComplete="email"
                required
                placeholder="you@company.com"
              />
            </div>
            <Button type="submit" variant="secondary" className="w-full">
              Email me a sign-in link
            </Button>
          </form>
        </CardContent>

        <CardFooter className="text-sm text-muted-foreground">
          Don&apos;t have an account?{" "}
          <Link
            href="/sign-up"
            className="ml-1 font-medium text-foreground underline-offset-4 hover:underline"
          >
            Sign up
          </Link>
        </CardFooter>
      </Card>
    </div>
  );
}
