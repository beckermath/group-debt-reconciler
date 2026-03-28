"use client";

import { signOut } from "next-auth/react";
import { Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export function UserMenu({ name }: { name: string }) {
  return (
    <div className="flex items-center gap-1">
      <Link href="/settings">
        <Button variant="ghost" size="sm" className="hidden sm:inline-flex">
          {name}
        </Button>
        <Button variant="ghost" size="icon" className="sm:hidden" aria-label="Settings">
          <Settings className="size-4" />
        </Button>
      </Link>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => signOut({ callbackUrl: "/phone" })}
      >
        Sign out
      </Button>
    </div>
  );
}
