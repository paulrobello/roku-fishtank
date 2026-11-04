import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

test("frozen test-channel frame matches the baseline", async ({ page }) => {
  const renderer = await page.evaluate(() => {
    const gl = document.createElement("canvas").getContext("webgl");
    const ext = gl?.getExtension("WEBGL_debug_renderer_info");
    return ext ? String(gl?.getParameter(ext.UNMASKED_RENDERER_WEBGL)) : "unknown";
  });
  test.info().annotations.push({ type: "renderer", description: renderer });
  console.log(`renderer: ${renderer}`);

  await page.goto("/?freeze=3");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");

  // toHaveScreenshot waits for two identical consecutive captures before comparing.
  await expect(page.locator("#display")).toHaveScreenshot("frozen-t3.png");
});
