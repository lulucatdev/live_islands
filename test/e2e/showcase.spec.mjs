import { expect, test } from "@playwright/test";

const featureIds = [
  "react-vue",
  "ssr-static",
  "lazy-deferred",
  "liveview-events",
  "benchmarks",
];

async function installIslandProbe(page) {
  await page.addInitScript(() => {
    const state = {
      mounted: [],
      hydrated: [],
      deferredLoaded: [],
    };

    window.__showcaseIslandProbe = state;

    const rememberIsland = (type, event) => {
      const el = event.detail?.el;
      state[type].push({
        framework:
          event.detail?.framework || el?.getAttribute?.("data-framework"),
        name: event.detail?.name || el?.getAttribute?.("data-name"),
        client: el?.getAttribute?.("data-client") || null,
        prefetch: el?.getAttribute?.("data-prefetch") || null,
        ssr: el?.hasAttribute?.("data-ssr") || false,
        serverOnly: el?.hasAttribute?.("data-server-only") || false,
        deferred: el?.hasAttribute?.("data-deferred") || false,
      });
    };

    window.addEventListener("live-islands:mounted", (event) =>
      rememberIsland("mounted", event),
    );
    window.addEventListener("live-islands:hydrated", (event) =>
      rememberIsland("hydrated", event),
    );
    window.addEventListener("live-islands:deferred:load", (event) =>
      rememberIsland("deferredLoaded", event),
    );
  });
}

async function initialHtml(page, path) {
  const response = await page.request.get(path);
  expect(response.ok()).toBe(true);
  return response.text();
}

async function islandManifest(page) {
  return page.evaluate(() => window.__liveIslandsPrefetch?.manifest?.() || []);
}

async function islandEvents(page, type) {
  return page.evaluate((eventType) => {
    return window.__showcaseIslandProbe?.[eventType] || [];
  }, type);
}

async function hasIslandEvent(page, type, expected) {
  return page.evaluate(
    ({ eventType, expectedEvent }) =>
      (window.__showcaseIslandProbe?.[eventType] || []).some((event) =>
        Object.entries(expectedEvent).every(
          ([key, value]) => event[key] === value,
        ),
      ),
    { eventType: type, expectedEvent: expected },
  );
}

async function expectIslandEvent(page, type, expected) {
  await expect.poll(() => hasIslandEvent(page, type, expected)).toBe(true);
}

test("showcase home is a feature map, not a mixed demo page", async ({
  page,
}) => {
  await page.goto("/", { waitUntil: "networkidle" });

  await expect(page.getByTestId("showcase-home")).toBeVisible();
  await expect(page.getByTestId("feature-map")).toBeVisible();

  for (const featureId of featureIds) {
    await expect(page.getByTestId(`feature-card-${featureId}`)).toHaveAttribute(
      "href",
      `/features/${featureId}`,
    );
  }

  await expect(page.locator("[data-framework][data-name]")).toHaveCount(0);
});

test("react-vue feature page isolates framework parity", async ({ page }) => {
  await installIslandProbe(page);
  const html = await initialHtml(page, "/features/react-vue");

  expect(html).toMatch(/id="feature_react_command"[^>]*data-ssr(?:\s|>)/);
  expect(html).toMatch(/id="feature_vue_board"[^>]*data-ssr(?:\s|>)/);
  expect(html).toContain("Command deck");
  expect(html).toContain("Active signal: edge");

  await page.goto("/features/react-vue", { waitUntil: "networkidle" });

  await expect(page.getByTestId("feature-page-react-vue")).toBeVisible();
  await expect(page.getByTestId("feature-block-react-vue")).toBeVisible();
  await expect(page.getByTestId("showcase-react-command")).toBeVisible();
  await expect(page.getByTestId("showcase-vue-board")).toBeVisible();

  expect(await islandManifest(page)).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        page: "/features/react-vue",
        framework: "react",
        name: "ShowcaseCommand",
        client: "load",
        prefetch: "load",
        serverOnly: false,
        deferred: false,
      }),
      expect.objectContaining({
        page: "/features/react-vue",
        framework: "vue",
        name: "showcase-vue-board",
        client: "load",
        prefetch: "none",
        serverOnly: false,
        deferred: false,
      }),
    ]),
  );

  await expectIslandEvent(page, "hydrated", {
    framework: "react",
    name: "ShowcaseCommand",
    client: "load",
  });
  await expectIslandEvent(page, "hydrated", {
    framework: "vue",
    name: "showcase-vue-board",
    client: "load",
  });

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
});

