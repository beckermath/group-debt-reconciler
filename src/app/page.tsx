import Link from "next/link";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { createGroup } from "./actions";
import { auth } from "@/lib/auth";
import { redirect } from "next/navigation";
import * as groupService from "@/services/group-service";
import { Plus } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function Home() {
  const session = await auth();
  if (!session?.user?.id) redirect("/login");

  const userGroups = await groupService.getUserGroups(session.user.id);

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Your Groups</h1>
        <form action={createGroup}>
          <SubmitButton size="default">
            <Plus className="size-4" />
            Create group
          </SubmitButton>
        </form>
      </div>

      {userGroups.length === 0 ? (
        <div className="text-center py-12 space-y-3">
          <p className="text-muted-foreground">
            No groups yet. Create one to start splitting expenses.
          </p>
        </div>
      ) : (
        <div className="grid gap-3">
          {userGroups.map((group) => (
            <Link key={group.id} href={`/group/${group.id}`}>
              <Card className="hover:bg-muted/50 transition-colors">
                <CardHeader>
                  <CardTitle>{group.name}</CardTitle>
                </CardHeader>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
