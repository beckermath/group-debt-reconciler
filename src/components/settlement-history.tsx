"use client";

import { useState } from "react";
import { SubmitButton } from "@/components/submit-button";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { undoSettlement } from "@/app/actions";

type Settlement = {
  id: string;
  settledAt: Date;
  settledByName: string;
};

type Expense = {
  id: string;
  description: string;
  amount: number;
  paidByName: string;
  splitCount: number;
};

export function SettlementHistory({
  groupId,
  settlements,
  expensesBySettlement,
  isOwner,
}: {
  groupId: string;
  settlements: Settlement[];
  expensesBySettlement: Record<string, Expense[]>;
  isOwner: boolean;
}) {
  const [viewingSettlementId, setViewingSettlementId] = useState<string | null>(null);

  if (settlements.length === 0) return null;

  const viewingExpenses = viewingSettlementId
    ? expensesBySettlement[viewingSettlementId] ?? []
    : [];
  const viewingSettlement = viewingSettlementId
    ? settlements.find((s) => s.id === viewingSettlementId)
    : null;

  return (
    <>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-muted-foreground">
              <th scope="col" className="pb-2 font-medium">Date</th>
              <th scope="col" className="pb-2 font-medium">Settled by</th>
              <th scope="col" className="pb-2 font-medium text-right">Expenses</th>
              <th scope="col" className="pb-2 font-medium text-right">Total</th>
              <th scope="col" className="pb-2 font-medium text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {settlements.map((settlement, index) => {
              const periodExpenses = expensesBySettlement[settlement.id] ?? [];
              const totalCents = periodExpenses.reduce((sum, e) => sum + e.amount, 0);
              const isLatest = index === 0;

              return (
                <tr key={settlement.id} className="group">
                  <td className="py-3 whitespace-nowrap">
                    {settlement.settledAt.toLocaleDateString("en-US", {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </td>
                  <td className="py-3">{settlement.settledByName}</td>
                  <td className="py-3 text-right tabular-nums">
                    {periodExpenses.length}
                  </td>
                  <td className="py-3 text-right font-medium tabular-nums">
                    ${(totalCents / 100).toFixed(2)}
                  </td>
                  <td className="py-3 text-right">
                    <div className="flex items-center justify-end gap-1">
                      {periodExpenses.length > 0 && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setViewingSettlementId(settlement.id)}
                        >
                          View
                        </Button>
                      )}
                      {isLatest && isOwner && (
                        <form action={undoSettlement}>
                          <input type="hidden" name="groupId" value={groupId} />
                          <input type="hidden" name="settlementId" value={settlement.id} />
                          <SubmitButton variant="ghost" size="sm">
                            Undo
                          </SubmitButton>
                        </form>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <Dialog
        open={viewingSettlementId !== null}
        onOpenChange={(open) => { if (!open) setViewingSettlementId(null); }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              Settlement &mdash;{" "}
              {viewingSettlement?.settledAt.toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
                year: "numeric",
              })}
            </DialogTitle>
          </DialogHeader>
          {viewingExpenses.length > 0 && (
            <ul className="divide-y max-h-80 overflow-y-auto">
              {viewingExpenses.map((expense) => (
                <li key={expense.id} className="py-3 text-sm">
                  <div className="flex justify-between">
                    <span className="truncate">{expense.description}</span>
                    <span className="tabular-nums font-medium shrink-0 ml-2">
                      ${(expense.amount / 100).toFixed(2)}
                    </span>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {expense.paidByName} paid &middot; split {expense.splitCount} way
                    {expense.splitCount !== 1 && "s"}
                  </p>
                </li>
              ))}
            </ul>
          )}
          <DialogFooter showCloseButton />
        </DialogContent>
      </Dialog>
    </>
  );
}
