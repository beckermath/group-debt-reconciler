import Link from "next/link";
import { SubmitButton } from "@/components/submit-button";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { createGroup } from "./actions";
import { auth } from "@/lib/auth";
import { redirect } from "next/navigation";
import * as groupService from "@/services/group-service";

export const dynamic = "force-dynamic";

export default async function Home() {
  const session = await auth();
  if (!session?.user?.id) redirect("/login");

  const userGroups = await groupService.getUserGroups(session.user.id);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold mb-4">Your Groups</h1>
        <form action={createGroup} className="flex gap-2">
          <Input name="name" placeholder="New group name" required />
          <SubmitButton>Create</SubmitButton>
        </form>
      </div>

      {userGroups.length === 0 ? (
        <p className="text-muted-foreground">No groups yet. Create one above.</p>
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
