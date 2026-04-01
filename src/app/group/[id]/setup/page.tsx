import { auth } from "@/lib/auth";
import { GroupSetupClient } from "./client";

export default async function GroupSetupPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const session = await auth();
  const isGuest = session?.user?.isGuest ?? false;

  return <GroupSetupClient id={id} isGuest={isGuest} />;
}
