import { defineConfig } from "@playwright/test";

// Local gate only (there is no CI). Renders on the real GPU; PW_GPU=swiftshader opts into
// software GL. Port 8139 is reserved for this isolated server, separate from `make dev` on 8138.
const gpu: string = process.env.PW_GPU ?? "metal";
const gpuArgs: string[] =
  gpu === "metal"
    ? ["--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist"]
    : ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"];

export default defineConfig({
  testDir: "tests/visual",
  outputDir: "test-results",
  snapshotPathTemplate: "{testDir}/__screenshots__/{arg}{ext}",
  workers: 1,
  fullyParallel: false,
  retries: 0,
  reporter: [["list"]],
  timeout: 60_000,
  expect: {
    toHaveScreenshot: { maxDiffPixelRatio: 0.001, threshold: 0.02 },
  },
  use: {
    baseURL: "http://localhost:8139",
    channel: "chromium",
    headless: true,
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    launchOptions: { args: gpuArgs },
  },
  webServer: {
    command: "bunx --bun vite --config preview/vite.config.ts --port 8139 --strictPort",
    url: "http://localhost:8139/",
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
