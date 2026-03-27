import { db } from "@/db";
import { otpCodes, users } from "@/db/schema";
import { eq, and, isNull, desc } from "drizzle-orm";
import { randomUUID, randomInt, timingSafeEqual } from "crypto";
import { sendSms } from "@/services/sms-service";

const OTP_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes
const MAX_ATTEMPTS = 5;

export async function generateOtp(phoneNumber: string): Promise<void> {
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
    code,
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
  const now = new Date();

  // Find the latest unexpired, unused OTP for this phone
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

  // Increment attempts before checking
  await db
    .update(otpCodes)
    .set({ attempts: otp.attempts + 1 })
    .where(eq(otpCodes.id, otp.id));

  // Timing-safe comparison
  const inputBuffer = Buffer.from(inputCode.padEnd(6, "0"));
  const storedBuffer = Buffer.from(otp.code.padEnd(6, "0"));

  if (!timingSafeEqual(inputBuffer, storedBuffer)) {
    return { valid: false, error: "Incorrect code. Please try again." };
  }

  // Mark as used
  await db.update(otpCodes).set({ usedAt: now }).where(eq(otpCodes.id, otp.id));

  // Look up existing user
  const [existingUser] = await db
    .select({ id: users.id })
    .from(users)
    .where(eq(users.phoneNumber, phoneNumber));

  if (existingUser) {
    return { valid: true, userId: existingUser.id, isNewUser: false };
  }

  return { valid: true, userId: null, isNewUser: true };
}
