"use server";

import { db } from "@/db";
import { groups, groupMembers, groupInvites, members, users, expenses, expenseSplits, settlements } from "@/db/schema";
import { eq, and, desc, inArray, sql } from "drizzle-orm";
import { randomUUID, randomInt } from "crypto";
import { redirect } from "next/navigation";
import { requireAuth, requireGroupAccess, requireGroupOwner } from "@/lib/auth-helpers";
import { computeSplits } from "@/lib/splits";

async function validateMembersInGroup(memberIds: string[], groupId: string) {
  if (memberIds.length === 0) return false;
  const found = await db
    .select({ id: members.id })
    .from(members)
    .where(and(inArray(members.id, memberIds), eq(members.groupId, groupId)));
  return found.length === memberIds.length;
}

export async function renameGroup(groupId: string, newName: string) {
  if (!groupId || !newName?.trim()) return;
  await requireGroupOwner(groupId);
  await db.update(groups).set({ name: newName.trim().slice(0, 100) }).where(eq(groups.id, groupId));
}

export async function createGroup(formData: FormData) {
  const { userId } = await requireAuth();
  const name = formData.get("name") as string;
  if (!name?.trim()) return;

  const id = randomUUID();
  const now = new Date();

  await db.insert(groups).values({
    id,
    name: name.trim().slice(0, 100),
    createdBy: userId,
    createdAt: now,
  });

  await db.insert(groupMembers).values({
    id: randomUUID(),
    groupId: id,
    userId,
    role: "owner",
    joinedAt: now,
  });

  // Add the user as a member (expense participant)
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  await db.insert(members).values({
    id: randomUUID(),
    groupId: id,
    name: user.name ?? user.email,
    userId,
  });

  redirect(`/group/${id}`);
}

export async function addMember(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const name = formData.get("name") as string;
  if (!name?.trim() || !groupId) return;

  await requireGroupAccess(groupId);
  await db.insert(members).values({ id: randomUUID(), groupId, name: name.trim().slice(0, 100) });
  redirect(`/group/${groupId}`);
}

export async function deleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await db.delete(expenseSplits).where(eq(expenseSplits.memberId, id));
  await db.delete(expenses).where(eq(expenses.paidBy, id));
  await db.delete(members).where(eq(members.id, id));
  redirect(`/group/${groupId}`);
}

export async function createExpense(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const paidBy = formData.get("paidBy") as string;
  const description = formData.get("description") as string;
  const amountStr = formData.get("amount") as string;
  const splitMemberIds = formData.getAll("splitWith") as string[];

  if (!groupId || !paidBy || !description?.trim() || !amountStr || splitMemberIds.length === 0) return;

  await requireGroupAccess(groupId);

  // Validate all member IDs belong to this group
  const allMemberIds = [paidBy, ...splitMemberIds.filter((id) => id !== paidBy)];
  if (!(await validateMembersInGroup(allMemberIds, groupId))) return;

  const amountCents = Math.round(parseFloat(amountStr) * 100);
  if (isNaN(amountCents) || amountCents <= 0) return;
  if (amountCents > 100_000_00) return; // $100,000 max

  const desc = description.trim().slice(0, 500);

  const splitMode = (formData.get("splitMode") as string) === "custom" ? "custom" : "equal";
  const customAmounts: Record<string, string> = {};
  for (const memberId of splitMemberIds) {
    customAmounts[memberId] = (formData.get(`splitAmount_${memberId}`) as string) ?? "";
  }

  const splits = computeSplits({ splitMode, memberIds: splitMemberIds, amountCents, customAmounts });
  if (splits.length === 0) return;

  const expenseId = randomUUID();

  await db.insert(expenses).values({
    id: expenseId,
    groupId,
    paidBy,
    amount: amountCents,
    description: desc,
    createdAt: new Date(),
  });

  for (const split of splits) {
    await db.insert(expenseSplits).values({
      id: randomUUID(),
      expenseId,
      memberId: split.memberId,
      share: split.share,
    });
  }

  redirect(`/group/${groupId}`);
}

