"use client";

import { useState, useCallback, useRef } from "react";
import { UserPlus, Search, Check, LoaderCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { searchUsers, sendDirectInvite } from "@/app/actions";

type SearchResult = {
  id: string;
  name: string;
  maskedPhone: string;
};

export function DirectInviteDialog({ groupId }: { groupId: string }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [sentIds, setSentIds] = useState<Set<string>>(new Set());
  const [sendingId, setSendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const queryRef = useRef(query);

  const handleSearch = useCallback(
    (value: string) => {
      setQuery(value);
      queryRef.current = value;
      setError(null);

      if (debounceRef.current) clearTimeout(debounceRef.current);

      if (value.trim().length < 3) {
        setResults([]);
        setSearching(false);
        return;
      }

      setSearching(true);
      debounceRef.current = setTimeout(async () => {
        const res = await searchUsers(value.trim(), groupId);
        // Only update if query hasn't changed
        if (queryRef.current === value) {
          if (res.error) setError(res.error);
          setResults(res.results ?? []);
          setSearching(false);
        }
      }, 300);
    },
    [groupId]
  );

  async function handleInvite(userId: string) {
    setSendingId(userId);
    setError(null);
    const formData = new FormData();
    formData.set("groupId", groupId);
    formData.set("userId", userId);
    const result = await sendDirectInvite(formData);
    setSendingId(null);
    if (result?.error) {
      setError(result.error);
    } else {
      setSentIds((prev) => new Set([...prev, userId]));
    }
  }

  function handleOpenChange(isOpen: boolean) {
    setOpen(isOpen);
    if (!isOpen) {
      setQuery("");
      setResults([]);
      setError(null);
      setSentIds(new Set());
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger
        render={
          <Button variant="outline" size="sm">
            <UserPlus className="size-4" data-icon="inline-start" />
            Invite
          </Button>
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Invite someone to this group</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
            <Input
              placeholder="Search by name or phone number..."
              value={query}
              onChange={(e) => handleSearch(e.target.value)}
              className="pl-9"
              autoFocus
            />
          </div>

          {error && (
            <p className="text-sm text-destructive">{error}</p>
          )}

          {searching && (
            <div className="flex items-center justify-center py-4">
              <LoaderCircle className="size-5 animate-spin text-muted-foreground" />
            </div>
          )}

          {!searching && query.length >= 3 && results.length === 0 && (
            <p className="text-sm text-muted-foreground text-center py-4">
              No users found
            </p>
          )}

          {results.length > 0 && (
            <ul className="divide-y max-h-64 overflow-y-auto">
              {results.map((user) => {
                const isSent = sentIds.has(user.id);
                const isSending = sendingId === user.id;
                return (
                  <li
                    key={user.id}
                    className="flex items-center justify-between py-2.5 gap-3"
                  >
                    <div className="min-w-0">
                      <p className="text-sm font-medium truncate">{user.name}</p>
                      <p className="text-xs text-muted-foreground">{user.maskedPhone}</p>
                    </div>
                    {isSent ? (
                      <span className="inline-flex items-center gap-1 text-xs font-medium text-owed shrink-0">
                        <Check className="size-3.5" />
                        Sent
                      </span>
                    ) : (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleInvite(user.id)}
                        disabled={isSending}
                      >
                        {isSending && <LoaderCircle className="size-3.5 animate-spin" />}
                        Invite
                      </Button>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
