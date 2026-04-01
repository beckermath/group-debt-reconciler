"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { devSwitchUser } from "@/app/actions";

const TEST_USERS = [
  { name: "Alice", phone: "+15550000001" },
  { name: "Bob", phone: "+15550000002" },
  { name: "Charlie", phone: "+15550000003" },
  { name: "Diana", phone: "+15550000004" },
];

export function DevSwitcher({ currentUserName }: { currentUserName?: string }) {
  const [open, setOpen] = useState(false);
  const [switching, setSwitching] = useState<string | null>(null);
  const router = useRouter();

  if (process.env.NODE_ENV === "production" || !process.env.NEXT_PUBLIC_ENABLE_DEV_TOOLS) return null;

  async function handleSwitch(phone: string) {
    setSwitching(phone);
    const result = await devSwitchUser(phone);
    if (result?.error) {
      setSwitching(null);
      return;
    }
    router.refresh();
    window.location.href = "/";
  }

  return (
    <div className="fixed bottom-4 right-4 z-50">
      {open ? (
        <div className="rounded-xl border bg-card shadow-lg p-3 space-y-2 w-52">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Dev Accounts</span>
            <button onClick={() => setOpen(false)} className="text-xs text-muted-foreground hover:text-foreground cursor-pointer">
              Close
            </button>
          </div>
          {TEST_USERS.map((user) => {
            const isCurrent = currentUserName === user.name;
            const isSwitching = switching === user.phone;
            return (
              <button
                key={user.phone}
                onClick={() => handleSwitch(user.phone)}
                disabled={isCurrent || isSwitching}
                className={`w-full text-left px-2.5 py-1.5 rounded-md text-sm transition-colors cursor-pointer ${
                  isCurrent
                    ? "bg-primary/10 text-primary font-medium"
                    : "hover:bg-muted text-foreground"
                } disabled:opacity-50`}
              >
                <span className="font-medium">{user.name}</span>
                <span className="text-xs text-muted-foreground ml-1.5">{user.phone}</span>
                {isCurrent && <span className="text-[0.65rem] ml-1">(you)</span>}
                {isSwitching && <span className="text-[0.65rem] ml-1">switching...</span>}
              </button>
            );
          })}
        </div>
      ) : (
        <button
          onClick={() => setOpen(true)}
          className="h-10 w-10 rounded-full bg-primary text-primary-foreground shadow-lg flex items-center justify-center text-sm font-bold hover:bg-primary/90 transition-colors cursor-pointer"
          title="Dev Account Switcher"
        >
          {currentUserName?.[0] ?? "?"}
        </button>
      )}
    </div>
  );
}
