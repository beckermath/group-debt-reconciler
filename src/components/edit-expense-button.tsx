"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Toggle } from "@/components/ui/toggle";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
            <Label>Paid by</Label>
            <Select value={paidBy} onValueChange={(v) => { if (v) setPaidBy(v); }}>
              <SelectTrigger className="w-full">
                <SelectValue>
                  {members.find((m) => m.id === paidBy)?.name ?? "Select member"}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {members.map((m) => (
                  <SelectItem key={m.id} value={m.id}>
                    {m.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
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
