import { requireGroupAccess } from "@/lib/auth-helpers";
import { GroupSetupClient } from "./client";

export default async function GroupSetupPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { session } = await requireGroupAccess(id);
  const isGuest = session?.user?.isGuest ?? false;

  return <GroupSetupClient id={id} isGuest={isGuest} />;
}
