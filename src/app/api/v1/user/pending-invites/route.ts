import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as directInviteService from "@/services/direct-invite-service";
import { withErrorHandling } from "@/lib/api-handler";

export const GET = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const invites = await directInviteService.getPendingInvitesForUser(auth.user.userId);
  return res.ok(invites);
});
