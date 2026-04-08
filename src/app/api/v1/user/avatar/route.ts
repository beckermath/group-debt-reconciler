import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { put, del } from "@vercel/blob";
import { withErrorHandling } from "@/lib/api-handler";

const MAX_SIZE = 5 * 1024 * 1024; // 5MB

export const PUT = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const formData = await request.formData();
  const file = formData.get("file") as File | null;
  if (!file) return res.badRequest("No file provided");
  if (file.size > MAX_SIZE) return res.badRequest("File too large. Maximum 5MB.");

  const contentType = file.type && file.type.startsWith("image/")
    ? file.type
    : "image/jpeg";

  // Delete old avatar if exists
  const [user] = await db
    .select({ image: users.image })
    .from(users)
    .where(eq(users.id, auth.user.userId));

  if (user?.image) {
    try { await del(user.image); } catch { /* ignore */ }
  }

  const blob = await put(`avatars/${auth.user.userId}-${Date.now()}`, file, {
    access: "public",
    contentType,
  });

  await db
    .update(users)
    .set({ image: blob.url })
    .where(eq(users.id, auth.user.userId));

  return res.ok({ imageUrl: blob.url });
});

export const DELETE = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const [user] = await db
    .select({ image: users.image })
    .from(users)
    .where(eq(users.id, auth.user.userId));

  if (user?.image) {
    try { await del(user.image); } catch { /* ignore */ }
  }

  await db
    .update(users)
    .set({ image: null })
    .where(eq(users.id, auth.user.userId));

  return res.noContent();
});
