"use client";

import { useState } from "react";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { ExpenseForm } from "@/components/expense-form";

type Member = { id: string; name: string };

export function AddExpenseDialog({
  groupId,
  members,
  currentMemberId,
  isGuest,
}: {
  groupId: string;
  members: Member[];
  currentMemberId?: string;
  isGuest?: boolean;
}) {
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button variant="outline" size="sm">
            <Plus className="size-4" data-icon="inline-start" />
            Add Expense
          </Button>
        }
      />
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Add Expense</DialogTitle>
        </DialogHeader>
        <ExpenseForm groupId={groupId} members={members} currentMemberId={currentMemberId} isGuest={isGuest} onSuccess={() => setOpen(false)} />
      </DialogContent>
    </Dialog>
  );
}
