import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Rekn — Split expenses with friends",
  description:
    "Rekn is a group expense-splitting app that makes it easy to track shared costs and settle up.",
};

export default function LandingPage() {
  return (
    <main
      style={{
        maxWidth: 600,
        margin: "0 auto",
        padding: "48px 24px",
        fontFamily: "system-ui, -apple-system, sans-serif",
        color: "#1a1a1a",
        lineHeight: 1.6,
      }}
    >
      <h1 style={{ fontSize: 32, fontWeight: 700, marginBottom: 8 }}>Rekn</h1>
      <p style={{ fontSize: 18, color: "#555", marginBottom: 32 }}>
        Split expenses with friends, track balances, and settle up — all in one
        place.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          What is Rekn?
        </h2>
        <p>
          Rekn is a mobile and web application for splitting group expenses.
          Users create groups, log shared expenses, and Rekn calculates who owes
          whom. When it&apos;s time to settle up, Rekn shows the simplest set of
          payments to zero out all balances.
        </p>
        <p>
          Want to try it out? Rekn offers a <strong>guest mode</strong> that
          lets you explore the app without creating an account or providing a
          phone number. Guests can create groups, add expenses, and see how
          balances work — no sign-up required.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          How we use SMS
        </h2>
        <p>
          Rekn uses SMS solely for <strong>one-time passcode (OTP)</strong>{" "}
          verification during sign-in. When a user enters their phone number to
          log in, we send a single SMS containing a 6-digit verification code.
          No marketing messages, no recurring texts — just authentication.
        </p>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Messaging consent
        </h2>
        <ul style={{ paddingLeft: 20 }}>
          <li>
            Users opt in by entering their phone number and tapping &quot;Send
            Code&quot; on the sign-in screen.
          </li>
          <li>
            Message frequency: one SMS per sign-in attempt (no recurring
            messages).
          </li>
          <li>Standard message and data rates may apply.</li>
          <li>
            Users can stop at any time by not requesting a code. No ongoing
            subscription.
          </li>
        </ul>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Contact
        </h2>
        <p>
          Rekn is built by Becker Mathie.
          <br />
          For questions or support, reach out at{" "}
          <a href="mailto:beckerjmathie@gmail.com" style={{ color: "#5E7B8A" }}>
            beckerjmathie@gmail.com
          </a>
          .
        </p>
      </section>
    </main>
  );
}
