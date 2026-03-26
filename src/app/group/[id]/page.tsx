import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { notFound } from "next/navigation";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { addMember, deleteExpense, deleteMember, restoreMember } from "@/app/actions";
import { EditExpenseButton } from "@/components/edit-expense-button";
import { ExpenseForm } from "@/components/expense-form";
import { RemoveMemberButton } from "@/components/remove-member-button";
import { DeleteGroupButton } from "@/components/delete-group-button";
import { InviteButton } from "@/components/invite-button";
import { EditableGroupName } from "@/components/editable-group-name";
import { SettleUpButton } from "@/components/settle-up-button";
import { SettlementHistory } from "@/components/settlement-history";
import { reconcile } from "@/lib/reconcile";
import { computeBalances } from "@/lib/balances";
import { requireGroupAccess } from "@/lib/auth-helpers";
import * as groupService from "@/services/group-service";
import * as memberService from "@/services/member-service";
import * as expenseService from "@/services/expense-service";
import * as settlementService from "@/services/settlement-service";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function GroupPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const { membership } = await requireGroupAccess(id);
  const isOwner = membership.role === "owner";

  const group = await groupService.getGroup(id);
  if (!group) notFound();

  const allGroupMembers = await memberService.getGroupMembers(id);

  const activeMembers = allGroupMembers.filter((m) => !m.removedAt);
  const removedMembers = allGroupMembers.filter((m) => m.removedAt);
  const allMembers = [...activeMembers, ...removedMembers];
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

  // Build settlement history data
  const settlementUsers = new Map<string, string>();
  for (const s of allSettlements) {
    if (!settlementUsers.has(s.settledBy)) {
      const [u] = await db.select().from(users).where(eq(users.id, s.settledBy));
      if (u) settlementUsers.set(s.settledBy, u.name ?? u.email);
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

  return (
    <div className="space-y-8">
      <div>
        <Link href="/" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
          &larr; All groups
        </Link>
        <div className="flex items-center justify-between gap-2 mt-1">
          <div className="min-w-0 flex-1">
            <EditableGroupName groupId={id} name={group.name} isOwner={isOwner} />
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <InviteButton groupId={id} />
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

      <Card>
        <CardHeader>
          <CardTitle>Members</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <form action={addMember} className="flex gap-2">
            <input type="hidden" name="groupId" value={id} />
            <Input name="name" placeholder="Member name" required />
            <SubmitButton>Add</SubmitButton>
          </form>

          {activeMembers.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No members yet. Add some above.
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
                    <RemoveMemberButton
                      member={member}
                      groupId={id}
                      balanceCents={impact.balanceCents}
                      expensesPaidCount={impact.expensesPaidCount}
                      expensesSplitCount={impact.expensesSplitCount}
                    />
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

      <Card>
        <CardHeader>
          <CardTitle>Add Expense</CardTitle>
        </CardHeader>
        <CardContent>
          <ExpenseForm groupId={id} members={activeMembers} />
        </CardContent>
      </Card>

      {currentExpenses.length > 0 && (
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Expenses</CardTitle>
              {lastSettlement && (
                <span className="text-xs text-muted-foreground">
                  Since {lastSettlement.settledAt.toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                </span>
              )}
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
                      <form action={deleteExpense}>
                        <input type="hidden" name="id" value={expense.id} />
                        <input type="hidden" name="groupId" value={id} />
                        <SubmitButton variant="destructive" size="sm">
                          Delete
                        </SubmitButton>
                      </form>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      )}

      <ReconciliationCard
        expensesWithSplits={currentExpenses}
        memberMap={memberMap}
        isOwner={isOwner}
        groupId={id}
        transfers={transfersWithNames}
      />

      <SettlementHistory
        groupId={id}
        settlements={settlementsWithNames}
        expensesBySettlement={expensesBySettlement}
        isOwner={isOwner}
      />
    </div>
  );
}

function ReconciliationCard({
  expensesWithSplits,
  memberMap,
  isOwner,
  groupId,
  transfers: transfersWithNames,
}: {
  expensesWithSplits: {
    id: string;
    paidBy: string;
    amount: number;
    splits: { memberId: string; share: number }[];
  }[];
  memberMap: Map<string, string>;
  isOwner: boolean;
  groupId: string;
  transfers: { fromName: string; toName: string; amount: number }[];
}) {
  const balances = computeBalances(
    expensesWithSplits,
    Array.from(memberMap.keys())
  );

  const transfers = reconcile(balances);

  return (
    <Card className="border-primary/20 bg-primary/[0.02]">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Settle Up</CardTitle>
          {isOwner && transfers.length > 0 && (
            <SettleUpButton groupId={groupId} transfers={transfersWithNames} />
          )}
        </div>
      </CardHeader>
      <CardContent className="space-y-6">
        <div>
          <p className="text-sm font-medium text-muted-foreground mb-2">Balances</p>
          <ul className="space-y-1">
            {Array.from(balances.entries())
              .sort((a, b) => b[1] - a[1])
              .map(([id, balance]) => (
                <li key={id} className="flex justify-between text-sm">
                  <span>{memberMap.get(id)}</span>
                  <span
                    className={
                      balance > 0
                        ? "text-green-600"
                        : balance < 0
                          ? "text-red-600"
                          : "text-muted-foreground"
                    }
                  >
                    <span className="tabular-nums">{balance > 0 ? "+" : ""}${(balance / 100).toFixed(2)}</span>
                  </span>
                </li>
              ))}
          </ul>
        </div>

        {transfers.length === 0 ? (
          <p className="text-sm text-muted-foreground">All settled up!</p>
        ) : (
          <div>
            <p className="text-sm font-medium text-muted-foreground mb-2">
              {transfers.length} payment{transfers.length !== 1 && "s"} to settle
            </p>
            <ul className="space-y-2">
              {transfers.map((t, i) => (
                <li
                  key={i}
                  className="flex items-center justify-between gap-2 rounded-lg border p-3"
                >
                  <span className="text-sm min-w-0 truncate">
                    <span className="font-medium">{memberMap.get(t.from)}</span>
                    {" pays "}
                    <span className="font-medium">{memberMap.get(t.to)}</span>
                  </span>
                  <span className="font-semibold tabular-nums shrink-0">
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
