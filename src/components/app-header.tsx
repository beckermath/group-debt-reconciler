"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { ThemeToggle } from "@/components/theme-toggle";
import { UserMenu } from "@/components/user-menu";
import { GuestBanner } from "@/components/guest-banner";

export function AppHeader({ name, isGuest }: { name: string; isGuest: boolean }) {
  const pathname = usePathname();

  // Hide header on auth pages
  if (pathname.startsWith("/phone")) return null;

  return (
    <>
      <header className="border-b px-4 sm:px-6 py-4 flex items-center justify-between">
        <Link href="/" className="text-xl font-bold tracking-tight text-primary">
          Rekn
        </Link>
        <div className="flex items-center gap-2">
          <UserMenu name={name} isGuest={isGuest} />
          <ThemeToggle />
        </div>
      </header>
      <GuestBanner isGuest={isGuest} />
    </>
  );
}
