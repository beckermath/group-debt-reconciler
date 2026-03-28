import { expect } from "@playwright/test";

const TEST_OTP = "000000";

/**
 * Register a new user via phone OTP and land on the home page.
 * Uses a unique phone number per call to avoid collisions.
 */
export async function registerAndLogin(
  page: import("@playwright/test").Page,
  name: string = "E2E Tester"
) {
  const phone = `+1555${Date.now().toString().slice(-7)}`;

  await page.goto("/phone");
  await page.getByLabel("Phone number").fill(phone);
  await page.getByRole("button", { name: "Send code" }).click();

  // Wait for verify page — if there's an error, fail with the error text
  await expect(page).toHaveURL(/\/phone\/verify/, { timeout: 10000 }).catch(async (e) => {
    const errorText = await page.locator(".text-destructive").textContent().catch(() => null);
    if (errorText) throw new Error(`OTP send failed: ${errorText}`);
    throw e;
  });
  await page.getByLabel("Verification code").fill(TEST_OTP);
  await page.getByRole("button", { name: "Verify" }).click();

  // New user → setup page
  await expect(page).toHaveURL(/\/phone\/setup/, { timeout: 10000 });
  await page.getByLabel("Your name").fill(name);
  await page.getByRole("button", { name: "Get started" }).click();

  // Should land on home
  await expect(page).toHaveURL("/", { timeout: 10000 });
}

/**
 * Create a group via the dialog and navigate to the group detail page.
 */
export async function createGroup(
  page: import("@playwright/test").Page,
  name: string
) {
  await page.getByRole("button", { name: "Create group" }).first().click();
  await page.getByLabel("Group name").fill(name);
  await page.locator("[data-slot='dialog-content']").getByRole("button", { name: "Create group" }).click();
  await expect(page).toHaveURL(/\/group\/.*\/setup/, { timeout: 10000 });
  const groupUrl = page.url().replace("/setup", "");
  await page.goto(groupUrl);
  await expect(page).toHaveURL(/\/group\/(?!.*setup)/, { timeout: 10000 });
}
