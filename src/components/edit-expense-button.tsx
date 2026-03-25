"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Toggle } from "@/components/ui/toggle";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { updateExpense } from "@/app/actions";

type Member = { id: string; name: string };

export function EditExpenseButton({
  expense,
  groupId,
  members,
}: {
  expense: {
    id: string;
    paidBy: string;
    amount: number;
    description: string;
    splits: { memberId: string }[];
  };
  groupId: string;
  members: Member[];
}) {
  const [open, setOpen] = useState(false);
  const [paidBy, setPaidBy] = useState(expense.paidBy);
  const [selectedMembers, setSelectedMembers] = useState<Set<string>>(
    new Set(expense.splits.map((s) => s.memberId))
  );

  function toggleMember(id: string) {
    setSelectedMembers((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function selectAll() {
    setSelectedMembers(new Set(members.map((m) => m.id)));
  }

  function handleOpenChange(isOpen: boolean) {
    setOpen(isOpen);
    if (isOpen) {
      // Reset to current expense values when opening
      setPaidBy(expense.paidBy);
      setSelectedMembers(new Set(expense.splits.map((s) => s.memberId)));
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger
        render={
          <Button variant="ghost" size="sm">
            Edit
          </Button>
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit expense</DialogTitle>
        </DialogHeader>

        <form action={updateExpense} className="space-y-4">
          <input type="hidden" name="expenseId" value={expense.id} />
          <input type="hidden" name="groupId" value={groupId} />
          <input type="hidden" name="paidBy" value={paidBy} />
          {Array.from(selectedMembers).map((id) => (
            <input key={id} type="hidden" name="splitWith" value={id} />
          ))}

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="edit-description">Description</Label>
              <Input
                id="edit-description"
                name="description"
                defaultValue={expense.description}
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-amount">Amount ($)</Label>
              <Input
                id="edit-amount"
                name="amount"
                type="number"
                step="0.01"
                min="0.01"
                defaultValue={(expense.amount / 100).toFixed(2)}
                required
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="edit-paidBy">Paid by</Label>
            <select
              id="edit-paidBy"
              value={paidBy}
              onChange={(e) => setPaidBy(e.target.value)}
              className="h-8 w-full rounded-lg border border-input bg-transparent px-3 py-1.5 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30 dark:hover:bg-input/50"
            >
              {members.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.name}
                </option>
              ))}
            </select>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label>Split between</Label>
              <button
                type="button"
                onClick={selectAll}
                className="text-xs text-muted-foreground hover:underline"
              >
                Select all
              </button>
            </div>
            <div className="flex flex-wrap gap-2">
              {members.map((m) => (
                <Toggle
                  key={m.id}
                  variant="outline"
                  size="sm"
                  pressed={selectedMembers.has(m.id)}
                  onPressedChange={() => toggleMember(m.id)}
                >
                  {m.name}
                </Toggle>
              ))}
            </div>
          </div>

          <Button type="submit" className="w-full" disabled={selectedMembers.size === 0}>
            Save changes
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
