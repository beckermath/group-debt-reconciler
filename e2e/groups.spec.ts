import { test, expect } from "@playwright/test";

// Helper to register and land on the home page
async function registerAndLogin(page: import("@playwright/test").Page) {
  const email = `e2e-grp-${Date.now()}@rekn.test`;
  await page.goto("/register");
  await page.getByLabel("Name").fill("Group Tester");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password", { exact: true }).fill("testpass123");
  await page.getByLabel("Confirm password").fill("testpass123");
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page).toHaveURL("/", { timeout: 10000 });
}

test.describe("Groups", () => {
  test("can create a group and navigate to it", async ({ page }) => {
    await registerAndLogin(page);

    await page.getByPlaceholder("New group name").fill("Vacation Trip");
    await page.getByRole("button", { name: "Create" }).click();

    // Should redirect to the group page
    await expect(page).toHaveURL(/\/group\//, { timeout: 10000 });
    await expect(page.getByText("Vacation Trip")).toBeVisible();
    // Creator should be auto-added as a member (name appears in member list)
    await expect(page.getByText("1 member")).toBeVisible({ timeout: 10000 });
  });

  test("group appears on home page", async ({ page }) => {
    await registerAndLogin(page);

    await page.getByPlaceholder("New group name").fill("Roommates");
    await page.getByRole("button", { name: "Create" }).click();
    await expect(page).toHaveURL(/\/group\//, { timeout: 10000 });

    // Navigate home
    await page.getByRole("link", { name: "Rekn" }).click();
    await expect(page.getByText("Roommates")).toBeVisible();
  });

  test("can add a guest member", async ({ page }) => {
    await registerAndLogin(page);

    await page.getByPlaceholder("New group name").fill("Dinner Club");
    await page.getByRole("button", { name: "Create" }).click();
    await expect(page).toHaveURL(/\/group\//, { timeout: 10000 });

    await page.getByPlaceholder("Member name").fill("Guest Dave");
    await page.getByRole("button", { name: "Add" }).click();

    await expect(page.getByText("Guest Dave").first()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText("guest").first()).toBeVisible();
  });

  test("can rename a group by clicking the name", async ({ page }) => {
    await registerAndLogin(page);

    await page.getByPlaceholder("New group name").fill("Old Name");
    await page.getByRole("button", { name: "Create" }).click();
    await expect(page).toHaveURL(/\/group\//, { timeout: 10000 });

    // Click the group name to edit
    await page.getByText("Old Name").click();
    const input = page.locator("input.text-2xl");
    await input.clear();
    await input.fill("New Name");
    await input.press("Enter");

    // Verify the name changed
    await expect(page.getByText("New Name")).toBeVisible({ timeout: 5000 });
  });
});
