import { NextRequest } from "next/server";
import { withAuthRateLimit } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as apiKeyService from "@/services/api-key-service";

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  const result = await apiKeyService.revokeApiKey(id, auth.user.userId);
  if ("error" in result) return res.notFound(result.error);
  return res.noContent();
}
