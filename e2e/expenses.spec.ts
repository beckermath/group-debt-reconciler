import { test, expect } from "@playwright/test";

async function setupGroupWithMembers(page: import("@playwright/test").Page) {
  const email = `e2e-exp-${Date.now()}@rekn.test`;
  await page.goto("/register");
  await page.getByLabel("Name").fill("Expense Tester");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password", { exact: true }).fill("testpass123");
  await page.getByLabel("Confirm password").fill("testpass123");
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page).toHaveURL("/", { timeout: 10000 });

  // Create group via dialog
  await page.getByRole("button", { name: "Create group" }).click();
  await page.getByLabel("Group name").fill("Test Group");
  await page.getByRole("button", { name: "Create group" }).nth(1).click();
  await expect(page).toHaveURL(/\/group\/.*\/setup/, { timeout: 10000 });
  // Complete setup — navigate to group page
  await page.getByRole("button", { name: /skip for now/i }).click();
  await expect(page).toHaveURL(/\/group\/(?!.*setup)/, { timeout: 10000 });

  // Add a second member via Members tab
  await page.getByRole("tab", { name: /Members/ }).click();
  await page.getByPlaceholder("Member name").fill("Bob");
  await page.getByRole("button", { name: "Add" }).click();
  await expect(page.getByText("Bob").first()).toBeVisible({ timeout: 10000 });

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

    // Should show balances in the top card
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

    // Click Edit
    await page.getByRole("button", { name: "Edit" }).click();

    // Update description in the edit dialog
    const dialog = page.locator("[data-slot='dialog-content']");
    await dialog.getByLabel("Description").clear();
    await dialog.getByLabel("Description").fill("Updated");
    await dialog.getByRole("button", { name: "Save changes" }).click();

    await expect(page.getByText("Updated")).toBeVisible({ timeout: 10000 });
  });
});
