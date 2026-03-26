import { db } from "@/db";
import { settlements } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { randomUUID } from "crypto";

export async function settleUp(groupId: string, userId: string) {
  const id = randomUUID();
  await db.insert(settlements).values({
    id,
    groupId,
    settledBy: userId,
    settledAt: new Date(),
  });
  return { settlementId: id };
}

export async function undoSettlement(settlementId: string, groupId: string) {
  const [latest] = await db
    .select()
    .from(settlements)
    .where(eq(settlements.groupId, groupId))
    .orderBy(desc(settlements.settledAt))
    .limit(1);

  if (!latest || latest.id !== settlementId) {
    return { error: "Can only undo the most recent settlement" };
  }

  await db.delete(settlements).where(eq(settlements.id, settlementId));
  return {};
}

export async function getGroupSettlements(groupId: string) {
  return db
    .select()
    .from(settlements)
    .where(eq(settlements.groupId, groupId))
    .orderBy(desc(settlements.settledAt));
}
