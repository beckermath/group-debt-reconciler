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

// Helper to create a group via the dialog and setup flow
async function createGroup(page: import("@playwright/test").Page, name: string) {
  await page.getByRole("button", { name: "Create group" }).first().click();
  await page.getByLabel("Group name").fill(name);
  await page.locator("[data-slot='dialog-content']").getByRole("button", { name: "Create group" }).click();
  // Lands on setup page — navigate directly to group detail
  await expect(page).toHaveURL(/\/group\/.*\/setup/, { timeout: 10000 });
  const groupUrl = page.url().replace("/setup", "");
  await page.goto(groupUrl);
  await expect(page).toHaveURL(/\/group\/(?!.*setup)/, { timeout: 10000 });
}

test.describe("Groups", () => {
  test("can create a group and navigate to it", async ({ page }) => {
    await registerAndLogin(page);
    await createGroup(page, "Vacation Trip");

    await expect(page.getByText("Vacation Trip")).toBeVisible();
    await expect(page.getByText("1 member")).toBeVisible({ timeout: 10000 });
  });

  test("group appears on home page", async ({ page }) => {
    await registerAndLogin(page);
    await createGroup(page, "Roommates");

    // Navigate home
    await page.getByRole("link", { name: "Rekn" }).click();
    await expect(page.getByText("Roommates")).toBeVisible();
  });

  test("can add a guest member", async ({ page }) => {
    await registerAndLogin(page);
    await createGroup(page, "Dinner Club");

    // Click on Members tab to access the add member form
    await page.getByRole("tab", { name: /Members/ }).click();
    await page.getByPlaceholder("Member name").fill("Guest Dave");
    await page.getByRole("button", { name: "Add", exact: true }).click();

    await expect(page.getByText("Guest Dave").first()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText("guest").first()).toBeVisible();
  });

  test("can rename a group by clicking the name", async ({ page }) => {
    await registerAndLogin(page);
    await createGroup(page, "Old Name");

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
