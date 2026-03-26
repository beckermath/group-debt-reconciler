import { db } from "@/db";
import { users, groupMembers, members, groups, expenses, expenseSplits, settlements, groupInvites } from "@/db/schema";
import { eq, and } from "drizzle-orm";

export async function updateProfile(userId: string, name: string) {
  if (!name?.trim()) return { error: "Name is required" };

  await db
    .update(users)
    .set({ name: name.trim().slice(0, 100) })
    .where(eq(users.id, userId));

  return { success: "Profile updated" };
}

export async function deleteAccount(userId: string) {
  const ownedGroups = await db
    .select({ groupId: groupMembers.groupId })
    .from(groupMembers)
    .where(eq(groupMembers.userId, userId));

  for (const { groupId } of ownedGroups) {
    const groupMemberCount = await db
      .select({ id: groupMembers.id })
      .from(groupMembers)
      .where(eq(groupMembers.groupId, groupId));

    if (groupMemberCount.length <= 1) {
      // Only member — delete the entire group
      const groupExpenses = await db.select().from(expenses).where(eq(expenses.groupId, groupId));
      for (const expense of groupExpenses) {
        await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, expense.id));
      }
      await db.delete(expenses).where(eq(expenses.groupId, groupId));
      await db.delete(settlements).where(eq(settlements.groupId, groupId));
      await db.delete(members).where(eq(members.groupId, groupId));
      await db.delete(groupInvites).where(eq(groupInvites.groupId, groupId));
      await db.delete(groupMembers).where(eq(groupMembers.groupId, groupId));
      await db.delete(groups).where(eq(groups.id, groupId));
    } else {
      await db.delete(groupMembers).where(
        and(eq(groupMembers.groupId, groupId), eq(groupMembers.userId, userId))
      );
      await db.delete(members).where(
        and(eq(members.groupId, groupId), eq(members.userId, userId))
      );
    }
  }

  await db.delete(users).where(eq(users.id, userId));
}
