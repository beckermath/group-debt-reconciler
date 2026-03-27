"use client";

import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { useState, useCallback, useEffect } from "react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";

const VALID_TABS = ["expenses", "members", "history"] as const;
type TabValue = (typeof VALID_TABS)[number];

function isValidTab(value: string | undefined): value is TabValue {
  return VALID_TABS.includes(value as TabValue);
}

export function GroupDetailTabs({
  tab,
  availableTabs = VALID_TABS as unknown as TabValue[],
  children,
}: {
  tab?: string;
  availableTabs?: TabValue[];
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  function resolveTab(value: string | undefined): TabValue {
    if (isValidTab(value) && availableTabs.includes(value)) return value;
    return "expenses";
  }

  const initialTab = resolveTab(tab);
  const [activeTab, setActiveTab] = useState<TabValue>(initialTab);

  // Sync with server-provided tab on navigation
  useEffect(() => {
    setActiveTab(resolveTab(tab));
  }, [tab, availableTabs]);

  const handleTabChange = useCallback(
    (value: string) => {
      if (!isValidTab(value)) return;
      setActiveTab(value);
      const params = new URLSearchParams(searchParams.toString());
      if (value === "expenses") {
        params.delete("tab");
      } else {
        params.set("tab", value);
      }
      const query = params.toString();
      router.replace(`${pathname}${query ? `?${query}` : ""}`, { scroll: false });
    },
    [searchParams, router, pathname]
  );

  return (
    <Tabs value={activeTab} onValueChange={handleTabChange}>
      {children}
    </Tabs>
  );
}

export { TabsList, TabsTrigger, TabsContent };
