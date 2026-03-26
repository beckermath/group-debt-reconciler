import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as inviteService from "@/services/invite-service";
import { withErrorHandling } from "@/lib/api-handler";

export const POST = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const result = await inviteService.createInviteLink(id, auth.user.userId);
  return res.created(result);
});
