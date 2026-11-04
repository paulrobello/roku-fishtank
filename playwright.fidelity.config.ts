import { defineConfig } from "@playwright/test";
import base from "./playwright.config";

// P0.5 simulator capture (`make fidelity-sim`), kept out of the checkall screenshot gate:
// the scene pauses itself on a Timer, so the frame is approximate by design and the
// verdict comes from the read-back FIDELITY console lines, not a pixel baseline.
export default defineConfig({
  ...base,
  testDir: "tests/fidelity",
});
