"use server";

import { db } from "@/db";
import { groups, groupMembers, members, users, expenses, expenseSplits } from "@/db/schema";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import { redirect } from "next/navigation";
import { requireAuth, requireGroupAccess, requireGroupOwner } from "@/lib/auth-helpers";

export async function createGroup(formData: FormData) {
  const { userId } = await requireAuth();
  const name = formData.get("name") as string;
  if (!name?.trim()) return;

  const id = randomUUID();
  const now = new Date();

  await db.insert(groups).values({
    id,
    name: name.trim(),
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
  await db.insert(members).values({ id: randomUUID(), groupId, name: name.trim() });
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

  const amountCents = Math.round(parseFloat(amountStr) * 100);
  if (isNaN(amountCents) || amountCents <= 0) return;

  const shareBase = Math.floor(amountCents / splitMemberIds.length);
  const remainder = amountCents - shareBase * splitMemberIds.length;

  const expenseId = randomUUID();

  await db.insert(expenses).values({
    id: expenseId,
    groupId,
    paidBy,
    amount: amountCents,
    description: description.trim(),
    createdAt: new Date(),
  });

  for (let i = 0; i < splitMemberIds.length; i++) {
    await db.insert(expenseSplits).values({
      id: randomUUID(),
      expenseId,
      memberId: splitMemberIds[i],
      share: shareBase + (i < remainder ? 1 : 0),
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
  await db.delete(members).where(eq(members.groupId, groupId));
  await db.delete(groupMembers).where(eq(groupMembers.groupId, groupId));
  await db.delete(groups).where(eq(groups.id, groupId));

  redirect("/");
}
