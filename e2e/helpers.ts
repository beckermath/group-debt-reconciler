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
  // 10 digits — the +1 prefix is added by the input component
  const phone = Date.now().toString().slice(-10);

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
 * Create a group and navigate to the group detail page.
 * Clicks "Create group" button → setup wizard → names the group → navigates to detail.
 */
export async function createGroup(
  page: import("@playwright/test").Page,
  name: string
) {
  // Click "Create group" — goes straight to setup wizard
  await page.getByRole("button", { name: "Create group" }).first().click();
  await expect(page).toHaveURL(/\/group\/.*\/setup/, { timeout: 10000 });

  // Name the group in the setup wizard
  const nameInput = page.getByLabel("Group name");
  await nameInput.clear();
  await nameInput.fill(name);
  await nameInput.press("Enter");
  // Wait for the rename to complete (blur triggers server action)
  await page.waitForTimeout(1000);

  // Navigate directly to the group detail page
  const groupUrl = page.url().replace("/setup", "");
  await page.goto(groupUrl);
  await expect(page).toHaveURL(/\/group\/(?!.*setup)/, { timeout: 10000 });
}

/**
 * Add a guest member via the "Add people" dialog on the Members tab.
 */
export async function addGuestMember(
  page: import("@playwright/test").Page,
  name: string
) {
  await page.getByRole("tab", { name: /Members/ }).click();
  await page.getByRole("button", { name: "Add people" }).first().click();
  const dialog = page.locator("[data-slot='dialog-content']");
  await dialog.getByPlaceholder("Guest name").fill(name);
  await dialog.getByRole("button", { name: "Add", exact: true }).click();
  // Wait for success message in the dialog
  await expect(dialog.getByText(`${name} added as guest`)).toBeVisible({ timeout: 10000 });
  // Close the dialog
  await page.keyboard.press("Escape");
  // Wait for the member to appear on the page (router.refresh updates the data)
  await expect(page.getByText(name).first()).toBeVisible({ timeout: 10000 });
}
