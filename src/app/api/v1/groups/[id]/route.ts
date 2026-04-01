import { NextRequest } from "next/server";
import { withGroupAccess, withGroupOwner } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as groupService from "@/services/group-service";
import * as memberService from "@/services/member-service";
import * as expenseService from "@/services/expense-service";
import * as settlementService from "@/services/settlement-service";
import { computeBalances } from "@/lib/balances";
import { reconcile } from "@/lib/reconcile";
import { withErrorHandling } from "@/lib/api-handler";

export const GET = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const group = await groupService.getGroup(id);
  if (!group) return res.notFound("Group not found");

  const members = await memberService.getGroupMembers(id);
  const expensesWithSplits = await expenseService.getGroupExpensesWithSplits(id);
  const settlements = await settlementService.getGroupSettlements(id);

  const lastSettlement = settlements[0] ?? null;
  const currentExpenses = lastSettlement
    ? expensesWithSplits.filter((e) => e.createdAt > lastSettlement.settledAt)
    : expensesWithSplits;

  const activeMembers = members.filter((m) => !m.removedAt);
  const balances = computeBalances(
    currentExpenses,
    members.map((m) => m.id)
  );
  const transfers = reconcile(balances);

  return res.ok({
    ...group,
    members,
    expenses: expensesWithSplits,
    settlements,
    balances: Object.fromEntries(balances),
    transfers,
    activeMembers: activeMembers.length,
  });
});

export const PATCH = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupOwner(request, id);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body?.name?.trim()) return res.badRequest("Name is required");

  await groupService.renameGroup(id, body.name);
  return res.ok({ id, name: body.name.trim().slice(0, 100) });
});

export const DELETE = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupOwner(request, id);
  if (auth instanceof Response) return auth;

  // Enforce no unsettled balances before deletion
  const { computeBalances } = await import("@/lib/balances");
  const { reconcile } = await import("@/lib/reconcile");
  const allMembers = await (await import("@/services/member-service")).getGroupMembers(id);
  const allExpenses = await (await import("@/services/expense-service")).getGroupExpensesWithSplits(id);
  const settlements = await (await import("@/services/settlement-service")).getGroupSettlements(id);
  const lastSettlement = settlements[0] ?? null;
  const currentExpenses = lastSettlement
    ? allExpenses.filter((e) => e.createdAt > lastSettlement.settledAt)
    : allExpenses;

  if (currentExpenses.length > 0) {
    const balances = computeBalances(currentExpenses, allMembers.map((m) => m.id));
    const transfers = reconcile(balances);
    if (transfers.length > 0) {
      return res.badRequest("Cannot delete group with unsettled balances. Settle up first.");
    }
  }

  await groupService.deleteGroup(id);
  return res.noContent();
});
