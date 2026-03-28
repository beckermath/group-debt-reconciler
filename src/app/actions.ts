"use server";

import { redirect } from "next/navigation";
import { signIn } from "@/lib/auth";
import { requireAuthWithRateLimit, requireGroupAccess, requireGroupOwner } from "@/lib/auth-helpers";
import { inviteRateLimit, searchRateLimit, directInviteRateLimit } from "@/lib/rate-limit";
import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import * as groupService from "@/services/group-service";
import * as memberService from "@/services/member-service";
import * as expenseService from "@/services/expense-service";
import * as settlementService from "@/services/settlement-service";
import * as inviteService from "@/services/invite-service";
import * as directInviteService from "@/services/direct-invite-service";
import * as userSearchService from "@/services/user-search-service";
import type { SplitMode } from "@/lib/splits";

// --- Dev-only account switcher ---

export async function devSwitchUser(phoneNumber: string): Promise<{ error?: string }> {
  if (process.env.NODE_ENV === "production") return { error: "Not available" };
  if (!phoneNumber) return { error: "Phone number required" };

  const [user] = await db
    .select({ id: users.id, phoneNumber: users.phoneNumber })
    .from(users)
    .where(eq(users.phoneNumber, phoneNumber));

  if (!user || !user.phoneNumber) return { error: "User not found. Run npm run seed first." };

  try {
    await signIn("credentials", {
      phoneNumber: user.phoneNumber,
      userId: user.id,
      redirect: false,
    });
  } catch (error) {
    if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) {
      // Expected — credentials provider may throw redirect even with redirect:false
    } else {
      return { error: "Sign in failed" };
    }
  }

  return {};
}

export async function renameGroup(groupId: string, newName: string) {
  if (!groupId || !newName?.trim()) return;
  try {
    await requireGroupOwner(groupId);
    await groupService.renameGroup(groupId, newName);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { error: "Something went wrong" };
  }
}

