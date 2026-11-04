// Preview evidence capture (run with bun against a running `make dev`).
//
//   bun tools/preview_capture.ts log <query> <seconds> <outFile> [grep]
//     Loads /?<query>, waits, and writes the preview log lines containing grep
//     (default "BRAIN") to outFile.
//   bun tools/preview_capture.ts frames <query> <startSec> <count> <intervalMs> <outPrefix>
//     Loads /?<query>, waits startSec, then saves count canvas screenshots
//     intervalMs apart as <outPrefix>-NN.png, and prints the log lines seen meanwhile.
//   bun tools/preview_capture.ts frozen <query> <outFile>
//     Loads /?<query> (with freeze=T), waits for the frozen status and saves one screenshot.
//
// PREVIEW_URL overrides the base URL (default http://localhost:8138).
import { writeFileSync } from "node:fs";
import { chromium, type Page } from "playwright";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

const base: string = process.env.PREVIEW_URL ?? "http://localhost:8138";
const gpuArgs: string[] = ["--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist"];

async function open(query: string): Promise<{ page: Page; close: () => Promise<void> }> {
  const browser = await chromium.launch({ channel: "chromium", headless: true, args: gpuArgs });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.goto(`${base}/?${query}`);
  await page.waitForFunction(() => (window as PreviewWindow).__preview?.status !== "loading", null, {
    timeout: 30_000,
  });
  return { page, close: () => browser.close() };
}

async function log(page: Page): Promise<string[]> {
  return page.evaluate(() => (window as PreviewWindow).__preview?.log ?? []);
}

async function main(): Promise<void> {
  const [mode, query, ...rest] = process.argv.slice(2);
  if (mode === "log") {
    const [seconds, outFile, grep = "BRAIN"] = rest;
    const { page, close } = await open(query);
    const started = Date.now();
    await page.waitForTimeout(Number(seconds) * 1000);
    const lines = (await log(page)).filter((l) => l.includes(grep) || l.includes("PREVIEW_PARAMS"));
    lines.push(`# wall seconds: ${((Date.now() - started) / 1000).toFixed(1)}, url: ${base}/?${query}`);
    writeFileSync(outFile, `${lines.join("\n")}\n`);
    console.log(`${lines.length} lines -> ${outFile}`);
    await close();
  } else if (mode === "frames") {
    const [startSec, count, intervalMs, outPrefix] = rest;
    const { page, close } = await open(query);
    await page.waitForTimeout(Number(startSec) * 1000);
    const before = (await log(page)).length;
    const display = page.locator("#display");
    for (let i = 0; i < Number(count); i++) {
      const t0 = Date.now();
      await display.screenshot({ path: `${outPrefix}-${String(i).padStart(2, "0")}.png` });
      const wait = Number(intervalMs) - (Date.now() - t0);
      if (wait > 0) await page.waitForTimeout(wait);
    }
    const seen = (await log(page)).slice(before).filter((l) => l.includes("BRAIN"));
    console.log(seen.join("\n"));
    await close();
  } else if (mode === "frozen") {
    const [outFile] = rest;
    const { page, close } = await open(query);
    await page.waitForFunction(
      () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null,
      { timeout: 60_000 },
    );
    // Let the post-freeze re-pause loop settle before capturing.
    await page.waitForTimeout(1000);
    await page.locator("#display").screenshot({ path: outFile });
    console.log(`${outFile} ${await page.evaluate(() => (window as PreviewWindow).__preview?.status)}`);
    await close();
  } else {
    throw new Error(`unknown mode ${mode}`);
  }
}

main().catch((err: Error) => {
  console.error(err);
  process.exit(1);
});
