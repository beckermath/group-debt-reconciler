import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as inviteService from "@/services/invite-service";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const result = await inviteService.createInviteLink(id, auth.user.userId);
  return res.created(result);
}
