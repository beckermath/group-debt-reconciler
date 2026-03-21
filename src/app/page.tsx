import { db } from "@/db";
import { groups } from "@/db/schema";
import { desc } from "drizzle-orm";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { createGroup } from "./actions";

export const dynamic = "force-dynamic";

export default function Home() {
  const allGroups = db.select().from(groups).orderBy(desc(groups.createdAt)).all();

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold mb-4">Your Groups</h1>
        <form action={createGroup} className="flex gap-2">
          <Input name="name" placeholder="New group name" required />
          <Button type="submit">Create</Button>
        </form>
      </div>

      {allGroups.length === 0 ? (
        <p className="text-muted-foreground">No groups yet. Create one above.</p>
      ) : (
        <div className="grid gap-3">
          {allGroups.map((group) => (
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
