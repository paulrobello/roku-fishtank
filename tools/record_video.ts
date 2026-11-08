// Record the running preview to a WebM video (run with bun against a `make dev`).
//
//   bun tools/record_video.ts <query> <outDir> [holdSeconds]
//
// Loads /?<query> in a 1920x1080 Chromium window with Playwright's video
// recorder, waits for window.__preview.status === "running", holds holdSeconds
// (default 17) more, then flushes the recording into <outDir>. Prints the
// wall-clock second at which the tank appeared and the #display bounding box
// (for ffmpeg crop/scale math). GPU flags match tools/preview_capture.ts.
import { chromium } from "playwright";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

const base: string = process.env.PREVIEW_URL ?? "http://localhost:8138";
const gpuArgs: string[] = ["--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist"];

async function main(): Promise<void> {
  const [query, outDir, hold = "17"] = process.argv.slice(2);
  if (!query || !outDir) throw new Error("usage: record_video.ts <query> <outDir> [holdSeconds]");
  const browser = await chromium.launch({ channel: "chromium", headless: true, args: gpuArgs });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    recordVideo: { dir: outDir, size: { width: 1920, height: 1080 } },
  });
  const page = await context.newPage();
  const t0 = Date.now();
  await page.goto(`${base}/?${query}`);
  await page.waitForFunction(() => (window as PreviewWindow).__preview?.status === "running", null, {
    timeout: 60_000,
  });
  const runningAt = (Date.now() - t0) / 1000;
  const box = await page.locator("#display").boundingBox();
  await page.waitForTimeout(Number(hold) * 1000);
  const videoPath = await page.video()?.path();
  await context.close();
  await browser.close();
  console.log(
    JSON.stringify({ runningAt, box, videoPath, query, hold: Number(hold) }, null, 2),
  );
}

main().catch((err: Error) => {
  console.error(err);
  process.exit(1);
});
