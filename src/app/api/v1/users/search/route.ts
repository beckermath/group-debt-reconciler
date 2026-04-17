import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as userSearchService from "@/services/user-search-service";
import { withErrorHandling } from "@/lib/api-handler";

export const GET = withErrorHandling(async (request: NextRequest) => {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const url = new URL(request.url);
  const query = url.searchParams.get("q") ?? "";
  const groupId = url.searchParams.get("groupId") ?? undefined;

  const results = await userSearchService.searchUsers(query, auth.user.userId, groupId);
  return res.ok(results);
});
