import { expect, test } from "@playwright/test";
type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };
for (const locale of ["en_US", "fr_CA", "de_DE"]) {
  for (const fixture of ["ready", "missing", "malformed"]) {
    test(`local launch report ${fixture} ${locale}`, async ({ page }, testInfo) => {
      await page.goto(`/?scene=ReefTankSettings&seed=7&freeze=1&locale=${locale}&launchReportFixture=${fixture}`);
      await page.waitForFunction(() => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""));
      const display = page.locator("#display");
      const press = async (key: string) => {
        const before = await display.screenshot();
        await page.keyboard.press(key);
        await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(false);
      };
      for (let i = 0; i < 7; i++) await press("ArrowDown");
      const before = await display.screenshot();
      await press("Enter");
      // Capture for review; native/Metal baselines have not been approved yet.
      await testInfo.attach(`launch-report-${fixture}-${locale}`, { body: await display.screenshot(), contentType: "image/png" });
      await press("Escape");
      await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(true);
      const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
      expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
      expect(preview?.log.filter(line => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
    });
  }
}
