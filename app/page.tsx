import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function Home() {
  return (
    <div className="flex flex-1 items-center justify-center px-6 py-24">
      <div className="flex flex-col items-center gap-6 text-center">
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
          Catering
        </h1>
        <p className="max-w-md text-muted-foreground">
          Daily lunch polls, custom orders, and billing for your office.
        </p>
        <Button asChild size="lg">
          <Link href="/login">Sign in to continue</Link>
        </Button>
      </div>
    </div>
  );
}
