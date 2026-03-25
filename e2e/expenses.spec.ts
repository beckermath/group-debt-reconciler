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

  // Create group
  await page.getByPlaceholder("New group name").fill("Test Group");
  await page.getByRole("button", { name: "Create" }).click();
  await expect(page).toHaveURL(/\/group\//, { timeout: 10000 });

  // Add a second member
  await page.getByPlaceholder("Member name").fill("Bob");
  await page.getByRole("button", { name: "Add" }).click();
  await expect(page.getByText("Bob").first()).toBeVisible();
}

test.describe("Expenses", () => {
  test("can add an equal split expense", async ({ page }) => {
    await setupGroupWithMembers(page);

    await page.getByLabel("Description").fill("Dinner");
    await page.getByLabel("Amount ($)").fill("50");
    // Default: paid by first member, split between all
    await page.getByRole("button", { name: "Add Expense" }).click();

    await expect(page.getByText("Dinner")).toBeVisible({ timeout: 10000 });
    await expect(page.getByText("$50.00")).toBeVisible();
  });

  test("shows balances after adding expense", async ({ page }) => {
    await setupGroupWithMembers(page);

    await page.getByLabel("Description").fill("Groceries");
    await page.getByLabel("Amount ($)").fill("100");
    await page.getByRole("button", { name: "Add Expense" }).click();

    // Should show settle up section with balances
    await expect(page.getByText("Settle Up")).toBeVisible({ timeout: 10000 });
    await expect(page.getByText("$50.00").first()).toBeVisible();
  });

  test("can delete an expense", async ({ page }) => {
    await setupGroupWithMembers(page);

    await page.getByLabel("Description").fill("To Delete");
    await page.getByLabel("Amount ($)").fill("25");
    await page.getByRole("button", { name: "Add Expense" }).click();
    await expect(page.getByText("To Delete")).toBeVisible({ timeout: 10000 });

    await page.getByRole("button", { name: "Delete", exact: true }).click();
    await expect(page.getByText("To Delete")).not.toBeVisible({ timeout: 10000 });
  });

  test("can edit an expense", async ({ page }) => {
    await setupGroupWithMembers(page);

    await page.getByLabel("Description").fill("Original");
    await page.getByLabel("Amount ($)").fill("30");
    await page.getByRole("button", { name: "Add Expense" }).click();
    await expect(page.getByText("Original")).toBeVisible({ timeout: 10000 });

    // Click Edit
    await page.getByRole("button", { name: "Edit" }).click();

    // Update description in the dialog
    const dialog = page.locator("[data-slot='dialog-content']");
    await dialog.getByLabel("Description").clear();
    await dialog.getByLabel("Description").fill("Updated");
    await dialog.getByRole("button", { name: "Save changes" }).click();

    await expect(page.getByText("Updated")).toBeVisible({ timeout: 10000 });
  });
});
