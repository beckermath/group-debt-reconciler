"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { softDeleteMember, deleteMember } from "@/app/actions";

export function RemoveMemberButton({
  member,
  groupId,
  balanceCents,
  expensesPaidCount,
  expensesSplitCount,
}: {
  member: { id: string; name: string };
  groupId: string;
  balanceCents: number;
  expensesPaidCount: number;
  expensesSplitCount: number;
}) {
  const [open, setOpen] = useState(false);
  const hasFinancialInvolvement =
    balanceCents !== 0 || expensesPaidCount > 0 || expensesSplitCount > 0;

  const balanceLabel =
    balanceCents > 0
      ? `is owed $${(balanceCents / 100).toFixed(2)}`
      : balanceCents < 0
        ? `owes $${(Math.abs(balanceCents) / 100).toFixed(2)}`
        : "is settled up";

  if (!hasFinancialInvolvement) {
    return (
      <form action={softDeleteMember}>
        <input type="hidden" name="id" value={member.id} />
        <input type="hidden" name="groupId" value={groupId} />
        <Button variant="destructive" size="sm" type="submit">
          Remove
        </Button>
      </form>
    );
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button variant="destructive" size="sm">
            Remove
          </Button>
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Remove {member.name}?</DialogTitle>
          <DialogDescription>
            {member.name} {balanceLabel} and is involved in{" "}
            {expensesPaidCount + expensesSplitCount} expense
            {expensesPaidCount + expensesSplitCount !== 1 && "s"}.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 text-sm">
          {expensesPaidCount > 0 && (
            <p>
              Paid for <span className="font-medium">{expensesPaidCount}</span>{" "}
              expense{expensesPaidCount !== 1 && "s"}
            </p>
          )}
          {expensesSplitCount > 0 && (
            <p>
              Included in{" "}
              <span className="font-medium">{expensesSplitCount}</span> expense
              split{expensesSplitCount !== 1 && "s"}
            </p>
          )}
        </div>

        <DialogFooter className="flex flex-col gap-2 sm:flex-col">
          <form action={softDeleteMember} className="w-full">
            <input type="hidden" name="id" value={member.id} />
            <input type="hidden" name="groupId" value={groupId} />
            <Button type="submit" className="w-full">
              Remove member
            </Button>
            <p className="mt-1 text-xs text-muted-foreground">
              Expenses and balances are preserved
            </p>
          </form>

          <form action={deleteMember} className="w-full">
            <input type="hidden" name="id" value={member.id} />
            <input type="hidden" name="groupId" value={groupId} />
            <Button type="submit" variant="destructive" className="w-full">
              Remove and delete all data
            </Button>
            <p className="mt-1 text-xs text-muted-foreground">
              Permanently deletes all expense data for this member
            </p>
          </form>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
