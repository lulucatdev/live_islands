import { expect, test } from "@playwright/test";

test("complex todo app exercises React, Vue, SSR, deferred, and lazy islands", async ({
  page,
}) => {
  await page.goto("/todo", { waitUntil: "networkidle" });

  await expect(page.getByTestId("todo-demo-page")).toBeVisible();
  await expect(page.getByTestId("todo-ssr-digest")).toBeVisible();
  await expect(page.getByTestId("todo-workspace")).toBeVisible();
  await expect(page.getByTestId("todo-rhythm").first()).toBeVisible();
  await expect(page.getByTestId("todo-focus-timer")).toBeVisible();
  await expect(page.getByTestId("todo-command-center")).toBeVisible();
  await expect(page.getByTestId("todo-deferred-digest")).toBeVisible();
  await expect(page.getByTestId("todo-liveview-panel")).toBeVisible();
  await expect(page.getByTestId("todo-live-activity")).toContainText(
    "SSR digest rendered in shell",
  );

  await expect(page.locator("#todo_static_digest")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );
  await expect(page.locator("#todo_static_rhythm")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );

  await page.getByTestId("todo-native-title").fill("No");
  await expect(page.getByTestId("todo-native-title-error")).toContainText(
    "Use at least 4 characters",
  );
  await page.getByTestId("todo-native-title").fill("Review LiveView mimic");
  await page.getByTestId("todo-native-submit").click();
  await expect(
    page.getByRole("heading", { name: "Review LiveView mimic" }),
  ).toBeVisible();
  await expect(page.getByTestId("todo-live-activity")).toContainText(
    "LiveView form created Review LiveView mimic",
  );

  await page.getByTestId("todo-live-filter-review").click();
  await expect(page).toHaveURL(/filter=review/);
  await expect(page.getByTestId("todo-url-state")).toContainText("Review");

  await page.getByTestId("todo-js-inspector-toggle").click();
  await expect(page.getByTestId("todo-liveview-inspector")).toBeVisible();

  await page.getByTestId("todo-live-filter-all").click();
  await expect(page.getByTestId("todo-url-state")).toContainText("All");

  await page.getByTestId("todo-title-input").fill("Write v0.11 demo notes");
  await page.getByTestId("todo-add-button").click();
  await expect(
    page.getByRole("heading", { name: "Write v0.11 demo notes" }),
  ).toBeVisible();

  await page.getByTestId("todo-plan-button").click();
  await expect(page.getByTestId("todo-plan-headline")).toContainText("Focus");

  await page
    .locator("#todo_rhythm_panel")
    .getByTestId("todo-mode-deep-work")
    .click();
  await expect(page.getByText("Deep Work mode")).toBeVisible();

  await page.getByTestId("todo-command-toggle").click();
  await page.getByTestId("todo-command-plan-today").click();
  await expect(page.getByText("Plan mode")).toBeVisible();

  await page.getByRole("button", { name: "Start" }).click();
  await expect(page.getByRole("button", { name: "Pause" })).toBeVisible();

  const manifest = await page.evaluate(
    () => window.__liveIslandsPrefetch?.manifest?.() || [],
  );
  expect(manifest).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        framework: "react",
        name: "TodoWorkspace",
      }),
      expect.objectContaining({
        framework: "vue",
        name: "todo-rhythm",
      }),
      expect.objectContaining({
        framework: "react",
        name: "TodoCommandCenter",
      }),
    ]),
  );
});
