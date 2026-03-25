import { auth } from "@/lib/auth";
import { db } from "@/db";
import { groupMembers } from "@/db/schema";
import { and, eq } from "drizzle-orm";

export async function requireAuth() {
  const session = await auth();
  const userId = session?.user?.id;
  if (!userId) {
    throw new Error("Unauthorized");
  }
  return { session, userId };
}

export async function requireGroupAccess(groupId: string) {
  const { session, userId } = await requireAuth();
  const [membership] = await db
    .select()
    .from(groupMembers)
    .where(
      and(
        eq(groupMembers.groupId, groupId),
        eq(groupMembers.userId, userId)
      )
    );

  if (!membership) {
    throw new Error("Forbidden");
  }

  return { session, userId, membership };
}

export async function requireGroupOwner(groupId: string) {
  const result = await requireGroupAccess(groupId);
  if (result.membership.role !== "owner") {
    throw new Error("Forbidden: owner required");
  }
  return result;
}
