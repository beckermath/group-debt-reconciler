import { db } from "@/db";
import { users } from "@/db/schema";
import { inArray } from "drizzle-orm";
import { notFound } from "next/navigation";
import { auth } from "@/lib/auth";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { deleteExpense, deleteMember, restoreMember } from "@/app/actions";
import { EditExpenseButton } from "@/components/edit-expense-button";
import { AddExpenseDialog } from "@/components/add-expense-dialog";
import { RemoveMemberButton } from "@/components/remove-member-button";
import { DeleteGroupButton } from "@/components/delete-group-button";
import { AddPeopleDialog } from "@/components/add-people-dialog";
import { EditableGroupName } from "@/components/editable-group-name";
import { SettleUpButton } from "@/components/settle-up-button";
import { SettlementHistory } from "@/components/settlement-history";
import { MemberAvatar } from "@/components/member-avatar";
import { GroupDetailTabs, TabsList, TabsTrigger, TabsContent } from "@/components/group-detail-tabs";
import { reconcile } from "@/lib/reconcile";
import { computeBalances } from "@/lib/balances";
import { requireGroupAccess } from "@/lib/auth-helpers";
import * as groupService from "@/services/group-service";
import * as memberService from "@/services/member-service";
import * as expenseService from "@/services/expense-service";
import * as settlementService from "@/services/settlement-service";
import Link from "next/link";
import { ChevronLeft } from "lucide-react";


export const dynamic = "force-dynamic";

