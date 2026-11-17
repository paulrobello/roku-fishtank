import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

async function frozen(page: import("@playwright/test").Page, query: string): Promise<void> {
  await page.goto(`/?seed=7&freeze=3&${query}`);
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null, { timeout: 90_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
}

for (const [name, time] of [["day", "2026-11-04T13:05"], ["night", "2026-11-04T23:05"]]) {
  test(`subtle background clock ${name}`, async ({ page }) => {
    await frozen(page, `clock=1&time=${time}`);
    await expect(page.locator("#display")).toHaveScreenshot(`clock-${name}.png`);
    const enabledFrame = await page.locator("#display").screenshot();
    await frozen(page, `clock=0&time=${time}`);
    expect((await page.locator("#display").screenshot()).equals(enabledFrame)).toBe(false);
  });
}

test("clock defaults off and leaves the tank unchanged", async ({ page }) => {
  await frozen(page, "time=2026-11-04T13:05");
  const defaultFrame = await page.locator("#display").screenshot();
  await frozen(page, "clock=0&time=2026-11-04T13:05");
  await expect.poll(async () => (await page.locator("#display").screenshot()).equals(defaultFrame)).toBe(true);
});

test("clock is behind fish and keeps independent drift with camera off", () => {
  const source = readFileSync("components/ReefTank/ReefTank.brs", "utf8");
  expect(source).toContain('findNode("waterGradient")');
  expect(source).toContain('water.createChild("BackgroundClock")');
  const config = JSON.parse(readFileSync("config/scene.json", "utf8"));
  const layers = config.layers.map((layer: { id: string }) => layer.id);
  expect(layers.indexOf("waterGradient")).toBeLessThan(layers.indexOf("backLane"));
  const clock = readFileSync("components/BackgroundClock/BackgroundClock.brs", "utf8");
  expect(clock).not.toContain("m.top.drift");
  expect(clock).toContain('m.tick.control = "stop"');
  expect(clock).toContain('m.drift.control = "stop"');
});

// The preview stays at 1080p internally; this checks its 720px presentation fit,
// not native Roku 720p output or TV viewing-distance readability.
test("clock fits a 720p-sized viewport", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  await frozen(page, "clock=1&time=2026-11-04T23:05");
  await expect(page.locator("#display")).toHaveScreenshot("clock-night-720-viewport.png");
});
