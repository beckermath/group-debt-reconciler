"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { acceptInvite } from "@/app/actions";

export function AcceptInviteButton({
  code,
  groupName,
}: {
  code: string;
  groupName: string;
}) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleAccept() {
    setLoading(true);
    setError(null);
    const result = await acceptInvite(code);
    if (result?.error) {
      setError(result.error);
      setLoading(false);
    }
    // On success, acceptInvite redirects to the group page
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        You have been invited to join <span className="font-medium text-foreground">{groupName}</span>.
      </p>
      {error && <p className="text-sm text-destructive">{error}</p>}
      <Button onClick={handleAccept} disabled={loading} className="w-full">
        {loading ? "Joining..." : "Join group"}
      </Button>
    </div>
  );
}
