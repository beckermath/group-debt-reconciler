import { createClient } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import bcrypt from "bcryptjs";
import * as schema from "./schema";

const client = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN,
});

const db = drizzle(client, { schema });

const TEST_USERS = [
  { name: "Alice", email: "alice@rekn.test" },
  { name: "Bob", email: "bob@rekn.test" },
  { name: "Charlie", email: "charlie@rekn.test" },
  { name: "Diana", email: "diana@rekn.test" },
  { name: "Eve", email: "eve@rekn.test" },
];

const PASSWORD = "testpass123";

async function seed() {
  console.log("Seeding test users...\n");

  const passwordHash = await bcrypt.hash(PASSWORD, 10);

  for (const user of TEST_USERS) {
    const [found] = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.email, user.email));

    if (found) {
      console.log(`  skip ${user.name} (${user.email}) — already exists`);
      continue;
    }

    await db.insert(schema.users).values({
      id: randomUUID(),
      name: user.name,
      email: user.email,
      passwordHash,
    });

    console.log(`  + ${user.name} (${user.email}) — created`);
  }

  console.log(`\nDone! All test users have password: ${PASSWORD}`);
  console.log("\nTest accounts:");
  console.log("-----------------------------------");
  for (const user of TEST_USERS) {
    console.log(`  ${user.email} / ${PASSWORD}`);
  }
  console.log("-----------------------------------");

  process.exit(0);
}

seed().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
