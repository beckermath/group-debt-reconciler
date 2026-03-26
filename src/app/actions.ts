"use server";

import { redirect } from "next/navigation";
import { requireAuthWithRateLimit, requireGroupAccess, requireGroupOwner } from "@/lib/auth-helpers";
import { inviteRateLimit } from "@/lib/rate-limit";
import * as groupService from "@/services/group-service";
import * as memberService from "@/services/member-service";
import * as expenseService from "@/services/expense-service";
import * as settlementService from "@/services/settlement-service";
import * as inviteService from "@/services/invite-service";
import type { SplitMode } from "@/lib/splits";

export async function renameGroup(groupId: string, newName: string) {
  if (!groupId || !newName?.trim()) return;
  await requireGroupOwner(groupId);
  await groupService.renameGroup(groupId, newName);
}

export async function createGroup(formData: FormData) {
  const { userId } = await requireAuthWithRateLimit();
  const name = formData.get("name") as string;
  if (!name?.trim()) return;

  const { groupId } = await groupService.createGroup(userId, name);
  redirect(`/group/${groupId}`);
}

export async function addMember(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const name = formData.get("name") as string;
  if (!name?.trim() || !groupId) return;

  await requireGroupAccess(groupId);
  await memberService.addMember(groupId, name);
  redirect(`/group/${groupId}`);
}

export async function deleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await memberService.deleteMember(id, groupId);
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
}

export async function softDeleteMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await memberService.softDeleteMember(id, groupId);
  redirect(`/group/${groupId}`);
}

export async function restoreMember(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await memberService.restoreMember(id, groupId);
  redirect(`/group/${groupId}`);
}

export async function deleteExpense(formData: FormData) {
  const id = formData.get("id") as string;
  const groupId = formData.get("groupId") as string;
  if (!id || !groupId) return;

  await requireGroupAccess(groupId);
  await expenseService.deleteExpense(id, groupId);
  redirect(`/group/${groupId}`);
}

export async function deleteGroup(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return;

  await requireGroupOwner(groupId);
  await groupService.deleteGroup(groupId);
  redirect("/");
}

export async function createInviteLink(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return { error: "Missing group" };

  const { userId } = await requireGroupAccess(groupId);
  return inviteService.createInviteLink(groupId, userId);
}

export async function acceptInvite(code: string) {
  const { userId } = await requireAuthWithRateLimit();

  const { success } = await inviteRateLimit.limit(userId);
  if (!success) {
    return { error: "Too many invite attempts. Please try again later." };
  }

  const result = await inviteService.acceptInvite(code, userId);

  if ("error" in result) return result;
  if ("alreadyMember" in result) redirect(`/group/${result.groupId}`);
  redirect(`/group/${result.groupId}`);
}

export async function settleUp(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  if (!groupId) return;

  const { userId } = await requireGroupOwner(groupId);
  await settlementService.settleUp(groupId, userId);
  redirect(`/group/${groupId}`);
}

export async function undoSettlement(formData: FormData) {
  const groupId = formData.get("groupId") as string;
  const settlementId = formData.get("settlementId") as string;
  if (!groupId || !settlementId) return;

  await requireGroupOwner(groupId);
  await settlementService.undoSettlement(settlementId, groupId);
  redirect(`/group/${groupId}`);
}
