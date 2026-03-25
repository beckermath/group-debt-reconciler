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
import { settleUp } from "@/app/actions";

export function SettleUpButton({
  groupId,
  transfers,
}: {
  groupId: string;
  transfers: { fromName: string; toName: string; amount: number }[];
}) {
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button size="sm">
            Settle Up
          </Button>
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Settle all debts?</DialogTitle>
          <DialogDescription>
            This will mark all current debts as settled. New expenses will start
            with a clean slate.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-2">
          <p className="text-sm font-medium text-muted-foreground">
            Debts being settled
          </p>
          <ul className="space-y-1.5">
            {transfers.map((t, i) => (
              <li
                key={i}
                className="flex items-center justify-between rounded-lg border p-2.5 text-sm"
              >
                <span>
                  <span className="font-medium">{t.fromName}</span>
                  {" pays "}
                  <span className="font-medium">{t.toName}</span>
                </span>
                <span className="font-semibold tabular-nums">
                  ${(t.amount / 100).toFixed(2)}
                </span>
              </li>
            ))}
          </ul>
        </div>

        <DialogFooter>
          <form action={settleUp} className="w-full">
            <input type="hidden" name="groupId" value={groupId} />
            <SubmitButton className="w-full">
              Confirm settlement
            </SubmitButton>
          </form>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
