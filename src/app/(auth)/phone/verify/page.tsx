"use client";

import { useActionState, useState, useEffect, useRef } from "react";
import { useSearchParams } from "next/navigation";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { verifyOtpAction, sendOtp } from "../../actions";

function maskPhone(phone: string): string {
  if (phone.length <= 4) return phone;
  return phone.slice(0, -4).replace(/\d/g, "*") + phone.slice(-4);
}

export default function VerifyPage() {
  const searchParams = useSearchParams();
  const phoneNumber = searchParams.get("phone") ?? "";
  const callbackUrl = searchParams.get("callbackUrl") ?? "/";
  const [state, action] = useActionState(verifyOtpAction, null);
  const [code, setCode] = useState("");
  const [resendCooldown, setResendCooldown] = useState(60);
  const [resendState, resendAction] = useActionState(sendOtp, null);
  const cooldownRef = useRef<ReturnType<typeof setInterval>>(undefined);

  useEffect(() => {
    cooldownRef.current = setInterval(() => {
      setResendCooldown((prev) => {
        if (prev <= 1) {
          clearInterval(cooldownRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(cooldownRef.current);
  }, []);

  function handleResend() {
    const formData = new FormData();
    formData.set("phoneNumber", phoneNumber);
    resendAction(formData);
    setResendCooldown(60);
    cooldownRef.current = setInterval(() => {
      setResendCooldown((prev) => {
        if (prev <= 1) {
          clearInterval(cooldownRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }

  if (!phoneNumber) {
    return (
      <Card>
        <CardContent className="py-8 text-center">
          <p className="text-muted-foreground">No phone number provided.</p>
          <a href="/phone" className="text-sm text-primary hover:underline mt-2 block">
            Go back
          </a>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Enter verification code</CardTitle>
        <CardDescription>
          We sent a 6-digit code to {maskPhone(phoneNumber)}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form action={action} className="space-y-4">
          <input type="hidden" name="phoneNumber" value={phoneNumber} />
          <input type="hidden" name="callbackUrl" value={callbackUrl} />

          <div className="space-y-2">
            <Label htmlFor="code">Verification code</Label>
            <Input
              id="code"
              name="code"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="000000"
              maxLength={6}
              required
              autoFocus
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
              className="text-center text-lg tracking-[0.5em] font-mono"
            />
          </div>

          {(state?.error || resendState?.error) && (
            <p className="text-sm text-destructive">
              {state?.error || resendState?.error}
            </p>
          )}

          <SubmitButton className="w-full" disabled={code.length !== 6}>
            Verify
          </SubmitButton>

          <div className="text-center">
            {resendCooldown > 0 ? (
              <p className="text-xs text-muted-foreground">
                Resend code in {resendCooldown}s
              </p>
            ) : (
              <button
                type="button"
                onClick={handleResend}
                className="text-xs text-primary hover:underline cursor-pointer"
              >
                Resend code
              </button>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
