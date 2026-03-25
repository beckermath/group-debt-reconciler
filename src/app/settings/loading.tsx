import { Skeleton } from "@/components/ui/skeleton";

export default function SettingsLoading() {
  return (
    <div className="space-y-8">
      <div>
        <Skeleton className="h-4 w-16 mb-2" />
        <Skeleton className="h-8 w-32" />
      </div>
      <div className="rounded-xl border p-6 space-y-4">
        <Skeleton className="h-5 w-16" />
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-8 w-16" />
      </div>
      <div className="rounded-xl border p-6 space-y-4">
        <Skeleton className="h-5 w-28" />
        <Skeleton className="h-4 w-64" />
        <Skeleton className="h-8 w-32" />
      </div>
    </div>
  );
}
