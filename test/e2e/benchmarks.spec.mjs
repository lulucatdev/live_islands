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

test("benchmark page can run an online browser measurement", async ({
  page,
}) => {
  await page.goto("/benchmarks");

  await expect(page.getByTestId("benchmark-online-runner")).toBeVisible();
  await page.getByTestId("benchmark-run-online").click();

  await expect(page.getByTestId("benchmark-online-status")).toContainText(
    "Measurement complete",
    { timeout: 20_000 },
  );
  await expect(page.getByTestId("benchmark-online-result")).toBeVisible();
  await expect(page.getByTestId("benchmark-online-initial-total")).toContainText(
    /B|KiB|MiB/,
  );
  await expect(page.getByTestId("benchmark-online-initial-js")).toContainText(
    /B|KiB|MiB/,
  );
  await expect(page.getByTestId("benchmark-online-heavy-duration")).toContainText(
    /ms/,
  );
  await expect(page.getByTestId("benchmark-online-checks")).toContainText(
    "Initial route bytes",
  );
  await expect(page.getByTestId("benchmark-heavy-report")).toContainText(
    "Rendered",
  );
});
