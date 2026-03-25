import { db } from "@/db";
import { groups, members, expenses, expenseSplits } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
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
import { reconcile } from "@/lib/reconcile";
import { requireGroupAccess } from "@/lib/auth-helpers";
import Link from "next/link";

export const dynamic = "force-dynamic";

function computeBalances(
  expensesWithSplits: {
    paidBy: string;
    amount: number;
    splits: { memberId: string; share: number }[];
  }[],
  memberIds: string[]
) {
  const balances = new Map<string, number>();
  for (const id of memberIds) {
    balances.set(id, 0);
  }
  for (const expense of expensesWithSplits) {
    balances.set(expense.paidBy, (balances.get(expense.paidBy) ?? 0) + expense.amount);
    for (const split of expense.splits) {
      balances.set(split.memberId, (balances.get(split.memberId) ?? 0) - split.share);
    }
  }
  return balances;
}

export default async function GroupPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const { membership } = await requireGroupAccess(id);
  const isOwner = membership.role === "owner";

  const [group] = await db.select().from(groups).where(eq(groups.id, id));
  if (!group) notFound();

  const allGroupMembers = await db
    .select()
    .from(members)
    .where(eq(members.groupId, id));

  const activeMembers = allGroupMembers.filter((m) => !m.removedAt);
  const removedMembers = allGroupMembers.filter((m) => m.removedAt);
  const allMembers = [...activeMembers, ...removedMembers];
  const memberMap = new Map(
    allMembers.map((m) => [m.id, m.removedAt ? `${m.name} (removed)` : m.name])
  );

  const groupExpenses = await db
    .select()
    .from(expenses)
    .where(eq(expenses.groupId, id))
    .orderBy(desc(expenses.createdAt));

  const expensesWithSplits = await Promise.all(
    groupExpenses.map(async (expense) => {
      const splits = await db
        .select()
        .from(expenseSplits)
        .where(eq(expenseSplits.expenseId, expense.id));
      return { ...expense, splits };
    })
  );

  // Compute balances for all members (including removed) for impact calculations
  const balances = computeBalances(
    expensesWithSplits,
    allMembers.map((m) => m.id)
  );

  // Compute transfers for group deletion dialog
  const transfers = reconcile(balances);
  const hasUnsettledDebts = transfers.length > 0;
  const transfersWithNames = transfers.map((t) => ({
    fromName: memberMap.get(t.from) ?? "Unknown",
    toName: memberMap.get(t.to) ?? "Unknown",
    amount: t.amount,
  }));

  // Compute per-member impact for remove dialog
  function getMemberImpact(memberId: string) {
    const expensesPaidCount = groupExpenses.filter((e) => e.paidBy === memberId).length;
    const expensesSplitCount = expensesWithSplits.filter(
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
        <div className="flex items-center justify-between mt-1">
          <EditableGroupName groupId={id} name={group.name} isOwner={isOwner} />
          <div className="flex items-center gap-2">
            <InviteButton groupId={id} />
            {isOwner && (
            <DeleteGroupButton
              groupId={id}
              groupName={group.name}
              hasUnsettledDebts={hasUnsettledDebts}
              totalExpenses={groupExpenses.length}
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
                    <span>{member.name}</span>
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

      {expensesWithSplits.length > 0 && (
        <>
          <Card>
            <CardHeader>
              <CardTitle>Expenses</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="divide-y">
                {expensesWithSplits.map((expense) => (
                  <li key={expense.id} className="py-3">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-medium">{expense.description}</p>
                        <p className="text-sm text-muted-foreground">
                          {memberMap.get(expense.paidBy) ?? "Unknown"} paid $
                          {(expense.amount / 100).toFixed(2)} &middot; split{" "}
                          {expense.splits.length} way
                          {expense.splits.length !== 1 && "s"}
                        </p>
                      </div>
                      <div className="flex items-center gap-1">
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

          <ReconciliationCard
            expensesWithSplits={expensesWithSplits}
            memberMap={memberMap}
          />
        </>
      )}
    </div>
  );
}

function ReconciliationCard({
  expensesWithSplits,
  memberMap,
}: {
  expensesWithSplits: {
    id: string;
    paidBy: string;
    amount: number;
    splits: { memberId: string; share: number }[];
  }[];
  memberMap: Map<string, string>;
}) {
  const balances = computeBalances(
    expensesWithSplits,
    Array.from(memberMap.keys())
  );

  const transfers = reconcile(balances);

  return (
    <Card className="border-primary/20 bg-primary/[0.02]">
      <CardHeader>
        <CardTitle>Settle Up</CardTitle>
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
                  className="flex items-center justify-between rounded-lg border p-3"
                >
                  <span className="text-sm">
                    <span className="font-medium">{memberMap.get(t.from)}</span>
                    {" pays "}
                    <span className="font-medium">{memberMap.get(t.to)}</span>
                  </span>
                  <span className="font-semibold tabular-nums">
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
