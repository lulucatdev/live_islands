import { expect, test } from "@playwright/test";

test("default showcase balances React, Vue, SSR, deferred, and LiveView", async ({
  page,
}) => {
  await page.addInitScript(() => {
    window.__showcaseHydrated = [];
    window.addEventListener("live-islands:hydrated", (event) => {
      window.__showcaseHydrated.push(
        `${event.detail?.framework}:${event.detail?.name}`,
      );
    });
  });

  await page.goto("/", { waitUntil: "networkidle" });

  await expect(page.getByTestId("showcase-page")).toBeVisible();
  await expect(page.getByTestId("showcase-react-command")).toBeVisible();
  await expect(page.getByTestId("showcase-vue-board")).toBeVisible();

  const manifest = await page.evaluate(() =>
    window.__liveIslandsPrefetch
      ?.manifest()
      .map((island) => `${island.page}:${island.framework}:${island.name}`)
      .sort(),
  );

  expect(manifest).toEqual(
    expect.arrayContaining([
      "/:react:ShowcaseCommand",
      "/:vue:showcase-vue-board",
      "/:react:ShowcaseProof",
      "/:vue:showcase-vue-proof",
    ]),
  );

  await expect(page.locator("#showcase_react_server")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );
  await expect(page.locator("#showcase_vue_server")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );
  await expect(page.getByTestId("showcase-react-server-proof")).toBeVisible();
  await expect(page.getByTestId("showcase-vue-server-proof")).toBeVisible();
  await expect(page.getByTestId("showcase-react-deferred-proof")).toBeVisible();
  await expect(page.getByTestId("showcase-vue-deferred-proof")).toBeVisible();

  await page.getByTestId("showcase-vue-board").scrollIntoViewIfNeeded();
  await page.waitForFunction(() =>
    window.__showcaseHydrated?.includes("vue:showcase-vue-board"),
  );
  await page.getByTestId("showcase-vue-signal-ssr").click();
  await expect(page.getByTestId("showcase-active-signal")).toContainText(
    "SSR lane",
  );
  await expect(page.getByTestId("showcase-vue-active")).toContainText("ssr");

  await page.getByTestId("showcase-react-signal-react").click();
  await page.getByTestId("showcase-react-run").click();
  await expect(page.getByTestId("showcase-react-reply")).toContainText(
    "React reply",
  );
  await expect(page.locator("#showcase-events")).toContainText(
    "React command inspected",
  );

  await page.getByTestId("showcase-native-name").fill("No");
  await expect(page.getByTestId("showcase-native-error")).toContainText(
    "use at least 4 characters",
  );
  await page.getByTestId("showcase-native-name").fill("Vue parity proof");
  await page.getByTestId("showcase-native-submit").click();
  await expect(page.locator("#showcase-events")).toContainText(
    "Native LiveView form captured Vue parity proof",
  );

  await page.getByTestId("showcase-js-toggle").click();
  await expect(page.locator("#showcase-js-panel")).toBeVisible();
});
