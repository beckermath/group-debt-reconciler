import { db } from "@/db";
import { members, expenses, expenseSplits } from "@/db/schema";
import { eq, and, inArray } from "drizzle-orm";
import { randomUUID } from "crypto";

export async function addMember(groupId: string, name: string) {
  const id = randomUUID();
  await db.insert(members).values({
    id,
    groupId,
    name: name.trim().slice(0, 100),
  });
  return { memberId: id };
}

export async function deleteMember(memberId: string, groupId: string) {
  const [member] = await db
    .select({ groupId: members.groupId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== groupId) return { error: "Member not found in group" };

  await db.delete(expenseSplits).where(eq(expenseSplits.memberId, memberId));
  await db.delete(expenses).where(eq(expenses.paidBy, memberId));
  await db.delete(members).where(eq(members.id, memberId));
  return {};
}

export async function softDeleteMember(memberId: string, groupId: string) {
  const [member] = await db
    .select({ groupId: members.groupId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== groupId) return { error: "Member not found in group" };

  await db.update(members).set({ removedAt: new Date() }).where(eq(members.id, memberId));
  return {};
}

export async function restoreMember(memberId: string, groupId: string) {
  const [member] = await db
    .select({ groupId: members.groupId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== groupId) return { error: "Member not found in group" };

  await db.update(members).set({ removedAt: null }).where(eq(members.id, memberId));
  return {};
}

export async function validateMembersInGroup(memberIds: string[], groupId: string) {
  if (memberIds.length === 0) return false;
  const found = await db
    .select({ id: members.id })
    .from(members)
    .where(and(inArray(members.id, memberIds), eq(members.groupId, groupId)));
  return found.length === memberIds.length;
}

export async function getGroupMembers(groupId: string) {
  return db.select().from(members).where(eq(members.groupId, groupId));
}
