import { NextRequest, NextResponse } from "next/server";
import { authenticateRequest, type ApiUser } from "./api-auth";
import { db } from "@/db";
import { groupMembers } from "@/db/schema";
import { and, eq } from "drizzle-orm";
import { mutationRateLimit } from "./rate-limit";
import * as res from "./api-response";

/**
 * Authenticate and return the user, or a 401 response.
 */
export async function withAuth(
  request: NextRequest
): Promise<{ user: ApiUser } | NextResponse> {
  const result = await authenticateRequest(request);
  if (result instanceof NextResponse) return result;
  return { user: result };
}

/**
 * Authenticate, rate-limit mutations, and return the user.
 */
export async function withAuthRateLimit(
  request: NextRequest
): Promise<{ user: ApiUser } | NextResponse> {
  const auth = await withAuth(request);
  if (auth instanceof NextResponse) return auth;

  const { success } = await mutationRateLimit.limit(auth.user.userId);
  if (!success) return res.tooManyRequests();

  return auth;
}

/**
 * Authenticate and verify the user has access to the group.
 */
export async function withGroupAccess(
  request: NextRequest,
  groupId: string
): Promise<{ user: ApiUser; role: string } | NextResponse> {
  const auth = await withAuthRateLimit(request);
  if (auth instanceof NextResponse) return auth;

  const [membership] = await db
    .select({ role: groupMembers.role })
    .from(groupMembers)
    .where(
      and(
        eq(groupMembers.groupId, groupId),
        eq(groupMembers.userId, auth.user.userId)
      )
    );

  if (!membership) return res.forbidden("Not a member of this group");

  return { user: auth.user, role: membership.role };
}

/**
 * Authenticate and verify the user is the group owner.
 */
export async function withGroupOwner(
  request: NextRequest,
  groupId: string
): Promise<{ user: ApiUser } | NextResponse> {
  const result = await withGroupAccess(request, groupId);
  if (result instanceof NextResponse) return result;

  if (result.role !== "owner") return res.forbidden("Owner access required");

  return { user: result.user };
}
