import "@/lib/env";
import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { db } from "@/db";
import { users } from "@/db/schema";
import { eq } from "drizzle-orm";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      name?: string | null;
      phoneNumber?: string | null;
      email?: string | null;
      image?: string | null;
    };
  }
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  trustHost: true,
  providers: [
    Credentials({
      credentials: {
        phoneNumber: {},
        userId: {},
      },
      async authorize(credentials) {
        // This is called after OTP verification succeeds.
        // The userId is passed from the verifyOtp action.
        const userId = credentials?.userId as string;
        const phoneNumber = credentials?.phoneNumber as string;
        if (!userId || !phoneNumber) return null;

        const [user] = await db
          .select()
          .from(users)
          .where(eq(users.id, userId));

        if (!user || user.phoneNumber !== phoneNumber) return null;

        return {
          id: user.id,
          name: user.name,
          phoneNumber: user.phoneNumber,
          email: user.email,
        };
      },
    }),
  ],
  session: { strategy: "jwt" },
  pages: {
    signIn: "/phone",
  },
  callbacks: {
    jwt({ token, user }) {
      if (user?.id) {
        token.sub = user.id;
        token.phoneNumber = (user as { phoneNumber?: string }).phoneNumber;
      }
      return token;
    },
    session({ session, token }) {
      if (session.user) {
        session.user.id = token.sub as string;
        session.user.phoneNumber = token.phoneNumber as string | undefined;
      }
      return session;
    },
  },
});
