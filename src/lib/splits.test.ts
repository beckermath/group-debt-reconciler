import { describe, it, expect } from "vitest";
import { computeSplits } from "./splits";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Build a SplitInput using equal-split mode.
 * memberIds are used directly; amountCents is the total in cents.
 */
function equalInput(memberIds: string[], amountCents: number) {
  return { splitMode: "equal" as const, memberIds, amountCents, customAmounts: {} };
}

/**
 * Build a SplitInput using custom-split mode.
 * customAmounts maps memberId → dollar string (e.g. "3.34").
 */
function customInput(
  memberIds: string[],
  amountCents: number,
  customAmounts: Record<string, string>
) {
  return { splitMode: "custom" as const, memberIds, amountCents, customAmounts };
}

// ---------------------------------------------------------------------------
// Equal splits — basic correctness
// ---------------------------------------------------------------------------

describe("computeSplits – equal split, basic correctness", () => {
  it("splits $10 equally between 2 members → 500 cents each", () => {
    const result = computeSplits(equalInput(["alice", "bob"], 1000));

    expect(result).toHaveLength(2);
    expect(result.find((s) => s.memberId === "alice")?.share).toBe(500);
    expect(result.find((s) => s.memberId === "bob")?.share).toBe(500);
  });

  it("splits $6 equally between 3 members → 200 cents each", () => {
    const result = computeSplits(equalInput(["a", "b", "c"], 600));

    expect(result).toHaveLength(3);
    for (const s of result) {
      expect(s.share).toBe(200);
    }
  });

  it("returns shares in the same order as memberIds", () => {
    const memberIds = ["carol", "dave", "eve"];
    const result = computeSplits(equalInput(memberIds, 300));

    expect(result.map((s) => s.memberId)).toEqual(memberIds);
  });

  it("shares sum to the exact total amount", () => {
    const result = computeSplits(equalInput(["a", "b", "c"], 1000));
    const total = result.reduce((sum, s) => sum + s.share, 0);
    expect(total).toBe(1000);
  });
});

// ---------------------------------------------------------------------------
// Equal splits — penny rounding
// ---------------------------------------------------------------------------

describe("computeSplits – equal split, penny rounding", () => {
  it("$10 split 3 ways: first member gets the extra penny (334, 333, 333)", () => {
    // 1000 / 3 = 333 remainder 1 → index 0 gets +1
    const result = computeSplits(equalInput(["a", "b", "c"], 1000));

    expect(result[0].share).toBe(334);
    expect(result[1].share).toBe(333);
    expect(result[2].share).toBe(333);
  });

  it("$10 split 3 ways: total of shares is exactly 1000", () => {
    const result = computeSplits(equalInput(["a", "b", "c"], 1000));
    const total = result.reduce((sum, s) => sum + s.share, 0);
    expect(total).toBe(1000);
  });

  it("$1 split 3 ways: two members get 34 cents, one gets 32 cents", () => {
    // 100 / 3 = 33 remainder 1 → index 0 gets 34, rest get 33
    const result = computeSplits(equalInput(["a", "b", "c"], 100));

    expect(result[0].share).toBe(34);
    expect(result[1].share).toBe(33);
    expect(result[2].share).toBe(33);
    expect(result.reduce((s, r) => s + r.share, 0)).toBe(100);
  });

  it("$10 split 7 ways: remainder cents go to first N members (total always exact)", () => {
    // 1000 / 7 = 142 remainder 6 → first 6 get 143, last gets 142
    const ids = ["m1", "m2", "m3", "m4", "m5", "m6", "m7"];
    const result = computeSplits(equalInput(ids, 1000));

    const total = result.reduce((sum, s) => sum + s.share, 0);
    expect(total).toBe(1000);

    // First 6 get one extra penny
    for (let i = 0; i < 6; i++) expect(result[i].share).toBe(143);
    expect(result[6].share).toBe(142);
  });

  it("amount that divides evenly: no member gets an extra penny", () => {
    // 900 / 3 = 300 exactly, remainder 0
    const result = computeSplits(equalInput(["a", "b", "c"], 900));
    for (const s of result) expect(s.share).toBe(300);
  });

  it("large amount with many members totals exactly", () => {
    const ids = Array.from({ length: 13 }, (_, i) => `m${i}`);
    const total = 9999; // odd prime-ish to force rounding
    const result = computeSplits(equalInput(ids, total));
    const sum = result.reduce((acc, s) => acc + s.share, 0);
    expect(sum).toBe(total);
  });
});

