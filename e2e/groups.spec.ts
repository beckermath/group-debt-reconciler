import { test, expect } from "@playwright/test";
import { registerAndLogin, createGroup, addGuestMember } from "./helpers";

test.describe("Groups", () => {
  test("can create a group and navigate to it", async ({ page }) => {
    await registerAndLogin(page, "Group Tester");
    await createGroup(page, "Vacation Trip");

    await expect(page.getByText("Vacation Trip")).toBeVisible();
    await expect(page.getByText("1 member")).toBeVisible({ timeout: 10000 });
  });

  test("group appears on home page", async ({ page }) => {
    await registerAndLogin(page, "Group Tester");
    await createGroup(page, "Roommates");

    await page.getByRole("link", { name: "Rekn" }).click();
    await expect(page.getByText("Roommates")).toBeVisible();
  });

  test("can add a guest member", async ({ page }) => {
    await registerAndLogin(page, "Group Tester");
    await createGroup(page, "Dinner Club");

    await addGuestMember(page, "Guest Dave");
    await expect(page.getByText("guest").first()).toBeVisible();
  });

  test("can rename a group by clicking the name", async ({ page }) => {
    await registerAndLogin(page, "Group Tester");
    await createGroup(page, "Old Name");

    await page.getByText("Old Name").click();
    const input = page.locator("input.text-2xl");
    await input.clear();
    await input.fill("New Name");
    await input.press("Enter");

    await expect(page.getByText("New Name")).toBeVisible({ timeout: 5000 });
  });
});
