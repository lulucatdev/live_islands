import { defineConfig, devices } from "@playwright/test";
import { fileURLToPath } from "node:url";

const exampleCwd = fileURLToPath(
  new URL("../../live_react_examples", import.meta.url),
);

export default defineConfig({
  testDir: ".",
  timeout: 30_000,
  fullyParallel: false,
  use: {
    baseURL: "http://127.0.0.1:4000",
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: "mix phx.server",
    cwd: exampleCwd,
    url: "http://127.0.0.1:4000/capabilities",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
