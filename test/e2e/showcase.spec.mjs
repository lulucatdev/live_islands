import { expect, test } from "@playwright/test";

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
        ssr: el?.getAttribute?.("data-ssr") === "true",
        serverOnly: el?.getAttribute?.("data-server-only") === "true",
        deferred: el?.getAttribute?.("data-deferred") === "true",
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

async function islandManifest(page) {
  return page.evaluate(() => window.__liveIslandsPrefetch?.manifest?.() || []);
}

async function initialHtml(page) {
  const response = await page.request.get("/");
  expect(response.ok()).toBe(true);
  return response.text();
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

test("default showcase balances React, Vue, SSR, deferred, and LiveView", async ({
  page,
}) => {
  await installIslandProbe(page);

  const html = await initialHtml(page);
  await page.goto("/", { waitUntil: "networkidle" });

  await test.step("renders the LiveView shell with SSR React and Vue content", async () => {
    expect(html).toMatch(/id="showcase_react_command"[^>]*data-ssr(?:\s|>)/);
    expect(html).toMatch(/id="showcase_vue_board"[^>]*data-ssr(?:\s|>)/);
    expect(html).toContain("Command deck");
    expect(html).toContain("Active signal: edge");

    await expect(page.getByTestId("showcase-page")).toBeVisible();
    await expect(page.getByTestId("showcase-react-command")).toBeVisible();
    await expect(page.getByTestId("showcase-vue-board")).toBeVisible();
    await expect(page.getByTestId("showcase-react-reply")).toContainText(
      "React reply waiting",
    );
    await expect(page.getByTestId("showcase-vue-active")).toContainText("edge");
  });

  await test.step("declares the page-level island contract explicitly", async () => {
    expect(await islandManifest(page)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          page: "/",
          framework: "react",
          name: "ShowcaseCommand",
          client: "load",
          prefetch: "load",
          serverOnly: false,
          deferred: false,
        }),
        expect.objectContaining({
          page: "/",
          framework: "vue",
          name: "showcase-vue-board",
          client: "visible",
          prefetch: "none",
          serverOnly: false,
          deferred: false,
        }),
        expect.objectContaining({
          page: "/",
          framework: "react",
          name: "ShowcaseProof",
          serverOnly: true,
        }),
        expect.objectContaining({
          page: "/",
          framework: "vue",
          name: "showcase-vue-proof",
          serverOnly: true,
        }),
      ]),
    );

    await expect(page.locator("#showcase_react_command")).toHaveAttribute(
      "data-client",
      "load",
    );
    await expect(page.locator("#showcase_vue_board")).toHaveAttribute(
      "data-client",
      "visible",
    );
    await expect(page.locator("#showcase_vue_board")).toHaveAttribute(
      "data-prefetch",
      "none",
    );
  });

  await test.step("keeps server-only and deferred proof islands static", async () => {
    for (const id of [
      "#showcase_react_server",
      "#showcase_vue_server",
      "#showcase_react_deferred",
      "#showcase_vue_deferred",
    ]) {
      await expect(page.locator(id)).not.toHaveAttribute("phx-hook", /.+/);
    }

    await expect(page.getByTestId("showcase-react-server-proof")).toBeVisible();
    await expect(page.getByTestId("showcase-vue-server-proof")).toBeVisible();
    await expect(
      page.getByTestId("showcase-react-deferred-proof"),
    ).toBeVisible();
    await expect(page.getByTestId("showcase-vue-deferred-proof")).toBeVisible();
    await expectIslandEvent(page, "deferredLoaded", {
      framework: "react",
      name: "ShowcaseProof",
    });
    await expectIslandEvent(page, "deferredLoaded", {
      framework: "vue",
      name: "showcase-vue-proof",
    });
  });

  await test.step("hydrates React on load but keeps Vue lazy until visible", async () => {
    await expectIslandEvent(page, "hydrated", {
      framework: "react",
      name: "ShowcaseCommand",
      client: "load",
      prefetch: "load",
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
      (event) =>
        event.framework === "vue" && event.name === "showcase-vue-board",
    );
    expect(vueEvents).toHaveLength(1);
  });

  await test.step("round-trips Vue and React island events through LiveView", async () => {
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

  await test.step("keeps native LiveView controls working beside islands", async () => {
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
});