export default async function GroupPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const { id } = await params;
  const { tab } = await searchParams;

  const { membership, userId: currentUserId } = await requireGroupAccess(id);
  const isOwner = membership.role === "owner";

  const group = await groupService.getGroup(id);
  if (!group) notFound();

  const allGroupMembers = await memberService.getGroupMembers(id);

  const activeMembers = allGroupMembers.filter((m) => !m.removedAt);
  const removedMembers = allGroupMembers.filter((m) => m.removedAt);
  const allMembers = [...activeMembers, ...removedMembers];
  const currentMember = activeMembers.find((m) => m.userId === currentUserId);
  const sessionIsGuest = (await auth())?.user?.isGuest ?? false;
  const memberMap = new Map(
    allMembers.map((m) => [m.id, m.removedAt ? `${m.name} (removed)` : m.name])
  );

  // Fetch settlements
  const allSettlements = await settlementService.getGroupSettlements(id);

  const lastSettlement = allSettlements[0] ?? null;

  // Fetch ALL expenses for the group
  const allExpensesWithSplits = await expenseService.getGroupExpensesWithSplits(id);

  // Split into current (after last settlement) and previous
  const currentExpenses = lastSettlement
    ? allExpensesWithSplits.filter((e) => e.createdAt > lastSettlement.settledAt)
    : allExpensesWithSplits;

  const previousExpenses = lastSettlement
    ? allExpensesWithSplits.filter((e) => e.createdAt <= lastSettlement.settledAt)
    : [];

  // Compute balances from CURRENT expenses only
  const balances = computeBalances(
    currentExpenses,
    allMembers.map((m) => m.id)
  );

  // Compute transfers for reconciliation and group deletion
  const transfers = reconcile(balances);
  const hasUnsettledDebts = transfers.length > 0;
  const transfersWithNames = transfers.map((t) => ({
    fromName: memberMap.get(t.from) ?? "Unknown",
    toName: memberMap.get(t.to) ?? "Unknown",
    amount: t.amount,
  }));

  // Build settlement history data — batch query instead of N+1
  const settlerIds = [...new Set(allSettlements.map((s) => s.settledBy))];
  const settlementUsers = new Map<string, string>();
  if (settlerIds.length > 0) {
    const settlers = await db
      .select({ id: users.id, name: users.name, phoneNumber: users.phoneNumber })
      .from(users)
      .where(inArray(users.id, settlerIds));
    for (const u of settlers) {
      settlementUsers.set(u.id, u.name ?? u.phoneNumber ?? "Unknown");
    }
  }

  const settlementsWithNames = allSettlements.map((s) => ({
    id: s.id,
    settledAt: s.settledAt,
    settledByName: settlementUsers.get(s.settledBy) ?? "Unknown",
  }));

  // Group previous expenses by settlement period
  const expensesBySettlement: Record<string, { id: string; description: string; amount: number; paidByName: string; splitCount: number }[]> = {};
  for (let i = 0; i < allSettlements.length; i++) {
    const settlement = allSettlements[i];
    const prevSettlement = allSettlements[i + 1] ?? null;
    const periodExpenses = previousExpenses.filter((e) => {
      const afterPrev = prevSettlement ? e.createdAt > prevSettlement.settledAt : true;
      const beforeCurrent = e.createdAt <= settlement.settledAt;
      return afterPrev && beforeCurrent;
    });
    expensesBySettlement[settlement.id] = periodExpenses.map((e) => ({
      id: e.id,
      description: e.description,
      amount: e.amount,
      paidByName: memberMap.get(e.paidBy) ?? "Unknown",
      splitCount: e.splits.length,
    }));
  }

  // Compute per-member impact for remove dialog (current expenses only)
  function getMemberImpact(memberId: string) {
    const expensesPaidCount = currentExpenses.filter((e) => e.paidBy === memberId).length;
    const expensesSplitCount = currentExpenses.filter(
      (e) => e.paidBy !== memberId && e.splits.some((s) => s.memberId === memberId)
    ).length;
    return {
      balanceCents: balances.get(memberId) ?? 0,
      expensesPaidCount,
      expensesSplitCount,
    };
  }

  if (activeMembers.length === 0) {
    return (
      <div className="space-y-8">
        <div>
          <Link
            href="/"
            className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            <ChevronLeft className="size-4" />
            All groups
          </Link>
          <div className="flex items-center justify-between gap-2 mt-1">
            <div className="min-w-0 flex-1">
              <EditableGroupName groupId={id} name={group.name} isOwner={isOwner} />
            </div>
            <div className="flex items-center gap-2 shrink-0">
              {isOwner && (
                <DeleteGroupButton
                  groupId={id}
                  groupName={group.name}
                  hasUnsettledDebts={false}
                  totalExpenses={0}
                  totalMembers={0}
                  transfers={[]}
                />
              )}
            </div>
          </div>
        </div>

        <Card>
          <CardContent className="py-12 text-center space-y-4">
            <p className="text-muted-foreground">
              Your group is empty. Add members to start splitting expenses.
            </p>
            <Link
              href={`/group/${id}/setup`}
              className="inline-flex items-center justify-center rounded-lg bg-primary text-primary-foreground px-4 py-2 text-sm font-medium hover:bg-primary/90 transition-colors"
            >
              Add members
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <Link
          href="/"
          className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
        >
          <ChevronLeft className="size-4" />
          All groups
        </Link>
        <div className="flex items-center justify-between gap-2 mt-1">
          <div className="min-w-0 flex-1">
            <EditableGroupName groupId={id} name={group.name} isOwner={isOwner} />
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <AddPeopleDialog groupId={id} isGuest={sessionIsGuest} />
            {isOwner && (
              <DeleteGroupButton
                groupId={id}
                groupName={group.name}
                hasUnsettledDebts={hasUnsettledDebts}
                totalExpenses={allExpensesWithSplits.length}
                totalMembers={allMembers.length}
                transfers={transfersWithNames}
              />
            )}
          </div>
        </div>
        <p className="text-muted-foreground">
          {activeMembers.length} member{activeMembers.length !== 1 && "s"}
        </p>
      </div>

      {/* Zone A: Balances + Settle Up (promoted to top) */}
      <ReconciliationCard
        balances={balances}
        memberMap={memberMap}
        isOwner={isOwner}
        groupId={id}
        transfers={transfersWithNames}
        activeMembers={activeMembers}
        currentMemberId={currentMember?.id}
        isGuest={sessionIsGuest}
      />

      {/* Zone B: Tabbed detail sections */}
      <GroupDetailTabs
        tab={tab}
        availableTabs={settlementsWithNames.length > 0
          ? ["expenses", "members", "history"]
          : ["expenses", "members"]
        }
      >
        <TabsList className="w-full">
          <TabsTrigger value="expenses">
            Expenses{currentExpenses.length > 0 && ` (${currentExpenses.length})`}
          </TabsTrigger>
          <TabsTrigger value="members">
            Members ({activeMembers.length})
          </TabsTrigger>
          {settlementsWithNames.length > 0 && (
            <TabsTrigger value="history">
              History ({settlementsWithNames.length})
            </TabsTrigger>
          )}
        </TabsList>

        {/* Expenses Tab */}
        <TabsContent value="expenses">
          {currentExpenses.length === 0 ? (
            <Card>
              <CardHeader>
                <CardTitle>Expenses</CardTitle>
              </CardHeader>
              <CardContent className="py-8 text-center space-y-3">
                <p className="text-sm text-muted-foreground">
                  No expenses yet{lastSettlement ? " since last settlement" : ""}.
                </p>
                <AddExpenseDialog groupId={id} members={activeMembers} currentMemberId={currentMember?.id} isGuest={sessionIsGuest} />
              </CardContent>
            </Card>
          ) : (
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle>
                    Expenses
                    {lastSettlement && (
                      <span className="text-xs font-normal text-muted-foreground ml-2">
                        since {lastSettlement.settledAt.toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                      </span>
                    )}
                  </CardTitle>
                  <AddExpenseDialog groupId={id} members={activeMembers} currentMemberId={currentMember?.id} isGuest={sessionIsGuest} />
                </div>
              </CardHeader>
              <CardContent>
                <ul className="divide-y">
                  {currentExpenses.map((expense) => (
                    <li key={expense.id} className="py-3">
                      <div className="flex items-center justify-between gap-2">
                        <div className="min-w-0 flex-1">
                          <p className="font-medium truncate">{expense.description}</p>
                          <p className="text-sm text-muted-foreground truncate">
                            {memberMap.get(expense.paidBy) ?? "Unknown"} paid $
                            {(expense.amount / 100).toFixed(2)} &middot; split{" "}
                            {expense.splits.length} way
                            {expense.splits.length !== 1 && "s"}
                          </p>
                        </div>
                        <div className="flex items-center gap-1 shrink-0">
                          <EditExpenseButton
                            expense={expense}
                            groupId={id}
                            members={activeMembers}
                          />
                          {(isOwner || activeMembers.find((m) => m.userId === currentUserId)?.id === expense.paidBy) && (
                            <form action={deleteExpense}>
                              <input type="hidden" name="id" value={expense.id} />
                              <input type="hidden" name="groupId" value={id} />
                              <SubmitButton variant="destructive" size="sm">
                                Delete
                              </SubmitButton>
                            </form>
                          )}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        {/* Members Tab */}
        <TabsContent value="members">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>Members</CardTitle>
                <AddPeopleDialog groupId={id} variant="inline" isGuest={sessionIsGuest} />
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              {activeMembers.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                  No members yet. Add people above.
                </p>
              ) : (
                <ul className="divide-y">
                  {activeMembers.map((member) => {
                    const impact = getMemberImpact(member.id);
                    return (
                      <li
                        key={member.id}
                        className="flex items-center justify-between py-2"
                      >
                        <div className="flex items-center gap-1.5">
                          <span>{member.name}</span>
                          {!member.userId && (
                            <span className="inline-flex items-center rounded-full bg-muted px-1.5 py-0.5 text-[0.65rem] font-medium text-muted-foreground">
                              guest
                            </span>
                          )}
                        </div>
                        {/* Owner can remove others but not themselves */}
                        {isOwner && member.userId !== membership.userId && (
                          <RemoveMemberButton
                            member={member}
                            groupId={id}
                            balanceCents={impact.balanceCents}
                            expensesPaidCount={impact.expensesPaidCount}
                            expensesSplitCount={impact.expensesSplitCount}
                          />
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}

              {removedMembers.length > 0 && (
                <div className="pt-2">
                  <p className="text-xs font-medium text-muted-foreground mb-2">
                    Removed members
                  </p>
                  <ul className="space-y-1">
                    {removedMembers.map((member) => (
                      <li
                        key={member.id}
                        className="flex items-center justify-between py-1 text-sm text-muted-foreground"
                      >
                        <span>{member.name}</span>
                        <div className="flex gap-1">
                          <form action={restoreMember}>
                            <input type="hidden" name="id" value={member.id} />
                            <input type="hidden" name="groupId" value={id} />
                            <SubmitButton variant="ghost" size="sm">
                              Restore
                            </SubmitButton>
                          </form>
                          <form action={deleteMember}>
                            <input type="hidden" name="id" value={member.id} />
                            <input type="hidden" name="groupId" value={id} />
                            <SubmitButton variant="destructive" size="sm">
                              Delete
                            </SubmitButton>
                          </form>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* History Tab */}
        {settlementsWithNames.length > 0 && (
          <TabsContent value="history">
            <Card>
              <CardHeader>
                <CardTitle>Settlement History</CardTitle>
              </CardHeader>
              <CardContent>
                <SettlementHistory
                  groupId={id}
                  settlements={settlementsWithNames}
                  expensesBySettlement={expensesBySettlement}
                  isOwner={isOwner}
                />
              </CardContent>
            </Card>
          </TabsContent>
        )}
      </GroupDetailTabs>
    </div>
  );
}

// MemberAvatar is imported from @/components/member-avatar

function BalanceBar({
  balance,
  maxAbsBalance,
}: {
  balance: number;
  maxAbsBalance: number;
}) {
  if (balance === 0 || maxAbsBalance === 0) return null;

  const percentage = Math.round((Math.abs(balance) / maxAbsBalance) * 100);
  const widthPercent = Math.max(percentage, 4);
  const isPositive = balance > 0;

  return (
    <div className="mt-1.5 flex h-1.5 w-full items-center rounded-full bg-muted">
      {isPositive ? (
        <div
          className="h-full rounded-full bg-owed/70 transition-all duration-500"
          style={{ width: `${widthPercent}%` }}
        />
      ) : (
        <div className="flex h-full w-full justify-end">
          <div
            className="h-full rounded-full bg-owes/60 transition-all duration-500"
            style={{ width: `${widthPercent}%` }}
          />
        </div>
      )}
    </div>
  );
}

function ReconciliationCard({
  balances,
  memberMap,
  isOwner,
  groupId,
  transfers: transfersWithNames,
  activeMembers,
  currentMemberId,
  isGuest: isGuestUser,
}: {
  balances: Map<string, number>;
  memberMap: Map<string, string>;
  isOwner: boolean;
  groupId: string;
  transfers: { fromName: string; toName: string; amount: number }[];
  activeMembers: { id: string; name: string }[];
  currentMemberId?: string;
  isGuest?: boolean;
}) {
  const hasTransfers = transfersWithNames.length > 0;
  const sortedBalances = Array.from(balances.entries()).sort(
    (a, b) => b[1] - a[1]
  );
  const maxAbsBalance = sortedBalances.reduce(
    (max, [, b]) => Math.max(max, Math.abs(b)),
    0
  );

  return (
    <Card className="border-primary/20 bg-gradient-to-br from-primary/[0.04] to-transparent">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Balances</CardTitle>
          <div className="flex items-center gap-2">
            <AddExpenseDialog groupId={groupId} members={activeMembers} currentMemberId={currentMemberId} isGuest={isGuestUser} />
            {isOwner && hasTransfers && (
              <SettleUpButton groupId={groupId} transfers={transfersWithNames} />
            )}
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Per-member balances */}
        <ul className="space-y-3">
          {sortedBalances.map(([id, balance]) => {
            const name = memberMap.get(id) ?? "Unknown";
            return (
              <li key={id}>
                <div className="flex items-center gap-3">
                  <MemberAvatar name={name} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="truncate text-sm font-medium">
                        {name}
                      </span>
                      <span className="shrink-0 text-right">
                        <span
                          className={`text-sm font-semibold tabular-nums ${
                            balance > 0
                              ? "text-owed"
                              : balance < 0
                                ? "text-owes"
                                : "text-settled"
                          }`}
                        >
                          {balance > 0 ? "+" : ""}
                          ${(balance / 100).toFixed(2)}
                        </span>
                        <span
                          className={`ml-1.5 text-xs ${
                            balance === 0
                              ? "text-muted-foreground"
                              : "text-muted-foreground/70"
                          }`}
                        >
                          {balance > 0
                            ? "is owed"
                            : balance < 0
                              ? "owes"
                              : "settled"}
                        </span>
                      </span>
                    </div>
                    <BalanceBar
                      balance={balance}
                      maxAbsBalance={maxAbsBalance}
                    />
                  </div>
                </div>
              </li>
            );
          })}
        </ul>

        {/* Divider */}
        <div className="border-t" />

        {/* Transfers */}
        {!hasTransfers ? (
          <div className="relative flex flex-col items-center gap-3 py-6 text-center overflow-hidden">
            {/* CSS celebration particles */}
            <div className="pointer-events-none absolute inset-0" aria-hidden="true">
              <span className="absolute left-1/4 bottom-1/2 h-1.5 w-1.5 rounded-full bg-accent/60 animate-[float-up_1.8s_ease-out_forwards]" style={{ animationDelay: "0s" }} />
              <span className="absolute left-1/2 bottom-1/3 h-1 w-1 rounded-full bg-primary/50 animate-[float-up_2s_ease-out_forwards]" style={{ animationDelay: "0.2s" }} />
              <span className="absolute left-2/3 bottom-1/2 h-1.5 w-1.5 rounded-full bg-owed/50 animate-[float-up_1.6s_ease-out_forwards]" style={{ animationDelay: "0.4s" }} />
              <span className="absolute left-[40%] bottom-1/4 h-1 w-1 rounded-full bg-accent/40 animate-[float-up_2.2s_ease-out_forwards]" style={{ animationDelay: "0.1s" }} />
              <span className="absolute left-[60%] bottom-1/3 h-1.5 w-1.5 rounded-full bg-primary/40 animate-[float-up_1.9s_ease-out_forwards]" style={{ animationDelay: "0.3s" }} />
            </div>
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-owed/10 shadow-[0_0_20px_oklch(0.60_0.14_155/15%)] dark:shadow-[0_0_24px_oklch(0.60_0.14_155/20%)]">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                className="h-6 w-6 text-owed"
              >
                <path
                  fillRule="evenodd"
                  d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm3.857-9.809a.75.75 0 0 0-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 1 0-1.06 1.061l2.5 2.5a.75.75 0 0 0 1.137-.089l4-5.5Z"
                  clipRule="evenodd"
                />
              </svg>
            </div>
            <div>
              <p className="text-sm font-semibold text-owed" role="status">
                All settled up!
              </p>
              <p className="text-xs text-muted-foreground">
                No payments needed right now.
              </p>
            </div>
          </div>
        ) : (
          <div>
            <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              {transfersWithNames.length} payment
              {transfersWithNames.length !== 1 && "s"} to settle
            </p>
            <ul className="space-y-2">
              {transfersWithNames.map((t, i) => (
                <li
                  key={i}
                  className="flex items-center gap-3 rounded-lg border bg-card p-3"
                >
                  {/* From avatar */}
                  <MemberAvatar name={t.fromName} />

                  {/* Arrow */}
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    className="h-4 w-4 shrink-0 text-muted-foreground/50"
                  >
                    <path
                      fillRule="evenodd"
                      d="M3 10a.75.75 0 0 1 .75-.75h10.638l-3.175-2.847a.75.75 0 0 1 1.004-1.115l4.5 4.04a.75.75 0 0 1 0 1.115l-4.5 4.04a.75.75 0 0 1-1.004-1.114l3.175-2.849H3.75A.75.75 0 0 1 3 10Z"
                      clipRule="evenodd"
                    />
                  </svg>

                  {/* To avatar */}
                  <MemberAvatar name={t.toName} />

                  {/* Names */}
                  <div className="min-w-0 flex-1 text-sm">
                    <span className="font-medium">{t.fromName}</span>
                    <span className="text-muted-foreground"> pays </span>
                    <span className="font-medium">{t.toName}</span>
                  </div>

                  {/* Amount */}
                  <span className="shrink-0 rounded-md bg-primary/10 px-2.5 py-1 text-sm font-semibold tabular-nums text-primary">
                    ${(t.amount / 100).toFixed(2)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
