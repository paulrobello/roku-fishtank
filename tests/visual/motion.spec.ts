import { writeFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

// A frozen screenshot cannot detect interrupted tail cycles or segment handoffs.
// Keep moving footage for human review alongside runtime/error regression checks.
test.use({ video: { mode: "on", size: { width: 1920, height: 1080 } } });

for (const scene of ["BrainDemoScene", "SchoolDemoScene", "ReefTank"]) {
  test(`live ${scene} continues moving without runtime errors`, async ({ page }) => {
    const renderer = await page.evaluate(() => {
      const gl = document.createElement("canvas").getContext("webgl");
      const ext = gl?.getExtension("WEBGL_debug_renderer_info");
      return ext ? String(gl?.getParameter(ext.UNMASKED_RENDERER_WEBGL)) : "unknown";
    });
    console.log(`motion renderer: ${renderer}`);
    if (process.env.PW_GPU !== "swiftshader") expect(renderer).toContain("Metal");
    await page.goto(`/?scene=${scene}&seed=7&time=2026-11-04T12:00`);
    await page.waitForFunction(
      () => ["running", "error"].includes((window as PreviewWindow).__preview?.status ?? ""),
      null,
      { timeout: 30_000 },
    );
    await page.waitForTimeout(4_000);
    const frames: Buffer[] = [];
    for (let i = 0; i < 8; i++) {
      const frame = await page.locator("#display").screenshot({ path: test.info().outputPath(`frame-${i}.png`) });
      frames.push(frame);
      if ([0, 3, 7].includes(i)) {
        await test.info().attach(`${scene}-frame-${i}`, { body: frame, contentType: "image/png" });
      }
      await page.waitForTimeout(1_000);
    }
    for (let i = 1; i < frames.length; i++) expect(frames[i].equals(frames[i - 1])).toBe(false);
    const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
    expect(preview?.status, preview?.log.join("\n")).toBe("running");
    expect(preview?.log.filter((line) => /error,|Runtime Error|Type Mismatch/i.test(line))).toEqual([]);
    writeFileSync(test.info().outputPath("console.json"), JSON.stringify(preview, null, 2));
    await test.info().attach(`${scene}-console`, {
      body: JSON.stringify(preview, null, 2),
      contentType: "application/json",
    });
  });
}
