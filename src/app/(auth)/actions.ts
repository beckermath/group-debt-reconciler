"use server";

import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import { signIn } from "@/lib/auth";
import { redirect } from "next/navigation";
import { headers, cookies } from "next/headers";
import { otpSendRateLimit, otpVerifyRateLimit } from "@/lib/rate-limit";
import { generateOtp, verifyOtp } from "@/services/otp-service";
import { claimGuestMembers } from "@/services/identity-service";

// E.164 phone format: +1234567890 (10-15 digits after +)
const PHONE_REGEX = /^\+[1-9]\d{9,14}$/;

function safeCallbackUrl(url: string): string {
  if (!url || !url.startsWith("/") || url.startsWith("//")) return "/";
  return url;
}

async function getClientIp(): Promise<string> {
  const h = await headers();
  return (
    h.get("x-real-ip") ??
    h.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown"
  );
}

export async function sendOtp(prevState: unknown, formData: FormData) {
  let phoneNumber = (formData.get("phoneNumber") as string)?.trim();

  // Normalize: if just digits, prepend +1
  if (phoneNumber && /^\d{10}$/.test(phoneNumber)) {
    phoneNumber = `+1${phoneNumber}`;
  }

  if (!phoneNumber || !PHONE_REGEX.test(phoneNumber)) {
    return { error: "Please enter a valid 10-digit phone number" };
  }

  // Rate limit by both IP and phone number
  const ip = await getClientIp();
  const { success: ipOk } = await otpSendRateLimit.limit(`ip:${ip}`);
  if (!ipOk) {
    return { error: "Too many attempts. Please try again later." };
  }
  const { success: phoneOk } = await otpSendRateLimit.limit(`phone:${phoneNumber}`);
  if (!phoneOk) {
    return { error: "Too many codes sent. Please wait a few minutes." };
  }

  try {
    await generateOtp(phoneNumber);
  } catch {
    return { error: "Failed to send verification code. Please try again." };
  }

  return { success: true, phoneNumber };
}

export async function verifyOtpAction(prevState: unknown, formData: FormData) {
  const phoneNumber = (formData.get("phoneNumber") as string)?.trim();
  const code = (formData.get("code") as string)?.trim();
  const callbackUrl = safeCallbackUrl((formData.get("callbackUrl") as string) || "/");

  if (!phoneNumber || !code) {
    return { error: "Phone number and code are required" };
  }

  // Rate limit verification attempts
  const { success } = await otpVerifyRateLimit.limit(`verify:${phoneNumber}`);
  if (!success) {
    return { error: "Too many attempts. Please request a new code." };
  }

  const result = await verifyOtp(phoneNumber, code);

  if (!result.valid) {
    return { error: result.error };
  }

  if (result.isNewUser) {
    // Store verified phone in a signed cookie for the setup step
    const cookieStore = await cookies();
    cookieStore.set("verified-phone", phoneNumber, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: 600, // 10 minutes to complete setup
      path: "/",
    });
    redirect("/phone/setup");
  }

  // Existing user — sign in
  try {
    await signIn("credentials", {
      phoneNumber,
      userId: result.userId,
      redirectTo: callbackUrl,
    });
  } catch (error) {
    if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) {
      throw error;
    }
    return { error: "Sign in failed. Please try again." };
  }
}

export async function completeSetup(prevState: unknown, formData: FormData) {
  const name = (formData.get("name") as string)?.trim();

  if (!name || name.length < 1) {
    return { error: "Please enter your name" };
  }

  // Verify the phone cookie exists (proves OTP was verified)
  const cookieStore = await cookies();
  const phoneNumber = cookieStore.get("verified-phone")?.value;

  if (!phoneNumber) {
    redirect("/phone");
  }

  // Check no user was created in the meantime
  const [existing] = await db
    .select()
    .from(users)
    .where(eq(users.phoneNumber, phoneNumber));

  if (existing) {
    // User was created between OTP verify and setup — just sign in
    cookieStore.delete("verified-phone");
    try {
      await signIn("credentials", {
        phoneNumber,
        userId: existing.id,
        redirectTo: "/",
      });
    } catch (error) {
      if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) {
        throw error;
      }
      return { error: "Sign in failed. Please try again." };
    }
    return;
  }

  // Create the user
  const userId = randomUUID();
  await db.insert(users).values({
    id: userId,
    name,
    phoneNumber,
  });

  // Claim any guest members that match this phone
  try {
    await claimGuestMembers(userId, [
      { provider: "phone", providerIdentity: phoneNumber },
    ]);
  } catch {
    // member_identities table may not exist yet
  }

  // Clear the cookie
  cookieStore.delete("verified-phone");

  // Sign in
  try {
    await signIn("credentials", {
      phoneNumber,
      userId,
      redirectTo: "/",
    });
  } catch (error) {
    if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) {
      throw error;
    }
    return { error: "Account created but sign in failed. Please try signing in." };
  }
}
