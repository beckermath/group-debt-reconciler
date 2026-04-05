import { NextRequest } from "next/server";
import * as res from "@/lib/api-response";
import { issueMobileToken } from "@/lib/mobile-jwt";
import { otpSendRateLimit } from "@/lib/rate-limit";
import { withErrorHandling } from "@/lib/api-handler";
import { db } from "@/db";
import { users } from "@/db/schema";
import { randomUUID } from "crypto";

export const POST = withErrorHandling(async (request: NextRequest) => {
  // Rate limit guest creation by IP
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const { success } = await otpSendRateLimit.limit(`guest:${ip}`);
  if (!success) return res.tooManyRequests("Too many attempts");

  const guestId = randomUUID();

  await db.insert(users).values({
    id: guestId,
    name: "Guest",
    isGuest: true,
  });

  const token = await issueMobileToken({
    userId: guestId,
    isGuest: true,
  });

  return res.created({
    token,
    user: {
      id: guestId,
      name: "Guest",
      phoneNumber: null,
      isGuest: true,
    },
  });
});
