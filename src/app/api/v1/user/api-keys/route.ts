import { NextRequest } from "next/server";
import { withAuth, withAuthRateLimit } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as apiKeyService from "@/services/api-key-service";
import { withErrorHandling } from "@/lib/api-handler";

export const GET = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const keys = await apiKeyService.listApiKeys(auth.user.userId);
  return res.ok(keys);
});

export const POST = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body?.name?.trim()) return res.badRequest("Name is required");

  const result = await apiKeyService.createApiKey(auth.user.userId, body.name);
  if ("error" in result) return res.badRequest(result.error);
  return res.created(result);
});
