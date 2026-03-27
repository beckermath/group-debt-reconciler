import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import Link from "next/link";
import { ThemeProvider } from "@/components/theme-provider";
import { SessionProvider } from "@/components/session-provider";
import { ThemeToggle } from "@/components/theme-toggle";
import { UserMenu } from "@/components/user-menu";
import { auth } from "@/lib/auth";
import "./globals.css";

const dmSans = DM_Sans({
  variable: "--font-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Rekn",
  description: "Reconcile group debts simply",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const session = await auth();

  return (
    <html lang="en" className={`${dmSans.variable} h-full antialiased`} suppressHydrationWarning>
      <body className="min-h-full flex flex-col">
        <SessionProvider>
        <ThemeProvider>
          {session?.user && (
            <header className="border-b px-4 sm:px-6 py-4 flex items-center justify-between">
              <Link href="/" className="text-xl font-bold tracking-tight text-primary">
                Rekn
              </Link>
              <div className="flex items-center gap-2">
                <UserMenu name={session.user.name ?? ""} />
                <ThemeToggle />
              </div>
            </header>
          )}
          <main className="flex-1 px-4 sm:px-6 py-6 sm:py-8 max-w-3xl mx-auto w-full">
            {children}
          </main>
        </ThemeProvider>
        </SessionProvider>
      </body>
    </html>
  );
}
