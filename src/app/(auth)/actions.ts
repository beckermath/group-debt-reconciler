"use server";

import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import bcrypt from "bcryptjs";
import { signIn } from "@/lib/auth";
import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { loginRateLimit, registerRateLimit } from "@/lib/rate-limit";
import { claimGuestMembers } from "@/services/identity-service";

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

export async function register(prevState: unknown, formData: FormData) {
  const ip = await getClientIp();
  const { success } = await registerRateLimit.limit(ip);
  if (!success) {
    return { error: "Too many registration attempts. Please try again later." };
  }

  const name = (formData.get("name") as string)?.trim();
  const email = (formData.get("email") as string)?.trim().toLowerCase();
  const password = formData.get("password") as string;
  const confirmPassword = formData.get("confirmPassword") as string;

  if (!name || !email || !password) {
    return { error: "All fields are required" };
  }

  if (password.length < 8) {
    return { error: "Password must be at least 8 characters" };
  }

  if (password !== confirmPassword) {
    return { error: "Passwords do not match" };
  }

  const [existing] = await db.select().from(users).where(eq(users.email, email));
  if (existing) {
    return { error: "Unable to create account. Please try a different email or sign in." };
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const userId = randomUUID();
  await db.insert(users).values({
    id: userId,
    name,
    email,
    passwordHash,
  });

  // Claim any guest members that match this email (best-effort — table may not exist yet)
  try {
    await claimGuestMembers(userId, [{ provider: "email", providerIdentity: email }]);
  } catch {
    // member_identities table may not exist yet; skip silently
  }

  try {
    await signIn("credentials", { email, password, redirectTo: "/" });
  } catch (error) {
    if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) {
      throw error;
    }
    redirect("/login");
  }
}

export async function login(prevState: unknown, formData: FormData) {
  const ip = await getClientIp();
  const { success } = await loginRateLimit.limit(ip);
  if (!success) {
    return { error: "Too many login attempts. Please try again in a few minutes." };
  }

  const email = (formData.get("email") as string)?.trim().toLowerCase();
  const password = formData.get("password") as string;
  const callbackUrl = safeCallbackUrl((formData.get("callbackUrl") as string) || "/");

  if (!email || !password) {
    return { error: "Email and password are required" };
  }

  try {
    await signIn("credentials", { email, password, redirectTo: callbackUrl });
  } catch (error) {
    if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) {
      throw error;
    }
    return { error: "Invalid email or password" };
  }
}
