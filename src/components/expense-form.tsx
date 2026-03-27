"use client";

import { useState, useRef } from "react";
import { SubmitButton } from "@/components/submit-button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Toggle } from "@/components/ui/toggle";
import { Switch } from "@/components/ui/switch";
import { createExpense } from "@/app/actions";

type Member = { id: string; name: string };

export function ExpenseForm({
  groupId,
  members,
  onSuccess,
}: {
  groupId: string;
  members: Member[];
  onSuccess?: () => void;
}) {
  const [selectedMembers, setSelectedMembers] = useState<Set<string>>(
    new Set(members.map((m) => m.id))
  );
  const [paidBy, setPaidBy] = useState(members[0]?.id ?? "");
  const [isCustomSplit, setIsCustomSplit] = useState(false);
  const [customAmounts, setCustomAmounts] = useState<Record<string, string>>({});
  const [amount, setAmount] = useState("");

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
    // Find members without a custom amount (empty or zero)
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
  const formRef = useRef<HTMLFormElement>(null);

  async function handleAction(formData: FormData) {
    await createExpense(formData);
    formRef.current?.reset();
    setAmount("");
    setCustomAmounts({});
    setSelectedMembers(new Set(members.map((m) => m.id)));
    setIsCustomSplit(false);
    onSuccess?.();
  }

  if (members.length < 2) {
    return (
      <p className="text-sm text-muted-foreground">
        Add at least 2 members to start tracking expenses.
      </p>
    );
  }

  return (
    <form ref={formRef} action={handleAction} className="space-y-4">
      <input type="hidden" name="groupId" value={groupId} />
      <input type="hidden" name="paidBy" value={paidBy} />
      <input type="hidden" name="splitMode" value={isCustomSplit ? "custom" : "equal"} />
      {Array.from(selectedMembers).map((id) => (
        <input key={id} type="hidden" name="splitWith" value={id} />
      ))}

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="description">Description</Label>
          <Input id="description" name="description" placeholder="Dinner, taxi..." required />
        </div>
        <div className="space-y-2">
          <Label htmlFor="amount">Amount ($)</Label>
          <Input
            id="amount"
            name="amount"
            type="number"
            step="0.01"
            min="0.01"
            placeholder="0.00"
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
              <Label htmlFor="split-mode" className="text-xs text-muted-foreground font-normal">
                Custom
              </Label>
              <Switch
                id="split-mode"
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
                  className="min-w-20 justify-start shrink-0 h-8"
                >
                  {m.name}
                </Toggle>
                <div className="w-24 sm:w-28 shrink-0">
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
        Add Expense
      </SubmitButton>
    </form>
  );
}
