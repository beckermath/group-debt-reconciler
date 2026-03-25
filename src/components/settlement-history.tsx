"use client";

import { useState } from "react";
import { ChevronRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SubmitButton } from "@/components/submit-button";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
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
  const [expanded, setExpanded] = useState(false);
  const [expandedPeriods, setExpandedPeriods] = useState<Set<string>>(new Set());

  if (settlements.length === 0) return null;

  function togglePeriod(id: string) {
    setExpandedPeriods((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <Card>
      <Collapsible open={expanded} onOpenChange={setExpanded}>
        <CardHeader>
          <CollapsibleTrigger className="flex items-center justify-between w-full cursor-pointer">
            <CardTitle>Settlement History</CardTitle>
            <div className="flex items-center gap-1 text-sm text-muted-foreground">
              <span>
                {settlements.length} settlement{settlements.length !== 1 && "s"}
              </span>
              <ChevronRight
                className={`size-4 transition-transform duration-200 ${expanded ? "rotate-90" : ""}`}
              />
            </div>
          </CollapsibleTrigger>
        </CardHeader>

        <CollapsibleContent className="mt-4">
          <CardContent className="space-y-4">
            {settlements.map((settlement, index) => {
              const periodExpenses = expensesBySettlement[settlement.id] ?? [];
              const isPeriodExpanded = expandedPeriods.has(settlement.id);
              const isLatest = index === 0;

              return (
                <div key={settlement.id} className="rounded-lg border p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium">
                        {settlement.settledAt.toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        Settled by {settlement.settledByName}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      {isLatest && isOwner && (
                        <form action={undoSettlement}>
                          <input type="hidden" name="groupId" value={groupId} />
                          <input type="hidden" name="settlementId" value={settlement.id} />
                          <SubmitButton variant="ghost" size="sm">
                            Undo
                          </SubmitButton>
                        </form>
                      )}
                      {periodExpenses.length > 0 && (
                        <button
                          onClick={() => togglePeriod(settlement.id)}
                          className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground cursor-pointer"
                        >
                          <span>
                            {periodExpenses.length} expense{periodExpenses.length !== 1 ? "s" : ""}
                          </span>
                          <ChevronRight
                            className={`size-3.5 transition-transform duration-200 ${isPeriodExpanded ? "rotate-90" : ""}`}
                          />
                        </button>
                      )}
                    </div>
                  </div>

                  {isPeriodExpanded && periodExpenses.length > 0 && (
                    <ul className="divide-y mt-4 pt-3 border-t">
                      {periodExpenses.map((expense) => (
                        <li key={expense.id} className="py-3 text-sm">
                          <div className="flex justify-between">
                            <span>{expense.description}</span>
                            <span className="tabular-nums font-medium">
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
                </div>
              );
            })}
          </CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  );
}
