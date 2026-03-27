"use client";

import { useState, useRef, useTransition, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { InviteButton } from "@/components/invite-button";
import { renameGroup, addMembersInBatch } from "@/app/actions";
import { X, LoaderCircle, ChevronLeft } from "lucide-react";

export default function GroupSetupPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [groupName, setGroupName] = useState("New Group");
  const [isEditingName, setIsEditingName] = useState(true);
  const [memberNames, setMemberNames] = useState<string[]>([]);
  const [currentName, setCurrentName] = useState("");
  const [isPending, startTransition] = useTransition();

  const nameInputRef = useRef<HTMLInputElement>(null);
  const memberInputRef = useRef<HTMLInputElement>(null);

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
      memberInputRef.current?.focus();
    }
  }

  function addMemberToList() {
    const trimmed = currentName.trim();
    if (!trimmed) return;
    setMemberNames((prev) => [...prev, trimmed]);
    setCurrentName("");
    memberInputRef.current?.focus();
  }

  function removeMemberFromList(index: number) {
    setMemberNames((prev) => prev.filter((_, i) => i !== index));
  }

  function handleMemberKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") {
      e.preventDefault();
      addMemberToList();
    }
  }

  function handleFinish() {
    startTransition(async () => {
      if (memberNames.length > 0) {
        await addMembersInBatch(id, memberNames);
      } else {
        router.push(`/group/${id}`);
      }
    });
  }

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

          <div className="space-y-3">
            <label className="text-sm font-medium" htmlFor="member-name">
              Who's splitting expenses?
            </label>
            <div className="flex gap-2">
              <Input
                id="member-name"
                ref={memberInputRef}
                value={currentName}
                onChange={(e) => setCurrentName(e.target.value)}
                onKeyDown={handleMemberKeyDown}
                placeholder="Name"
              />
              <Button
                type="button"
                variant="secondary"
                onClick={addMemberToList}
                disabled={!currentName.trim()}
              >
                Add
              </Button>
            </div>

            {memberNames.length > 0 && (
              <ul className="space-y-1">
                {memberNames.map((name, index) => (
                  <li
                    key={index}
                    className="flex items-center justify-between rounded-md border px-3 py-2 text-sm"
                  >
                    <span>{name}</span>
                    <button
                      type="button"
                      onClick={() => removeMemberFromList(index)}
                      className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                      <X className="size-4" />
                    </button>
                  </li>
                ))}
              </ul>
            )}

            {memberNames.length > 0 && (
              <p className="text-xs text-muted-foreground">
                {memberNames.length} member{memberNames.length !== 1 && "s"} added
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
        {memberNames.length > 0 ? "Start splitting expenses" : "Skip for now"}
      </Button>

      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t" />
        </div>
        <div className="relative flex justify-center text-xs uppercase">
          <span className="bg-background px-2 text-muted-foreground">
            Or invite people with a link
          </span>
        </div>
      </div>

      <div className="flex justify-center">
        <InviteButton groupId={id} />
      </div>
    </div>
  );
}
