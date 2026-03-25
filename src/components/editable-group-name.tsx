"use client";

import { useState, useRef, useEffect, useTransition } from "react";
import { useRouter } from "next/navigation";
import { renameGroup } from "@/app/actions";

export function EditableGroupName({
  groupId,
  name,
  isOwner,
}: {
  groupId: string;
  name: string;
  isOwner: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(name);
  const [optimisticName, setOptimisticName] = useState(name);
  const [isPending, startTransition] = useTransition();
  const inputRef = useRef<HTMLInputElement>(null);
  const router = useRouter();

  useEffect(() => {
    if (editing && inputRef.current) {
      inputRef.current.focus();
      const len = inputRef.current.value.length;
      inputRef.current.setSelectionRange(len, len);
    }
  }, [editing]);

  // Sync if the server-rendered name changes
  useEffect(() => {
    setOptimisticName(name);
    setValue(name);
  }, [name]);

  function save() {
    setEditing(false);
    const trimmed = value.trim();
    if (!trimmed || trimmed === optimisticName) {
      setValue(optimisticName);
      return;
    }
    // Show the new name immediately
    setOptimisticName(trimmed);
    startTransition(async () => {
      await renameGroup(groupId, trimmed);
      router.refresh();
    });
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") {
      e.preventDefault();
      save();
    }
    if (e.key === "Escape") {
      setValue(optimisticName);
      setEditing(false);
    }
  }

  if (!isOwner) {
    return <h1 className="text-2xl font-bold">{optimisticName}</h1>;
  }

  if (editing) {
    return (
      <input
        ref={inputRef}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onBlur={save}
        onKeyDown={handleKeyDown}
        className="text-2xl font-bold bg-transparent outline-none flex-1 min-w-0 caret-primary"
      />
    );
  }

  return (
    <h1
      className={`text-2xl font-bold cursor-text truncate ${isPending ? "opacity-60" : ""}`}
      onClick={() => {
        setValue(optimisticName);
        setEditing(true);
      }}
      title="Click to rename"
    >
      {optimisticName}
    </h1>
  );
}
