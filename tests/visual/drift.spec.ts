import { mkdirSync, writeFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

// scene.json drift.periodSeconds (90) at ?speed=30 is a 3 s loop, and ?freeze=T snaps the
// drift animation to T seconds into it. Phase 0 is the wrap at T=3 (freeze=0 means unfrozen),
// phases 1..3 are the +x extreme, the centre and the -x extreme of the sine path.
const LOOP_SECONDS = 3;
const PHASES: readonly number[] = [0, 1, 2, 3].map((k) => (k === 0 ? LOOP_SECONDS : (k * LOOP_SECONDS) / 4));

// scene.json backgroundColor 0x0B2F55: visible only where no layer's art covers the view.
const BACKGROUND: readonly number[] = [0x0b, 0x2f, 0x55];

interface EdgeStats {
  leftBackground: number;
  rightBackground: number;
  height: number;
}

async function frozenFrame(page: import("@playwright/test").Page, freeze: number): Promise<Buffer> {
  await page.goto(`/?speed=30&freeze=${freeze}`);
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  // Let two consecutive captures agree so the frozen frame has been presented.
  await page.waitForTimeout(300);
  return page.locator("#display").screenshot();
}

// Counts the left-most and right-most pixel columns whose rows match the scene background.
async function edgeStats(page: import("@playwright/test").Page, png: Buffer): Promise<EdgeStats> {
  return page.evaluate(
    async ({ b64, bg }) => {
      const img = new Image();
      img.src = `data:image/png;base64,${b64}`;
      await img.decode();
      const c = document.createElement("canvas");
      c.width = img.width;
      c.height = img.height;
      const ctx = c.getContext("2d") as CanvasRenderingContext2D;
      ctx.drawImage(img, 0, 0);
      const near = (d: Uint8ClampedArray, i: number): boolean =>
        Math.abs(d[i] - bg[0]) <= 3 && Math.abs(d[i + 1] - bg[1]) <= 3 && Math.abs(d[i + 2] - bg[2]) <= 3;
      const count = (x: number): number => {
        const d = ctx.getImageData(x, 0, 1, img.height).data;
        let n = 0;
        for (let y = 0; y < img.height; y++) if (near(d, y * 4)) n++;
        return n;
      };
      return { leftBackground: count(0), rightBackground: count(img.width - 1), height: img.height };
    },
    { b64: png.toString("base64"), bg: [...BACKGROUND] },
  );
}

test("camera drift never reveals the backdrop edge at four loop phases", async ({ page }) => {
  const frames: Buffer[] = [];
  for (const [k, freeze] of PHASES.entries()) {
    const png = await frozenFrame(page, freeze);
    frames.push(png);
    if (process.env.DRIFT_SAVE) {
      mkdirSync("docs/preview", { recursive: true });
      writeFileSync(`docs/preview/drift-phase-${k}.png`, png);
    }
    const stats = await edgeStats(page, png);
    expect(stats.leftBackground, `phase ${k} (freeze=${freeze}) left edge shows background`).toBe(0);
    expect(stats.rightBackground, `phase ${k} (freeze=${freeze}) right edge shows background`).toBe(0);
  }
  // The drift really moves, and the loop closes: the wrap (phase 0) and the centre (phase 2)
  // are both zero offset.
  expect(frames[1].equals(frames[3]), "+x and -x extremes should differ").toBe(false);
  expect(frames[2].equals(frames[1]), "centre and +x extreme should differ").toBe(false);
  expect(frames[0].equals(frames[2]), "phase 0 (wrap) and the centre should both be zero offset").toBe(true);
});
