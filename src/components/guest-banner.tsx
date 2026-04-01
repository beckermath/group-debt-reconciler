"use client";

import { useState } from "react";
import { useIsGuest } from "@/hooks/use-is-guest";
import { Button } from "@/components/ui/button";
import { X } from "lucide-react";
import Link from "next/link";

export function GuestBanner() {
  const { isGuest, isLoading } = useIsGuest();
  const [dismissed, setDismissed] = useState(false);

  if (isLoading || !isGuest || dismissed) return null;

  return (
    <div className="border-b bg-accent/5 px-4 sm:px-6 py-2.5 flex items-center justify-between gap-3">
      <p className="text-sm text-muted-foreground">
        You&apos;re using Rekn as a guest.{" "}
        <Link href="/phone" className="font-medium text-primary hover:underline">
          Sign up
        </Link>{" "}
        to save your data and invite friends.
      </p>
      <button
        onClick={() => setDismissed(true)}
        className="text-muted-foreground hover:text-foreground shrink-0 cursor-pointer"
        aria-label="Dismiss"
      >
        <X className="size-4" />
      </button>
    </div>
  );
}
