import { expect, test } from "@playwright/test";

const simplePropsRequest = (url) =>
  url.includes("/react-components/simple-props.jsx") ||
  /\/simple-props-[\w-]+\.js/.test(url);

test("intent prefetch waits for explicit user intent and emits modulepreload evidence", async ({
  page,
}) => {
  const responses = [];
  page.on("response", (response) => responses.push(response.url()));

  await page.goto("/capabilities");

  await page.evaluate(() => {
    window.__liveIslandsPrefetchEvents = [];

    for (const type of [
      "queue",
      "start",
      "modulepreload",
      "load",
      "error",
      "skip",
    ]) {
      window.addEventListener(`live-islands:prefetch:${type}`, (event) => {
        const detail = event.detail || {};
        window.__liveIslandsPrefetchEvents.push({
          type,
          framework:
            detail.framework || detail.el?.getAttribute?.("data-framework"),
          name: detail.name || detail.el?.getAttribute?.("data-name"),
          policy: detail.policy,
          trigger: detail.trigger,
          priority: detail.priority,
          modulepreloadCount: detail.modulepreloadCount || detail.count || 0,
          urls: detail.modulepreloadUrls || detail.urls || [],
          reason: detail.reason || null,
        });
      });
    }
  });

  await page.waitForTimeout(250);
  expect(responses.some(simplePropsRequest)).toBe(false);

  await page.locator("#intent-prefetch-probe").evaluate((el) => {
    el.dispatchEvent(new PointerEvent("pointerenter"));
  });

  await expect
    .poll(() =>
      page.evaluate(() =>
        window.__liveIslandsPrefetchEvents.some(
          (event) => event.type === "load" && event.name === "SimpleProps",
        ),
      ),
    )
    .toBe(true);

  expect(responses.some(simplePropsRequest)).toBe(true);

  const events = await page.evaluate(() => window.__liveIslandsPrefetchEvents);
  expect(events).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        type: "queue",
        name: "SimpleProps",
        policy: "intent",
        trigger: "pointerenter",
        priority: "high",
      }),
      expect.objectContaining({
        type: "modulepreload",
        name: "SimpleProps",
        policy: "intent",
        trigger: "pointerenter",
      }),
      expect.objectContaining({
        type: "load",
        name: "SimpleProps",
        policy: "intent",
        trigger: "pointerenter",
        priority: "high",
        modulepreloadCount: 1,
      }),
    ]),
  );

  await expect(
    page.locator('link[rel="modulepreload"][href*="simple-props"]'),
  ).toHaveCount(1);
});
