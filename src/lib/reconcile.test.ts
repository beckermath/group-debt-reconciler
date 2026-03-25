import { describe, it, expect } from "vitest";
import { reconcile, Transfer } from "./reconcile";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build a Map from a plain object so tests read cleanly. */
function bal(obj: Record<string, number>): Map<string, number> {
  return new Map(Object.entries(obj));
}

/**
 * Assert that the transfers fully settle all balances in `original`.
 * This is a mathematical invariant: every transfer must reduce the debtor's
 * debt and the creditor's credit by exactly `amount`.
 */
function assertFullySettled(
  original: Map<string, number>,
  transfers: Transfer[]
): void {
  const running = new Map(original);
  for (const { from, to, amount } of transfers) {
    running.set(from, (running.get(from) ?? 0) + amount);
    running.set(to, (running.get(to) ?? 0) - amount);
  }
  for (const [id, balance] of running) {
    expect(balance, `${id} still has an outstanding balance after settlement`).toBe(0);
  }
}

/**
 * Verify every transfer has a positive amount and that from !== to.
 */
function assertValidTransfers(transfers: Transfer[]): void {
  for (const t of transfers) {
    expect(t.amount, "transfer amount must be positive").toBeGreaterThan(0);
    expect(t.from, "from and to must differ").not.toBe(t.to);
  }
}

// ---------------------------------------------------------------------------
// Basic correctness
// ---------------------------------------------------------------------------

