import Link from "next/link";

import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

type SearchParams = Promise<{ email?: string }>;

export default async function CheckEmailPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const { email } = await searchParams;

  return (
    <div className="flex flex-1 items-center justify-center px-4 py-12">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Check your email</CardTitle>
          <CardDescription>
            {email
              ? `We sent a sign-in link to ${email}. Open it on this device to continue.`
              : "We sent you a sign-in link. Open it on this device to continue."}
          </CardDescription>
        </CardHeader>
        <CardContent className="text-sm text-muted-foreground">
          The link expires in an hour. If you don&apos;t see the email, check
          your spam folder.
        </CardContent>
        <CardFooter className="text-sm">
          <Link
            href="/login"
            className="font-medium text-foreground underline-offset-4 hover:underline"
          >
            Back to sign in
          </Link>
        </CardFooter>
      </Card>
    </div>
  );
}
