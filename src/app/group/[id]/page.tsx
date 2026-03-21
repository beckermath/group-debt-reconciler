import { db } from "@/db";
import { groups, members, expenses, expenseSplits } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { addMember, deleteMember, deleteExpense } from "@/app/actions";
import { ExpenseForm } from "@/components/expense-form";
import { reconcile } from "@/lib/reconcile";

export const dynamic = "force-dynamic";

export default async function GroupPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const group = db.select().from(groups).where(eq(groups.id, id)).get();
  if (!group) notFound();

  const groupMembers = db
    .select()
    .from(members)
    .where(eq(members.groupId, id))
    .all();

  const groupExpenses = db
    .select()
    .from(expenses)
    .where(eq(expenses.groupId, id))
    .orderBy(desc(expenses.createdAt))
    .all();

  // Build a lookup for member names and expense splits
  const memberMap = new Map(groupMembers.map((m) => [m.id, m.name]));

  const expensesWithSplits = groupExpenses.map((expense) => {
    const splits = db
      .select()
      .from(expenseSplits)
      .where(eq(expenseSplits.expenseId, expense.id))
      .all();
    return { ...expense, splits };
  });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold">{group.name}</h1>
        <p className="text-muted-foreground">
          {groupMembers.length} member{groupMembers.length !== 1 && "s"}
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
            <Button type="submit">Add</Button>
          </form>

          {groupMembers.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No members yet. Add some above.
            </p>
          ) : (
            <ul className="divide-y">
              {groupMembers.map((member) => (
                <li
                  key={member.id}
                  className="flex items-center justify-between py-2"
                >
                  <span>{member.name}</span>
                  <form action={deleteMember}>
                    <input type="hidden" name="id" value={member.id} />
                    <input type="hidden" name="groupId" value={id} />
                    <Button variant="ghost" size="sm" type="submit">
                      Remove
                    </Button>
                  </form>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Add Expense</CardTitle>
        </CardHeader>
        <CardContent>
          <ExpenseForm groupId={id} members={groupMembers} />
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
                      <form action={deleteExpense}>
                        <input type="hidden" name="id" value={expense.id} />
                        <input type="hidden" name="groupId" value={id} />
                        <Button variant="ghost" size="sm" type="submit">
                          Delete
                        </Button>
                      </form>
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
  // Calculate net balances: positive = is owed, negative = owes
  const balances = new Map<string, number>();
  for (const [id] of memberMap) {
    balances.set(id, 0);
  }

  for (const expense of expensesWithSplits) {
    // Payer is owed the full amount
    balances.set(expense.paidBy, (balances.get(expense.paidBy) ?? 0) + expense.amount);
    // Each split member owes their share
    for (const split of expense.splits) {
      balances.set(split.memberId, (balances.get(split.memberId) ?? 0) - split.share);
    }
  }

  const transfers = reconcile(balances);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Settle Up</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Balances summary */}
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
                    {balance > 0 ? "+" : ""}${(balance / 100).toFixed(2)}
                  </span>
                </li>
              ))}
          </ul>
        </div>

        {/* Transfers */}
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
                  <span className="font-semibold">
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
