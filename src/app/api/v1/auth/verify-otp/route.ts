import { NextRequest } from "next/server";
import * as res from "@/lib/api-response";
import { verifyOtp } from "@/services/otp-service";
import { issueMobileToken } from "@/lib/mobile-jwt";
import { otpVerifyRateLimit } from "@/lib/rate-limit";
import { withErrorHandling } from "@/lib/api-handler";
import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";

export const POST = withErrorHandling(async (request: NextRequest) => {
  const body = await request.json().catch(() => null);
  const phoneNumber = body?.phoneNumber?.trim();
  const code = body?.code?.trim();

  if (!phoneNumber || !code) {
    return res.badRequest("Phone number and code are required");
  }

  // Rate limit
  const { success } = await otpVerifyRateLimit.limit(`verify:${phoneNumber}`);
  if (!success) return res.tooManyRequests("Too many attempts. Please request a new code.");

  const result = await verifyOtp(phoneNumber, code);

  if (!result.valid) {
    return res.badRequest(result.error);
  }

  if (result.isNewUser) {
    // Issue a temporary token for the setup step
    // The user doesn't exist yet — create a placeholder token with the phone
    return res.ok({
      isNewUser: true,
      phoneNumber,
      // No token yet — client must call /complete-setup
    });
  }

  // Existing user — issue token
  const [user] = await db
    .select({ id: users.id, name: users.name, isGuest: users.isGuest })
    .from(users)
    .where(eq(users.id, result.userId!));

  if (!user) return res.badRequest("User not found");

  const token = await issueMobileToken({
    userId: user.id,
    isGuest: !!user.isGuest,
  });

  return res.ok({
    isNewUser: false,
    token,
    user: {
      id: user.id,
      name: user.name,
      phoneNumber,
      isGuest: !!user.isGuest,
    },
  });
});
