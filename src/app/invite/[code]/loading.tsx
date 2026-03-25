import { Skeleton } from "@/components/ui/skeleton";

export default function InviteLoading() {
  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <div className="w-full max-w-sm rounded-xl border p-6 space-y-4">
        <Skeleton className="h-6 w-40" />
        <Skeleton className="h-4 w-56" />
        <Skeleton className="h-8 w-full" />
      </div>
    </div>
  );
}
