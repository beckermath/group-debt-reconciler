import { NextRequest } from "next/server";
import * as res from "@/lib/api-response";
import { generateOtp } from "@/services/otp-service";
import { otpSendRateLimit } from "@/lib/rate-limit";
import { withErrorHandling } from "@/lib/api-handler";

const PHONE_REGEX = /^\+[1-9]\d{9,14}$/;

export const POST = withErrorHandling(async (request: NextRequest) => {
  const body = await request.json().catch(() => null);
  let phoneNumber = body?.phoneNumber?.trim();

  if (!phoneNumber) return res.badRequest("Phone number is required");

  // Normalize 10-digit to E.164
  if (/^\d{10}$/.test(phoneNumber)) {
    phoneNumber = `+1${phoneNumber}`;
  }

  if (!PHONE_REGEX.test(phoneNumber)) {
    return res.badRequest("Invalid phone number format");
  }

  // Rate limit by IP
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const { success: ipOk } = await otpSendRateLimit.limit(`ip:${ip}`);
  if (!ipOk) return res.tooManyRequests("Too many attempts. Please try again later.");

  const { success: phoneOk } = await otpSendRateLimit.limit(`phone:${phoneNumber}`);
  if (!phoneOk) return res.tooManyRequests("Too many codes sent. Please wait a few minutes.");

  try {
    await generateOtp(phoneNumber);
  } catch {
    return res.badRequest("Failed to send verification code");
  }

  return res.ok({ sent: true, phoneNumber });
});