describe("reconcile – basic two-person debt", () => {
  it("alice owes bob $10 → single transfer of 1000 cents", () => {
    // alice: -1000 (owes), bob: +1000 (is owed)
    const transfers = reconcile(bal({ alice: -1000, bob: 1000 }));

    expect(transfers).toHaveLength(1);
    expect(transfers[0]).toEqual({ from: "alice", to: "bob", amount: 1000 });
  });

  it("direction is correct: debtor is `from`, creditor is `to`", () => {
    const transfers = reconcile(bal({ carol: -500, dave: 500 }));

    expect(transfers[0].from).toBe("carol");
    expect(transfers[0].to).toBe("dave");
  });

  it("returns [] when the single pair is already balanced (both zero)", () => {
    const transfers = reconcile(bal({ alice: 0, bob: 0 }));
    expect(transfers).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// All-zero balances
// ---------------------------------------------------------------------------

describe("reconcile – all-zero balances", () => {
  it("empty map → no transfers", () => {
    expect(reconcile(new Map())).toHaveLength(0);
  });

  it("all members at zero → no transfers", () => {
    const transfers = reconcile(bal({ alice: 0, bob: 0, carol: 0 }));
    expect(transfers).toHaveLength(0);
  });

  it("single member with zero balance → no transfers", () => {
    expect(reconcile(bal({ alice: 0 }))).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// Net-zero multi-person
// ---------------------------------------------------------------------------

describe("reconcile – multi-person with net-zero balances", () => {
  it("three-person cycle: A→B→C→A, each owes the next $5", () => {
    // alice paid for carol → alice +500, carol -500
    // bob paid for alice  → bob +500, alice -500
    // carol paid for bob  → carol +500, bob -500
    // net: alice 0, bob 0, carol 0 — already balanced, no transfers needed
    const transfers = reconcile(bal({ alice: 0, bob: 0, carol: 0 }));
    expect(transfers).toHaveLength(0);
  });

  it("four-person group: two creditors, two debtors, net zero", () => {
    // alice +3000, bob +2000, carol -2000, dave -3000
    const balances = bal({ alice: 3000, bob: 2000, carol: -2000, dave: -3000 });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
    // greedy sort: debtors [dave 3000, carol 2000], creditors [alice 3000, bob 2000]
    // step 1: dave 3000 → alice 3000  (dave cleared, alice cleared)
    // step 2: carol 2000 → bob 2000   (both cleared)
    expect(transfers).toHaveLength(2);
  });

  it("fully settled result has no remaining balances", () => {
    const balances = bal({
      alice: 1500,
      bob: -500,
      carol: -700,
      dave: -300,
    });
    const transfers = reconcile(balances);
    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
  });
});

// ---------------------------------------------------------------------------
// Minimum transfer count (greedy property)
// ---------------------------------------------------------------------------

describe("reconcile – greedy produces minimum transfers", () => {
  it("two debtors, two creditors with matching amounts → 2 transfers", () => {
    // Each debtor exactly matches one creditor in amount after greedy sort.
    const balances = bal({ a: 1000, b: 2000, c: -1000, d: -2000 });
    const transfers = reconcile(balances);

    expect(transfers).toHaveLength(2);
    assertFullySettled(balances, transfers);
  });
});

// ---------------------------------------------------------------------------
// Single debtor / multiple creditors
// ---------------------------------------------------------------------------

describe("reconcile – single debtor, multiple creditors", () => {
  it("one debtor owes three creditors different amounts", () => {
    // alice owes: bob $30, carol $20, dave $10 → alice -6000, others positive
    const balances = bal({
      alice: -6000,
      bob: 3000,
      carol: 2000,
      dave: 1000,
    });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
    // All transfers must come from alice
    expect(transfers.every((t) => t.from === "alice")).toBe(true);
    // Three separate payments (one per creditor)
    expect(transfers).toHaveLength(3);
  });

  it("one debtor owes two creditors equal amounts", () => {
    const balances = bal({ alice: -2000, bob: 1000, carol: 1000 });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
    expect(transfers.every((t) => t.from === "alice")).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Single creditor / multiple debtors
// ---------------------------------------------------------------------------

describe("reconcile – single creditor, multiple debtors", () => {
  it("three debtors all owe the same creditor", () => {
    const balances = bal({
      alice: 6000,
      bob: -2000,
      carol: -2000,
      dave: -2000,
    });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
    expect(transfers.every((t) => t.to === "alice")).toBe(true);
    expect(transfers).toHaveLength(3);
  });

  it("three debtors owe different amounts to one creditor", () => {
    // alice is owed 6000 total: bob 3000, carol 2000, dave 1000
    const balances = bal({
      alice: 6000,
      bob: -3000,
      carol: -2000,
      dave: -1000,
    });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
    expect(transfers.every((t) => t.to === "alice")).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Penny / rounding scenarios
// ---------------------------------------------------------------------------

describe("reconcile – penny rounding (uneven balances)", () => {
  it("$10 split 3 ways: one person gets the extra penny", () => {
    // $10 = 1000 cents ÷ 3 = 333 + 333 + 334
    // payer is owed 1000, two members owe 333, one owes 334
    const balances = bal({
      alice: 1000,  // paid
      bob: -334,    // gets the odd penny
      carol: -333,
      dave: -333,
    });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
  });

  it("large group with penny remainder fully settles", () => {
    // 7 people split $10.01 (1001 cents): shares are 143 cents each + 2 people get 144
    // payer +1001, 5 people -143, 2 people -144 (sums: 5*143 + 2*144 = 715+288 = 1003 ≠ 1001)
    // Correct: 1001 / 7 = 143.0, remainder 1001 - 143*7 = 1001 - 1001 = 0... let's use 1002/7:
    // 1002 / 7 = 143 remainder 2 → 2 members get 144, 5 get 143. Check: 2*144+5*143=288+715=1003 ≠ 1002
    // Use 1000/7: 142 remainder 6 → 6 get 143, 1 gets 142. Check: 6*143+142=858+142=1000. Correct.
    const balances = bal({
      payer: 1000,
      m1: -143,
      m2: -143,
      m3: -143,
      m4: -143,
      m5: -143,
      m6: -143,
      m7: -142,
    });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
  });

  it("two debtors with amounts that differ by one cent", () => {
    const balances = bal({ alice: 201, bob: -100, carol: -101 });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
  });
});

// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

describe("reconcile – edge cases", () => {
  it("single positive balance (no matching debtor) → no transfers", () => {
    // This is a degenerate / unbalanced input. The algorithm should not crash.
    const transfers = reconcile(bal({ alice: 500 }));
    expect(transfers).toHaveLength(0);
  });

  it("single negative balance (no matching creditor) → no transfers", () => {
    const transfers = reconcile(bal({ alice: -500 }));
    expect(transfers).toHaveLength(0);
  });

  it("very large amounts (no overflow for realistic group size)", () => {
    // $999,999.99 shared between two people: one creditor, one debtor
    const balances = bal({ alice: 99999999, bob: -99999999 });
    const transfers = reconcile(balances);

    expect(transfers).toHaveLength(1);
    expect(transfers[0].amount).toBe(99999999);
    assertFullySettled(balances, transfers);
  });

  it("minimum non-zero debt: 1 cent", () => {
    const balances = bal({ alice: 1, bob: -1 });
    const transfers = reconcile(balances);

    expect(transfers).toHaveLength(1);
    expect(transfers[0].amount).toBe(1);
  });

  it("transfer amount is always a positive integer (cents)", () => {
    const balances = bal({ a: 750, b: 250, c: -500, d: -500 });
    const transfers = reconcile(balances);

    for (const t of transfers) {
      expect(Number.isInteger(t.amount)).toBe(true);
      expect(t.amount).toBeGreaterThan(0);
    }
    assertFullySettled(balances, transfers);
  });

  it("five-person scenario fully settles without leftover", () => {
    const balances = bal({
      alice: 4000,
      bob: 1000,
      carol: -2000,
      dave: -1500,
      eve: -1500,
    });
    const transfers = reconcile(balances);

    assertValidTransfers(transfers);
    assertFullySettled(balances, transfers);
  });
});

// ---------------------------------------------------------------------------
// Return-type shape
// ---------------------------------------------------------------------------

describe("reconcile – return type", () => {
  it("returns an array", () => {
    expect(Array.isArray(reconcile(new Map()))).toBe(true);
  });

  it("each transfer has exactly the shape { from, to, amount }", () => {
    const [t] = reconcile(bal({ alice: -100, bob: 100 }));
    expect(t).toHaveProperty("from");
    expect(t).toHaveProperty("to");
    expect(t).toHaveProperty("amount");
    // No extra keys
    expect(Object.keys(t).sort()).toEqual(["amount", "from", "to"]);
  });
});