test("ssr-static feature page proves server-only islands stay static", async ({
  page,
}) => {
  await page.goto("/features/ssr-static", { waitUntil: "networkidle" });

  await expect(page.getByTestId("feature-page-ssr-static")).toBeVisible();
  await expect(page.getByTestId("showcase-react-server-proof")).toBeVisible();
  await expect(page.getByTestId("showcase-vue-server-proof")).toBeVisible();

  await expect(page.locator("#feature_react_server")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );
  await expect(page.locator("#feature_vue_server")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );
  await expect(
    page.locator("[data-framework][data-name][phx-hook]"),
  ).toHaveCount(0);

  expect(await islandManifest(page)).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        page: "/features/ssr-static",
        framework: "react",
        name: "ShowcaseProof",
        client: "none",
        prefetch: "none",
        serverOnly: true,
      }),
      expect.objectContaining({
        page: "/features/ssr-static",
        framework: "vue",
        name: "showcase-vue-proof",
        client: "none",
        prefetch: "none",
        serverOnly: true,
      }),
    ]),
  );
});

test("lazy-deferred feature page separates deferred HTML from visible hydration", async ({
  page,
}) => {
  await installIslandProbe(page);
  const html = await initialHtml(page, "/features/lazy-deferred");

  expect(html).toContain("showcase-react-deferred-fallback");
  expect(html).toContain("showcase-vue-deferred-fallback");
  expect(html).toMatch(/id="feature_lazy_vue_board"[^>]*data-client="visible"/);
  expect(html).toMatch(/id="feature_lazy_vue_board"[^>]*data-prefetch="none"/);

  await page.goto("/features/lazy-deferred", { waitUntil: "networkidle" });

  await expect(page.getByTestId("feature-page-lazy-deferred")).toBeVisible();
  await expect(page.getByTestId("showcase-react-deferred-proof")).toBeVisible();
  await expect(page.getByTestId("showcase-vue-deferred-proof")).toBeVisible();

  await expectIslandEvent(page, "deferredLoaded", {
    framework: "react",
    name: "ShowcaseProof",
  });
  await expectIslandEvent(page, "deferredLoaded", {
    framework: "vue",
    name: "showcase-vue-proof",
  });

  expect(
    await hasIslandEvent(page, "hydrated", {
      framework: "vue",
      name: "showcase-vue-board",
    }),
  ).toBe(false);

  await page.getByTestId("showcase-vue-board").scrollIntoViewIfNeeded();
  await expectIslandEvent(page, "hydrated", {
    framework: "vue",
    name: "showcase-vue-board",
    client: "visible",
    prefetch: "none",
  });

  const vueEvents = (await islandEvents(page, "hydrated")).filter(
    (event) => event.framework === "vue" && event.name === "showcase-vue-board",
  );
  expect(vueEvents).toHaveLength(1);
});

test("liveview-events feature page keeps server controls explicit", async ({
  page,
}) => {
  await page.goto("/features/liveview-events", { waitUntil: "networkidle" });

  await expect(page.getByTestId("feature-page-liveview-events")).toBeVisible();
  await expect(page.getByTestId("showcase-native-form")).toBeVisible();
  await expect(page.getByTestId("showcase-react-command")).toBeVisible();

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

  await page.getByTestId("showcase-react-run").click();
  await expect(page.getByTestId("showcase-react-reply")).toContainText(
    "React reply",
  );
});

test("benchmarks feature page points heavy work to the dedicated lab", async ({
  page,
}) => {
  await page.goto("/features/benchmarks", { waitUntil: "networkidle" });

  await expect(page.getByTestId("feature-page-benchmarks")).toBeVisible();
  await expect(page.getByTestId("feature-block-benchmarks")).toBeVisible();
  await expect(page.getByTestId("feature-open-benchmarks")).toHaveAttribute(
    "href",
    "/benchmarks",
  );
  await expect(page.locator("[data-framework][data-name]")).toHaveCount(0);
});
