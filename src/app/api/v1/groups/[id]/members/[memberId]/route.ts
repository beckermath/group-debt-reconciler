import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as memberService from "@/services/member-service";

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; memberId: string }> }
) {
  const { id, memberId } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  const action = body?.action;

  if (action === "remove") {
    const result = await memberService.softDeleteMember(memberId, id);
    if ("error" in result) return res.notFound(result.error);
    return res.ok({ memberId, status: "removed" });
  }

  if (action === "restore") {
    const result = await memberService.restoreMember(memberId, id);
    if ("error" in result) return res.notFound(result.error);
    return res.ok({ memberId, status: "active" });
  }

  return res.badRequest("Invalid action. Use 'remove' or 'restore'");
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; memberId: string }> }
) {
  const { id, memberId } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const result = await memberService.deleteMember(memberId, id);
  if ("error" in result) return res.notFound(result.error);
  return res.noContent();
}
