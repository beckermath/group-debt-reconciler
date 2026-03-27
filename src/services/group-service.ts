import { db } from "@/db";
import { groups, groupMembers, members, users, expenses, expenseSplits, settlements, groupInvites } from "@/db/schema";
import { eq, desc, and, gt, isNull } from "drizzle-orm";
import { randomUUID } from "crypto";
import { computeBalances } from "@/lib/balances";

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

export type GroupSummary = {
  id: string;
  name: string;
  createdAt: Date;
  memberCount: number;
  memberNames: string[];
  expenseCount: number;
  lastActivityAt: Date | null;
  userBalanceCents: number;
  status: "settled" | "has_balances" | "no_expenses";
};

export async function getUserGroupSummaries(userId: string): Promise<GroupSummary[]> {
  const userGroups = await db
    .select({ id: groups.id, name: groups.name, createdAt: groups.createdAt })
    .from(groups)
    .innerJoin(groupMembers, eq(groups.id, groupMembers.groupId))
    .where(eq(groupMembers.userId, userId));

  const summaries: GroupSummary[] = [];

  for (const group of userGroups) {
    // Get active members
    const groupMembersList = await db
      .select({ id: members.id, name: members.name, userId: members.userId })
      .from(members)
      .where(and(eq(members.groupId, group.id), isNull(members.removedAt)));

    // Get last settlement
    const [lastSettlement] = await db
      .select({ settledAt: settlements.settledAt })
      .from(settlements)
      .where(eq(settlements.groupId, group.id))
      .orderBy(desc(settlements.settledAt))
      .limit(1);

    // Get current expenses (after last settlement)
    const currentExpenses = lastSettlement
      ? await db
          .select()
          .from(expenses)
          .where(and(eq(expenses.groupId, group.id), gt(expenses.createdAt, lastSettlement.settledAt)))
          .orderBy(desc(expenses.createdAt))
      : await db
          .select()
          .from(expenses)
          .where(eq(expenses.groupId, group.id))
          .orderBy(desc(expenses.createdAt));

    // Get splits for current expenses
    const expensesWithSplits = await Promise.all(
      currentExpenses.map(async (expense) => {
        const splits = await db
          .select()
          .from(expenseSplits)
          .where(eq(expenseSplits.expenseId, expense.id));
        return { ...expense, splits };
      })
    );

    // Compute balances
    const balances = computeBalances(
      expensesWithSplits,
      groupMembersList.map((m) => m.id)
    );

    // Find user's member ID and balance
    const userMember = groupMembersList.find((m) => m.userId === userId);
    const userBalanceCents = userMember ? (balances.get(userMember.id) ?? 0) : 0;

    // Determine status
    const hasAnyBalance = Array.from(balances.values()).some((b) => b !== 0);
    const status: GroupSummary["status"] = currentExpenses.length === 0
      ? "no_expenses"
      : hasAnyBalance
        ? "has_balances"
        : "settled";

    // Last activity
    const lastActivityAt = currentExpenses[0]?.createdAt
      ?? lastSettlement?.settledAt
      ?? null;

    summaries.push({
      id: group.id,
      name: group.name,
      createdAt: group.createdAt,
      memberCount: groupMembersList.length,
      memberNames: groupMembersList.slice(0, 4).map((m) => m.name),
      expenseCount: currentExpenses.length,
      lastActivityAt,
      userBalanceCents,
      status,
    });
  }

  // Sort by last activity (most recent first), fallback to createdAt
  summaries.sort((a, b) => {
    const aTime = a.lastActivityAt?.getTime() ?? a.createdAt.getTime();
    const bTime = b.lastActivityAt?.getTime() ?? b.createdAt.getTime();
    return bTime - aTime;
  });

  return summaries;
}
