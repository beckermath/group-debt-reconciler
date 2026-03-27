import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as identityService from "@/services/identity-service";
import { db } from "@/db";
import { members } from "@/db/schema";
import { eq } from "drizzle-orm";
import { withErrorHandling } from "@/lib/api-handler";

export const GET = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string; memberId: string }> }
) => {
  const { id, memberId } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  // Verify member belongs to this group
  const [member] = await db
    .select({ groupId: members.groupId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== id) return res.notFound("Member not found");

  const identities = await identityService.getMemberIdentities(memberId);
  return res.ok(identities);
});

export const POST = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string; memberId: string }> }
) => {
  const { id, memberId } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  // Verify member belongs to this group
  const [member] = await db
    .select({ groupId: members.groupId })
    .from(members)
    .where(eq(members.id, memberId));
  if (!member || member.groupId !== id) return res.notFound("Member not found");

  const body = await request.json().catch(() => null);
  if (!body?.provider || !body?.providerIdentity) {
    return res.badRequest("provider and providerIdentity are required");
  }

  const validProviders = ["phone", "email", "discord", "slack"];
  if (!validProviders.includes(body.provider)) {
    return res.badRequest(`Invalid provider. Use: ${validProviders.join(", ")}`);
  }

  const result = await identityService.linkIdentity(memberId, {
    provider: body.provider,
    providerIdentity: body.providerIdentity,
  });

  return res.created(result);
});
