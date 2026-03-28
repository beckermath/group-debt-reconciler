"use client";

import { useActionState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { completeSetup } from "../../actions";

export default function SetupPage() {
  const [state, action] = useActionState(completeSetup, null);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Welcome to Rekn</CardTitle>
        <CardDescription>
          What should we call you?
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form action={action} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Your name</Label>
            <Input
              id="name"
              name="name"
              placeholder="Alex"
              required
              autoFocus
              autoComplete="name"
            />
          </div>

          {state?.error && (
            <p className="text-sm text-destructive">{state.error}</p>
          )}

          <SubmitButton className="w-full">Get started</SubmitButton>
        </form>
      </CardContent>
    </Card>
  );
}
