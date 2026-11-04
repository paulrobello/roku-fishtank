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

// Device-check scenes the preview also serves (?scene=MirrorProbeScene), so a device
// screenshot can be compared with the same scene in the preview. Never in the device build.
const previewOnlyFiles: Record<string, string> = {
  "tools/devicecheck/components/MirrorProbeScene.xml": "components/DeviceCheck/MirrorProbeScene.xml",
  "tools/devicecheck/components/MirrorProbeScene.brs": "components/DeviceCheck/MirrorProbeScene.brs",
};

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
  /** When set, replaces the anchor instead of inserting after it. */
  replace?: string;
}
const simPatches: Record<string, SimPatch[]> = {
  "/brs/brs-sg.js": [
    {
      why: "Roku OS 15.3.4 takes fieldToInterp as an roArray of path strings; brs-sg only accepts a string",
      anchor:
        'class Li extends ee{defaultFields=[{name:"fieldToInterp",type:"string"},{name:"key",type:"floatarray",value:"[]"},{name:"fraction",type:"float",value:"0.0"},{name:"reverse",type:"boolean",value:"false"}];',
      // Also F3: on the device a direct `fraction` write to an interpolator outside an
      // Animation drives its target (fidelity probe x 1662); brs-sg only interpolates inside
      // Animation.updateAnimation. The target is resolved with Animation's own lookup.
      insert:
        'setValue(t,i,s,n){const k="string"==typeof t?t.toLowerCase():"";"fieldtointerp"===k&&i instanceof e.RoArray&&i.elements.length>0&&(i=i.elements[0]);const r=super.setValue(t,i,s,n);if("fraction"===k&&!(this.getNodeParent()instanceof Ai)){const a=Object.create(Pi.prototype);a.targetCache=new WeakMap,a.warnedDescriptors=new WeakMap,a.getNodeParent=()=>this.getNodeParent();const o=a.resolveTarget(this),l=o&&this.interpolate(this.getValueJS("fraction"));l&&o.node.setValue(o.field,l)}return r}',
    },
    {
      // brs-sg already offsets the Group origin for scale about scaleRotateCenter but then
      // draws children unscaled. Scaling the canvas about that origin maps child point p to
      // origin + |scale| * p, as on the device. The device ignores the sign of a Group scale
      // (F4), so the canvas gets |scale|. A Group with scale.x * scale.y < 0 is pushed on
      // globalThis.__pvMirror so a rotated child Poster can reproduce the device's
      // 180-degree draw (drawImage patch below).
      why: "Roku scales a Group's children by |Group scale| (the 2x demo); brs-sg ignores it",
      anchor: "s=this.isVisible()?s*this.getOpacity():0,this.renderChildren(e,a,o,s,n),",
      insert: "",
      replace:
        's=this.isVisible()?s*this.getOpacity():0,this.withScale(n,a[0],a[1],this.getValueJS("scale").map(Math.abs),()=>{const k=globalThis.__pvMirror??=[],m=this.getValueJS("scale");k.push(m[0]*m[1]<0?this:null);try{this.renderChildren(e,a,o,s,n)}finally{k.pop()}}),',
    },
    {
      // F4: the device ignores the sign of scale when offsetting the origin for
      // scaleRotateCenter (MirrorProbeScene cells B, E, G, H draw exactly like the reference).
      why: "Roku offsets a node's origin by scaleRotateCenter * (|scale| - 1); brs-sg uses the signed scale",
      anchor:
        'getTranslation(e){const t=this.getValueJS("translation");e??=this.getValueJS("scale");const i=this.getScaleRotateCenter(),s=i[0]*(e[0]-1),n=i[1]*(e[1]-1);',
      insert: "",
      replace:
        'getTranslation(e){const t=this.getValueJS("translation");e??=this.getValueJS("scale");const i=this.getScaleRotateCenter(),s=i[0]*(Math.abs(e[0])-1),n=i[1]*(Math.abs(e[1])-1);',
    },
    {
      // Bitmap draw transform. Bitmap point q (node-local p = q * fit) lands at
      // O + R(s) * (L * q), O = parentOrigin + R(P) * (T + c - R(theta) * (S * c)), with
      // s = P + theta the accumulated rotation, c = scaleRotateCenter, S = scale, L = fit * S.
      // F1: brs-sg rotated the scaled bitmap about the unscaled center (34.5 px off in
      // FidelityScene cell 3); this is the exact pivot math the device measures.
      // F4 (MirrorProbeScene on the 4850X): with s = 0 the sign of S is ignored (|S|, |L|).
      // With s != 0 and a reflection (scale.x * scale.y < 0 on the Poster, XOR on its
      // immediate parent Group), the device keeps the signed origin O but draws the bitmap
      // with -|L|, a 180-degree turn: upside down and one height up when c is the center.
      // For a reflecting parent Group, O is reflected about the Group's center, because the
      // canvas carries only |Group scale|. i.x/i.y is brs-sg's origin, built from
      // T + c - |S| * c, so O = i + R(P) * (|S| * c - R(theta) * (S * c)).
      why: "Roku pivots rotate+scale exactly about scaleRotateCenter and does not mirror through negative scale",
      anchor:
        '{const e=this.getScaleRotateCenter();r?.doDrawRotatedBitmap(i.x,i.y,l,h,s,t,e[0],e[1],a,n)}else r?.doDrawScaledObject(i.x,i.y,l,h,t,a,n)}return i}',
      insert: "",
      replace:
        '{const e=this.getScaleRotateCenter(),c=this.getRotation(),P=s-c,d=globalThis.__pvMirror,g=this.getNodeParent(),f=!!d&&d.length>0&&null!==d[d.length-1]&&d[d.length-1]===g,m=o[0]*o[1]<0!==f;let L=[l,h],So=o;0===s?(L=[Math.abs(l),Math.abs(h)],So=[Math.abs(o[0]),Math.abs(o[1])]):m&&(L=[-Math.abs(l),-Math.abs(h)]);const A=[Math.abs(o[0])*e[0],Math.abs(o[1])*e[1]],B=J([So[0]*e[0],So[1]*e[1]],c);let q=[A[0]-B[0],A[1]-B[1]];if(f&&0!==s){const T=this.getValueJS("translation"),gc=g.getScaleRotateCenter(),gs=g.getValueJS("scale"),b=[T[0]-A[0]+e[0],T[1]-A[1]+e[1]],q0=[b[0]+q[0],b[1]+q[1]];q=[gc[0]+Math.sign(gs[0])*(q0[0]-gc[0])-b[0],gc[1]+Math.sign(gs[1])*(q0[1]-gc[1])-b[1]]}const O=J(q,P);0!==L[0]&&0!==L[1]&&r?.doDrawRotatedBitmap(i.x+O[0],i.y+O[1],L[0],L[1],s,t,0,0,a,n)}else r?.doDrawScaledObject(i.x,i.y,l,h,t,a,n)}return i}',
    },
    {
      // F5: the 4850X lerps hue linearly with no shortest-path wrap. Red -> blue measured
      // 0xFEFF01 / 0x00FF01 / 0x00FEFF at f 0.25 / 0.5 / 0.75 (hue 0 -> 240 through yellow,
      // green, cyan); brs-sg wrapped through magenta. Saturation, value and alpha unchanged.
      why: "Roku ColorFieldInterpolator lerps hue in [0,360) without wrapping",
      anchor:
        "interpolateColor(e,t,i){const s=this.toHsv(e),n=this.toHsv(t);let r=s.h,a=n.h;Math.abs(a-r)>180&&(a>r?r+=360:a+=360);",
      insert: "",
      replace: "interpolateColor(e,t,i){const s=this.toHsv(e),n=this.toHsv(t);let r=s.h,a=n.h;",
    },
  ],
};

function readPatched(path: string, file: string): Uint8Array {
  const patches = simPatches[path];
  if (!patches) return readFileSync(file);
  let text = readFileSync(file, "utf8");
  for (const p of patches) {
    const hits = text.split(p.anchor).length - 1;
    if (hits !== 1) throw new Error(`sim patch anchor found ${hits} times (want 1) in ${path}: ${p.why}`);
    const out = p.replace ?? p.anchor + p.insert;
    text = text.replace(p.anchor, () => out);
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
  for (const [src, dest] of Object.entries(previewOnlyFiles)) files[dest] = readFileSync(join(repoRoot, src));
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
