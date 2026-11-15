import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

// ?freeze=3 snaps the camera drift loop to T=3 s (a few px off centre at speed 1), so the frame
// is the layered tank (backdrop + decor from config/scene.json) at that drift offset, the bubble
// column posed from its schedule at T=3 (fixed seed 1 under freeze), the seaweed sway snapped
// to T=3, the reef extras (config/extras.json: sway chains, anemone, critter walk loops
// from seed 7, ripple and caustics) snapped to T=3 with the front-lane clownfish nestled in the
// anemone, and the default (normal) density: the lane FishBrains and the chromis School posed
// from seed and T, so the seed is pinned.
test("frozen Reef Tank frame matches the baseline", async ({ page }) => {
  const renderer = await page.evaluate(() => {
    const gl = document.createElement("canvas").getContext("webgl");
    const ext = gl?.getExtension("WEBGL_debug_renderer_info");
    return ext ? String(gl?.getParameter(ext.UNMASKED_RENDERER_WEBGL)) : "unknown";
  });
  test.info().annotations.push({ type: "renderer", description: renderer });
  console.log(`renderer: ${renderer}`);

  await page.goto("/?seed=7&freeze=3");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");

  // toHaveScreenshot waits for two identical consecutive captures before comparing.
  await expect(page.locator("#display")).toHaveScreenshot("reeftank-t3.png");
});

// FishBrain under ?freeze runs its logic to T at once and poses the fish without movers,
// so the frame depends only on seed and T (3 loads compared pixel-identical, 2026-11-04).
test("frozen brain demo at seed 7 matches the baseline", async ({ page }) => {
  await page.goto("/?scene=BrainDemoScene&seed=7&freeze=5");
  await page.waitForFunction(
    () => ["frozen", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).toBe("frozen");
  await expect(page.locator("#display")).toHaveScreenshot("brain-seed7-t5.png");
});

// Keep the critters behind the existing foreground, with their feet visibly embedded
// in the sand rather than hovering above it. No layer/order changes are needed.
test("crab and shrimp overlap the sand without changing depth", () => {
  const extras = JSON.parse(readFileSync("config/extras.json", "utf8"));
  for (const name of ["crab", "shrimp"]) {
    const critter = extras.critters[name];
    expect(critter.layer).toBe("frontLane");
    expect(critter.layerIndex).toBe(0);
    expect(critter.walk.y + critter.height).toBe(extras.caustics.clip.y + 10);
  }
});

test("tail has an independent clock while fins keep the original animation", () => {
  const xml = readFileSync("components/Fish/Fish.xml", "utf8");
  const tail = xml.match(/<Animation id="tailAnim"[\s\S]*?<\/Animation>/)?.[0] ?? "";
  const fin = xml.match(/<Animation id="swimAnim"[\s\S]*?<\/Animation>/)?.[0] ?? "";
  for (const id of ["tailInterp", "tailSway", "mTailSway", "mTailInterp"]) {
    expect(tail).toContain(`id="${id}"`);
    expect(fin).not.toContain(`id="${id}"`);
  }
  for (const id of ["finInterp", "mFinInterp"]) {
    expect(fin).toContain(`id="${id}"`);
    expect(tail).not.toContain(`id="${id}"`);
  }
});
