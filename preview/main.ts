import type * as Brs from "brs-engine";

declare const brs: typeof Brs;

/** State the screenshot gate and agents read from the page. */
interface PreviewState {
  status: "loading" | "running" | "frozen" | "error";
  params: Record<string, string>;
  log: string[];
}

declare global {
  interface Window {
    __preview: PreviewState;
  }
}

const WIDTH = 1920;
const HEIGHT = 1080;
const PARAM_KEYS = ["scene", "seed", "time", "speed", "freeze", "species", "density", "night", "debug"] as const;

const state: PreviewState = { status: "loading", params: {}, log: [] };
window.__preview = state;

function fitStage(): void {
  const stage = document.getElementById("stage") as HTMLElement;
  const scale = Math.min(window.innerWidth / WIDTH, window.innerHeight / HEIGHT);
  stage.style.transform = `scale(${scale})`;
  stage.style.left = `${Math.max(0, (window.innerWidth - WIDTH * scale) / 2)}px`;
  stage.style.top = `${Math.max(0, (window.innerHeight - HEIGHT * scale) / 2)}px`;
}

function onEngineEvent(event: string, data: unknown): void {
  // BrightScript print/error output arrives as debug events of {level, content}.
  const line = event === "debug" ? (data as { level: string; content: string }) : undefined;
  const text = line ? `${line.level},${line.content}` : typeof data === "string" ? data : "";
  if (event !== "icon") state.log.push(`${event}: ${text ? text.trimEnd() : JSON.stringify(data)?.slice(0, 200)}`);
  if (event === "started" || event === "resolution") {
    if (event === "started") state.status = "running";
    // Pin the canvas backing store to 1080p at 1:1 regardless of window size. The engine
    // caps it at the app's screen size, so re-apply after every resolution change.
    queueMicrotask(() => brs.redraw(false, WIDTH, HEIGHT, 1));
  } else if (text.includes("PREVIEW_FROZEN")) {
    state.status = "frozen";
  } else if (event === "closed" || (event === "debug" && text.startsWith("error,"))) {
    if (state.status !== "frozen") state.status = "error";
  }
}

async function main(): Promise<void> {
  fitStage();
  window.addEventListener("resize", fitStage);

  // URL params reach Main(args) through the engine's deep-link map (PRD Q2).
  const query = new URLSearchParams(window.location.search);
  const deepLink = new Map<string, string>();
  for (const key of PARAM_KEYS) {
    const value = query.get(key);
    if (value !== null) {
      deepLink.set(key, value);
      state.params[key] = value;
    }
  }

  // Hand the engine the SceneGraph common: volume (fonts, audio) up front; its own
  // lazy fetch races the sound module and the first execute.
  const common = await fetch("/assets/common.zip");
  const assets = await common.arrayBuffer();

  brs.subscribe("preview", onEngineEvent);
  await brs.initialize(
    {
      assets,
      displayMode: "1080p",
      extensions: new Map([[brs.SupportedExtension.SceneGraph, "./brs-sg.js"]]),
    },
    { debugToConsole: true },
  );

  const response = await fetch("/channel.zip", { cache: "no-store" });
  if (!response.ok) {
    state.status = "error";
    state.log.push(`channel.zip: HTTP ${response.status}`);
    return;
  }
  brs.execute("channel.zip", await response.arrayBuffer(), { clearDisplayOnExit: false }, deepLink);
  // A click sends OK, which ReefTank's preview-only key handler maps to a day/night flip.
  document.getElementById("display")?.addEventListener("click", () => brs.sendKeyPress("select"));
}

main().catch((err: Error) => {
  state.status = "error";
  state.log.push(`preview: ${err.message}`);
  console.error(err);
});
