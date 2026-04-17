import { NextRequest } from "next/server";
import { db } from "@/db";
import { users } from "@/db/schema";
import { like, and, isNotNull } from "drizzle-orm";
import * as res from "@/lib/api-response";
import { withErrorHandling } from "@/lib/api-handler";

const isDevAuthEnabled =
  process.env.PLAYWRIGHT_TEST === "1" && process.env.NODE_ENV !== "production";

if (process.env.PLAYWRIGHT_TEST === "1" && process.env.NODE_ENV === "production") {
  throw new Error("PLAYWRIGHT_TEST must not be set in production");
}

export const GET = withErrorHandling(async (_request: NextRequest) => {
  if (!isDevAuthEnabled) return res.notFound();

  const rows = await db
    .select({
      id: users.id,
      name: users.name,
      phoneNumber: users.phoneNumber,
    })
    .from(users)
    .where(and(isNotNull(users.phoneNumber), like(users.phoneNumber, "+1555000000%")));

  return res.ok(
    rows.map((u) => ({
      id: u.id,
      name: u.name ?? "Test User",
      phoneNumber: u.phoneNumber ?? "",
    }))
  );
});
