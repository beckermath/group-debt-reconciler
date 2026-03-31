import { db } from "@/db";
import { expenses, expenseSplits } from "@/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { randomUUID } from "crypto";
import { computeSplits, type SplitMode } from "@/lib/splits";
import { validateMembersInGroup } from "./member-service";

export interface CreateExpenseInput {
  groupId: string;
  paidBy: string;
  description: string;
  amountCents: number;
  splitMemberIds: string[];
  splitMode: SplitMode;
  customAmounts: Record<string, string>;
}

export interface UpdateExpenseInput extends CreateExpenseInput {
  expenseId: string;
}

function validateExpenseInput(input: { description: string; amountCents: number; splitMemberIds: string[] }) {
  if (!input.description?.trim()) return "Description is required";
  if (isNaN(input.amountCents) || input.amountCents <= 0) return "Amount must be positive";
  if (input.amountCents > 100_000_00) return "Amount exceeds maximum ($100,000)";
  if (input.splitMemberIds.length === 0) return "At least one member must be included in the split";
  return null;
}

export async function createExpense(input: CreateExpenseInput) {
  const validationError = validateExpenseInput(input);
  if (validationError) return { error: validationError };

  const allMemberIds = [input.paidBy, ...input.splitMemberIds.filter((id) => id !== input.paidBy)];
  if (!(await validateMembersInGroup(allMemberIds, input.groupId))) {
    return { error: "Invalid member IDs" };
  }

  const splits = computeSplits({
    splitMode: input.splitMode,
    memberIds: input.splitMemberIds,
    amountCents: input.amountCents,
    customAmounts: input.customAmounts,
  });
  if (splits.length === 0) return { error: "Invalid split amounts" };

  const expenseId = randomUUID();

  await db.insert(expenses).values({
    id: expenseId,
    groupId: input.groupId,
    paidBy: input.paidBy,
    amount: input.amountCents,
    description: input.description.trim().slice(0, 500),
    createdAt: new Date(),
  });

  for (const split of splits) {
    await db.insert(expenseSplits).values({
      id: randomUUID(),
      expenseId,
      memberId: split.memberId,
      share: split.share,
    });
  }

  return { expenseId };
}

export async function updateExpense(input: UpdateExpenseInput) {
  const [expense] = await db
    .select({ groupId: expenses.groupId })
    .from(expenses)
    .where(eq(expenses.id, input.expenseId));
  if (!expense || expense.groupId !== input.groupId) {
    return { error: "Expense not found in group" };
  }

  const validationError = validateExpenseInput(input);
  if (validationError) return { error: validationError };

  const allMemberIds = [input.paidBy, ...input.splitMemberIds.filter((id) => id !== input.paidBy)];
  if (!(await validateMembersInGroup(allMemberIds, input.groupId))) {
    return { error: "Invalid member IDs" };
  }

  const splits = computeSplits({
    splitMode: input.splitMode,
    memberIds: input.splitMemberIds,
    amountCents: input.amountCents,
    customAmounts: input.customAmounts,
  });
  if (splits.length === 0) return { error: "Invalid split amounts" };

  await db
    .update(expenses)
    .set({
      paidBy: input.paidBy,
      amount: input.amountCents,
      description: input.description.trim().slice(0, 500),
    })
    .where(eq(expenses.id, input.expenseId));

  await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, input.expenseId));

  for (const split of splits) {
    await db.insert(expenseSplits).values({
      id: randomUUID(),
      expenseId: input.expenseId,
      memberId: split.memberId,
      share: split.share,
    });
  }

  return { expenseId: input.expenseId };
}

export async function deleteExpense(expenseId: string, groupId: string) {
  const [expense] = await db
    .select({ groupId: expenses.groupId })
    .from(expenses)
    .where(eq(expenses.id, expenseId));
  if (!expense || expense.groupId !== groupId) {
    return { error: "Expense not found in group" };
  }

  await db.delete(expenseSplits).where(eq(expenseSplits.expenseId, expenseId));
  await db.delete(expenses).where(eq(expenses.id, expenseId));
  return {};
}

export async function getExpense(expenseId: string, groupId: string) {
  const [expense] = await db
    .select()
    .from(expenses)
    .where(and(eq(expenses.id, expenseId), eq(expenses.groupId, groupId)));
  return expense ?? null;
}

export async function getGroupExpensesWithSplits(groupId: string) {
  const allExpenses = await db
    .select()
    .from(expenses)
    .where(eq(expenses.groupId, groupId))
    .orderBy(desc(expenses.createdAt));

  return Promise.all(
    allExpenses.map(async (expense) => {
      const splits = await db
        .select()
        .from(expenseSplits)
        .where(eq(expenseSplits.expenseId, expense.id));
      return { ...expense, splits };
    })
  );
}
