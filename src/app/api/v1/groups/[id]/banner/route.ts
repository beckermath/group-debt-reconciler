import { NextRequest } from "next/server";
import { withGroupAccess } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as groupService from "@/services/group-service";
import { put, del } from "@vercel/blob";
import { withErrorHandling } from "@/lib/api-handler";

const MAX_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic"];

export const PUT = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const formData = await request.formData();
  const file = formData.get("file") as File | null;
  if (!file) return res.badRequest("No file provided");
  if (file.size > MAX_SIZE) return res.badRequest("File too large. Maximum 5MB.");

  // Determine content type — fall back to jpeg if the multipart type is missing
  const contentType = file.type && ALLOWED_TYPES.includes(file.type)
    ? file.type
    : "image/jpeg";

  // Delete old banner if exists
  const group = await groupService.getGroup(id);
  if (group?.bannerUrl) {
    try { await del(group.bannerUrl); } catch { /* ignore deletion errors */ }
  }

  // Upload new banner
  const blob = await put(`groups/${id}/banner-${Date.now()}`, file, {
    access: "public",
    contentType,
  });

  await groupService.updateGroupBanner(id, blob.url);
  return res.ok({ bannerUrl: blob.url });
});

export const DELETE = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) => {
  const { id } = await context.params;
  const auth = await withGroupAccess(request, id);
  if (auth instanceof Response) return auth;

  const group = await groupService.getGroup(id);
  if (group?.bannerUrl) {
    try { await del(group.bannerUrl); } catch { /* ignore */ }
  }

  await groupService.updateGroupBanner(id, null);
  return res.noContent();
});
