"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { SubmitButton } from "@/components/submit-button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Toggle } from "@/components/ui/toggle";
import { Switch } from "@/components/ui/switch";
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
    splits: { memberId: string; share: number }[];
  };
  groupId: string;
  members: Member[];
}) {
  const [open, setOpen] = useState(false);
  const [paidBy, setPaidBy] = useState(expense.paidBy);
  const [amount, setAmount] = useState((expense.amount / 100).toFixed(2));
  const [selectedMembers, setSelectedMembers] = useState<Set<string>>(
    new Set(expense.splits.map((s) => s.memberId))
  );

  function detectCustomSplit() {
    const shares = expense.splits.map((s) => s.share);
    return shares.length > 0 && !shares.every((s) => Math.abs(s - shares[0]) <= 1);
  }

  const [isCustomSplit, setIsCustomSplit] = useState(detectCustomSplit);
  const [customAmounts, setCustomAmounts] = useState<Record<string, string>>(() => {
    const amounts: Record<string, string> = {};
    for (const s of expense.splits) {
      amounts[s.memberId] = (s.share / 100).toFixed(2);
    }
    return amounts;
  });

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

  function setCustomAmount(memberId: string, value: string) {
    setCustomAmounts((prev) => ({ ...prev, [memberId]: value }));
  }

  const amountCents = Math.round((parseFloat(amount) || 0) * 100);
  const customTotalCents = Array.from(selectedMembers).reduce((sum, id) => {
    return sum + Math.round((parseFloat(customAmounts[id] || "0") || 0) * 100);
  }, 0);
  const remainingCents = amountCents - customTotalCents;

  function distributeRemaining() {
    const selected = Array.from(selectedMembers);
    const unassigned = selected.filter((id) => {
      const val = parseFloat(customAmounts[id] || "0") || 0;
      return Math.round(val * 100) === 0;
    });
    const targets = unassigned.length > 0 ? unassigned : selected;
    if (targets.length === 0 || remainingCents <= 0) return;

    const perMember = Math.floor(remainingCents / targets.length);
    const pennies = remainingCents - perMember * targets.length;

    const updated = { ...customAmounts };
    targets.forEach((id, i) => {
      const existing = Math.round((parseFloat(updated[id] || "0") || 0) * 100);
      const add = perMember + (i < pennies ? 1 : 0);
      updated[id] = ((existing + add) / 100).toFixed(2);
    });
    setCustomAmounts(updated);
  }

  const isCustomBalanced = isCustomSplit && remainingCents === 0 && amountCents > 0;
  const canSubmit = selectedMembers.size > 0 && (!isCustomSplit || isCustomBalanced);

  function handleOpenChange(isOpen: boolean) {
    setOpen(isOpen);
    if (isOpen) {
      setPaidBy(expense.paidBy);
      setAmount((expense.amount / 100).toFixed(2));
      setSelectedMembers(new Set(expense.splits.map((s) => s.memberId)));
      setIsCustomSplit(detectCustomSplit());
      const amounts: Record<string, string> = {};
      for (const s of expense.splits) {
        amounts[s.memberId] = (s.share / 100).toFixed(2);
      }
      setCustomAmounts(amounts);
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
          <input type="hidden" name="splitMode" value={isCustomSplit ? "custom" : "equal"} />
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
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
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
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={selectAll}
                  className="text-xs text-muted-foreground hover:underline"
                >
                  Select all
                </button>
                <div className="flex items-center gap-1.5">
                  <Label htmlFor="edit-split-mode" className="text-xs text-muted-foreground font-normal">
                    Custom
                  </Label>
                  <Switch
                    id="edit-split-mode"
                    checked={isCustomSplit}
                    onCheckedChange={setIsCustomSplit}
                  />
                </div>
              </div>
            </div>

            {!isCustomSplit ? (
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
            ) : (
              <div className="space-y-2">
                {members.map((m) => (
                  <div key={m.id} className="flex items-center gap-2 h-8">
                    <Toggle
                      variant="outline"
                      size="sm"
                      pressed={selectedMembers.has(m.id)}
                      onPressedChange={() => toggleMember(m.id)}
                      className="w-24 justify-start shrink-0 h-8"
                    >
                      {m.name}
                    </Toggle>
                    <div className="w-28">
                      {selectedMembers.has(m.id) && (
                        <Input
                          name={`splitAmount_${m.id}`}
                          type="number"
                          step="0.01"
                          min="0"
                          placeholder="0.00"
                          value={customAmounts[m.id] ?? ""}
                          onChange={(e) => setCustomAmount(m.id, e.target.value)}
                          className="h-8"
                        />
                      )}
                    </div>
                  </div>
                ))}
                <div className="flex items-center justify-between">
                  <p className={`text-xs font-medium tabular-nums ${
                    remainingCents === 0 && amountCents > 0
                      ? "text-green-600"
                      : remainingCents < 0
                        ? "text-destructive"
                        : "text-muted-foreground"
                  }`}>
                    Remaining: ${(remainingCents / 100).toFixed(2)}
                  </p>
                  {remainingCents > 0 && (
                    <button
                      type="button"
                      onClick={distributeRemaining}
                      className="text-xs text-primary hover:underline"
                    >
                      Distribute remaining
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>

          <SubmitButton className="w-full" disabled={!canSubmit}>
            Save changes
          </SubmitButton>
        </form>
      </DialogContent>
    </Dialog>
  );
}
