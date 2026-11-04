import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import type { ServerResponse } from "node:http";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { zipSync } from "fflate";
import { defineConfig, type Plugin } from "vite";

const previewDir: string = dirname(fileURLToPath(import.meta.url));
const repoRoot: string = resolve(previewDir, "..");
const modules: string = join(repoRoot, "node_modules");

// The engine derives the worker URL from the brs.api.js <script> src, and the worker
// importScripts the SceneGraph bundle relative to itself, so all three share /brs/.
const engineFiles: Record<string, string> = {
  "/brs/brs.api.js": join(modules, "brs-engine/lib/brs.api.js"),
  "/brs/brs.worker.js": join(modules, "brs-engine/lib/brs.worker.js"),
  "/brs/brs-sg.js": join(modules, "brs-scenegraph/lib/brs-sg.js"),
  // Fetched relative to the page; the SceneGraph build carries the fonts SG needs.
  "/assets/common.zip": join(modules, "brs-scenegraph/assets/common.zip"),
};

// Channel content shipped to the engine. source/ includes preview.brs (the Main shim),
// which bsconfig.json keeps out of the device zip.
const channelDirs: string[] = ["source", "components", "images", "config"];

// SharedArrayBuffer (engine threads, remote input) requires cross-origin isolation.
const isolationHeaders: Record<string, string> = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
};

function walk(dir: string, out: string[]): void {
  for (const name of readdirSync(dir)) {
    if (name.startsWith(".")) continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full, out);
    else out.push(full);
  }
}

// Simulator fidelity patches, keyed by served path. Each one makes brs-scenegraph 0.6.2
// match device-verified behavior, so the channel code runs unmodified. A missing anchor
// (package upgraded) fails the request loudly instead of silently diverging.
interface SimPatch {
  why: string;
  anchor: string;
  insert: string;
}
const simPatches: Record<string, SimPatch[]> = {
  "/brs/brs-sg.js": [
    {
      why: "Roku OS 15.3.4 takes fieldToInterp as an roArray of path strings; brs-sg only accepts a string",
      anchor:
        'class Li extends ee{defaultFields=[{name:"fieldToInterp",type:"string"},{name:"key",type:"floatarray",value:"[]"},{name:"fraction",type:"float",value:"0.0"},{name:"reverse",type:"boolean",value:"false"}];',
      insert:
        'setValue(t,i,s,n){return"string"==typeof t&&"fieldtointerp"===t.toLowerCase()&&i instanceof e.RoArray&&i.elements.length>0&&(i=i.elements[0]),super.setValue(t,i,s,n)}',
    },
  ],
};

function readPatched(path: string, file: string): Uint8Array {
  const patches = simPatches[path];
  if (!patches) return readFileSync(file);
  let text = readFileSync(file, "utf8");
  for (const p of patches) {
    if (!text.includes(p.anchor)) throw new Error(`sim patch anchor missing in ${path}: ${p.why}`);
    text = text.replace(p.anchor, p.anchor + p.insert);
  }
  return new TextEncoder().encode(text);
}

// brs-scenegraph takes the FIRST ui_resolutions entry as the design resolution; a device on
// a 1080p display picks fhd. Put fhd first in the preview copy so currentDesignResolution matches.
function previewManifest(): Uint8Array {
  const text = readFileSync(join(repoRoot, "manifest"), "utf8").replace(
    /^ui_resolutions=(.*)$/m,
    (_line: string, list: string) => {
      const res = list.split(",").map((r) => r.trim());
      const ordered = res.includes("fhd") ? ["fhd", ...res.filter((r) => r !== "fhd")] : res;
      return `ui_resolutions=${ordered.join(",")}`;
    },
  );
  return new TextEncoder().encode(text);
}

/** Zips the current channel sources on every request so the preview never runs stale code. */
export function buildChannelZip(): Uint8Array {
  const files: Record<string, Uint8Array> = { manifest: previewManifest() };
  for (const dir of channelDirs) {
    const abs = join(repoRoot, dir);
    if (!existsSync(abs)) continue;
    const paths: string[] = [];
    walk(abs, paths);
    for (const p of paths) files[relative(repoRoot, p)] = readFileSync(p);
  }
  return zipSync(files, { level: 1 });
}

function send(res: ServerResponse, type: string, body: Uint8Array): void {
  res.statusCode = 200;
  res.setHeader("Content-Type", type);
  res.setHeader("Cache-Control", "no-store");
  for (const [k, v] of Object.entries(isolationHeaders)) res.setHeader(k, v);
  res.end(body);
}

function brsEngine(): Plugin {
  return {
    name: "brs-engine-preview",
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const path = (req.url ?? "").split("?")[0];
        if (path === "/channel.zip") {
          try {
            send(res, "application/zip", buildChannelZip());
          } catch (err) {
            res.statusCode = 500;
            res.end(`channel.zip build failed: ${(err as Error).message}`);
          }
          return;
        }
        const file = engineFiles[path];
        if (file) {
          const type = path.endsWith(".zip") ? "application/zip" : "text/javascript";
          try {
            send(res, type, readPatched(path, file));
          } catch (err) {
            server.config.logger.error((err as Error).message);
            res.statusCode = 500;
            res.end((err as Error).message);
          }
          return;
        }
        next();
      });
    },
  };
}

export default defineConfig({
  root: previewDir,
  plugins: [brsEngine()],
  server: {
    port: 8138,
    strictPort: true,
    headers: isolationHeaders,
  },
  preview: { headers: isolationHeaders },
});