export async function createGroup(formData: FormData) {
  const name = (formData.get("name") as string)?.trim() || "New Group";
  try {
    const { userId } = await requireAuthWithRateLimit();
    const { groupId } = await groupService.createGroup(userId, name);
    redirect(`/group/${groupId}/setup`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function addMembersInBatch(groupId: string, names: string[]) {
  if (!groupId || names.length === 0) return;
  try {
    await requireGroupAccess(groupId);
    const validNames = names
      .map((n) => n.trim())
      .filter((n) => n.length > 0);
    for (const name of validNames) {
      await memberService.addMember(groupId, name);
    }
    redirect(`/group/${groupId}`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function addMemberQuiet(groupId: string, name: string): Promise<{ error?: string }> {
  if (!name?.trim() || !groupId) return { error: "Name is required" };
  try {
    await requireGroupAccess(groupId);
    await memberService.addMember(groupId, name);
    return {};
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { error: "Failed to add member" };
  }
}

export async function deleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;
  try {
    await requireGroupAccess(groupId);
    await memberService.deleteMember(id, groupId);
    redirect(`/group/${groupId}?tab=members`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function createExpense(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const paidBy = formData.get("paidBy") as string;
  const description = formData.get("description") as string;
  const amountStr = formData.get("amount") as string;
  const splitMemberIds = formData.getAll("splitWith") as string[];

  if (!groupId || !paidBy || !description?.trim() || !amountStr || splitMemberIds.length === 0) return;
  try {
    await requireGroupAccess(groupId);

    const amountCents = Math.round(parseFloat(amountStr) * 100);
    const splitMode: SplitMode = (formData.get("splitMode") as string) === "custom" ? "custom" : "equal";
    const customAmounts: Record<string, string> = {};
    for (const memberId of splitMemberIds) {
      customAmounts[memberId] = (formData.get(`splitAmount_${memberId}`) as string) ?? "";
    }

    await expenseService.createExpense({
      groupId,
      paidBy,
      description,
      amountCents,
      splitMemberIds,
      splitMode,
      customAmounts,
    });

    redirect(`/group/${groupId}`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function updateExpense(formData: FormData) {
  const expenseId = formData.get("expenseId") as string;
  const groupId = formData.get("groupId") as string;
  const paidBy = formData.get("paidBy") as string;
  const description = formData.get("description") as string;
  const amountStr = formData.get("amount") as string;
  const splitMemberIds = formData.getAll("splitWith") as string[];

  if (!expenseId || !groupId || !paidBy || !description?.trim() || !amountStr || splitMemberIds.length === 0) return;
  try {
    await requireGroupAccess(groupId);

    const amountCents = Math.round(parseFloat(amountStr) * 100);
    const splitMode: SplitMode = (formData.get("splitMode") as string) === "custom" ? "custom" : "equal";
    const customAmounts: Record<string, string> = {};
    for (const memberId of splitMemberIds) {
      customAmounts[memberId] = (formData.get(`splitAmount_${memberId}`) as string) ?? "";
    }

    await expenseService.updateExpense({
      expenseId,
      groupId,
      paidBy,
      description,
      amountCents,
      splitMemberIds,
      splitMode,
      customAmounts,
    });

    redirect(`/group/${groupId}`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function softDeleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;
  try {
    await requireGroupAccess(groupId);
    await memberService.softDeleteMember(id, groupId);
    redirect(`/group/${groupId}?tab=members`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function restoreMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;
  try {
    await requireGroupAccess(groupId);
    await memberService.restoreMember(id, groupId);
    redirect(`/group/${groupId}?tab=members`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function deleteExpense(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;
  try {
    await requireGroupAccess(groupId);
    await expenseService.deleteExpense(id, groupId);
    redirect(`/group/${groupId}`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function deleteGroup(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return;
  try {
    await requireGroupOwner(groupId);
    await groupService.deleteGroup(groupId);
    redirect("/");
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function createInviteLink(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return { error: "Missing group" };
  try {
    const { userId } = await requireGroupAccess(groupId);
    return await inviteService.createInviteLink(groupId, userId);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { error: "Something went wrong" };
  }
}

export async function acceptInvite(code: string) {
  try {
    const { userId } = await requireAuthWithRateLimit();

    const { success } = await inviteRateLimit.limit(userId);
    if (!success) {
      return { error: "Too many invite attempts. Please try again later." };
    }

    const result = await inviteService.acceptInvite(code, userId);

    if ("error" in result) return result;
    if ("alreadyMember" in result) redirect(`/group/${result.groupId}`);
    redirect(`/group/${result.groupId}`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function settleUp(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return;
  try {
    const { userId } = await requireGroupOwner(groupId);
    await settlementService.settleUp(groupId, userId);
    redirect(`/group/${groupId}?tab=history`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function undoSettlement(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const settlementId = formData.get("settlementId") as string;
  if (!groupId || !settlementId) return;
  try {
    await requireGroupOwner(groupId);
    await settlementService.undoSettlement(settlementId, groupId);
    redirect(`/group/${groupId}?tab=history`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

// --- Direct invite actions ---

export async function searchUsers(query: string, groupId: string) {
  try {
    const { userId } = await requireGroupAccess(groupId);
    const { success } = await searchRateLimit.limit(userId);
    if (!success) return { error: "Too many searches. Please slow down.", results: [] };
    const results = await userSearchService.searchUsers(query, userId, groupId);
    return { results };
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { error: "Something went wrong", results: [] };
  }
}

export async function sendDirectInvite(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const targetUserId = formData.get("userId") as string;
  if (!groupId || !targetUserId) return { error: "Missing fields" };
  try {
    const { userId } = await requireGroupAccess(groupId);
    const { success } = await directInviteRateLimit.limit(userId);
    if (!success) return { error: "Too many invites. Please try again later." };
    return await directInviteService.sendDirectInvite(groupId, userId, targetUserId);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { error: "Something went wrong" };
  }
}

export async function acceptDirectInvite(formData: FormData) {
  const inviteId = formData.get("inviteId") as string;
  if (!inviteId) return;
  try {
    const { userId } = await requireAuthWithRateLimit();
    const result = await directInviteService.acceptDirectInvite(inviteId, userId);
    if (result.groupId) redirect(`/group/${result.groupId}`);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}

export async function declineDirectInvite(formData: FormData) {
  const inviteId = formData.get("inviteId") as string;
  if (!inviteId) return;
  try {
    const { userId } = await requireAuthWithRateLimit();
    await directInviteService.declineDirectInvite(inviteId, userId);
    redirect("/");
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    console.error(error);
  }
}
