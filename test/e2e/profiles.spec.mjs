import { expect, test } from "@playwright/test";

async function islandManifest(page) {
  return page.evaluate(() => {
    const runtimeManifest = window.__liveIslandsPrefetch?.manifest?.();
    if (runtimeManifest?.length > 0) return runtimeManifest;

    return [...document.querySelectorAll("[data-framework][data-name]")].map(
      (el) => ({
        framework: el.getAttribute("data-framework"),
        name: el.getAttribute("data-name"),
        client: el.getAttribute("data-client") || "load",
        prefetch: el.getAttribute("data-prefetch") || "none",
      }),
    );
  });
}

async function shell(page) {
  return page.evaluate(() => ({
    liveSocketPresent: "liveSocket" in window,
    moduleScripts: [...document.querySelectorAll("script[type='module']")].map(
      (script) => script.getAttribute("src") || "inline",
    ),
  }));
}

test("profile matrix scopes islands per page", async ({ page }) => {
  await page.goto("/profile/react-only", { waitUntil: "networkidle" });
  await expect(page.getByTestId("profile-react-only-page")).toBeVisible();
  await expect(page.getByText("Hello world!")).toBeVisible();

  let manifest = await islandManifest(page);
  expect(manifest).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        framework: "react",
        name: "Simple",
        client: "load",
        prefetch: "none",
      }),
    ]),
  );
  expect(manifest.some((island) => island.framework === "vue")).toBe(false);
  expect(await shell(page)).toEqual(
    expect.objectContaining({ liveSocketPresent: true }),
  );

  await page.goto("/profile/vue-only", { waitUntil: "networkidle" });
  await expect(page.getByTestId("profile-vue-only-page")).toBeVisible();
  await expect(page.getByTestId("benchmark-vue-probe")).toBeVisible();

  manifest = await islandManifest(page);
  expect(manifest).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        framework: "vue",
        name: "benchmark-probe",
        client: "load",
        prefetch: "none",
      }),
    ]),
  );
  expect(manifest.some((island) => island.framework === "react")).toBe(false);

  await page.goto("/profile/mixed", { waitUntil: "networkidle" });
  await expect(page.getByTestId("profile-mixed-page")).toBeVisible();
  await expect(page.getByText("Hello world!")).toBeVisible();
  await expect(page.getByTestId("benchmark-vue-probe")).toBeVisible();

  manifest = await islandManifest(page);
  expect(manifest).toEqual(
    expect.arrayContaining([
      expect.objectContaining({ framework: "react", name: "Simple" }),
      expect.objectContaining({ framework: "vue", name: "benchmark-probe" }),
    ]),
  );
});
