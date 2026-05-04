import Link from "next/link";

import {
  signInWithGoogle,
  signUpWithPassword,
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

export default async function SignUpPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { error } = await searchParams;

  return (
    <div className="flex flex-1 items-center justify-center px-4 py-12">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Create your account</CardTitle>
          <CardDescription>
            Start a new workspace or join one with an invite.
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

          <form action={signUpWithPassword} className="flex flex-col gap-3">
            <div className="flex flex-col gap-2">
              <Label htmlFor="signup-email">Email</Label>
              <Input
                id="signup-email"
                name="email"
                type="email"
                autoComplete="email"
                required
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="signup-password">Password</Label>
              <Input
                id="signup-password"
                name="password"
                type="password"
                autoComplete="new-password"
                minLength={8}
                required
              />
              <p className="text-xs text-muted-foreground">
                At least 8 characters.
              </p>
            </div>
            <Button type="submit" className="w-full">
              Create account
            </Button>
          </form>
        </CardContent>

        <CardFooter className="text-sm text-muted-foreground">
          Already have an account?{" "}
          <Link
            href="/login"
            className="ml-1 font-medium text-foreground underline-offset-4 hover:underline"
          >
            Sign in
          </Link>
        </CardFooter>
      </Card>
    </div>
  );
}
