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

// Location is opt-in, local-only, and modal dismissal must return to the list.
test("solar city picker persists and dialogs cancel without changing it", async ({ page }) => {
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
  for (let i = 0; i < 3; i++) await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-location-picker.png");
  await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-location-countries.png");
  await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-location-cities.png");
  await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-location-selected.png");
  const selected = await display.screenshot();

  await press("Enter");
  await press("Escape");
  await expect.poll(async () => (await display.screenshot()).equals(selected)).toBe(true);
  await press("Enter");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-location-zip.png");
  await press("Escape");
  await expect.poll(async () => (await display.screenshot()).equals(selected)).toBe(true);
  await press("Enter");
  await press("ArrowDown");
  await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-location-custom.png");
  await press("Escape");
  await expect.poll(async () => (await display.screenshot()).equals(selected)).toBe(true);

  await page.reload();
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  for (let i = 0; i < 3; i++) await press("ArrowDown");
  await expect.poll(async () => (await display.screenshot()).equals(selected)).toBe(true);
  const log = await page.evaluate(() => (window as PreviewWindow).__preview?.log ?? []);
  expect(log.filter((line) => line.includes("error,") || line.includes("Runtime Error"))).toEqual([]);
});

// Exercises binary data loading through the packaged preview, not just pure decoding.
test("ZIP binary lookup saves leading zeros and rejects missing ZIPs", async ({ page }) => {
  await page.goto("/?scene=ReefTankSettings&seed=7&freeze=1");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null, { timeout: 30_000 },
  );
  const display = page.locator("#display");
  const press = async (key: string): Promise<void> => {
    const before = await display.screenshot();
    await page.keyboard.press(key);
    await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(false);
  };
  for (let i = 0; i < 3; i++) await press("ArrowDown");
  await press("Enter");
  await press("Enter");
  await page.keyboard.type("00601", { delay: 100 });
  for (let i = 0; i < 4; i++) await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-zip-leading-zero.png");
  const saved = await display.screenshot();
  await press("Enter");
  await press("Enter");
  await page.keyboard.type("00000", { delay: 100 });
  for (let i = 0; i < 4; i++) await press("ArrowDown");
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-zip-not-found.png");
  await press("Escape");
  await expect.poll(async () => (await display.screenshot()).equals(saved)).toBe(true);
  await page.reload();
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null, { timeout: 30_000 },
  );
  for (let i = 0; i < 3; i++) await press("ArrowDown");
  await expect.poll(async () => (await display.screenshot()).equals(saved)).toBe(true);
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
});

// Clock format is independent of enabled/off, and only display labels are localized.
// Persisting the underlying device/12h/24h keys must survive settings re-entry.
test("clock format cycles device to 12-hour to 24-hour and persists", async ({ page }) => {
  test.setTimeout(120_000);
  const display = page.locator("#display");
  const press = async (key: string): Promise<void> => {
    const before = await display.screenshot();
    await page.keyboard.press(key);
    await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(false);
  };
  const openFormat = async (expected: string): Promise<void> => {
    await page.goto("/?scene=ReefTankSettings&seed=7&freeze=1&locale=en_US");
    await page.waitForFunction(
      () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null, { timeout: 30_000 },
    );
    const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
    expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
    expect(preview?.log.some((line) => line.includes(`PREVIEW_OPTION Clock format: ${expected}`))).toBe(true);
    expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
    for (let i = 0; i < 5; i++) await press("ArrowDown");
  };
  await openFormat("Device setting");
  await expect(display).toHaveScreenshot("settings-clock-format-device.png");
  const device = await display.screenshot();
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-clock-format-12h.png");
  const twelve = await display.screenshot();
  await openFormat("12-hour");
  await expect.poll(async () => (await display.screenshot()).equals(twelve)).toBe(true);
  await press("Enter");
  await expect(display).toHaveScreenshot("settings-clock-format-24h.png");
  const twentyFour = await display.screenshot();
  await openFormat("24-hour");
  await expect.poll(async () => (await display.screenshot()).equals(twentyFour)).toBe(true);
  await press("Enter");
  await expect.poll(async () => (await display.screenshot()).equals(device)).toBe(true);
  await openFormat("Device setting");
  await expect.poll(async () => (await display.screenshot()).equals(device)).toBe(true);
});
