import { expect, test } from "@playwright/test";

test("LiveIslands React and Vue hooks work through LiveView", async ({
  page,
}) => {
  const responses = [];
  page.on("response", (response) => responses.push(response.url()));

  await page.goto("/capabilities");

  await expect
    .poll(() =>
      responses.some(
        (url) =>
          url.includes("/react-components/simple.jsx") ||
          url.includes("/simple.js"),
      ),
    )
    .toBe(true);
  await expect(page.locator("#server-only-react")).toContainText(
    "Hello world!",
  );
  await expect(page.locator("#server-only-react")).not.toHaveAttribute(
    "phx-hook",
    /.+/,
  );

  const streamItems = page.getByTestId("stream-list").locator("li");
  await expect(streamItems).toHaveCount(1);
  await page.getByTestId("stream-add").click();
  await expect(streamItems).toHaveCount(2);

  await expect(page.getByTestId("reply-result")).toHaveText("No reply yet");
  await page.getByTestId("reply-button").click();
  await expect(page.getByTestId("reply-result")).toHaveText("Reply for react");

  await page.getByTestId("email-input").fill("invalid");
  await expect(page.getByTestId("email-error")).toHaveText("must include @");
  await page.getByTestId("email-input").fill("valid@example.com");
  await expect(page.getByTestId("email-error")).toHaveText("");
  await expect(page.getByTestId("form-state")).toContainText("valid");

  await page.getByTestId("upload-input").setInputFiles({
    name: "hello.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("hello"),
  });
  await expect(page.getByTestId("selected-file")).toHaveText("hello.txt");
  await page.getByTestId("upload-submit").click();
  await expect(page.getByTestId("uploaded-files")).toContainText("hello.txt");

  await expect(page.getByTestId("vue-message")).toHaveText("Vue island ready");
  await page.getByTestId("vue-ping").click();
  await expect(page.getByTestId("vue-message")).toHaveText(
    "Vue replied from vue",
  );
});
