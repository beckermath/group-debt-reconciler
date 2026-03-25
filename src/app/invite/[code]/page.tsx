import { db } from "@/db";
import { groupInvites, groups, groupMembers } from "@/db/schema";
import { eq, and } from "drizzle-orm";
import { notFound } from "next/navigation";
import { auth } from "@/lib/auth";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { AcceptInviteButton } from "./accept-button";

export const dynamic = "force-dynamic";

export default async function InvitePage({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code } = await params;
  const session = await auth();

  const [invite] = await db
    .select()
    .from(groupInvites)
    .where(eq(groupInvites.code, code));

  if (!invite) notFound();

  const [group] = await db
    .select()
    .from(groups)
    .where(eq(groups.id, invite.groupId));

  if (!group) notFound();

  // Check if expired
  if (invite.expiresAt && invite.expiresAt < new Date()) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Card className="w-full max-w-sm">
          <CardHeader>
            <CardTitle>Invite expired</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              This invite link has expired. Ask the group owner for a new one.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Check if max uses reached
  if (invite.maxUses && invite.useCount >= invite.maxUses) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Card className="w-full max-w-sm">
          <CardHeader>
            <CardTitle>Invite no longer available</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              This invite link has reached its maximum uses.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Check if already a member
  let alreadyMember = false;
  if (session?.user?.id) {
    const [existing] = await db
      .select()
      .from(groupMembers)
      .where(
        and(
          eq(groupMembers.groupId, invite.groupId),
          eq(groupMembers.userId, session.user.id)
        )
      );
    alreadyMember = !!existing;
  }

  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Join {group.name}?</CardTitle>
        </CardHeader>
        <CardContent>
          {alreadyMember ? (
            <div className="space-y-3">
              <p className="text-sm text-muted-foreground">
                You are already a member of this group.
              </p>
              <a
                href={`/group/${group.id}`}
                className="inline-block text-sm text-primary hover:underline"
              >
                Go to group
              </a>
            </div>
          ) : (
            <AcceptInviteButton code={code} groupName={group.name} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
