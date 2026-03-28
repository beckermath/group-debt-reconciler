import { test, expect } from "@playwright/test";
import { registerAndLogin, createGroup, addGuestMember } from "./helpers";

async function setupGroupWithMembers(page: import("@playwright/test").Page) {
  await registerAndLogin(page, "Expense Tester");
  await createGroup(page, "Test Group");

  await addGuestMember(page, "Bob");

  // Switch to Expenses tab
  await page.getByRole("tab", { name: /Expenses/ }).click();
}

async function addExpenseViaDialog(
  page: import("@playwright/test").Page,
  description: string,
  amount: string
) {
  await page.getByRole("button", { name: "Add Expense" }).first().click();
  const dialog = page.locator("[data-slot='dialog-content']");
  await dialog.getByLabel("Description").fill(description);
  await dialog.getByLabel("Amount ($)").fill(amount);
  await dialog.getByRole("button", { name: "Add Expense" }).click();
}

test.describe("Expenses", () => {
  test("can add an equal split expense", async ({ page }) => {
    await setupGroupWithMembers(page);
    await addExpenseViaDialog(page, "Dinner", "50");

    await expect(page.getByText("Dinner")).toBeVisible({ timeout: 10000 });
    await expect(page.getByText("$50.00")).toBeVisible();
  });

  test("shows balances after adding expense", async ({ page }) => {
    await setupGroupWithMembers(page);
    await addExpenseViaDialog(page, "Groceries", "100");

    await expect(page.getByText("Settle Up")).toBeVisible({ timeout: 10000 });
    await expect(page.getByText("$50.00").first()).toBeVisible({ timeout: 10000 });
  });

  test("can delete an expense", async ({ page }) => {
    await setupGroupWithMembers(page);
    await addExpenseViaDialog(page, "To Delete", "25");
    await expect(page.getByText("To Delete")).toBeVisible({ timeout: 10000 });

    await page.getByRole("button", { name: "Delete", exact: true }).click();
    await expect(page.getByText("To Delete")).not.toBeVisible({ timeout: 10000 });
  });

  test("can edit an expense", async ({ page }) => {
    await setupGroupWithMembers(page);
    await addExpenseViaDialog(page, "Original", "30");
    await expect(page.getByText("Original")).toBeVisible({ timeout: 10000 });

    await page.getByRole("button", { name: "Edit" }).click();

    const dialog = page.locator("[data-slot='dialog-content']");
    await dialog.getByLabel("Description").clear();
    await dialog.getByLabel("Description").fill("Updated");
    await dialog.getByRole("button", { name: "Save changes" }).click();

    await expect(page.getByText("Updated")).toBeVisible({ timeout: 10000 });
  });
});
