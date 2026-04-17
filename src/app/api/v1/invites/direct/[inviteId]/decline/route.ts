import { NextRequest } from "next/server";
import { withAuthRateLimit } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as directInviteService from "@/services/direct-invite-service";
import { withErrorHandling } from "@/lib/api-handler";

export const POST = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ inviteId: string }> }
) => {
  const { inviteId } = await context.params;
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  const result = await directInviteService.declineDirectInvite(inviteId, auth.user.userId);
  if (result.error) return res.badRequest(result.error);
  return res.ok({ success: true });
});
