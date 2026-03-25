import { auth } from "@/lib/auth";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

export async function GET() {
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get("__Secure-authjs.session-token")
    ?? cookieStore.get("authjs.session-token");

  const session = await auth();

  return NextResponse.json({
    hasSessionCookie: !!sessionCookie,
    cookieName: sessionCookie?.name ?? null,
    hasSession: !!session,
    hasUser: !!session?.user,
    userId: session?.user?.id ?? null,
    userName: session?.user?.name ?? null,
    userEmail: session?.user?.email ?? null,
    authSecret: process.env.AUTH_SECRET ? "set" : "missing",
  });
}
