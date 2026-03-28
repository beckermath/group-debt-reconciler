"use client";

import { useState, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { UserPlus, Search, Check, LoaderCircle, Link2, Copy } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { searchUsers, sendDirectInvite, addMemberQuiet, createInviteLink } from "@/app/actions";

type SearchResult = {
  id: string;
  name: string;
  maskedPhone: string;
};

export function AddPeopleDialog({
  groupId,
  variant = "header",
}: {
  groupId: string;
  variant?: "header" | "inline";
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [sentIds, setSentIds] = useState<Set<string>>(new Set());
  const [sendingId, setSendingId] = useState<string | null>(null);
  const [guestName, setGuestName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Invite link state
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [linkLoading, setLinkLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const queryRef = useRef(query);

  const handleSearch = useCallback(
    (value: string) => {
      setQuery(value);
      queryRef.current = value;
      setError(null);
      setSuccess(null);

      if (debounceRef.current) clearTimeout(debounceRef.current);

      if (value.trim().length < 3) {
        setResults([]);
        setSearching(false);
        return;
      }

      setSearching(true);
      debounceRef.current = setTimeout(async () => {
        const res = await searchUsers(value.trim(), groupId);
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
    setSuccess(null);
    const formData = new FormData();
    formData.set("groupId", groupId);
    formData.set("userId", userId);
    const result = await sendDirectInvite(formData);
    setSendingId(null);
    if (result?.error) {
      setError(result.error);
    } else {
      setSentIds((prev) => new Set([...prev, userId]));
      setSuccess("Invite sent!");
    }
  }

  async function handleAddGuest() {
    if (!guestName.trim()) return;
    setError(null);
    setSuccess(null);
    const result = await addMemberQuiet(groupId, guestName.trim());
    if (result.error) {
      setError(result.error);
    } else {
      setSuccess(`${guestName.trim()} added as guest`);
      setGuestName("");
      router.refresh();
    }
  }

  async function handleGenerateLink() {
    setLinkLoading(true);
    setError(null);
    const formData = new FormData();
    formData.set("groupId", groupId);
    const result = await createInviteLink(formData);
    if (result && "code" in result) {
      const url = `${window.location.origin}/invite/${result.code}`;
      setInviteUrl(url);
    }
    setLinkLoading(false);
  }

  async function handleCopy() {
    if (!inviteUrl) return;
    await navigator.clipboard.writeText(inviteUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  function handleOpenChange(isOpen: boolean) {
    setOpen(isOpen);
    if (!isOpen) {
      setQuery("");
      setResults([]);
      setError(null);
      setSuccess(null);
      setSentIds(new Set());
      setGuestName("");
      setInviteUrl(null);
      setCopied(false);
    }
  }

  const hasSearchResults = query.length >= 3 && !searching;
  const showGuestFallback = hasSearchResults && results.length === 0;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger
        render={
          variant === "header" ? (
            <Button variant="outline" size="sm">
              <UserPlus className="size-4" data-icon="inline-start" />
              Add people
            </Button>
          ) : (
            <Button variant="outline" size="sm">
              <UserPlus className="size-4" data-icon="inline-start" />
              Add people
            </Button>
          )
        }
      />
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add people</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
            <Input
              placeholder="Search by name or phone..."
              value={query}
              onChange={(e) => handleSearch(e.target.value)}
              className="pl-9"
              autoFocus
            />
          </div>

          {/* Feedback */}
          {error && <p className="text-sm text-destructive">{error}</p>}
          {success && <p className="text-sm text-owed">{success}</p>}

          {/* Search results */}
          {searching && (
            <div className="flex items-center justify-center py-3">
              <LoaderCircle className="size-5 animate-spin text-muted-foreground" />
            </div>
          )}

          {results.length > 0 && (
            <ul className="divide-y max-h-48 overflow-y-auto">
              {results.map((user) => {
                const isSent = sentIds.has(user.id);
                const isSending = sendingId === user.id;
                return (
                  <li key={user.id} className="flex items-center justify-between py-2.5 gap-3">
                    <div className="min-w-0">
                      <p className="text-sm font-medium truncate">{user.name}</p>
                      <p className="text-xs text-muted-foreground">{user.maskedPhone}</p>
                    </div>
                    {isSent ? (
                      <span className="inline-flex items-center gap-1 text-xs font-medium text-owed shrink-0">
                        <Check className="size-3.5" />
                        Invited
                      </span>
                    ) : (
                      <Button variant="outline" size="sm" onClick={() => handleInvite(user.id)} disabled={isSending}>
                        {isSending && <LoaderCircle className="size-3.5 animate-spin" />}
                        Invite
                      </Button>
                    )}
                  </li>
                );
              })}
            </ul>
          )}

          {/* No results — show guest fallback */}
          {showGuestFallback && (
            <p className="text-xs text-muted-foreground text-center py-1">
              No users found for &ldquo;{query}&rdquo;
            </p>
          )}

          {/* Divider */}
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="bg-background px-2 text-muted-foreground">or</span>
            </div>
          </div>

          {/* Add as guest */}
          <div className="space-y-2">
            <Label className="text-xs text-muted-foreground">Add someone without a Rekn account</Label>
            <div className="flex gap-2">
              <Input
                placeholder="Guest name"
                value={guestName}
                onChange={(e) => setGuestName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    handleAddGuest();
                  }
                }}
              />
              <Button variant="secondary" onClick={handleAddGuest} disabled={!guestName.trim()}>
                Add
              </Button>
            </div>
          </div>

          {/* Divider */}
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="bg-background px-2 text-muted-foreground">or</span>
            </div>
          </div>

          {/* Invite link */}
          {inviteUrl ? (
            <div className="flex gap-2">
              <Input value={inviteUrl} readOnly className="text-xs" />
              <Button variant="outline" size="sm" onClick={handleCopy}>
                {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
              </Button>
            </div>
          ) : (
            <Button variant="ghost" size="sm" className="w-full" onClick={handleGenerateLink} disabled={linkLoading}>
              <Link2 className="size-4" data-icon="inline-start" />
              {linkLoading ? "Generating..." : "Generate invite link"}
            </Button>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
