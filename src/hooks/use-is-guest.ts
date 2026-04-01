"use client";

import { useSession } from "next-auth/react";

export function useIsGuest() {
  const { data: session, status } = useSession();
  return {
    isGuest: session?.user?.isGuest ?? false,
    isLoading: status === "loading",
  };
}
