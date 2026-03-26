import { NextRequest } from "next/server";
import { withAuth, withAuthRateLimit } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as groupService from "@/services/group-service";

export async function GET(request: NextRequest) {
  const auth = await withAuth(request);
  if (auth instanceof Response) return auth;

  const groups = await groupService.getUserGroups(auth.user.userId);
  return res.ok(groups);
}

export async function POST(request: NextRequest) {
  const auth = await withAuthRateLimit(request);
  if (auth instanceof Response) return auth;

  const body = await request.json().catch(() => null);
  if (!body?.name?.trim()) return res.badRequest("Name is required");

  const result = await groupService.createGroup(auth.user.userId, body.name);
  return res.created(result);
}