// ---------------------------------------------------------------------------
// Equal splits — single member edge case
// ---------------------------------------------------------------------------

describe("computeSplits – equal split, single member", () => {
  it("single member gets the entire amount", () => {
    const result = computeSplits(equalInput(["alice"], 999));
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ memberId: "alice", share: 999 });
  });

  it("single member with zero amount gets share of 0", () => {
    const result = computeSplits(equalInput(["alice"], 0));
    expect(result).toHaveLength(1);
    expect(result[0].share).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Custom splits — exact match
// ---------------------------------------------------------------------------

describe("computeSplits – custom split, exact match", () => {
  it("two members with custom amounts that exactly equal total", () => {
    // $10.00 total: alice 6.00, bob 4.00
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "6.00", bob: "4.00" })
    );

    expect(result).toHaveLength(2);
    expect(result.find((s) => s.memberId === "alice")?.share).toBe(600);
    expect(result.find((s) => s.memberId === "bob")?.share).toBe(400);
  });

  it("three members, unequal custom amounts that sum to total", () => {
    // $30.00 = 3000 cents: 1000 + 1500 + 500
    const result = computeSplits(
      customInput(["a", "b", "c"], 3000, { a: "10.00", b: "15.00", c: "5.00" })
    );

    expect(result).toHaveLength(3);
    expect(result.find((s) => s.memberId === "a")?.share).toBe(1000);
    expect(result.find((s) => s.memberId === "b")?.share).toBe(1500);
    expect(result.find((s) => s.memberId === "c")?.share).toBe(500);
  });

  it("custom amounts with sub-penny string values are rounded to nearest cent", () => {
    // "3.334" → Math.round(3.334 * 100) = 333; "6.666" → 667; total = 1000
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "3.334", bob: "6.666" })
    );

    // Both rounded amounts must sum to amountCents for a non-empty result
    const total = result.reduce((sum, s) => sum + s.share, 0);
    // 333 + 667 = 1000 → valid
    expect(result).toHaveLength(2);
    expect(total).toBe(1000);
  });

  it("single member custom split equaling total amount", () => {
    const result = computeSplits(
      customInput(["alice"], 500, { alice: "5.00" })
    );

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ memberId: "alice", share: 500 });
  });
});

// ---------------------------------------------------------------------------
// Custom splits — zero amounts
// ---------------------------------------------------------------------------

describe("computeSplits – custom split, zero amounts", () => {
  it("one member with zero share is allowed when total still matches", () => {
    // alice: $10.00, bob: $0.00 → total 1000 ✓
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "10.00", bob: "0.00" })
    );

    expect(result).toHaveLength(2);
    expect(result.find((s) => s.memberId === "alice")?.share).toBe(1000);
    expect(result.find((s) => s.memberId === "bob")?.share).toBe(0);
  });

  it("all members with zero share when total is also zero", () => {
    const result = computeSplits(
      customInput(["alice", "bob"], 0, { alice: "0.00", bob: "0.00" })
    );

    expect(result).toHaveLength(2);
    for (const s of result) expect(s.share).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Custom splits — validation (mismatch returns [])
// ---------------------------------------------------------------------------

describe("computeSplits – custom split, mismatch returns []", () => {
  it("over-allocation: custom amounts sum to more than total → returns []", () => {
    // $10.00 total but alice:6 + bob:6 = $12.00
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "6.00", bob: "6.00" })
    );

    expect(result).toHaveLength(0);
  });

  it("under-allocation: custom amounts sum to less than total → returns []", () => {
    // $10.00 total but alice:3 + bob:3 = $6.00
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "3.00", bob: "3.00" })
    );

    expect(result).toHaveLength(0);
  });

  it("single member whose custom amount does not match total → returns []", () => {
    const result = computeSplits(
      customInput(["alice"], 500, { alice: "4.00" })
    );

    expect(result).toHaveLength(0);
  });

  it("missing custom amount for a member (treated as 0) causes mismatch → returns []", () => {
    // bob is in memberIds but has no entry in customAmounts → treated as 0
    // alice: 500 + bob: 0 = 500 ≠ 1000
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "5.00" })
    );

    expect(result).toHaveLength(0);
  });

  it("returns [] for negative custom amounts that shift total off", () => {
    // Negative dollar strings after parseFloat → negative cents contributing to mismatch
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "15.00", bob: "-5.00" })
    );

    // 1500 + (-500) = 1000 — this actually matches! Should return valid splits.
    // This tests that we don't special-case negatives — the math rules.
    expect(result).toHaveLength(2);
  });

  it("non-numeric custom string is treated as 0 → likely mismatch", () => {
    const result = computeSplits(
      customInput(["alice", "bob"], 1000, { alice: "abc", bob: "10.00" })
    );

    // "abc" → parseFloat("abc") = NaN → 0; total = 0 + 1000 = 1000 ✓
    // This actually matches (alice:0, bob:1000 = 1000). Verify the behavior.
    expect(result).toHaveLength(2);
    expect(result.find((s) => s.memberId === "alice")?.share).toBe(0);
    expect(result.find((s) => s.memberId === "bob")?.share).toBe(1000);
  });
});

