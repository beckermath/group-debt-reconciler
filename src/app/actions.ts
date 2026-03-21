"use server";

import { db } from "@/db";
import { groups, members, expenses, expenseSplits } from "@/db/schema";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import { redirect } from "next/navigation";

export async function createGroup(formData: FormData) {
  const name = formData.get("name") as string;
  if (!name?.trim()) return;

  const id = randomUUID();
  db.insert(groups).values({ id, name: name.trim(), createdAt: new Date() }).run();
  redirect(`/group/${id}`);
}

export async function addMember(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const name = formData.get("name") as string;
  if (!name?.trim() || !groupId) return;

  db.insert(members)
    .values({ id: randomUUID(), groupId, name: name.trim() })
    .run();
  redirect(`/group/${groupId}`);
}

export async function deleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  db.delete(members).where(eq(members.id, id)).run();
  redirect(`/group/${groupId}`);
}

export async function createExpense(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const paidBy = formData.get("paidBy") as string;
  const description = formData.get("description") as string;
  const amountStr = formData.get("amount") as string;
  const splitMemberIds = formData.getAll("splitWith") as string[];

  if (!groupId || !paidBy || !description?.trim() || !amountStr || splitMemberIds.length === 0) return;

  const amountCents = Math.round(parseFloat(amountStr) * 100);
  if (isNaN(amountCents) || amountCents <= 0) return;

  // Equal split: divide evenly, assign remainder to first members
  const shareBase = Math.floor(amountCents / splitMemberIds.length);
  const remainder = amountCents - shareBase * splitMemberIds.length;

  const expenseId = randomUUID();

  db.insert(expenses)
    .values({
      id: expenseId,
      groupId,
      paidBy,
      amount: amountCents,
      description: description.trim(),
      createdAt: new Date(),
    })
    .run();

  for (let i = 0; i < splitMemberIds.length; i++) {
    db.insert(expenseSplits)
      .values({
        id: randomUUID(),
        expenseId,
        memberId: splitMemberIds[i],
        share: shareBase + (i < remainder ? 1 : 0),
      })
      .run();
  }

  redirect(`/group/${groupId}`);
}

export async function deleteExpense(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  db.delete(expenseSplits).where(eq(expenseSplits.expenseId, id)).run();
  db.delete(expenses).where(eq(expenses.id, id)).run();
  redirect(`/group/${groupId}`);
}
