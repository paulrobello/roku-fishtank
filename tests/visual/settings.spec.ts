import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

// Settings-driven tank states (P5.3): what the stored "Always night" and "Calm"
// settings produce, as the URL-param equivalents of the registry values.
test("Always night tank matches the baseline", async ({ page }) => {
  await page.goto("/?night=1&seed=7&freeze=3");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 90_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  await expect(page.locator("#display")).toHaveScreenshot("settings-night.png");
});

test("Calm density tank matches the baseline", async ({ page }) => {
  await page.goto("/?density=calm&seed=7&freeze=3");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 90_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  await expect(page.locator("#display")).toHaveScreenshot("settings-calm.png");
});

// The native LabelList must remain interactive without a shipped onKeyEvent handler.
test("native settings list cycles values with OK", async ({ page }) => {
  await page.goto("/?scene=ReefTankSettings&seed=7&freeze=1");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  await expect(page.locator("#display")).toHaveScreenshot("settings-native-initial.png");
  const before = await page.locator("#display").screenshot();
  await page.keyboard.press("Enter");
  await expect.poll(async () => (await page.locator("#display").screenshot()).equals(before)).toBe(false);
  await expect(page.locator("#display")).toHaveScreenshot("settings-native-changed.png");
  const day = await page.locator("#display").screenshot();
  await page.keyboard.press("Enter");
  await expect.poll(async () => (await page.locator("#display").screenshot()).equals(day)).toBe(false);
  await page.keyboard.press("Enter");
  await expect.poll(async () => (await page.locator("#display").screenshot()).equals(before)).toBe(true);
});
