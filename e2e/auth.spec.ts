import { test, expect } from "@playwright/test";
import { registerAndLogin } from "./helpers";

test.describe("Authentication", () => {
  test("redirects unauthenticated users to phone sign-in", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/phone/);
  });

  test("can register a new account via phone OTP", async ({ page }) => {
    await registerAndLogin(page, "New User");
    await expect(page.getByText("Your Groups")).toBeVisible();
  });

  test("can sign out and sign back in", async ({ page }) => {
    // 10 digits — the +1 prefix is added by the input component
    const phone = `555${Date.now().toString().slice(-7)}`;

    // Register
    await page.goto("/phone");
    await page.getByLabel("Phone number").fill(phone);
    await page.getByRole("button", { name: "Send code" }).click();
    await expect(page).toHaveURL(/\/phone\/verify/, { timeout: 10000 });
    await page.getByLabel("Verification code").fill("000000");
    await page.getByRole("button", { name: "Verify" }).click();
    await expect(page).toHaveURL(/\/phone\/setup/, { timeout: 10000 });
    await page.getByLabel("Your name").fill("Sign Out Test");
    await page.getByRole("button", { name: "Get started" }).click();
    await expect(page).toHaveURL("/", { timeout: 10000 });

    // Sign out
    await page.getByRole("button", { name: "Sign out", exact: true }).click();
    await expect(page).toHaveURL(/\/phone/, { timeout: 10000 });

    // Sign back in with same phone
    await page.getByLabel("Phone number").fill(phone);
    await page.getByRole("button", { name: "Send code" }).click();
    await expect(page).toHaveURL(/\/phone\/verify/, { timeout: 10000 });
    await page.getByLabel("Verification code").fill("000000");
    await page.getByRole("button", { name: "Verify" }).click();

    // Existing user → goes straight to home
    await expect(page).toHaveURL("/", { timeout: 10000 });
    await expect(page.getByText("Your Groups")).toBeVisible();
  });

  test("shows error for incorrect OTP", async ({ page }) => {
    await page.goto("/phone");
    await page.getByLabel("Phone number").fill("+15559999999");
    await page.getByRole("button", { name: "Send code" }).click();
    await expect(page).toHaveURL(/\/phone\/verify/, { timeout: 10000 });

    await page.getByLabel("Verification code").fill("111111");
    await page.getByRole("button", { name: "Verify" }).click();

    await expect(page.getByText("Incorrect code")).toBeVisible({ timeout: 5000 });
  });
});
