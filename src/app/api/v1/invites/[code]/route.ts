import { NextRequest } from "next/server";
import { withAuthRateLimit } from "@/lib/api-helpers";
import { inviteRateLimit } from "@/lib/rate-limit";
import * as res from "@/lib/api-response";
import * as inviteService from "@/services/invite-service";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ code: string }> }
) {
  const { code } = await params;
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  const { success } = await inviteRateLimit.limit(auth.user.userId);
  if (!success) return res.tooManyRequests("Too many invite attempts");

  const result = await inviteService.acceptInvite(code, auth.user.userId);

  if ("error" in result) return res.badRequest(result.error);
  if ("alreadyMember" in result) return res.ok({ groupId: result.groupId, alreadyMember: true });
  return res.ok({ groupId: result.groupId });
}
