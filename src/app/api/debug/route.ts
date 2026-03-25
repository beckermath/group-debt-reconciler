import { auth } from "@/lib/auth";
import { NextResponse } from "next/server";

export async function GET() {
  const session = await auth();
  return NextResponse.json({
    hasSession: !!session,
    hasUser: !!session?.user,
    userId: session?.user?.id ?? null,
    userName: session?.user?.name ?? null,
    userEmail: session?.user?.email ?? null,
  });
}
