import { db } from "@/db";
import { users, groupMembers } from "@/db/schema";
import { eq, like, or, and, notInArray } from "drizzle-orm";

export type SearchResult = {
  id: string;
  name: string;
  maskedPhone: string;
};

function maskPhone(phone: string): string {
  if (!phone || phone.length <= 4) return "****";
  return phone.slice(0, -4).replace(/\d/g, "*") + phone.slice(-4);
}

export async function searchUsers(
  query: string,
  excludeUserId: string,
  groupId?: string
): Promise<SearchResult[]> {
  if (!query || query.length < 3) return [];

  // Determine if query looks like a phone number
  const isPhoneQuery = /^\+?\d[\d\s-]{2,}$/.test(query.trim());
  const cleanQuery = query.trim();

  let results;
  if (isPhoneQuery) {
    // Phone number search — prefix match
    const phoneDigits = cleanQuery.replace(/\D/g, "");
    results = await db
      .select({ id: users.id, name: users.name, phoneNumber: users.phoneNumber })
      .from(users)
      .where(like(users.phoneNumber, `%${phoneDigits}%`))
      .limit(15);
  } else {
    // Name search — case-insensitive LIKE
    results = await db
      .select({ id: users.id, name: users.name, phoneNumber: users.phoneNumber })
      .from(users)
      .where(like(users.name, `%${cleanQuery}%`))
      .limit(15);
  }

  // Exclude current user
  let filtered = results.filter((u) => u.id !== excludeUserId);

  // Exclude existing group members if groupId provided
  if (groupId) {
    const existingMembers = await db
      .select({ userId: groupMembers.userId })
      .from(groupMembers)
      .where(eq(groupMembers.groupId, groupId));
    const memberUserIds = new Set(existingMembers.map((m) => m.userId));
    filtered = filtered.filter((u) => !memberUserIds.has(u.id));
  }

  return filtered.slice(0, 10).map((u) => ({
    id: u.id,
    name: u.name ?? "Unknown",
    maskedPhone: maskPhone(u.phoneNumber ?? ""),
  }));
}
