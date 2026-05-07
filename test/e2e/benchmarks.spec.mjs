import { expect, test } from "@playwright/test";

test("deferred server islands load static HTML without hooks", async ({
  page,
}) => {
  const deferredResponses = [];
  page.on("response", (response) => {
    if (response.url().includes("/live-islands/deferred")) {
      deferredResponses.push(response);
    }
  });

  await page.goto("/benchmarks");

  const deferred = page.locator("#benchmark_deferred_report");
  await expect(deferred).toHaveAttribute("data-deferred", "");
  await expect(deferred).not.toHaveAttribute("phx-hook", /.+/);
  await expect(page.getByTestId("benchmark-deferred-report")).toBeVisible();
  await expect(page.getByTestId("benchmark-deferred-fallback")).toHaveCount(0);
  await expect
    .poll(() => deferredResponses.some((response) => response.ok()))
    .toBe(true);

  const manifest = await page.evaluate(() =>
    window.__liveIslandsPrefetch
      ?.manifest()
      .find((island) => island.name === "BenchmarkDeferredReport"),
  );

  expect(manifest).toMatchObject({
    framework: "react",
    serverOnly: true,
    deferred: true,
    client: "none",
    prefetch: "none",
  });
});
