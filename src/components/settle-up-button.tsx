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

  const totalCents = transfers.reduce((sum, t) => sum + t.amount, 0);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button size="sm" className="bg-accent text-accent-foreground shadow-[inset_0_1px_0_oklch(1_0_0/15%)] hover:bg-accent/90 hover:shadow-[inset_0_1px_0_oklch(1_0_0/15%),0_2px_8px_oklch(0.58_0.26_330/25%)] dark:hover:shadow-[inset_0_1px_0_oklch(1_0_0/15%),0_2px_12px_oklch(0.60_0.20_332/30%)]">
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
          <div className="flex items-center justify-between">
            <p className="text-sm font-medium text-muted-foreground">
              {transfers.length} payment{transfers.length !== 1 && "s"} to settle
            </p>
            <p className="text-sm font-semibold tabular-nums">
              ${(totalCents / 100).toFixed(2)} total
            </p>
          </div>
          <ul className="space-y-1.5">
            {transfers.map((t, i) => (
              <li
                key={i}
                className="flex items-center justify-between gap-2 rounded-lg border p-2.5 text-sm"
              >
                <span className="min-w-0 truncate">
                  <span className="font-medium">{t.fromName}</span>
                  {" pays "}
                  <span className="font-medium">{t.toName}</span>
                </span>
                <span className="font-semibold tabular-nums shrink-0">
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
