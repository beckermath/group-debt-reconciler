import { db } from "@/db";
import { groupInvites, groupMembers, members, users } from "@/db/schema";
import { eq, and, sql } from "drizzle-orm";
import { randomUUID, randomInt } from "crypto";

function generateInviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars[randomInt(chars.length)];
  }
  return code;
}

export async function createInviteLink(groupId: string, userId: string) {
  const code = generateInviteCode();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

  await db.insert(groupInvites).values({
    id: randomUUID(),
    groupId,
    code,
    createdBy: userId,
    createdAt: new Date(),
    expiresAt,
  });

  return { code };
}

export async function acceptInvite(code: string, userId: string) {
  const [invite] = await db
    .select()
    .from(groupInvites)
    .where(eq(groupInvites.code, code));

  if (!invite) return { error: "Invalid invite link" };

  if (invite.expiresAt && invite.expiresAt < new Date()) {
    return { error: "This invite has expired" };
  }

  if (invite.maxUses && invite.useCount >= invite.maxUses) {
    return { error: "This invite has reached its maximum uses" };
  }

  // Check if already a member
  const [existing] = await db
    .select()
    .from(groupMembers)
    .where(
      and(
        eq(groupMembers.groupId, invite.groupId),
        eq(groupMembers.userId, userId)
      )
    );

  if (existing) {
    return { alreadyMember: true, groupId: invite.groupId };
  }

  // Atomic increment — prevents race condition with maxUses
  const updated = await db
    .update(groupInvites)
    .set({ useCount: sql`${groupInvites.useCount} + 1` })
    .where(
      and(
        eq(groupInvites.id, invite.id),
        invite.maxUses
          ? sql`${groupInvites.useCount} < ${invite.maxUses}`
          : undefined
      )
    )
    .returning({ id: groupInvites.id });

  if (updated.length === 0) {
    return { error: "This invite has reached its maximum uses" };
  }

  await addUserToGroup(invite.groupId, userId);
  return { groupId: invite.groupId };
}

/**
 * Add a user to a group's membership and expense participants.
 * Shared by link-based invites and direct invites.
 */
export async function addUserToGroup(groupId: string, userId: string) {
  await db.insert(groupMembers).values({
    id: randomUUID(),
    groupId,
    userId,
    role: "member",
    joinedAt: new Date(),
  });

  const [user] = await db.select().from(users).where(eq(users.id, userId));
  await db.insert(members).values({
    id: randomUUID(),
    groupId,
    name: user.name ?? user.phoneNumber ?? "Unknown",
    userId,
  });
}
