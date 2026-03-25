"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { SubmitButton } from "@/components/submit-button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { deleteGroup } from "@/app/actions";

export function DeleteGroupButton({
  groupId,
  groupName,
  hasUnsettledDebts,
  totalExpenses,
  totalMembers,
  transfers,
}: {
  groupId: string;
  groupName: string;
  hasUnsettledDebts: boolean;
  totalExpenses: number;
  totalMembers: number;
  transfers: { fromName: string; toName: string; amount: number }[];
}) {
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button variant="destructive" size="sm">
            Delete group
          </Button>
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete {groupName}?</DialogTitle>
          <DialogDescription>
            {hasUnsettledDebts
              ? "This group has unsettled debts. Deleting it will erase all records permanently."
              : `This will permanently delete the group, ${totalMembers} member${totalMembers !== 1 ? "s" : ""}, and ${totalExpenses} expense${totalExpenses !== 1 ? "s" : ""}. This cannot be undone.`}
          </DialogDescription>
        </DialogHeader>

        {hasUnsettledDebts && transfers.length > 0 && (
          <div className="space-y-2">
            <p className="text-sm font-medium text-muted-foreground">
              Outstanding debts
            </p>
            <ul className="space-y-1.5">
              {transfers.map((t, i) => (
                <li
                  key={i}
                  className="flex items-center justify-between rounded-lg border p-2.5 text-sm"
                >
                  <span>
                    <span className="font-medium">{t.fromName}</span>
                    {" owes "}
                    <span className="font-medium">{t.toName}</span>
                  </span>
                  <span className="font-semibold tabular-nums">
                    ${(t.amount / 100).toFixed(2)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}

        <DialogFooter>
          <form action={deleteGroup} className="w-full">
            <input type="hidden" name="groupId" value={groupId} />
            <SubmitButton variant="destructive" className="w-full">
              {hasUnsettledDebts
                ? "Delete group and erase all debts"
                : "Delete group"}
            </SubmitButton>
          </form>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
