import Link from "next/link";
import { Card, CardContent } from "@/components/ui/card";
import { auth } from "@/lib/auth";
import { redirect } from "next/navigation";
import * as groupService from "@/services/group-service";
import * as directInviteService from "@/services/direct-invite-service";
import type { GroupSummary } from "@/services/group-service";
import { SubmitButton } from "@/components/submit-button";
import { createGroup } from "./actions";
import { PendingInvites } from "@/components/pending-invites";
import { MemberAvatar } from "@/components/member-avatar";
import { Plus, Users, Receipt, ArrowRight } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function Home() {
  const session = await auth();
  if (!session?.user?.id) redirect("/phone");

  const groups = await groupService.getUserGroupSummaries(session.user.id);
  const pendingInvites = await directInviteService.getPendingInvitesForUser(session.user.id);

  // Compute global balance
  const totalOwed = groups.reduce(
    (sum, g) => sum + (g.userBalanceCents > 0 ? g.userBalanceCents : 0),
    0
  );
  const totalOwes = groups.reduce(
    (sum, g) => sum + (g.userBalanceCents < 0 ? -g.userBalanceCents : 0),
    0
  );
  const groupsWithBalances = groups.filter((g) => g.status === "has_balances").length;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Your Groups</h1>
          {groups.length > 0 && (
            <p className="text-sm text-muted-foreground mt-0.5">
              {groups.length} group{groups.length !== 1 && "s"}
              {groupsWithBalances > 0 && (
                <>, {groupsWithBalances} with unsettled balances</>
              )}
            </p>
          )}
        </div>
        <form action={createGroup}>
          <SubmitButton>
            <Plus className="size-4" />
            Create group
          </SubmitButton>
        </form>
      </div>

      {/* Global balance summary */}
      {groups.length > 0 && (totalOwed > 0 || totalOwes > 0) && (
        <div className="flex gap-3">
          {totalOwed > 0 && (
            <div className="flex-1 rounded-xl bg-owed/8 border border-owed/15 p-4">
              <p className="text-xs font-medium text-owed/80">You are owed</p>
              <p className="text-xl font-bold tabular-nums text-owed">
                ${(totalOwed / 100).toFixed(2)}
              </p>
            </div>
          )}
          {totalOwes > 0 && (
            <div className="flex-1 rounded-xl bg-owes/8 border border-owes/15 p-4">
              <p className="text-xs font-medium text-owes/80">You owe</p>
              <p className="text-xl font-bold tabular-nums text-owes">
                ${(totalOwes / 100).toFixed(2)}
              </p>
            </div>
          )}
        </div>
      )}

      {groups.length > 0 && totalOwed === 0 && totalOwes === 0 && groups.some((g) => g.expenseCount > 0) && (
        <div className="rounded-xl bg-owed/8 border border-owed/15 p-4 text-center">
          <p className="text-sm font-semibold text-owed">All settled up across all groups</p>
        </div>
      )}

      {/* Pending invites */}
      <PendingInvites invites={pendingInvites} />

      {/* Group list */}
      {groups.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="grid gap-3">
          {groups.map((group) => (
            <GroupCard key={group.id} group={group} />
          ))}
        </div>
      )}
    </div>
  );
}

