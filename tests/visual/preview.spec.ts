import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

// ?freeze=3 snaps the camera drift loop to T=3 s (a few px off centre at speed 1), so the frame
// is the layered tank (backdrop + decor from config/scene.json) at that drift offset.
test("frozen Reef Tank frame matches the baseline", async ({ page }) => {
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
  await expect(page.locator("#display")).toHaveScreenshot("reeftank-t3.png");
});

// FishBrain under ?freeze runs its logic to T at once and poses the fish without movers,
// so the frame depends only on seed and T (3 loads compared pixel-identical, 2026-11-04).
test("frozen brain demo at seed 7 matches the baseline", async ({ page }) => {
  await page.goto("/?scene=BrainDemoScene&seed=7&freeze=5");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  await expect(page.locator("#display")).toHaveScreenshot("brain-seed7-t5.png");
});
