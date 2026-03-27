"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { sendOtp } from "../actions";

export default function PhonePage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const callbackUrl = searchParams.get("callbackUrl") ?? "/";
  const [state, action] = useActionState(sendOtp, null);
  const [phone, setPhone] = useState("");

  useEffect(() => {
    if (state?.success && state.phoneNumber) {
      const params = new URLSearchParams({ phone: state.phoneNumber });
      if (callbackUrl !== "/") params.set("callbackUrl", callbackUrl);
      router.push(`/phone/verify?${params}`);
    }
  }, [state, router, callbackUrl]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Sign in with your phone</CardTitle>
      </CardHeader>
      <CardContent>
        <form action={action} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="phoneNumber">Phone number</Label>
            <Input
              id="phoneNumber"
              name="phoneNumber"
              type="tel"
              placeholder="+12125551234"
              autoComplete="tel"
              required
              autoFocus
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
            <p className="text-xs text-muted-foreground">
              We&apos;ll send you a 6-digit verification code.
            </p>
          </div>

          {state?.error && (
            <p className="text-sm text-destructive">{state.error}</p>
          )}

          <SubmitButton className="w-full">Send code</SubmitButton>
        </form>
      </CardContent>
    </Card>
  );
}
