import { expect, test } from "@playwright/test";

const forbiddenClientChunk = (url) =>
  /\/react\/hooks|\/vue\/hooks|react-dom|runtime-core\.esm|\/react-components\/benchmark-static-report|\/vue-components\/benchmark-probe|\/assets\/(benchmark-static-report|benchmark-probe|hooks-)/.test(
    url,
  );

test("server-only islands render without hydration or framework chunks", async ({
  page,
}) => {
  const responses = [];
  page.on("response", (response) => responses.push(response.url()));

  await page.addInitScript(() => {
    window.__serverOnlyEvents = [];

    for (const eventName of [
      "live-islands:mounted",
      "live-islands:hydrated",
      "live-islands:prefetch:queue",
      "live-islands:prefetch:load",
    ]) {
      window.addEventListener(eventName, (event) => {
        window.__serverOnlyEvents.push({
          eventName,
          name:
            event.detail?.name ||
            event.detail?.el?.getAttribute?.("data-name") ||
            null,
        });
      });
    }
  });

  await page.goto("/server-only", { waitUntil: "networkidle" });

  await expect(page.getByTestId("server-only-zero-js-page")).toBeVisible();
  await expect(page.getByTestId("benchmark-server-report")).toBeVisible();
  await expect(page.getByTestId("benchmark-vue-probe")).toBeVisible();
  await expect(page.getByTestId("server-only-proof-summary")).toBeVisible();

  await expect(page.locator("#server_only_react_proof")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );
  await expect(page.locator("#server_only_vue_proof")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );

  const manifest = await page.evaluate(
    () => window.__liveIslandsPrefetch?.manifest?.() || [],
  );
  expect(manifest).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        framework: "react",
        name: "BenchmarkStaticReport",
        client: "none",
        prefetch: "none",
        serverOnly: true,
      }),
      expect.objectContaining({
        framework: "vue",
        name: "benchmark-probe",
        client: "none",
        prefetch: "none",
        serverOnly: true,
      }),
    ]),
  );

  const events = await page.evaluate(() => window.__serverOnlyEvents);
  expect(events).toEqual([]);
  expect(responses.filter(forbiddenClientChunk)).toEqual([]);
});
