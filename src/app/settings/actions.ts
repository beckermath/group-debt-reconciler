"use server";

import { requireAuth } from "@/lib/auth-helpers";
import { signOut } from "@/lib/auth";
import { redirect } from "next/navigation";
import * as userService from "@/services/user-service";

export async function updateProfile(prevState: unknown, formData: FormData) {
  const name = (formData.get("name") as string)?.trim();

  if (!name) {
    return { error: "Name is required" };
  }

  try {
    const { userId } = await requireAuth();
    return await userService.updateProfile(userId, name);
  } catch (error) {
    if ((error as any)?.digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { error: "Something went wrong" };
  }
}

export async function deleteAccount(formData: FormData) {
  const confirmation = formData.get("confirmation") as string;

  if (confirmation !== "DELETE") return;

  try {
    const { userId } = await requireAuth();
    await userService.deleteAccount(userId);
    await signOut({ redirect: false });
    redirect("/phone");
  } catch (error) {
    if ((error as { digest?: string })?.digest?.startsWith("NEXT_REDIRECT")) throw error;
  }
}
