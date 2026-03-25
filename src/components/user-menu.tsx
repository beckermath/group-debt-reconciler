"use client";

import { signOut } from "next-auth/react";
import { Button } from "@/components/ui/button";

export function UserMenu({ name }: { name: string }) {
  return (
    <div className="flex items-center gap-3">
      <span className="text-sm text-muted-foreground hidden sm:inline">
        {name}
      </span>
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
