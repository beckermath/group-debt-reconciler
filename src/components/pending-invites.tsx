import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SubmitButton } from "@/components/submit-button";
import { acceptDirectInvite, declineDirectInvite } from "@/app/actions";
import type { PendingInvite } from "@/services/direct-invite-service";
import { UserPlus } from "lucide-react";

export function PendingInvites({ invites }: { invites: PendingInvite[] }) {
  if (invites.length === 0) return null;

  return (
    <Card className="border-accent/20 bg-accent/[0.03]">
      <CardHeader>
        <div className="flex items-center gap-2">
          <UserPlus className="size-4 text-accent" />
          <CardTitle>
            Pending Invites
            <span className="ml-1.5 text-xs font-normal text-muted-foreground">
              ({invites.length})
            </span>
          </CardTitle>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {invites.map((invite) => (
          <div
            key={invite.id}
            className="flex items-center justify-between gap-3 rounded-lg border p-3"
          >
            <div className="min-w-0">
              <p className="text-sm font-medium truncate">
                {invite.groupName}
              </p>
              <p className="text-xs text-muted-foreground">
                Invited by {invite.inviterName}
              </p>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <form action={acceptDirectInvite}>
                <input type="hidden" name="inviteId" value={invite.id} />
                <SubmitButton size="sm">Accept</SubmitButton>
              </form>
              <form action={declineDirectInvite}>
                <input type="hidden" name="inviteId" value={invite.id} />
                <SubmitButton variant="ghost" size="sm">
                  Decline
                </SubmitButton>
              </form>
            </div>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
