"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
import { deleteAccount } from "./actions";

export function DeleteAccountSection() {
  const [open, setOpen] = useState(false);
  const [confirmation, setConfirmation] = useState("");

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        Permanently delete your account and all associated data. Groups where you
        are the only member will be deleted. Your membership in shared groups will
        be removed.
      </p>

      <Dialog open={open} onOpenChange={(isOpen) => { setOpen(isOpen); setConfirmation(""); }}>
        <DialogTrigger
          render={
            <Button variant="destructive" size="sm">
              Delete account
            </Button>
          }
        />
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete your account?</DialogTitle>
            <DialogDescription>
              This action is permanent and cannot be undone. All your data will be
              deleted.
            </DialogDescription>
          </DialogHeader>

          <form action={deleteAccount} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="confirmation">
                Type <span className="font-mono font-semibold">DELETE</span> to confirm
              </Label>
              <Input
                id="confirmation"
                name="confirmation"
                value={confirmation}
                onChange={(e) => setConfirmation(e.target.value)}
                placeholder="DELETE"
              />
            </div>

            <DialogFooter>
              <SubmitButton
                variant="destructive"
                className="w-full"
                disabled={confirmation !== "DELETE"}
              >
                Permanently delete account
              </SubmitButton>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
