"use client";

import { useActionState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/submit-button";
import { updateProfile } from "./actions";

export function ProfileForm({ name, phoneNumber }: { name: string; phoneNumber: string }) {
  const [state, action] = useActionState(updateProfile, null);

  return (
    <form action={action} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="name">Name</Label>
        <Input id="name" name="name" defaultValue={name} required />
      </div>

      <div className="space-y-2">
        <Label htmlFor="phone">Phone number</Label>
        <Input id="phone" value={phoneNumber} disabled className="opacity-60" />
        <p className="text-xs text-muted-foreground">Phone number cannot be changed</p>
      </div>

      {state?.error && (
        <p className="text-sm text-destructive">{state.error}</p>
      )}
      {"success" in (state ?? {}) && (
        <p className="text-sm text-owed">{(state as { success: string }).success}</p>
      )}

      <SubmitButton>Save</SubmitButton>
    </form>
  );
}
