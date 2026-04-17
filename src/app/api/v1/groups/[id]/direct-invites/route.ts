import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as directInviteService from "@/services/direct-invite-service";
import { withErrorHandling } from "@/lib/api-handler";

export const POST = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  const invitedUserId = body?.invitedUserId;
  if (typeof invitedUserId !== "string" || !invitedUserId) {
    return res.badRequest("invitedUserId is required");
  }

  const result = await directInviteService.sendDirectInvite(
    id,
    auth.user.userId,
    invitedUserId
  );

  if (result.error) return res.badRequest(result.error);
  return res.created({ success: true });
});
