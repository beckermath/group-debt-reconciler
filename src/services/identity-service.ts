import { db } from "@/db";
import { memberIdentities, members, groupMembers } from "@/db/schema";
import { eq, and } from "drizzle-orm";
import { randomUUID } from "crypto";

export type IdentityProvider = "phone" | "email" | "discord" | "slack";

export interface ExternalIdentity {
  provider: IdentityProvider;
  providerIdentity: string;
}

/**
 * Link an external identity to a member.
 */
export async function linkIdentity(
  memberId: string,
  identity: ExternalIdentity
) {
  const normalized = normalizeIdentity(identity);

  // Check if this identity is already linked to this member
  const [existing] = await db
    .select()
    .from(memberIdentities)
    .where(
      and(
        eq(memberIdentities.memberId, memberId),
        eq(memberIdentities.provider, normalized.provider),
        eq(memberIdentities.providerIdentity, normalized.providerIdentity)
      )
    );

  if (existing) return { id: existing.id };

  const id = randomUUID();
  await db.insert(memberIdentities).values({
    id,
    memberId,
    provider: normalized.provider,
    providerIdentity: normalized.providerIdentity,
    createdAt: new Date(),
  });

  return { id };
}

/**
 * Remove an identity link from a member.
 */
export async function unlinkIdentity(identityId: string, memberId: string) {
  const [identity] = await db
    .select({ memberId: memberIdentities.memberId })
    .from(memberIdentities)
    .where(eq(memberIdentities.id, identityId));

  if (!identity || identity.memberId !== memberId) {
    return { error: "Identity not found" };
  }

  await db.delete(memberIdentities).where(eq(memberIdentities.id, identityId));
  return {};
}

/**
 * Find a member in a group by their external identity.
 * Returns the member ID if found, null otherwise.
 */
export async function resolveIdentityInGroup(
  groupId: string,
  identity: ExternalIdentity
): Promise<string | null> {
  const normalized = normalizeIdentity(identity);

  const results = await db
    .select({ memberId: memberIdentities.memberId, memberGroupId: members.groupId })
    .from(memberIdentities)
    .innerJoin(members, eq(memberIdentities.memberId, members.id))
    .where(
      and(
        eq(memberIdentities.provider, normalized.provider),
        eq(memberIdentities.providerIdentity, normalized.providerIdentity),
        eq(members.groupId, groupId)
      )
    );

  return results[0]?.memberId ?? null;
}

/**
 * Find all members across all groups linked to an external identity.
 */
export async function findMembersByIdentity(identity: ExternalIdentity) {
  const normalized = normalizeIdentity(identity);

  return db
    .select({
      memberId: memberIdentities.memberId,
      groupId: members.groupId,
      memberName: members.name,
      provider: memberIdentities.provider,
    })
    .from(memberIdentities)
    .innerJoin(members, eq(memberIdentities.memberId, members.id))
    .where(
      and(
        eq(memberIdentities.provider, normalized.provider),
        eq(memberIdentities.providerIdentity, normalized.providerIdentity)
      )
    );
}

/**
 * Get all identities linked to a member.
 */
export async function getMemberIdentities(memberId: string) {
  return db
    .select({
      id: memberIdentities.id,
      provider: memberIdentities.provider,
      providerIdentity: memberIdentities.providerIdentity,
      createdAt: memberIdentities.createdAt,
    })
    .from(memberIdentities)
    .where(eq(memberIdentities.memberId, memberId));
}

/**
 * When a new user registers, link their account to any existing guest
 * members that share a matching identity (email or phone).
 *
 * This connects their existing expense history to their new account.
 * Only links members that don't already have a userId (guests).
 */
export async function claimGuestMembers(
  userId: string,
  identities: ExternalIdentity[]
) {
  const claimed: { memberId: string; groupId: string }[] = [];

  for (const identity of identities) {
    const normalized = normalizeIdentity(identity);

    // Find guest members with this identity
    const matches = await db
      .select({
        memberId: members.id,
        groupId: members.groupId,
        existingUserId: members.userId,
      })
      .from(memberIdentities)
      .innerJoin(members, eq(memberIdentities.memberId, members.id))
      .where(
        and(
          eq(memberIdentities.provider, normalized.provider),
          eq(memberIdentities.providerIdentity, normalized.providerIdentity)
        )
      );

    for (const match of matches) {
      // Only claim guests (no userId yet)
      if (match.existingUserId) continue;

      // Check user isn't already a member of this group
      const [existingMembership] = await db
        .select()
        .from(groupMembers)
        .where(
          and(
            eq(groupMembers.groupId, match.groupId),
            eq(groupMembers.userId, userId)
          )
        );

      if (existingMembership) continue;

      // Link the member to the user
      await db
        .update(members)
        .set({ userId })
        .where(eq(members.id, match.memberId));

      // Grant group access
      await db.insert(groupMembers).values({
        id: randomUUID(),
        groupId: match.groupId,
        userId,
        role: "member",
        joinedAt: new Date(),
      });

      claimed.push({ memberId: match.memberId, groupId: match.groupId });
    }
  }

  return { claimed };
}

/**
 * Normalize an identity for consistent storage and lookup.
 */
function normalizeIdentity(identity: ExternalIdentity): ExternalIdentity {
  const providerIdentity = identity.provider === "email"
    ? identity.providerIdentity.trim().toLowerCase()
    : identity.provider === "phone"
      ? identity.providerIdentity.replace(/[\s\-()]/g, "")
      : identity.providerIdentity.trim();

  return {
    provider: identity.provider,
    providerIdentity,
  };
}
