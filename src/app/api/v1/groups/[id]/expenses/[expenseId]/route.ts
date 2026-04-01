import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as expenseService from "@/services/expense-service";
import * as memberService from "@/services/member-service";
import { withErrorHandling } from "@/lib/api-handler";

export const PATCH = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string; expenseId: string }> }
) => {
  const { id, expenseId } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  // Owner can edit any expense; members can only edit their own
  if (auth.role !== "owner") {
    const expense = await expenseService.getExpense(expenseId, id);
    if (!expense) return res.notFound("Expense not found");
    const allMembers = await memberService.getGroupMembers(id);
    const userMember = allMembers.find((m) => m.userId === auth.user.userId);
    if (!userMember || expense.paidBy !== userMember.id) {
      return res.forbidden("You can only edit expenses you paid for");
    }
  }

  const body = await request.json().catch(() => null);
  if (!body) return res.badRequest("Invalid request body");

  const amountCents = Math.round((body.amount ?? 0) * 100);
  if (!Number.isFinite(amountCents) || amountCents <= 0) return res.badRequest("Invalid amount");

  const result = await expenseService.updateExpense({
    expenseId,
    groupId: id,
    paidBy: body.paidBy,
    description: (body.description ?? "").slice(0, 500),
    amountCents,
    splitMemberIds: body.splitWith ?? [],
    splitMode: body.splitMode === "custom" ? "custom" : "equal",
    customAmounts: body.customAmounts ?? {},
  });

  if ("error" in result) return res.badRequest(result.error);
  return res.ok(result);
});

export const DELETE = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string; expenseId: string }> }
) => {
  const { id, expenseId } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  // Owner can delete any expense; members can only delete their own
  if (auth.role !== "owner") {
    const expense = await expenseService.getExpense(expenseId, id);
    if (!expense) return res.notFound("Expense not found");
    const allMembers = await memberService.getGroupMembers(id);
    const userMember = allMembers.find((m) => m.userId === auth.user.userId);
    if (!userMember || expense.paidBy !== userMember.id) {
      return res.forbidden("You can only delete expenses you paid for");
    }
  }

  const result = await expenseService.deleteExpense(expenseId, id);
  if ("error" in result) return res.notFound(result.error);
  return res.noContent();
});
