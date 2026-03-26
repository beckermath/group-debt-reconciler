import { db } from "@/db";
import { groups, groupMembers, members, users, expenses, expenseSplits, settlements, groupInvites } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { randomUUID } from "crypto";

export async function createGroup(userId: string, name: string) {
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

  const [user] = await db.select().from(users).where(eq(users.id, userId));
  await db.insert(members).values({
    id: randomUUID(),
    groupId: id,
    name: user.name ?? user.email,
    userId,
  });

  return { groupId: id };
}

export async function renameGroup(groupId: string, newName: string) {
  await db
    .update(groups)
    .set({ name: newName.trim().slice(0, 100) })
    .where(eq(groups.id, groupId));
}

export async function deleteGroup(groupId: string) {
  const groupExpenses = await db
    .select()
    .from(expenses)
    .where(eq(expenses.groupId, groupId));

  for (const expense of groupExpenses) {
    await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, expense.id));
  }

  await db.delete(expenses).where(eq(expenses.groupId, groupId));
  await db.delete(settlements).where(eq(settlements.groupId, groupId));
  await db.delete(members).where(eq(members.groupId, groupId));
  await db.delete(groupInvites).where(eq(groupInvites.groupId, groupId));
  await db.delete(groupMembers).where(eq(groupMembers.groupId, groupId));
  await db.delete(groups).where(eq(groups.id, groupId));
}

export async function getUserGroups(userId: string) {
  return db
    .select({ id: groups.id, name: groups.name, createdAt: groups.createdAt })
    .from(groups)
    .innerJoin(groupMembers, eq(groups.id, groupMembers.groupId))
    .where(eq(groupMembers.userId, userId))
    .orderBy(desc(groups.createdAt));
}

export async function getGroup(groupId: string) {
  const [group] = await db.select().from(groups).where(eq(groups.id, groupId));
  return group ?? null;
}
