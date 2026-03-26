import { NextRequest } from "next/server";
import { withGroupAccess, withGroupOwner } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as groupService from "@/services/group-service";
import * as memberService from "@/services/member-service";
import * as expenseService from "@/services/expense-service";
import * as settlementService from "@/services/settlement-service";
import { computeBalances } from "@/lib/balances";
import { reconcile } from "@/lib/reconcile";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
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
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withGroupOwner(request, id);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body?.name?.trim()) return res.badRequest("Name is required");

  await groupService.renameGroup(id, body.name);
  return res.ok({ id, name: body.name.trim().slice(0, 100) });
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withGroupOwner(request, id);
  if (auth instanceof Response) return auth;

  await groupService.deleteGroup(id);
  return res.noContent();
}
