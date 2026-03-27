import { cn } from "@/lib/utils";

const AVATAR_GRADIENTS = [
  ["oklch(0.58 0.20 280)", "oklch(0.55 0.22 310)"],
  ["oklch(0.60 0.18 200)", "oklch(0.55 0.20 240)"],
  ["oklch(0.62 0.16 150)", "oklch(0.58 0.18 180)"],
  ["oklch(0.60 0.18 30)", "oklch(0.56 0.22 350)"],
  ["oklch(0.58 0.20 255)", "oklch(0.54 0.22 285)"],
  ["oklch(0.62 0.16 90)", "oklch(0.58 0.18 130)"],
  ["oklch(0.58 0.20 320)", "oklch(0.55 0.22 350)"],
  ["oklch(0.60 0.18 170)", "oklch(0.56 0.20 210)"],
] as const;

function hashName(name: string): number {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = ((hash << 5) - hash + name.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
}

export function MemberAvatar({
  name,
  className,
}: {
  name: string;
  className?: string;
}) {
  const initials = name
    .split(/\s+/)
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  const [from, to] = AVATAR_GRADIENTS[hashName(name) % AVATAR_GRADIENTS.length];

  return (
    <span
      className={cn(
        "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-semibold text-white shadow-sm",
        className
      )}
      style={{ background: `linear-gradient(135deg, ${from}, ${to})` }}
    >
      {initials}
    </span>
  );
}
