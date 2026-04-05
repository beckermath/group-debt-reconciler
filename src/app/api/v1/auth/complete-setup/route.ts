import { NextRequest } from "next/server";
import * as res from "@/lib/api-response";
import { issueMobileToken } from "@/lib/mobile-jwt";
import { withErrorHandling } from "@/lib/api-handler";
import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";

export const POST = withErrorHandling(async (request: NextRequest) => {
  const body = await request.json().catch(() => null);
  const name = body?.name?.trim();
  const phoneNumber = body?.phoneNumber?.trim();

  if (!name || name.length < 1) return res.badRequest("Name is required");
  if (name.length > 100) return res.badRequest("Name must be 100 characters or fewer");
  if (!phoneNumber) return res.badRequest("Phone number is required");

  // Check if user already exists with this phone
  const [existing] = await db
    .select()
    .from(users)
    .where(eq(users.phoneNumber, phoneNumber));

  if (existing) {
    // User created between verify and setup — just issue token
    const token = await issueMobileToken({
      userId: existing.id,
      isGuest: !!existing.isGuest,
    });
    return res.ok({
      token,
      user: {
        id: existing.id,
        name: existing.name,
        phoneNumber,
        isGuest: !!existing.isGuest,
      },
    });
  }

  // Create new user
  const userId = randomUUID();
  await db.insert(users).values({
    id: userId,
    name,
    phoneNumber,
  });

  const token = await issueMobileToken({
    userId,
    isGuest: false,
  });

  return res.created({
    token,
    user: {
      id: userId,
      name,
      phoneNumber,
      isGuest: false,
    },
  });
});
