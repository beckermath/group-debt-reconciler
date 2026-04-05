import { NextRequest, NextResponse } from "next/server";
import { getToken } from "next-auth/jwt";
import { db } from "@/db";
import { apiKeys } from "@/db/schema";
import { eq } from "drizzle-orm";
import bcrypt from "bcryptjs";
import { verifyMobileToken } from "@/lib/mobile-jwt";

export interface ApiUser {
  userId: string;
  authMethod: "jwt" | "api-key";
}

const UNAUTHORIZED = () =>
  NextResponse.json({ error: "Unauthorized" }, { status: 401 });

/**
 * Authenticate an API request via JWT session cookie or Bearer API key.
 * Returns the authenticated user or a 401 response.
 */
export async function authenticateRequest(
  request: NextRequest
): Promise<ApiUser | NextResponse> {
  // Try JWT session first (cookie-based)
  const token = await getToken({
    req: request,
    secret: process.env.AUTH_SECRET,
    secureCookie: request.nextUrl.protocol === "https:",
  });

  if (token?.sub) {
    return { userId: token.sub, authMethod: "jwt" };
  }

  // Try Bearer token (mobile JWT or API key)
  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return UNAUTHORIZED();
  }

  const rawToken = authHeader.slice(7);
  if (!rawToken || rawToken.length < 16) {
    return UNAUTHORIZED();
  }

  // Try mobile JWT first (contains dots = JWT format)
  if (rawToken.includes(".")) {
    const mobilePayload = await verifyMobileToken(rawToken);
    if (mobilePayload) {
      return { userId: mobilePayload.userId, authMethod: "jwt" };
    }
  }

  // Fall through to API key
  const rawKey = rawToken;
  const prefix = rawKey.slice(0, 8);
  const candidates = await db
    .select()
    .from(apiKeys)
    .where(eq(apiKeys.prefix, prefix));

  for (const candidate of candidates) {
    if (candidate.expiresAt && candidate.expiresAt < new Date()) continue;

    const valid = await bcrypt.compare(rawKey, candidate.keyHash);
    if (valid) {
      // Update last used (fire-and-forget)
      db.update(apiKeys)
        .set({ lastUsedAt: new Date() })
        .where(eq(apiKeys.id, candidate.id))
        .then(() => {});

      return { userId: candidate.userId, authMethod: "api-key" };
    }
  }

  return UNAUTHORIZED();
}

