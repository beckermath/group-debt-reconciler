"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createExpense } from "@/app/actions";

type Member = { id: string; name: string };

export function ExpenseForm({
  groupId,
  members,
}: {
  groupId: string;
  members: Member[];
}) {
  const [selectedMembers, setSelectedMembers] = useState<Set<string>>(
    new Set(members.map((m) => m.id))
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

  if (members.length < 2) {
    return (
      <p className="text-sm text-muted-foreground">
        Add at least 2 members to start tracking expenses.
      </p>
    );
  }

  return (
    <form action={createExpense} className="space-y-4">
      <input type="hidden" name="groupId" value={groupId} />
      {Array.from(selectedMembers).map((id) => (
        <input key={id} type="hidden" name="splitWith" value={id} />
      ))}

      <div className="grid grid-cols-2 gap-4">
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
            required
          />
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="paidBy">Paid by</Label>
        <select
          id="paidBy"
          name="paidBy"
          required
          className="w-full rounded-md border px-3 py-2 text-sm"
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
            <button
              key={m.id}
              type="button"
              onClick={() => toggleMember(m.id)}
              className={`rounded-full border px-3 py-1 text-sm transition-colors ${
                selectedMembers.has(m.id)
                  ? "bg-primary text-primary-foreground"
                  : "bg-background text-muted-foreground"
              }`}
            >
              {m.name}
            </button>
          ))}
        </div>
      </div>

      <Button type="submit" disabled={selectedMembers.size === 0}>
        Add Expense
      </Button>
    </form>
  );
}