function GroupCard({ group }: { group: GroupSummary }) {
  const statusColor =
    group.status === "has_balances"
      ? "bg-owes"
      : group.status === "settled"
        ? "bg-owed"
        : "bg-settled";

  return (
    <Link href={`/group/${group.id}`}>
      <Card className="group/link hover:-translate-y-0.5 hover:shadow-md hover:shadow-[oklch(0.50_0.01_260/8%)] dark:hover:border-[oklch(1_0_0/14%)] transition-all duration-200">
        <CardContent className="py-4">
          {/* Mobile: stacked layout */}
          <div className="flex flex-col gap-3 sm:hidden">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-3 min-w-0">
                <div className="relative shrink-0">
                  <div className="flex -space-x-2">
                    {group.memberNames.slice(0, 2).map((name) => (
                      <MemberAvatar
                        key={name}
                        name={name}
                        className="h-8 w-8 ring-2 ring-card text-[0.6rem]"
                      />
                    ))}
                    {group.memberCount > 2 && (
                      <span className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted text-[0.6rem] font-semibold text-muted-foreground ring-2 ring-card">
                        +{group.memberCount - 2}
                      </span>
                    )}
                  </div>
                  <span
                    className={`absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full ${statusColor} ring-2 ring-card`}
                  />
                </div>
                <p className="font-semibold truncate">{group.name}</p>
              </div>
              {group.userBalanceCents !== 0 && (
                <p
                  className={`shrink-0 text-sm font-semibold tabular-nums ${
                    group.userBalanceCents > 0 ? "text-owed" : "text-owes"
                  }`}
                >
                  {group.userBalanceCents > 0 ? "+" : ""}
                  ${(group.userBalanceCents / 100).toFixed(2)}
                </p>
              )}
              {group.userBalanceCents === 0 && group.status === "settled" && (
                <span className="shrink-0 text-xs font-medium text-owed">Settled</span>
              )}
            </div>
            <div className="flex items-center gap-3 text-xs text-muted-foreground">
              <span className="inline-flex items-center gap-1">
                <Users className="size-3" />
                {group.memberCount}
              </span>
              {group.expenseCount > 0 && (
                <span className="inline-flex items-center gap-1">
                  <Receipt className="size-3" />
                  {group.expenseCount}
                </span>
              )}
              {group.lastActivityAt && (
                <span>{formatRelativeDate(group.lastActivityAt)}</span>
              )}
              {group.userBalanceCents !== 0 && (
                <span className="ml-auto text-[0.65rem]">
                  {group.userBalanceCents > 0 ? "owed to you" : "you owe"}
                </span>
              )}
            </div>
          </div>

          {/* Desktop: single-row layout */}
          <div className="hidden sm:flex items-center gap-4">
            <div className="relative">
              <div className="flex -space-x-2">
                {group.memberNames.slice(0, 3).map((name) => (
                  <MemberAvatar
                    key={name}
                    name={name}
                    className="h-9 w-9 ring-2 ring-card text-[0.65rem]"
                  />
                ))}
                {group.memberCount > 3 && (
                  <span className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted text-[0.65rem] font-semibold text-muted-foreground ring-2 ring-card">
                    +{group.memberCount - 3}
                  </span>
                )}
              </div>
              <span
                className={`absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full ${statusColor} ring-2 ring-card`}
              />
            </div>

            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between gap-2">
                <p className="font-semibold truncate">{group.name}</p>
                <ArrowRight className="size-4 text-muted-foreground opacity-0 -translate-x-1 transition-all group-hover/link:opacity-100 group-hover/link:translate-x-0" />
              </div>
              <div className="flex items-center gap-3 text-xs text-muted-foreground mt-0.5">
                <span className="inline-flex items-center gap-1">
                  <Users className="size-3" />
                  {group.memberCount}
                </span>
                {group.expenseCount > 0 && (
                  <span className="inline-flex items-center gap-1">
                    <Receipt className="size-3" />
                    {group.expenseCount} expense{group.expenseCount !== 1 && "s"}
                  </span>
                )}
                {group.lastActivityAt && (
                  <span>{formatRelativeDate(group.lastActivityAt)}</span>
                )}
              </div>
            </div>

            {group.userBalanceCents !== 0 && (
              <div className="shrink-0 text-right">
                <p
                  className={`text-sm font-semibold tabular-nums ${
                    group.userBalanceCents > 0 ? "text-owed" : "text-owes"
                  }`}
                >
                  {group.userBalanceCents > 0 ? "+" : ""}
                  ${(group.userBalanceCents / 100).toFixed(2)}
                </p>
                <p className="text-[0.65rem] text-muted-foreground">
                  {group.userBalanceCents > 0 ? "owed to you" : "you owe"}
                </p>
              </div>
            )}
            {group.userBalanceCents === 0 && group.status === "settled" && (
              <span className="shrink-0 text-xs font-medium text-owed">Settled</span>
            )}
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

function EmptyState() {
  return (
    <Card>
      <CardContent className="py-12 text-center space-y-6">
        <div className="flex justify-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/10">
            <Receipt className="h-8 w-8 text-primary" />
          </div>
        </div>

        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Split expenses with anyone</h2>
          <p className="text-sm text-muted-foreground max-w-sm mx-auto">
            Create a group, add your friends, and start logging shared expenses.
            Rekn figures out who owes whom.
          </p>
        </div>

        <div className="flex justify-center gap-6 sm:gap-8 text-xs text-muted-foreground">
          <div className="flex flex-col items-center gap-1.5">
            <span className="flex h-7 w-7 sm:h-8 sm:w-8 items-center justify-center rounded-full bg-muted text-xs sm:text-sm font-semibold">1</span>
            <span>Create group</span>
          </div>
          <div className="flex flex-col items-center gap-1.5">
            <span className="flex h-7 w-7 sm:h-8 sm:w-8 items-center justify-center rounded-full bg-muted text-xs sm:text-sm font-semibold">2</span>
            <span>Add members</span>
          </div>
          <div className="flex flex-col items-center gap-1.5">
            <span className="flex h-7 w-7 sm:h-8 sm:w-8 items-center justify-center rounded-full bg-muted text-xs sm:text-sm font-semibold">3</span>
            <span>Log expenses</span>
          </div>
        </div>

        <form action={createGroup}>
          <SubmitButton>
            <Plus className="size-4" />
            Create group
          </SubmitButton>
        </form>
      </CardContent>
    </Card>
  );
}

function formatRelativeDate(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  if (diffDays < 7) return `${diffDays}d ago`;
  if (diffDays < 30) return `${Math.floor(diffDays / 7)}w ago`;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}
