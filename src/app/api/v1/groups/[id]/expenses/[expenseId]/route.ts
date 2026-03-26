import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as expenseService from "@/services/expense-service";

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; expenseId: string }> }
) {
  const { id, expenseId } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body) return res.badRequest("Invalid request body");

  const result = await expenseService.updateExpense({
    expenseId,
    groupId: id,
    paidBy: body.paidBy,
    description: body.description,
    amountCents: Math.round((body.amount ?? 0) * 100),
    splitMemberIds: body.splitWith ?? [],
    splitMode: body.splitMode === "custom" ? "custom" : "equal",
    customAmounts: body.customAmounts ?? {},
  });

  if ("error" in result) return res.badRequest(result.error);
  return res.ok(result);
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; expenseId: string }> }
) {
  const { id, expenseId } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const result = await expenseService.deleteExpense(expenseId, id);
  if ("error" in result) return res.notFound(result.error);
  return res.noContent();
}
