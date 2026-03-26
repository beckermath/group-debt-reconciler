/**
 * Compute net balances from expenses with splits.
 *
 * Positive balance = owed money (paid more than their share).
 * Negative balance = owes money (paid less than their share).
 */
export function computeBalances(
  expensesWithSplits: {
    paidBy: string;
    amount: number;
    splits: { memberId: string; share: number }[];
  }[],
  memberIds: string[]
): Map<string, number> {
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
