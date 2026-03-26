import { NextRequest } from "next/server";
import { withGroupOwner } from "@/lib/api-helpers";
import * as res from "@/lib/api-response";
import * as settlementService from "@/services/settlement-service";
import { withErrorHandling } from "@/lib/api-handler";

export const DELETE = withErrorHandling(async (
  request: NextRequest,
  context: { params: Promise<{ id: string; settlementId: string }> }
) => {
  const { id, settlementId } = await context.params;
  const auth = await withGroupOwner(request, id);
  if (auth instanceof Response) return auth;

  const result = await settlementService.undoSettlement(settlementId, id);
  if ("error" in result) return res.badRequest(result.error);
  return res.noContent();
});
