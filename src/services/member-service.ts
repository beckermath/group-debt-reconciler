import { db } from "@/db";
import { members, memberIdentities, expenses, expenseSplits, groupMembers } from "@/db/schema";
import { eq, and, inArray, isNull, or } from "drizzle-orm";
import { randomUUID } from "crypto";
import { linkIdentity, type ExternalIdentity } from "./identity-service";

export interface AddMemberOptions {
  phone?: string;
  email?: string;
  discordId?: string;
  slackId?: string;
}

export async function addMember(groupId: string, name: string, options?: AddMemberOptions) {
  const id = randomUUID();
  await db.insert(members).values({
    id,
    groupId,
    name: name.trim().slice(0, 100),
  });

  if (options) {
    const identities: ExternalIdentity[] = [];
    if (options.phone) identities.push({ provider: "phone", providerIdentity: options.phone });
    if (options.email) identities.push({ provider: "email", providerIdentity: options.email });
    if (options.discordId) identities.push({ provider: "discord", providerIdentity: options.discordId });
    if (options.slackId) identities.push({ provider: "slack", providerIdentity: options.slackId });

    for (const identity of identities) {
      await linkIdentity(id, identity);
    }
  }

  return { memberId: id };
}

/**
 * Check if a member has any expense involvement (paid for or split on).
 */
async function hasExpenseInvolvement(memberId: string): Promise<boolean> {
  const [paidExpense] = await db
    .select({ id: expenses.id })
    .from(expenses)
    .where(eq(expenses.paidBy, memberId))
    .limit(1);
  if (paidExpense) return true;

  const [splitRow] = await db
    .select({ id: expenseSplits.id })
    .from(expenseSplits)
    .where(eq(expenseSplits.memberId, memberId))
    .limit(1);
  return !!splitRow;
}

/**
 * Hard-delete a member and all their expense data.
 * Blocked if the member has any expense involvement (use soft-delete instead).
 */
export async function deleteMember(memberId: string, groupId: string) {
  const [member] = await db
    .select({ groupId: members.groupId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== groupId) return { error: "Member not found in group" };

  if (await hasExpenseInvolvement(memberId)) {
    return { error: "Cannot permanently delete a member with expense history. Remove them instead." };
  }

  // Wrap in a conceptual transaction — delete in safe order
  try {
    await db.delete(memberIdentities).where(eq(memberIdentities.memberId, memberId));
  } catch {
    // member_identities table may not exist yet
  }
  await db.delete(members).where(eq(members.id, memberId));
  return {};
}

/**
 * Soft-delete a member (set removedAt). Also revokes group access if linked to a user.
 */
export async function softDeleteMember(memberId: string, groupId: string) {
  const [member] = await db
    .select({ groupId: members.groupId, userId: members.userId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== groupId) return { error: "Member not found in group" };

  await db.update(members).set({ removedAt: new Date() }).where(eq(members.id, memberId));

  // Revoke group access for linked users (prevents removed members from seeing the group)
  if (member.userId) {
    await db
      .delete(groupMembers)
      .where(and(eq(groupMembers.groupId, groupId), eq(groupMembers.userId, member.userId)));
  }

  return {};
}

export async function restoreMember(memberId: string, groupId: string) {
  const [member] = await db
    .select({ groupId: members.groupId, userId: members.userId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== groupId) return { error: "Member not found in group" };

  await db.update(members).set({ removedAt: null }).where(eq(members.id, memberId));

  // Re-grant group access for linked users
  if (member.userId) {
    const [existing] = await db
      .select()
      .from(groupMembers)
      .where(and(eq(groupMembers.groupId, groupId), eq(groupMembers.userId, member.userId)));
    if (!existing) {
      await db.insert(groupMembers).values({
        id: randomUUID(),
        groupId,
        userId: member.userId,
        role: "member",
        joinedAt: new Date(),
      });
    }
  }

  return {};
}

/**
 * Validate that member IDs belong to the group AND are not removed.
 */
export async function validateMembersInGroup(memberIds: string[], groupId: string) {
  if (memberIds.length === 0) return false;
  const found = await db
    .select({ id: members.id })
    .from(members)
    .where(
      and(
        inArray(members.id, memberIds),
        eq(members.groupId, groupId),
        isNull(members.removedAt)
      )
    );
  return found.length === memberIds.length;
}

export async function getGroupMembers(groupId: string) {
  return db.select().from(members).where(eq(members.groupId, groupId));
}