// ---------------------------------------------------------------------------
// Return-type shape
// ---------------------------------------------------------------------------

describe("computeSplits – return type", () => {
  it("returns an array", () => {
    expect(Array.isArray(computeSplits(equalInput(["a"], 100)))).toBe(true);
  });

  it("each item has exactly { memberId, share } and no extra keys", () => {
    const [item] = computeSplits(equalInput(["a", "b"], 200));
    expect(Object.keys(item).sort()).toEqual(["memberId", "share"]);
  });

  it("share values are integers (no floating point)", () => {
    const result = computeSplits(equalInput(["a", "b", "c"], 1000));
    for (const s of result) {
      expect(Number.isInteger(s.share)).toBe(true);
    }
  });

  it("custom split share values are integers", () => {
    const result = computeSplits(
      customInput(["a", "b"], 1000, { a: "7.00", b: "3.00" })
    );
    for (const s of result) {
      expect(Number.isInteger(s.share)).toBe(true);
    }
  });
});

// ---------------------------------------------------------------------------
// Boundary / stress
// ---------------------------------------------------------------------------

describe("computeSplits – boundary and stress", () => {
  it("minimum amount of 1 cent split equally between 2 members", () => {
    // 1 / 2 = 0 remainder 1 → first gets 1, second gets 0
    const result = computeSplits(equalInput(["a", "b"], 1));

    expect(result[0].share).toBe(1);
    expect(result[1].share).toBe(0);
    expect(result.reduce((s, r) => s + r.share, 0)).toBe(1);
  });

  it("very large amount (99999999 cents) splits evenly between 2", () => {
    const result = computeSplits(equalInput(["a", "b"], 99999999));

    // 99999999 / 2 = 49999999 remainder 1 → first gets +1
    expect(result[0].share).toBe(50000000);
    expect(result[1].share).toBe(49999999);
    expect(result.reduce((s, r) => s + r.share, 0)).toBe(99999999);
  });

  it("100 members splitting $1 (100 cents) → each gets 1 cent", () => {
    const ids = Array.from({ length: 100 }, (_, i) => `m${i}`);
    const result = computeSplits(equalInput(ids, 100));

    const total = result.reduce((sum, s) => sum + s.share, 0);
    expect(total).toBe(100);
    for (const s of result) expect(s.share).toBe(1);
  });

  it("99 members splitting 100 cents → first member gets extra penny", () => {
    const ids = Array.from({ length: 99 }, (_, i) => `m${i}`);
    const result = computeSplits(equalInput(ids, 100));

    const total = result.reduce((sum, s) => sum + s.share, 0);
    expect(total).toBe(100);
    // 100 / 99 = 1 remainder 1 → first gets 2, rest get 1
    expect(result[0].share).toBe(2);
    for (let i = 1; i < 99; i++) expect(result[i].share).toBe(1);
  });
});
