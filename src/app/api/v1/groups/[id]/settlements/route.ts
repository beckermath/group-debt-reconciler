import { NextRequest } from "next/server";
import { withGroupAccess, withGroupOwner } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as settlementService from "@/services/settlement-service";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const settlements = await settlementService.getGroupSettlements(id);
  return res.ok(settlements);
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withGroupOwner(request, id);
  if (auth instanceof Response) return auth;

  const result = await settlementService.settleUp(id, auth.user.userId);
  return res.created(result);
}
