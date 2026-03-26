import { describe, it, expect } from "vitest";
import { computeBalances } from "./balances";

describe("computeBalances", () => {
  it("returns zero balances when no expenses", () => {
    const balances = computeBalances([], ["a", "b"]);
    expect(balances.get("a")).toBe(0);
    expect(balances.get("b")).toBe(0);
  });

  it("computes correct balances for a single expense split equally", () => {
    const balances = computeBalances(
      [
        {
          paidBy: "a",
          amount: 1000,
          splits: [
            { memberId: "a", share: 500 },
            { memberId: "b", share: 500 },
          ],
        },
      ],
      ["a", "b"]
    );
    // a paid 1000 but owes 500 → net +500
    expect(balances.get("a")).toBe(500);
    // b paid 0 but owes 500 → net -500
    expect(balances.get("b")).toBe(-500);
  });

  it("computes correct balances across multiple expenses", () => {
    const balances = computeBalances(
      [
        {
          paidBy: "a",
          amount: 600,
          splits: [
            { memberId: "a", share: 200 },
            { memberId: "b", share: 200 },
            { memberId: "c", share: 200 },
          ],
        },
        {
          paidBy: "b",
          amount: 300,
          splits: [
            { memberId: "a", share: 100 },
            { memberId: "b", share: 100 },
            { memberId: "c", share: 100 },
          ],
        },
      ],
      ["a", "b", "c"]
    );
    // a: +600 - 200 - 100 = +300
    expect(balances.get("a")).toBe(300);
    // b: +300 - 200 - 100 = 0
    expect(balances.get("b")).toBe(0);
    // c: 0 - 200 - 100 = -300
    expect(balances.get("c")).toBe(-300);
  });

  it("handles members with no expenses", () => {
    const balances = computeBalances(
      [
        {
          paidBy: "a",
          amount: 100,
          splits: [{ memberId: "a", share: 100 }],
        },
      ],
      ["a", "b"]
    );
    expect(balances.get("a")).toBe(0); // paid 100, owes 100
    expect(balances.get("b")).toBe(0); // not involved
  });
});
