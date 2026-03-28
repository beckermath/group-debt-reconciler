"use client";

import { useState, useRef, useTransition, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { renameGroup, addMembersInBatch, searchUsers, sendDirectInvite, createInviteLink } from "@/app/actions";
import { X, LoaderCircle, ChevronLeft, Search, Check, Link2, Copy } from "lucide-react";

type SearchResult = { id: string; name: string; maskedPhone: string };

export default function GroupSetupPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [groupName, setGroupName] = useState("New Group");
  const [isEditingName, setIsEditingName] = useState(true);
  const [guestNames, setGuestNames] = useState<string[]>([]);
  const [invitedUsers, setInvitedUsers] = useState<{ id: string; name: string }[]>([]);
  const [currentName, setCurrentName] = useState("");
  const [isPending, startTransition] = useTransition();

  // Search state
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [sentIds, setSentIds] = useState<Set<string>>(new Set());
  const [sendingId, setSendingId] = useState<string | null>(null);

  // Invite link state
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [linkLoading, setLinkLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const nameInputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const queryRef = useRef(searchQuery);

  useEffect(() => {
    nameInputRef.current?.focus();
    nameInputRef.current?.select();
  }, []);

  function handleNameBlur() {
    const trimmed = groupName.trim();
    if (!trimmed) {
      setGroupName("New Group");
      return;
    }
    setIsEditingName(false);
    startTransition(async () => {
      await renameGroup(id, trimmed);
    });
  }

  function handleNameKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") {
      e.preventDefault();
      nameInputRef.current?.blur();
    }
  }

  // Search
  const handleSearch = useCallback(
    (value: string) => {
      setSearchQuery(value);
      queryRef.current = value;
      if (debounceRef.current) clearTimeout(debounceRef.current);

      if (value.trim().length < 3) {
        setSearchResults([]);
        setSearching(false);
        return;
      }

      setSearching(true);
      debounceRef.current = setTimeout(async () => {
        const res = await searchUsers(value.trim(), id);
        if (queryRef.current === value) {
          setSearchResults(res.results ?? []);
          setSearching(false);
        }
      }, 300);
    },
    [id]
  );

  async function handleInviteUser(user: SearchResult) {
    setSendingId(user.id);
    const formData = new FormData();
    formData.set("groupId", id);
    formData.set("userId", user.id);
    const result = await sendDirectInvite(formData);
    setSendingId(null);
    if (!result?.error) {
      setSentIds((prev) => new Set([...prev, user.id]));
      setInvitedUsers((prev) => [...prev, { id: user.id, name: user.name }]);
      setSearchQuery("");
      setSearchResults([]);
    }
  }

  // Guest names
  function addGuestToList() {
    const trimmed = currentName.trim();
    if (!trimmed) return;
    setGuestNames((prev) => [...prev, trimmed]);
    setCurrentName("");
  }

  function removeGuest(index: number) {
    setGuestNames((prev) => prev.filter((_, i) => i !== index));
  }

  function removeInvited(userId: string) {
    setInvitedUsers((prev) => prev.filter((u) => u.id !== userId));
  }

  // Invite link
  async function handleGenerateLink() {
    setLinkLoading(true);
    const formData = new FormData();
    formData.set("groupId", id);
    const result = await createInviteLink(formData);
    if (result && "code" in result) {
      setInviteUrl(`${window.location.origin}/invite/${result.code}`);
    }
    setLinkLoading(false);
  }

  async function handleCopy() {
    if (!inviteUrl) return;
    await navigator.clipboard.writeText(inviteUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  // Finish
  function handleFinish() {
    startTransition(async () => {
      if (guestNames.length > 0) {
        await addMembersInBatch(id, guestNames);
      } else {
        router.push(`/group/${id}`);
      }
    });
  }

  const totalAdded = guestNames.length + invitedUsers.length;

  return (
    <div className="space-y-6 max-w-lg mx-auto">
      <div>
        <button
          onClick={() => router.push("/")}
          className="inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground cursor-pointer"
        >
          <ChevronLeft className="size-4" />
          All groups
        </button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Create your group</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Group name */}
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="group-name">
              Group name
            </label>
            {isEditingName ? (
              <Input
                id="group-name"
                ref={nameInputRef}
                value={groupName}
                onChange={(e) => setGroupName(e.target.value)}
                onBlur={handleNameBlur}
                onKeyDown={handleNameKeyDown}
                placeholder="Trip to Berlin, Rent, Dinner..."
              />
            ) : (
              <button
                onClick={() => {
                  setIsEditingName(true);
                  setTimeout(() => {
                    nameInputRef.current?.focus();
                    nameInputRef.current?.select();
                  }, 0);
                }}
                className="text-lg font-semibold hover:text-muted-foreground transition-colors w-full text-left"
              >
                {groupName}
              </button>
            )}
          </div>

          {/* Add people — matches AddPeopleDialog layout */}
          <div className="space-y-4">
            <label className="text-sm font-medium">
              Who&apos;s splitting expenses?
            </label>

            {/* Search existing users */}
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
              <Input
                placeholder="Search by name or phone..."
                value={searchQuery}
                onChange={(e) => handleSearch(e.target.value)}
                className="pl-9"
              />
            </div>

            {/* Search results */}
            {searching && (
              <div className="flex items-center justify-center py-2">
                <LoaderCircle className="size-4 animate-spin text-muted-foreground" />
              </div>
            )}

            {searchResults.length > 0 && (
              <ul className="divide-y rounded-md border">
                {searchResults.map((user) => {
                  const isSent = sentIds.has(user.id);
                  const isSending = sendingId === user.id;
                  return (
                    <li key={user.id} className="flex items-center justify-between px-3 py-2 gap-3">
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
                        <Button variant="outline" size="sm" onClick={() => handleInviteUser(user)} disabled={isSending}>
                          {isSending && <LoaderCircle className="size-3.5 animate-spin" />}
                          Invite
                        </Button>
                      )}
                    </li>
                  );
                })}
              </ul>
            )}

            {searchQuery.length >= 3 && !searching && searchResults.length === 0 && (
              <p className="text-xs text-muted-foreground text-center">
                No users found for &ldquo;{searchQuery}&rdquo;
              </p>
            )}

            {/* Divider */}
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <span className="w-full border-t" />
              </div>
              <div className="relative flex justify-center text-xs">
                <span className="bg-card px-2 text-muted-foreground">or</span>
              </div>
            </div>

            {/* Add guest by name */}
            <div className="space-y-2">
              <Label className="text-xs text-muted-foreground">Add someone without a Rekn account</Label>
              <div className="flex gap-2">
                <Input
                  value={currentName}
                  onChange={(e) => setCurrentName(e.target.value)}
                  onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addGuestToList(); } }}
                  placeholder="Guest name"
                />
                <Button type="button" variant="secondary" onClick={addGuestToList} disabled={!currentName.trim()}>
                  Add
                </Button>
              </div>
            </div>

            {/* Member list */}
            {(guestNames.length > 0 || invitedUsers.length > 0) && (
              <ul className="space-y-1">
                {invitedUsers.map((user) => (
                  <li key={user.id} className="flex items-center justify-between rounded-md border px-3 py-2 text-sm">
                    <div className="flex items-center gap-1.5">
                      <span>{user.name}</span>
                      <span className="inline-flex items-center rounded-full bg-primary/10 px-1.5 py-0.5 text-[0.65rem] font-medium text-primary">
                        invited
                      </span>
                    </div>
                    <button type="button" onClick={() => removeInvited(user.id)} className="text-muted-foreground hover:text-foreground transition-colors">
                      <X className="size-4" />
                    </button>
                  </li>
                ))}
                {guestNames.map((name, index) => (
                  <li key={index} className="flex items-center justify-between rounded-md border px-3 py-2 text-sm">
                    <div className="flex items-center gap-1.5">
                      <span>{name}</span>
                      <span className="inline-flex items-center rounded-full bg-muted px-1.5 py-0.5 text-[0.65rem] font-medium text-muted-foreground">
                        guest
                      </span>
                    </div>
                    <button type="button" onClick={() => removeGuest(index)} className="text-muted-foreground hover:text-foreground transition-colors">
                      <X className="size-4" />
                    </button>
                  </li>
                ))}
              </ul>
            )}

            {totalAdded > 0 && (
              <p className="text-xs text-muted-foreground">
                {totalAdded} {totalAdded === 1 ? "person" : "people"} added
              </p>
            )}
          </div>
        </CardContent>
      </Card>

      <Button
        onClick={handleFinish}
        disabled={isPending}
        className="w-full"
        size="lg"
      >
        {isPending && <LoaderCircle className="size-4 animate-spin" />}
        {totalAdded > 0 ? "Start splitting expenses" : "Skip for now"}
      </Button>

      {/* Invite link */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t" />
        </div>
        <div className="relative flex justify-center text-xs">
          <span className="bg-background px-2 text-muted-foreground">or share a link</span>
        </div>
      </div>

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
  );
}
