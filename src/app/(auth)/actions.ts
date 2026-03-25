"use server";

import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { randomUUID } from "crypto";
import bcrypt from "bcryptjs";
import { signIn } from "@/lib/auth";
import { redirect } from "next/navigation";

export async function register(prevState: unknown, formData: FormData) {
  const name = (formData.get("name") as string)?.trim();
  const email = (formData.get("email") as string)?.trim().toLowerCase();
  const password = formData.get("password") as string;
  const confirmPassword = formData.get("confirmPassword") as string;

  if (!name || !email || !password) {
    return { error: "All fields are required" };
  }

  if (password.length < 8) {
    return { error: "Password must be at least 8 characters" };
  }

  if (password !== confirmPassword) {
    return { error: "Passwords do not match" };
  }

  const [existing] = await db.select().from(users).where(eq(users.email, email));
  if (existing) {
    return { error: "An account with this email already exists" };
  }

  const passwordHash = await bcrypt.hash(password, 10);
  await db.insert(users).values({
    id: randomUUID(),
    name,
    email,
    passwordHash,
  });

  await signIn("credentials", { email, password, redirect: false });
  redirect("/");
}

export async function login(prevState: unknown, formData: FormData) {
  const email = (formData.get("email") as string)?.trim().toLowerCase();
  const password = formData.get("password") as string;

  if (!email || !password) {
    return { error: "Email and password are required" };
  }

  try {
    await signIn("credentials", { email, password, redirect: false });
  } catch {
    return { error: "Invalid email or password" };
  }

  redirect("/");
}
