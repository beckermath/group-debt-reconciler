import { SignJWT, jwtVerify } from "jose";

const SECRET = new TextEncoder().encode(process.env.AUTH_SECRET!);
const ISSUER = "rekn-mobile";
const TOKEN_EXPIRY = "30d";

export interface MobileTokenPayload {
  userId: string;
  isGuest: boolean;
}

export async function issueMobileToken(payload: MobileTokenPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setIssuer(ISSUER)
    .setSubject(payload.userId)
    .setExpirationTime(TOKEN_EXPIRY)
    .sign(SECRET);
}

export async function verifyMobileToken(token: string): Promise<MobileTokenPayload | null> {
  try {
    const { payload } = await jwtVerify(token, SECRET, { issuer: ISSUER });
    if (!payload.sub) return null;
    return {
      userId: payload.sub,
      isGuest: (payload.isGuest as boolean) ?? false,
    };
  } catch {
    return null;
  }
}
