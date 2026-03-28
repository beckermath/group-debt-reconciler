import { db } from "@/db";
import { directInvites, groups, groupMembers, users } from "@/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { randomUUID } from "crypto";
import { addUserToGroup } from "@/services/invite-service";

export type PendingInvite = {
  id: string;
  groupId: string;
  groupName: string;
  inviterName: string;
  createdAt: Date;
};

export async function sendDirectInvite(
  groupId: string,
  invitedBy: string,
  invitedUserId: string
): Promise<{ error?: string }> {
  // Verify inviter is a group member
  const [membership] = await db
    .select()
    .from(groupMembers)
    .where(and(eq(groupMembers.groupId, groupId), eq(groupMembers.userId, invitedBy)));

  if (!membership) {
    return { error: "You are not a member of this group" };
  }

  // Check invitee is not already a member
  const [existingMember] = await db
    .select()
    .from(groupMembers)
    .where(and(eq(groupMembers.groupId, groupId), eq(groupMembers.userId, invitedUserId)));

  if (existingMember) {
    return { error: "This user is already a member of the group" };
  }

  // Check no existing pending invite
  const [existingInvite] = await db
    .select()
    .from(directInvites)
    .where(
      and(
        eq(directInvites.groupId, groupId),
        eq(directInvites.invitedUserId, invitedUserId),
        eq(directInvites.status, "pending")
      )
    );

  if (existingInvite) {
    return { error: "An invite has already been sent to this user" };
  }

  await db.insert(directInvites).values({
    id: randomUUID(),
    groupId,
    invitedBy,
    invitedUserId,
    status: "pending",
    createdAt: new Date(),
  });

  return {};
}

export async function acceptDirectInvite(
  inviteId: string,
  userId: string
): Promise<{ error?: string; groupId?: string }> {
  const [invite] = await db
    .select()
    .from(directInvites)
    .where(eq(directInvites.id, inviteId));

  if (!invite) return { error: "Invite not found" };
  if (invite.invitedUserId !== userId) return { error: "This invite is not for you" };
  if (invite.status !== "pending") return { error: "This invite has already been responded to" };

  // Check not already a member (could have joined via link in the meantime)
  const [existingMember] = await db
    .select()
    .from(groupMembers)
    .where(and(eq(groupMembers.groupId, invite.groupId), eq(groupMembers.userId, userId)));

  if (existingMember) {
    await db
      .update(directInvites)
      .set({ status: "accepted", respondedAt: new Date() })
      .where(eq(directInvites.id, inviteId));
    return { groupId: invite.groupId };
  }

  await addUserToGroup(invite.groupId, userId);

  await db
    .update(directInvites)
    .set({ status: "accepted", respondedAt: new Date() })
    .where(eq(directInvites.id, inviteId));

  return { groupId: invite.groupId };
}

export async function declineDirectInvite(
  inviteId: string,
  userId: string
): Promise<{ error?: string }> {
  const [invite] = await db
    .select()
    .from(directInvites)
    .where(eq(directInvites.id, inviteId));

  if (!invite) return { error: "Invite not found" };
  if (invite.invitedUserId !== userId) return { error: "This invite is not for you" };
  if (invite.status !== "pending") return { error: "This invite has already been responded to" };

  await db
    .update(directInvites)
    .set({ status: "declined", respondedAt: new Date() })
    .where(eq(directInvites.id, inviteId));

  return {};
}

export async function getPendingInvitesForUser(userId: string): Promise<PendingInvite[]> {
  const invites = await db
    .select({
      id: directInvites.id,
      groupId: directInvites.groupId,
      groupName: groups.name,
      invitedBy: directInvites.invitedBy,
      createdAt: directInvites.createdAt,
    })
    .from(directInvites)
    .innerJoin(groups, eq(directInvites.groupId, groups.id))
    .where(
      and(
        eq(directInvites.invitedUserId, userId),
        eq(directInvites.status, "pending")
      )
    )
    .orderBy(desc(directInvites.createdAt));

  // Fetch inviter names
  const inviterIds = [...new Set(invites.map((i) => i.invitedBy))];
  const inviterMap = new Map<string, string>();
  for (const id of inviterIds) {
    const [user] = await db.select({ name: users.name }).from(users).where(eq(users.id, id));
    if (user) inviterMap.set(id, user.name ?? "Someone");
  }

  return invites.map((i) => ({
    id: i.id,
    groupId: i.groupId,
    groupName: i.groupName,
    inviterName: inviterMap.get(i.invitedBy) ?? "Someone",
    createdAt: i.createdAt,
  }));
}
