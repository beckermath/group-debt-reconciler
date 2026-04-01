import { db } from "@/db";
import { otpCodes, users } from "@/db/schema";
import { eq, and, isNull, desc } from "drizzle-orm";
import { randomUUID, randomInt, timingSafeEqual, createHash } from "crypto";
import { sendSms } from "@/services/sms-service";

const OTP_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes
const MAX_ATTEMPTS = 5;
const TEST_CODE = "000000";

function hashOtp(code: string): string {
  return createHash("sha256").update(code).digest("hex");
}

// Test mode: only allowed outside production
const isTest = process.env.PLAYWRIGHT_TEST === "1" && process.env.NODE_ENV !== "production";
if (process.env.PLAYWRIGHT_TEST === "1" && process.env.NODE_ENV === "production") {
  throw new Error("PLAYWRIGHT_TEST must not be set in production");
}

export async function generateOtp(phoneNumber: string): Promise<void> {
  // In test mode, skip DB and SMS entirely — tests use static code "000000"
  if (isTest) {
    console.log(`[TEST OTP → ${phoneNumber}] ${TEST_CODE}`);
    return;
  }

  // Invalidate any existing unused OTPs for this phone
  const existing = await db
    .select({ id: otpCodes.id })
    .from(otpCodes)
    .where(and(eq(otpCodes.phoneNumber, phoneNumber), isNull(otpCodes.usedAt)));

  for (const row of existing) {
    await db.update(otpCodes).set({ usedAt: new Date() }).where(eq(otpCodes.id, row.id));
  }

  const code = String(randomInt(100000, 999999));
  const now = new Date();

  await db.insert(otpCodes).values({
    id: randomUUID(),
    phoneNumber,
    code: hashOtp(code), // Store hash, not plaintext
    expiresAt: new Date(now.getTime() + OTP_EXPIRY_MS),
    attempts: 0,
    createdAt: now,
  });

  await sendSms(phoneNumber, `Your Rekn verification code is: ${code}`);
}

export type VerifyResult =
  | { valid: true; userId: string; isNewUser: false }
  | { valid: true; userId: null; isNewUser: true }
  | { valid: false; error: string };

export async function verifyOtp(
  phoneNumber: string,
  inputCode: string
): Promise<VerifyResult> {
  // In test mode, accept the static code without touching the DB
  if (isTest) {
    if (inputCode !== TEST_CODE) {
      return { valid: false, error: "Incorrect code. Please try again." };
    }

    const [existingUser] = await db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.phoneNumber, phoneNumber));

    if (existingUser) {
      return { valid: true, userId: existingUser.id, isNewUser: false };
    }
    return { valid: true, userId: null, isNewUser: true };
  }

  // Production OTP verification
  const now = new Date();

  const [otp] = await db
    .select()
    .from(otpCodes)
    .where(
      and(
        eq(otpCodes.phoneNumber, phoneNumber),
        isNull(otpCodes.usedAt)
      )
    )
    .orderBy(desc(otpCodes.createdAt))
    .limit(1);

  if (!otp) {
    return { valid: false, error: "No verification code found. Please request a new one." };
  }

  if (otp.expiresAt < now) {
    await db.update(otpCodes).set({ usedAt: now }).where(eq(otpCodes.id, otp.id));
    return { valid: false, error: "Code expired. Please request a new one." };
  }

  if (otp.attempts >= MAX_ATTEMPTS) {
    await db.update(otpCodes).set({ usedAt: now }).where(eq(otpCodes.id, otp.id));
    return { valid: false, error: "Too many attempts. Please request a new code." };
  }

  await db
    .update(otpCodes)
    .set({ attempts: otp.attempts + 1 })
    .where(eq(otpCodes.id, otp.id));

  // Compare hashes using timing-safe comparison
  const inputHash = hashOtp(inputCode);
  const inputBuffer = Buffer.from(inputHash);
  const storedBuffer = Buffer.from(otp.code);

  if (inputBuffer.length !== storedBuffer.length || !timingSafeEqual(inputBuffer, storedBuffer)) {
    return { valid: false, error: "Incorrect code. Please try again." };
  }

  await db.update(otpCodes).set({ usedAt: now }).where(eq(otpCodes.id, otp.id));

  const [existingUser] = await db
    .select({ id: users.id })
    .from(users)
    .where(eq(users.phoneNumber, phoneNumber));

  if (existingUser) {
    return { valid: true, userId: existingUser.id, isNewUser: false };
  }

  return { valid: true, userId: null, isNewUser: true };
}
