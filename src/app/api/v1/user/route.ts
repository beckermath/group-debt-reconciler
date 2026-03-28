import { NextRequest } from "next/server";
import { withAuth, withAuthRateLimit } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as userService from "@/services/user-service";
import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { withErrorHandling } from "@/lib/api-handler";

export const GET = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const [user] = await db
    .select({ id: users.id, name: users.name, phoneNumber: users.phoneNumber, email: users.email })
    .from(users)
    .where(eq(users.id, auth.user.userId));

  if (!user) return res.notFound("User not found");
  return res.ok(user);
});

export const PATCH = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body?.name?.trim()) return res.badRequest("Name is required");

  const result = await userService.updateProfile(auth.user.userId, body.name);
  if ("error" in result) return res.badRequest(result.error);
  return res.ok(result);
});

export const DELETE = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  await userService.deleteAccount(auth.user.userId);
  return res.noContent();
});
