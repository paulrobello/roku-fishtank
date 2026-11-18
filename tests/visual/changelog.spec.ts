import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

test("changelog cycles build history and closes without changing settings", async ({ page }) => {
  await page.goto("/?scene=ReefTankSettings&seed=7&freeze=1");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const display = page.locator("#display");
  const press = async (key: string): Promise<void> => {
    const before = await display.screenshot();
    await page.keyboard.press(key);
    await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(false);
  };
  for (let i = 0; i < 6; i++) await press("ArrowDown");
  const settings = await display.screenshot();
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-changelog-unreleased.png");
  const newest = await display.screenshot();
  for (const name of ["022", "021", "011"]) {
    await press("Enter");
    await expect(display).toHaveScreenshot(`settings-changelog-${name}.png`);
  }
  await press("Enter");
  await expect.poll(async () => (await display.screenshot()).equals(newest)).toBe(true);
  await press("Escape");
  await expect.poll(async () => (await display.screenshot()).equals(settings)).toBe(true);
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
});

test("background clock toggles off to on and persists across settings reload", async ({ page }) => {
  const openSettings = async (): Promise<void> => {
    await page.goto("/?scene=ReefTankSettings&seed=7&freeze=1");
    await page.waitForFunction(
      () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null,
      { timeout: 30_000 },
    );
  };
  await openSettings();
  const display = page.locator("#display");
  const press = async (key: string): Promise<void> => {
    const before = await display.screenshot();
    await page.keyboard.press(key);
    await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(false);
  };
  for (let i = 0; i < 4; i++) await press("ArrowDown");
  await expect(display).toHaveScreenshot("settings-clock-off.png");
  const off = await display.screenshot();
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-clock-on.png");
  const on = await display.screenshot();
  await openSettings();
  for (let i = 0; i < 4; i++) await press("ArrowDown");
  await expect.poll(async () => (await display.screenshot()).equals(on)).toBe(true);
  await press("Enter");
  await expect.poll(async () => (await display.screenshot()).equals(off)).toBe(true);
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
});
