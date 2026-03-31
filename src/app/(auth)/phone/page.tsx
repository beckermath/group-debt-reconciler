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

  function handlePhoneChange(e: React.ChangeEvent<HTMLInputElement>) {
    // Strip non-digits
    const digits = e.target.value.replace(/\D/g, "").slice(0, 10);
    setPhone(digits);
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Sign in with your phone</CardTitle>
      </CardHeader>
      <CardContent>
        <form action={action} className="space-y-4">
          <input type="hidden" name="phoneNumber" value={`+1${phone}`} />
          <div className="space-y-2">
            <Label htmlFor="phoneNumber">Phone number</Label>
            <div className="flex">
              <span className="inline-flex items-center rounded-l-lg border border-r-0 border-input bg-muted px-3 text-sm text-muted-foreground">
                +1
              </span>
              <Input
                id="phoneNumber"
                type="tel"
                placeholder="(212) 555-1234"
                autoComplete="tel-national"
                required
                autoFocus
                value={phone}
                onChange={handlePhoneChange}
                className="rounded-l-none"
              />
            </div>
            <p className="text-xs text-muted-foreground">
              We&apos;ll send you a 6-digit verification code.
            </p>
          </div>

          {state?.error && (
            <p className="text-sm text-destructive">{state.error}</p>
          )}

          <SubmitButton className="w-full" disabled={phone.length < 10}>
            Send code
          </SubmitButton>
        </form>
      </CardContent>
    </Card>
  );
}
