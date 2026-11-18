import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; params: Record<string, string>; log: string[] } };
const locales = ["en_US", "en_GB", "en_CA", "en_AU", "fr_CA", "es_ES", "es_MX", "de_DE", "it_IT", "pt_BR"];

function translated(locale: string, source: string): string {
  // Roku validator rejects an en_CA catalog; native tr() returns English source.
  if (locale === "en_CA") return source;
  const xml = readFileSync(`locale/${locale}/translations.xml`, "utf8");
  const decode = (text: string): string => text.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '\"').replace(/&apos;/g, "'").replace(/&amp;/g, "&");
  for (const unit of xml.matchAll(/<trans-unit\b[^>]*>([\s\S]*?)<\/trans-unit>/g)) {
    const original = unit[1].match(/<source>([\s\S]*?)<\/source>/)?.[1];
    const target = unit[1].match(/<target>([\s\S]*?)<\/target>/)?.[1];
    if (original && target && decode(original) === source) return decode(target);
  }
  throw new Error(`Missing ${locale} translation: ${source}`);
}

// Native engine locale selection exercises the same package catalogs and tr() calls
// as the Roku. New baselines need visual review for clipping and accented characters.
for (const locale of locales) {
  test(`localized settings and dialogs ${locale}`, async ({ page }) => {
    await page.goto(`/?scene=ReefTankSettings&seed=7&freeze=1&locale=${locale}`);
    await page.waitForFunction(
      () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null, { timeout: 30_000 },
    );
    const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
    expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
    expect(preview?.params.locale).toBe(locale);
    const subtitle = translated(locale, "Screensaver settings");
    expect(preview?.log.some((line) => line.includes(`PREVIEW_LOCALE ${locale}`))).toBe(true);
    expect(preview?.log.some((line) => line.includes(`PREVIEW_SUBTITLE ${subtitle}`))).toBe(true);
    if (!locale.startsWith("en_")) expect(subtitle).not.toBe("Screensaver settings");
    const display = page.locator("#display");
    const press = async (key: string): Promise<void> => {
      const before = await display.screenshot();
      await page.keyboard.press(key);
      await expect.poll(async () => (await display.screenshot()).equals(before)).toBe(false);
    };
    await expect(display).toHaveScreenshot(`locale-${locale}-settings.png`);
    if (locale === "de_DE" || locale === "fr_CA") {
      await page.setViewportSize({ width: 1280, height: 720 });
      await expect(display).toHaveScreenshot(`locale-${locale}-settings-scaled720.png`);
      await page.setViewportSize({ width: 1920, height: 1080 });
    }
    // English regional copies share base UI; exercise full translated paths elsewhere.
    if (!locale.startsWith("en_")) {
      for (let i = 0; i < 3; i++) await press("ArrowDown");
      await press("Enter");
      await expect(display).toHaveScreenshot(`locale-${locale}-location.png`);
      await press("ArrowDown");
      await press("Enter");
      await expect(display).toHaveScreenshot(`locale-${locale}-countries.png`);
      await press("Enter"); // Cancel; focus returns to Solar location (row 3).
      for (let i = 0; i < 3; i++) await press("ArrowDown"); // Changelog is now row 6.
      await press("Enter");
      await expect(display).toHaveScreenshot(`locale-${locale}-changelog.png`);
    }
    const log = await page.evaluate(() => (window as PreviewWindow).__preview?.log ?? []);
    expect(log.filter((line) => line.includes("error,") || line.includes("Runtime Error"))).toEqual([]);
  });
}

for (const locale of ["de_DE", "fr_CA", "es_ES"]) {
  test(`localized invalid location preserves settings ${locale}`, async ({ page }) => {
    await page.goto(`/?scene=ReefTankSettings&seed=7&freeze=1&locale=${locale}`);
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
    const original = await display.screenshot();
    await press("Enter");
    await press("Enter");
    await page.keyboard.type("00000", { delay: 50 });
    for (let i = 0; i < 4; i++) await press("ArrowDown");
    await press("Enter");
    await expect.poll(async () => (await page.evaluate(() => (window as PreviewWindow).__preview?.log ?? []))
      .some((line) => line.includes(`PREVIEW_DIALOG ${translated(locale, "ZIP not found")}`))).toBe(true);
    await expect(display).toHaveScreenshot(`locale-${locale}-zip-error.png`);
    await press("Escape");
    await expect.poll(async () => (await display.screenshot()).equals(original)).toBe(true);
    // Reopening proves focus returns to the native settings row after rejection.
    await press("Enter");
    await press("ArrowDown");
    await press("ArrowDown");
    await press("Enter");
    // Append a second separator to the prefilled coordinates: unambiguously invalid
    // regardless of the previously stored numeric coordinate values.
    await page.keyboard.type(",", { delay: 50 });
    for (let i = 0; i < 4; i++) await press("ArrowDown");
    await press("Enter");
    await expect.poll(async () => (await page.evaluate(() => (window as PreviewWindow).__preview?.log ?? []))
      .some((line) => line.includes(`PREVIEW_DIALOG ${translated(locale, "Invalid coordinates")}`))).toBe(true);
    await expect(display).toHaveScreenshot(`locale-${locale}-coordinates-error.png`);
    await press("Escape");
    await expect.poll(async () => (await display.screenshot()).equals(original)).toBe(true);
    await press("Enter");
    await expect(display).toHaveScreenshot(`locale-${locale}-location.png`);
    await press("Escape");
    await expect.poll(async () => (await display.screenshot()).equals(original)).toBe(true);
    const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
    expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
    expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
  });
}

for (const [name, time] of [["noon", "12:00"], ["late-night", "23:05"], ["after-midnight", "00:05"]]) {
  test(`Spanish clock period fits ${name}`, async ({ page }) => {
    await page.goto(`/?seed=7&freeze=3&clock=1&time=2026-11-04T${time}&locale=es_ES`);
    await page.waitForFunction(
      () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null, { timeout: 90_000 },
    );
    const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
    expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
    expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
    await expect(page.locator("#display")).toHaveScreenshot(`locale-es_ES-clock-${name}.png`);
  });
}
