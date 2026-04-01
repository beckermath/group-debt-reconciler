"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { sendOtp, startGuestSession } from "../actions";
import { useIsGuest } from "@/hooks/use-is-guest";

export default function PhonePage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const callbackUrl = searchParams.get("callbackUrl") ?? "/";
  const { isGuest } = useIsGuest();
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
    const digits = e.target.value.replace(/\D/g, "").slice(0, 10);
    setPhone(digits);
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle>{isGuest ? "Create your account" : "Sign in with your phone"}</CardTitle>
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

      {isGuest ? (
        <p className="text-xs text-muted-foreground text-center">
          Your existing groups and expenses will be preserved.
        </p>
      ) : (
        <>
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="bg-background px-2 text-muted-foreground">or</span>
            </div>
          </div>

          <form action={startGuestSession}>
            <Button variant="ghost" className="w-full" type="submit">
              Try as guest
            </Button>
          </form>
        </>
      )}
    </div>
  );
}
