import { db } from "@/db";
import { apiKeys } from "@/db/schema";
import { eq, and } from "drizzle-orm";
import { randomUUID, randomBytes } from "crypto";
import bcrypt from "bcryptjs";

/**
 * Create a new API key. Returns the raw key (only shown once) and metadata.
 */
export async function createApiKey(userId: string, name: string) {
  if (!name?.trim()) return { error: "Name is required" };

  const rawKey = `rk_${randomBytes(32).toString("hex")}`;
  const prefix = rawKey.slice(0, 8);
  const keyHash = await bcrypt.hash(rawKey, 10);
  const id = randomUUID();
  const now = new Date();

  await db.insert(apiKeys).values({
    id,
    userId,
    name: name.trim().slice(0, 100),
    keyHash,
    prefix,
    createdAt: now,
  });

  return {
    id,
    name: name.trim(),
    prefix,
    rawKey, // Only returned at creation time
    createdAt: now,
  };
}

/**
 * List API keys for a user (without key hashes).
 */
export async function listApiKeys(userId: string) {
  const keys = await db
    .select({
      id: apiKeys.id,
      name: apiKeys.name,
      prefix: apiKeys.prefix,
      lastUsedAt: apiKeys.lastUsedAt,
      createdAt: apiKeys.createdAt,
      expiresAt: apiKeys.expiresAt,
    })
    .from(apiKeys)
    .where(eq(apiKeys.userId, userId));

  return keys;
}

/**
 * Revoke (delete) an API key.
 */
export async function revokeApiKey(keyId: string, userId: string) {
  const [key] = await db
    .select({ userId: apiKeys.userId })
    .from(apiKeys)
    .where(eq(apiKeys.id, keyId));

  if (!key || key.userId !== userId) {
    return { error: "API key not found" };
  }

  await db.delete(apiKeys).where(eq(apiKeys.id, keyId));
  return {};
}
