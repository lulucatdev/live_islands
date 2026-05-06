import { defineConfig, devices } from "@playwright/test";
import { fileURLToPath } from "node:url";

const exampleCwd = fileURLToPath(
  new URL("../../live_islands_examples", import.meta.url),
);
const port = process.env.E2E_PORT || "4021";
const vitePort = process.env.E2E_VITE_PORT || "5174";
const baseURL = `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: ".",
  timeout: 30_000,
  fullyParallel: false,
  use: {
    baseURL,
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: `PORT=${port} VITE_PORT=${vitePort} VITE_HOST=http://localhost:${vitePort} mix phx.server`,
    cwd: exampleCwd,
    url: `${baseURL}/capabilities`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
