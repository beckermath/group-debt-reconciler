"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
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
  const [paidBy, setPaidBy] = useState(members[0]?.id ?? "");

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
      <input type="hidden" name="paidBy" value={paidBy} />
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
        Add Expense
      </Button>
    </form>
  );
}
