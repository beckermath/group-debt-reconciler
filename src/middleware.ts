import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getToken } from "next-auth/jwt";

export async function middleware(request: NextRequest) {
  const token = await getToken({
    req: request,
    secret: process.env.AUTH_SECRET,
    secureCookie: request.nextUrl.protocol === "https:",
  });

  if (!token) {
    const phoneUrl = new URL("/phone", request.url);
    // For invite pages, redirect with callback URL
    if (request.nextUrl.pathname.startsWith("/invite/")) {
      phoneUrl.searchParams.set("callbackUrl", request.nextUrl.pathname);
    }
    return NextResponse.redirect(phoneUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!phone|api/auth|api/v1|_next/static|_next/image|favicon.ico).*)",
  ],
};
