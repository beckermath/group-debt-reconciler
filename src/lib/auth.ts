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
      isGuest: boolean;
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
        guestId: {},
      },
      async authorize(credentials) {
        const guestId = credentials?.guestId as string;

        // Guest sign-in
        if (guestId) {
          const [guest] = await db
            .select()
            .from(users)
            .where(eq(users.id, guestId));

          if (!guest || !guest.isGuest) return null;

          return { id: guest.id, name: guest.name };
        }

        // Phone OTP sign-in
        const userId = credentials?.userId as string;
        const phoneNumber = credentials?.phoneNumber as string;
        if (!userId || !phoneNumber) return null;

        const [user] = await db
          .select()
          .from(users)
          .where(eq(users.id, userId));

        if (!user || user.phoneNumber !== phoneNumber) return null;

        return { id: user.id, name: user.name, email: user.email };
      },
    }),
  ],
  session: { strategy: "jwt" },
  pages: {
    signIn: "/phone",
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user?.id) {
        token.sub = user.id;
      }
      // Always read isGuest and phoneNumber from DB for fresh data
      if (token.sub) {
        const [dbUser] = await db
          .select({ isGuest: users.isGuest, phoneNumber: users.phoneNumber })
          .from(users)
          .where(eq(users.id, token.sub));
        if (dbUser) {
          token.isGuest = !!dbUser.isGuest;
          token.phoneNumber = dbUser.phoneNumber;
        }
      }
      return token;
    },
    session({ session, token }) {
      if (session.user) {
        session.user.id = token.sub as string;
        session.user.phoneNumber = (token.phoneNumber as string) ?? null;
        session.user.isGuest = !!token.isGuest;
      }
      return session;
    },
  },
});
