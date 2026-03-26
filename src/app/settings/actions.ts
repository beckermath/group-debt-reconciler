"use server";

import { requireAuth } from "@/lib/auth-helpers";
import { signOut } from "@/lib/auth";
import { redirect } from "next/navigation";
import * as userService from "@/services/user-service";

export async function updateProfile(prevState: unknown, formData: FormData) {
  const { userId } = await requireAuth();
  const name = (formData.get("name") as string)?.trim();

  if (!name) {
    return { error: "Name is required" };
  }

  return userService.updateProfile(userId, name);
}

export async function deleteAccount(formData: FormData) {
  const { userId } = await requireAuth();
  const confirmation = formData.get("confirmation") as string;

  if (confirmation !== "DELETE") return;

  await userService.deleteAccount(userId);
  await signOut({ redirect: false });
  redirect("/login");
}
