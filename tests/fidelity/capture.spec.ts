import { writeFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

type PreviewWindow = Window & { __preview?: { status: string; log: string[] } };

test("capture FidelityScene from the simulator", async ({ page }) => {
  await page.goto("/?scene=FidelityScene");
  // The scene pauses its Animations at 4 s and prints FIDELITY lines ending with the probe.
  await page.waitForFunction(
    () => {
      const p = (window as PreviewWindow).__preview;
      return p?.status === "error" || (p?.log ?? []).some((l) => l.includes("FIDELITY fraction_probe"));
    },
    null,
    { timeout: 30_000 },
  );
  const preview = await page.evaluate(() => (window as PreviewWindow).__preview);
  expect(preview?.status, preview?.log.join("\n")).not.toBe("error");

  // Let the paused frame and the report Label settle before capturing.
  await page.waitForTimeout(1_000);
  await page.locator("#display").screenshot({ path: "docs/fidelity/simulator.png" });

  const lines = (preview?.log ?? []).filter((l) => l.includes("FIDELITY")).map((l) => l.replace(/^debug: /, ""));
  writeFileSync("docs/fidelity/simulator-console.txt", `${lines.join("\n")}\n`);
});
