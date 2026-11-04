import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

// Frozen night-phase baselines (P3.3): the Woodland CA sunset crossfade at sunset,
// +20 min, +45 min, and full night at 23:00. ?time= pins the clock, ?freeze=3 the motion.
// Sunset 2026-11-04 is about 17:10 PST; the exact minute only shifts the blend slightly.
const PHASES: readonly [string, string][] = [
  ["night-sunset", "17:10"],
  ["night-sunset20", "17:30"],
  ["night-sunset45", "17:55"],
  ["night-2300", "23:00"],
];

for (const [name, time] of PHASES) {
  test(`night phase ${name} matches the baseline`, async ({ page }) => {
    await page.goto(`/?time=${time}&freeze=3`);
    await page.waitForFunction(
      () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null,
      { timeout: 90_000 },
    );
    const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
    expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
    await expect(page.locator("#display")).toHaveScreenshot(`${name}.png`);
  });
}
