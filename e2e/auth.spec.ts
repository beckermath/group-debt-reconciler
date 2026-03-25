import { test, expect } from "@playwright/test";

const testUser = {
  name: "E2E Tester",
  email: `e2e-${Date.now()}@rekn.test`,
  password: "testpass123",
};

test.describe("Authentication", () => {
  test("redirects unauthenticated users to login", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/login/);
  });

  test("shows register link on login page", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("link", { name: "Register" })).toBeVisible();
  });

  test("can register a new account", async ({ page }) => {
    await page.goto("/register");
    await page.getByLabel("Name").fill(testUser.name);
    await page.getByLabel("Email").fill(testUser.email);
    await page.getByLabel("Password", { exact: true }).fill(testUser.password);
    await page.getByLabel("Confirm password").fill(testUser.password);
    await page.getByRole("button", { name: "Create account" }).click();

    // Should redirect to home page
    await expect(page).toHaveURL("/", { timeout: 10000 });
    await expect(page.getByText("Your Groups")).toBeVisible();
  });

  test("can sign out and sign back in", async ({ page }) => {
    // Register first
    await page.goto("/register");
    const email = `e2e-signout-${Date.now()}@rekn.test`;
    await page.getByLabel("Name").fill("Sign Out Test");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password", { exact: true }).fill("testpass123");
    await page.getByLabel("Confirm password").fill("testpass123");
    await page.getByRole("button", { name: "Create account" }).click();
    await expect(page).toHaveURL("/", { timeout: 10000 });

    // Sign out
    await page.getByRole("button", { name: "Sign out", exact: true }).click();
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });

    // Sign back in
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password").fill("testpass123");
    await page.getByRole("button", { name: "Sign in" }).click();
    await expect(page).toHaveURL("/", { timeout: 10000 });
    await expect(page.getByText("Your Groups")).toBeVisible();
  });

  test("shows error for invalid credentials", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill("nonexistent@rekn.test");
    await page.getByLabel("Password").fill("wrongpassword");
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page.getByText("Invalid email or password")).toBeVisible({ timeout: 5000 });
  });

  test("shows error for duplicate registration", async ({ page }) => {
    // Register once
    const email = `e2e-dup-${Date.now()}@rekn.test`;
    await page.goto("/register");
    await page.getByLabel("Name").fill("First");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password", { exact: true }).fill("testpass123");
    await page.getByLabel("Confirm password").fill("testpass123");
    await page.getByRole("button", { name: "Create account" }).click();
    await expect(page).toHaveURL("/", { timeout: 10000 });

    // Sign out
    await page.getByRole("button", { name: "Sign out", exact: true }).click();
    await expect(page).toHaveURL(/\/login/, { timeout: 10000 });

    // Try to register again with same email
    await page.goto("/register");
    await page.getByLabel("Name").fill("Second");
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password", { exact: true }).fill("testpass123");
    await page.getByLabel("Confirm password").fill("testpass123");
    await page.getByRole("button", { name: "Create account" }).click();

    await expect(page.getByText("An account with this email already exists")).toBeVisible({ timeout: 5000 });
  });
});
