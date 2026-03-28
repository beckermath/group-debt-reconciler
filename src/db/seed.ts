import { createClient } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import * as schema from "./schema";

const client = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN,
});

const db = drizzle(client, { schema });

const TEST_USERS = [
  { name: "Alice", phone: "+15550000001" },
  { name: "Bob", phone: "+15550000002" },
  { name: "Charlie", phone: "+15550000003" },
  { name: "Diana", phone: "+15550000004" },
];

async function seed() {
  console.log("Seeding test users...\n");

  const userIds: Record<string, string> = {};

  for (const user of TEST_USERS) {
    const [found] = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.phoneNumber, user.phone));

    if (found) {
      console.log(`  skip ${user.name} (${user.phone}) — already exists`);
      userIds[user.name] = found.id;
      continue;
    }

    const id = randomUUID();
    await db.insert(schema.users).values({
      id,
      name: user.name,
      phoneNumber: user.phone,
    });
    userIds[user.name] = id;
    console.log(`  + ${user.name} (${user.phone}) — created`);
  }

  // Create a sample group with Alice as owner, Bob and Charlie as members
  const [existingGroup] = await db
    .select()
    .from(schema.groups)
    .where(eq(schema.groups.name, "Weekend Trip"));

  if (!existingGroup) {
    const groupId = randomUUID();
    const now = new Date();

    await db.insert(schema.groups).values({
      id: groupId,
      name: "Weekend Trip",
      createdBy: userIds.Alice,
      createdAt: now,
    });

    // Add Alice as owner
    await db.insert(schema.groupMembers).values({
      id: randomUUID(),
      groupId,
      userId: userIds.Alice,
      role: "owner",
      joinedAt: now,
    });

    const aliceMemberId = randomUUID();
    await db.insert(schema.members).values({
      id: aliceMemberId,
      groupId,
      name: "Alice",
      userId: userIds.Alice,
    });

    // Add Bob as member
    await db.insert(schema.groupMembers).values({
      id: randomUUID(),
      groupId,
      userId: userIds.Bob,
      role: "member",
      joinedAt: now,
    });

    const bobMemberId = randomUUID();
    await db.insert(schema.members).values({
      id: bobMemberId,
      groupId,
      name: "Bob",
      userId: userIds.Bob,
    });

    // Add Charlie as member
    await db.insert(schema.groupMembers).values({
      id: randomUUID(),
      groupId,
      userId: userIds.Charlie,
      role: "member",
      joinedAt: now,
    });

    const charlieMemberId = randomUUID();
    await db.insert(schema.members).values({
      id: charlieMemberId,
      groupId,
      name: "Charlie",
      userId: userIds.Charlie,
    });

    // Add some expenses
    const expense1Id = randomUUID();
    await db.insert(schema.expenses).values({
      id: expense1Id,
      groupId,
      paidBy: aliceMemberId,
      amount: 9000, // $90
      description: "Dinner",
      createdAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
    });
    await db.insert(schema.expenseSplits).values([
      { id: randomUUID(), expenseId: expense1Id, memberId: aliceMemberId, share: 3000 },
      { id: randomUUID(), expenseId: expense1Id, memberId: bobMemberId, share: 3000 },
      { id: randomUUID(), expenseId: expense1Id, memberId: charlieMemberId, share: 3000 },
    ]);

    const expense2Id = randomUUID();
    await db.insert(schema.expenses).values({
      id: expense2Id,
      groupId,
      paidBy: bobMemberId,
      amount: 4500, // $45
      description: "Gas",
      createdAt: new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000),
    });
    await db.insert(schema.expenseSplits).values([
      { id: randomUUID(), expenseId: expense2Id, memberId: aliceMemberId, share: 1500 },
      { id: randomUUID(), expenseId: expense2Id, memberId: bobMemberId, share: 1500 },
      { id: randomUUID(), expenseId: expense2Id, memberId: charlieMemberId, share: 1500 },
    ]);

    console.log(`  + "Weekend Trip" group with Alice, Bob, Charlie — created`);
    console.log(`    - Dinner ($90, paid by Alice, split 3 ways)`);
    console.log(`    - Gas ($45, paid by Bob, split 3 ways)`);
  } else {
    console.log(`  skip "Weekend Trip" group — already exists`);
  }

  console.log("\nDone! Test accounts:");
  console.log("-----------------------------------");
  for (const user of TEST_USERS) {
    console.log(`  ${user.name}: ${user.phone}`);
  }
  console.log("-----------------------------------");
  console.log("Use the dev account switcher to log in as any test user.\n");

  process.exit(0);
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
