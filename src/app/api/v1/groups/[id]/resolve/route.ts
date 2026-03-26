import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as identityService from "@/services/identity-service";

/**
 * Resolve an external identity to a member in this group.
 * Used by Discord/Slack bots to find which member a chat user corresponds to.
 *
 * POST /api/v1/groups/[id]/resolve
 * { "provider": "discord", "providerIdentity": "123456789" }
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body?.provider || !body?.providerIdentity) {
    return res.badRequest("provider and providerIdentity are required");
  }

  const memberId = await identityService.resolveIdentityInGroup(id, {
    provider: body.provider,
    providerIdentity: body.providerIdentity,
  });

  if (!memberId) return res.notFound("No member found with this identity in this group");

  return res.ok({ memberId });
}
