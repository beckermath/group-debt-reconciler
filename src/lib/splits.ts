/**
 * Pure, framework-agnostic split computation.
 *
 * Extracted from src/app/actions.ts so the logic can be unit-tested without
 * a Next.js / "use server" runtime or a live database connection.
 */

export type SplitMode = "equal" | "custom";

export interface SplitInput {
  splitMode: SplitMode;
  /** Ordered list of member IDs that participate in this expense. */
  memberIds: string[];
  /** Total expense amount in cents (integer). */
  amountCents: number;
  /**
   * For "custom" mode: maps memberId → dollar-string (e.g. "3.34").
   * Ignored for "equal" mode.
   */
  customAmounts: Record<string, string>;
}

export interface SplitResult {
  memberId: string;
  /** Share amount in cents (integer). */
  share: number;
}

/**
 * Compute per-member expense splits.
 *
 * Equal mode
 * ----------
 * Divides `amountCents` by the number of members using integer floor division.
 * The remainder pennies are distributed one-per-member starting from the first
 * member in `memberIds` order, so the total always equals `amountCents`.
 *
 * Custom mode
 * -----------
 * Each member's dollar-string is parsed and rounded to cents.  If the
 * resulting sum does not exactly equal `amountCents` an empty array is
 * returned so the caller can treat the input as invalid.
 *
 * Returns [] on any validation failure.
 */
export function computeSplits(input: SplitInput): SplitResult[] {
  const { splitMode, memberIds, amountCents, customAmounts } = input;

  if (splitMode === "custom") {
    const splits = memberIds.map((memberId) => {
      const raw = customAmounts[memberId] ?? "";
      const share = Math.round((parseFloat(raw) || 0) * 100);
      return { memberId, share };
    });

    const total = splits.reduce((sum, s) => sum + s.share, 0);
    if (total !== amountCents) return [];

    return splits;
  }

  // Equal split with penny rounding
  const count = memberIds.length;
  const shareBase = Math.floor(amountCents / count);
  const remainder = amountCents - shareBase * count;

  return memberIds.map((memberId, i) => ({
    memberId,
    share: shareBase + (i < remainder ? 1 : 0),
  }));
}
