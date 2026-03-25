import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    coverage: {
      provider: "v8",
      // Scope coverage reporting to pure library modules.
      // actions.ts requires a live DB + Next.js runtime (integration-tested
      // separately). utils.ts is a one-line Tailwind helper.
      include: ["src/lib/reconcile.ts", "src/lib/splits.ts"],
      reporter: ["text", "lcov"],
      thresholds: {
        branches: 80,
        functions: 80,
        lines: 80,
        statements: 80,
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
