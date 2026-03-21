export type Transfer = {
  from: string;
  to: string;
  amount: number; // cents
};

/**
 * Given net balances (positive = owed money, negative = owes money),
 * compute the minimum set of transfers to settle all debts.
 */
export function reconcile(
  balances: Map<string, number>
): Transfer[] {
  const debtors: { id: string; amount: number }[] = [];
  const creditors: { id: string; amount: number }[] = [];

  for (const [id, balance] of balances) {
    if (balance < 0) debtors.push({ id, amount: -balance });
    else if (balance > 0) creditors.push({ id, amount: balance });
  }

  // Sort largest first for greedy matching
  debtors.sort((a, b) => b.amount - a.amount);
  creditors.sort((a, b) => b.amount - a.amount);

  const transfers: Transfer[] = [];
  let i = 0;
  let j = 0;

  while (i < debtors.length && j < creditors.length) {
    const amount = Math.min(debtors[i].amount, creditors[j].amount);
    transfers.push({
      from: debtors[i].id,
      to: creditors[j].id,
      amount,
    });
    debtors[i].amount -= amount;
    creditors[j].amount -= amount;
    if (debtors[i].amount === 0) i++;
    if (creditors[j].amount === 0) j++;
  }

  return transfers;
}