export async function updateExpense(formData: FormData) {
  const expenseId = formData.get("expenseId") as string;
  const groupId = formData.get("groupId") as string;
  const paidBy = formData.get("paidBy") as string;
  const description = formData.get("description") as string;
  const amountStr = formData.get("amount") as string;
  const splitMemberIds = formData.getAll("splitWith") as string[];

  if (!expenseId || !groupId || !paidBy || !description?.trim() || !amountStr || splitMemberIds.length === 0) return;

  await requireGroupAccess(groupId);

  const allMemberIds = [paidBy, ...splitMemberIds.filter((id) => id !== paidBy)];
  if (!(await validateMembersInGroup(allMemberIds, groupId))) return;

  const amountCents = Math.round(parseFloat(amountStr) * 100);
  if (isNaN(amountCents) || amountCents <= 0) return;
  if (amountCents > 100_000_00) return;

  const desc = description.trim().slice(0, 500);

  const splitMode = (formData.get("splitMode") as string) === "custom" ? "custom" : "equal";
  const customAmounts: Record<string, string> = {};
  for (const memberId of splitMemberIds) {
    customAmounts[memberId] = (formData.get(`splitAmount_${memberId}`) as string) ?? "";
  }

  const splits = computeSplits({ splitMode, memberIds: splitMemberIds, amountCents, customAmounts });
  if (splits.length === 0) return;

  await db
    .update(expenses)
    .set({ paidBy, amount: amountCents, description: desc })
    .where(eq(expenses.id, expenseId));

  await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, expenseId));

  for (const split of splits) {
    await db.insert(expenseSplits).values({
      id: randomUUID(),
      expenseId,
      memberId: split.memberId,
      share: split.share,
    });
  }

  redirect(`/group/${groupId}`);
}

export async function softDeleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await db.update(members).set({ removedAt: new Date() }).where(eq(members.id, id));
  redirect(`/group/${groupId}`);
}

export async function restoreMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await db.update(members).set({ removedAt: null }).where(eq(members.id, id));
  redirect(`/group/${groupId}`);
}

export async function deleteExpense(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, id));
  await db.delete(expenses).where(eq(expenses.id, id));
  redirect(`/group/${groupId}`);
}

export async function deleteGroup(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return;

  await requireGroupOwner(groupId);

  // Manually clean up in order to avoid FK constraint issues
  // (expenseSplits.memberId has no cascade)
  const groupExpenses = await db.select().from(expenses).where(eq(expenses.groupId, groupId));
  for (const expense of groupExpenses) {
    await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, expense.id));
  }
  await db.delete(expenses).where(eq(expenses.groupId, groupId));
  await db.delete(settlements).where(eq(settlements.groupId, groupId));
  await db.delete(members).where(eq(members.groupId, groupId));
  await db.delete(groupMembers).where(eq(groupMembers.groupId, groupId));
  await db.delete(groups).where(eq(groups.id, groupId));

  redirect("/");
}

function generateInviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars[randomInt(chars.length)];
  }
  return code;
}

export async function createInviteLink(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return { error: "Missing group" };

  const { userId } = await requireGroupAccess(groupId);

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

export async function acceptInvite(code: string) {
  const { userId } = await requireAuth();

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
    redirect(`/group/${invite.groupId}`);
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
    );

  // Add to groupMembers (access control)
  await db.insert(groupMembers).values({
    id: randomUUID(),
    groupId: invite.groupId,
    userId,
    role: "member",
    joinedAt: new Date(),
  });

  // Add to members (expense participant)
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  await db.insert(members).values({
    id: randomUUID(),
    groupId: invite.groupId,
    name: user.name ?? user.email,
    userId,
  });

  redirect(`/group/${invite.groupId}`);
}

export async function settleUp(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return;

  const { userId } = await requireGroupOwner(groupId);

  await db.insert(settlements).values({
    id: randomUUID(),
    groupId,
    settledBy: userId,
    settledAt: new Date(),
  });

  redirect(`/group/${groupId}`);
}

export async function undoSettlement(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const settlementId = formData.get("settlementId") as string;
  if (!groupId || !settlementId) return;

  await requireGroupOwner(groupId);

  // Only allow undoing the most recent settlement
  const [latest] = await db
    .select()
    .from(settlements)
    .where(eq(settlements.groupId, groupId))
    .orderBy(desc(settlements.settledAt))
    .limit(1);

  if (!latest || latest.id !== settlementId) return;

  await db.delete(settlements).where(eq(settlements.id, settlementId));
  redirect(`/group/${groupId}`);
}
