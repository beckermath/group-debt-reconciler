"use server";

import { db } from "@/db";
import { users, groupMembers, members, groups, expenses, expenseSplits, settlements, groupInvites } from "@/db/schema";
import { eq, and } from "drizzle-orm";
import { requireAuth } from "@/lib/auth-helpers";
import { signOut } from "@/lib/auth";
import { redirect } from "next/navigation";

export async function updateProfile(prevState: unknown, formData: FormData) {
  const { userId } = await requireAuth();
  const name = (formData.get("name") as string)?.trim();

  if (!name) {
    return { error: "Name is required" };
  }

  await db
    .update(users)
    .set({ name: name.slice(0, 100) })
    .where(eq(users.id, userId));

  return { success: "Profile updated" };
}

export async function deleteAccount(formData: FormData) {
  const { userId } = await requireAuth();
  const confirmation = formData.get("confirmation") as string;

  if (confirmation !== "DELETE") return;

  // Find all groups owned by this user
  const ownedGroups = await db
    .select({ groupId: groupMembers.groupId })
    .from(groupMembers)
    .where(eq(groupMembers.userId, userId));

  // For each group, clean up if this user is the only member
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
      // Other members exist — just remove this user from this group
      await db.delete(groupMembers).where(
        and(eq(groupMembers.groupId, groupId), eq(groupMembers.userId, userId))
      );
      await db.delete(members).where(
        and(eq(members.groupId, groupId), eq(members.userId, userId))
      );
    }
  }

  // Delete the user account
  await db.delete(users).where(eq(users.id, userId));

  await signOut({ redirect: false });
  redirect("/login");
}
