"use client";

import { signOut } from "next-auth/react";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export function UserMenu({ name }: { name: string }) {
  return (
    <div className="flex items-center gap-1">
      <Link href="/settings">
        <Button variant="ghost" size="sm" className="hidden sm:inline-flex">
          {name}
        </Button>
      </Link>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => signOut({ callbackUrl: "/login" })}
      >
        Sign out
      </Button>
    </div>
  );
}
