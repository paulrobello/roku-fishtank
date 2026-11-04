# Roku Custom Screensaver (Tropical Fishtank) — Feasibility Research

Researched 2026-11-03 against primary sources at developer.roku.com (docs fetched live), plus Roku's developer forum, Roku's developer blog, and the RokuCommunity tooling repos. Every claim cites the page it came from; anything not verifiable from a primary source is marked **UNVERIFIED**.

## Bottom line

**Yes, feasible.** A Roku screensaver is just a channel package whose entry point is `RunScreenSaver()` with a `screensaver_title` manifest entry; Roku's official docs explicitly allow SceneGraph animation for screensavers. Programmatic SceneGraph animation (layered PNG sprites + `Animation`/`Interpolator` nodes + `Timer`) is the right rendering approach — **video playback is prohibited in screensavers**, so a pre-rendered video loop is not an option for a true screensaver. Load path:

1. On the Roku remote: **Home ×3, Up ×2, Right, Left, Right, Left, Right**, enable the Development Application Installer, set a `rokudev` password ([developer-setup](https://developer.roku.com/dev/docs/developer-setup)).
2. Zip the channel (manifest + `source/` + `components/`), upload at `http://<roku-ip>/plugin_install` (browser or `roku-deploy`).
3. On the device: **Settings > Theme > Screensavers**, select it as the active screensaver.

No publishing, developer-account certification, or store presence is required for personal use — sideloading is enough.

---

## 1. Screensaver app model

What a Roku screensaver technically is, per [Roku's Screensavers doc](https://developer.roku.com/dev/docs/screensavers) and the [Development environment overview](https://developer.roku.com/dev/docs/dev-environment):

- **It is a channel package with a different entry point.** `RunScreenSaver()` is the entry point for all screensavers; `RunUserInterface()` and `Main()` are prohibited in screensaver apps ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). `RunScreenSaver()` "is called to launch a screensaver when the Roku has been idle for the configured idle time" ([dev-environment](https://developer.roku.com/dev/docs/dev-environment)).
- **Optional settings entry point.** `RunScreenSaverSettings()` is invoked when the user picks "Change screensaver settings" on the screensaver's detail page; it stores options in the device registry ([Screensavers](https://developer.roku.com/dev/docs/screensavers)).
- **Manifest entry.** The only screensaver-specific manifest field is `screensaver_title` (string, "name of the screensaver"; example `screensaver_title=Dog Screensaver`). It "may only be used for screensaver applications" — any other app declaring it is blocked from publishing ([Screensavers](https://developer.roku.com/dev/docs/screensavers), [channel-manifest](https://developer.roku.com/dev/docs/channel-manifest)). A Roku staff-assisted forum thread (July 2026) confirms a subtle corollary: a dedicated screensaver app should **omit the ordinary channel `title` manifest field** while keeping `screensaver_title`, or Roku's static analysis misclassifies it as an in-channel screensaver and blocks submission ([forum thread](https://forum.developer.roku.com/t/static-analysis-blocks-a-dedicated-screensaver-false-positive-in-channel-screensaver-req-4-5/11503)).
- **The names `run_screensaver` / `run_screensaver_automatic` / `screensaver_empty_launch` as manifest entries do not exist** in the current manifest or screensaver docs — those behaviors are expressed by the `RunScreenSaver()` entry point and the user's idle-timeout setting instead. (Checked [channel-manifest](https://developer.roku.com/dev/docs/channel-manifest) and [Screensavers](https://developer.roku.com/dev/docs/screensavers).)
- **There is no dedicated `Screensaver` SceneGraph base component or `isScreensaver` flag** in the current SceneGraph component reference — the Scene node doc contains no mention of screensavers ([scene.md](https://developer.roku.com/docs/references/scenegraph/renderable-components/scene.md)). A screensaver is an ordinary SceneGraph app entered via `RunScreenSaver()`. (Absence verified on the Scene node page; absence across the whole component reference **UNVERIFIED** — searched, not exhaustively read.)
- **Lifecycle.** The screensaver runs in its own BrightScript context, separate from whatever streaming app is active, with no shared BrightScript objects; its debugger runs on telnet port **8087** (normal apps use 8085) ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). It launches automatically after the user-configured idle period and **any user input terminates it**, returning to the previous app ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). No documented `shown`/`hidden` field-level lifecycle events exist; `Timer` + `Animation` `control` fields are the documented start/stop mechanisms ([Timer](https://developer.roku.com/docs/references/scenegraph/event-functions/timer.md), [Animation](https://developer.roku.com/docs/references/scenegraph/animation-control/nodes/animation.md)).
- **User selection.** After install, the screensaver is chosen under **Settings > Theme > Screensavers**; the app itself never appears on the Home screen ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). If memory is insufficient at launch time, the system falls back to a default screensaver ([dev-environment](https://developer.roku.com/dev/docs/dev-environment)).
- **Whether a *sideloaded* (dev) screensaver app appears in that same Settings > Theme > Screensavers list is not explicitly documented.** The selection flow is documented only in terms of installed screensaver apps, and sideloaded dev apps are "installed" on the device ([developer-setup](https://developer.roku.com/dev/docs/developer-setup)). Community experience (How-To Geek's coverage of third-party aquarium screensaver channels, and Roku's own sample screensaver apps designed for sideload testing) is consistent with sideloaded screensavers being selectable, but consider this **UNVERIFIED from a primary source** — first sideload test should confirm it.

## 2. Rendering the animated fishtank

### SceneGraph capabilities relevant to a fishtank

- **Sprite rendering:** `Poster` nodes display PNGs. There is **no built-in flipbook/PNG-sequence animation node** — frame animation is done by swapping `Poster.uri` from a `Timer` observer, or by composing fish from separate body/f fin Posters. `Animation` nodes animate *fields* (translation, scale, rotation, opacity, color) of target nodes, not sprite frames ([Animation](https://developer.roku.com/docs/references/scenegraph/animation-control/nodes/animation.md)). (Absence of a flipbook node **UNVERIFIED** across the full component reference — searched, not exhaustively read.)
- **`Animation` node:** has `duration` (seconds), `easeFunction` (default `outCubic`; linear / in-out Quad..Expo / piecewise), and child interpolators — `FloatFieldInterpolator`, `Vector2DFieldInterpolator`, `ColorFieldInterpolator` — each with `fieldToInterp` (e.g. `myPoster.translation`), `key` (positions) and `keyValue` (field values). Start with `control = "start"`; repeating animations loop indefinitely ([Animation](https://developer.roku.com/docs/references/scenegraph/animation-control/nodes/animation.md)).
- **`Timer` node:** `duration` (float seconds — millisecond precision), `repeat` (bool), `control` = start/stop; fires an observable `fire` field. The doc notes the observer callback **executes on the render thread** ([Timer](https://developer.roku.com/docs/references/scenegraph/event-functions/timer.md)) — fine for frame swaps, but keep the callback short.
- **Camera pan / parallax:** there is no camera; the standard pattern is a wide `Group` holding background layers, with its `translation` field animated by a slow `Vector2DFieldInterpolator` loop (a Group's translation moves all children). Parallax = several Groups at different widths/depths moving at different speeds. (Group/parallax as "standard pattern" is community-consistent; the Animation/translation mechanics themselves are documented ([Animation](https://developer.roku.com/docs/references/scenegraph/animation-control/nodes/animation.md)).)
- **`observedField` pattern:** `m.node.ObserveField("field", "callbackFunction")` is the documented way to react to changes (e.g. `Timer.fire`) ([Timer](https://developer.roku.com/docs/references/scenegraph/event-functions/timer.md)).

### Video in a screensaver: prohibited

- The screensaver doc is explicit: screensavers "must not require user input... or have video playback", and `roVideoPlayer`, `roAudioPlayer`, and `roChannelStore` are **forbidden** components; also banned are ad insertion, in-app purchases, deep links, and "any type of user-initiated, interactive functionality" ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). Design accordingly: silent, non-interactive, pure graphics.
- What the store's "aquarium" apps actually are: apps like [Aquarium Screensaver](https://channelstore.roku.com/details/0021011e9850404936b9a70d6cee7b89:7162be89c14513c41910caf8d7c052bc/aquarium-screensaver) are **regular video-loop channels** the user launches manually — not true system screensavers. (App page; classification of its internals **UNVERIFIED** — inference from Roku's video-in-screensaver prohibition.) This is exactly the gap a custom SceneGraph screensaver fills.

### Performance constraints

- **Texture memory is the real budget:** bitmaps cost 4 bytes per pixel uncompressed — a 1920×1080 image is ~8.3 MB; file size on disk is irrelevant. Reusing the same image URI across many fish costs no extra texture memory (one copy shared by all nodes), so build a few fish species/colored variants and instance them. Symptoms of exceeding texture memory: "flickering images or slow content loading"; the doc warns against more than two full-HD images resident at once. Device DRAM ranges 512 MB–2 GB ([memory-management](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md)).
- Match source image size to display size; use `loadWidth`/`loadHeight` to downscale at load ([memory-management](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md)).
- Be conscious of CPU-heavy work on older devices — low frame rate results ([optimization-techniques](https://developer.roku.com/dev/docs/optimization-techniques)). No published numeric frame-rate target or node-count limit was found (**UNVERIFIED** as to any official figure; SceneGraph renders at the display refresh and `Animation` timing is duration-based).
- Long-running context: since screensavers run indefinitely, avoid reference cycles; GC does not catch cross-domain or node/BrightScript cycles, and leaks accumulate in long-running apps ([debugging](https://developer.roku.com/dev/docs/debugging)).

### Screensaver-specific restrictions (summary)

No audio, no video, no ads, no purchases, no deep links, no user input of any kind — any keypress exits the screensaver ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). Background tasks of a suspended app are not executed while a screensaver is active ([Instant Resume](https://developer.roku.com/dev/docs/instant-resume)). Burn-in-protection rules (e.g. mandated pixel drift) were **not found** in the certification docs fetched (**UNVERIFIED** — searched certification references only indirectly via the forum thread).

## 3. Loading it onto a consumer Roku — the full path

### Enable developer mode

From [developer-setup](https://developer.roku.com/dev/docs/developer-setup):

1. On the remote (physical remote or the Roku remote app): **Home ×3 → Up ×2 → Right → Left → Right → Left → Right**. (Sequence verified verbatim on the page.)
2. The Developer Settings screen appears; note the device's IP address shown there, enable the **Development Application Installer**, accept the Developer Tools License Agreement, and set a **case-sensitive** password. The Roku reboots into developer mode.

### Sideload via the web installer

From [developer-setup](https://developer.roku.com/dev/docs/developer-setup):

1. Browse to the recorded device address — the installer endpoint is `http://<roku-ip>/plugin_install` (endpoint name from the doc's flow and the tooling ecosystem; the doc says "visit the recorded device address").
2. Log in with username **`rokudev`** and the password from step 1.
3. Click **Upload** and choose the channel zip. Packaging options: **squashfs** (quicker loading; needs Roku OS 8.0+) or **zip** (Cramfs). The uploaded app starts automatically.

**Zip structure:** "During development packaging consists of a structured ZIP file" ([dev-environment](https://developer.roku.com/dev/docs/dev-environment)) — `manifest` at the zip root, `source/` (BrightScript), `components/` (SceneGraph XML + BrightScript), plus `images/` for art. This is the layout of Roku's official [Hello World sample](https://gitlab.com/rokudev/hello-world) whose `dist/apps/hello-world.zip` the developer-setup doc uses as its upload example.

**Limits and persistence:**

- **One sideloaded app per device** — uploading a new one replaces the previous; re-uploading an identical build errors until the old one is removed ([developer-setup](https://developer.roku.com/dev/docs/developer-setup)). Sideloading requires dev mode to stay enabled, which carries its own (undocumented-here) caveats.
- Sideloaded dev channels persist as installed apps and appear under a dev entry on Home. **Survival across reboot is not explicitly documented** on the fetched pages (**UNVERIFIED-primary**; consistent with widespread community experience — How-To Geek's sideloading guide, rokucommunity tooling docs).
- Because sideloading is unlimited-time, it is the right channel for a personal screensaver. The formal "beta app" mechanism in the Developer Dashboard is different and time-limited: a beta app expires **120 days** after creation and is then disabled for all users; max **10 beta apps** per account, **20 testers** each ([channel-publishing-guide](https://developer.roku.com/dev/docs/channel-publishing-guide)).

### Automation tooling

- **Roku has discontinued support for its Eclipse IDE plug-in**; it now points developers at **community IDE extensions**, specifically the BrightScript extension for VS Code ([development-setup](https://developer.roku.com/dev/docs/development-setup), extension: [RokuCommunity.brightscript](https://marketplace.visualstudio.com/items?itemName=RokuCommunity.brightscript)). That extension supports one-click sideloading and in-editor debugging ([rokucommunity.github.io](https://rokucommunity.github.io)).
- **`roku-deploy`** ([github.com/rokucommunity/roku-deploy](https://github.com/rokucommunity/roku-deploy)) is the npm module that zips a project and POSTs it to the device's `plugin_install` endpoint (with rokudev basic auth); it is the engine underneath the VS Code extension and has a CLI — the cleanest "edit → deploy" loop.
- **`curl` to plugin_install** is a well-known fallback (multipart POST with rokudev auth). The exact multipart field names (`mysquashfs`/`archive`) are community/tooling-documented rather than stated in Roku's fetched docs (**UNVERIFIED-primary**); prefer `roku-deploy` so you don't depend on them.

### Making it permanent

- A **sideloaded dev channel is sufficient for permanent personal use** — it stays installed as long as dev mode is enabled and nothing replaces it, and its screensaver can be set active in Settings (see §1 selection flow; sideloaded-selectable point UNVERIFIED-primary). No publishing involved.
- **Publishing landscape (verified current state):** Direct Publisher was sunset — no new DP channels after July 12, 2023, and all existing DP channels were removed January 12, 2024 ([Roku developer blog](https://blog.roku.com/developer/rdp-sunset)). Roku eliminated **private/non-certified channels in early 2022** ([developer forum](https://forum.developer.roku.com/t/private-channels-ending-what-am-i-supposed-to-do/10133)). Today the only store paths are **beta apps** (120-day expiry, QA-only, 20 users) or **certified public apps** — certification requires static analysis, app behavior analysis, and deep linking ([channel-publishing-guide](https://developer.roku.com/dev/docs/channel-publishing-guide)). Signed `.pkg` packaging (via `genkey` on telnet port 8080 and the installer's Packager) is for store submission, not for personal use ([packaging-channels](https://developer.roku.com/dev/docs/packaging-channels)).
- Note: the **publishing store does allow standalone screensaver apps** — "Only standalone screensaver apps are permitted" while ordinary channels may not embed screensavers; certification Requirement 4.5 reads "Channels are prohibited from offering in-channel screensavers or any feature that overrides the Roku system screensaver" ([Screensavers](https://developer.roku.com/dev/docs/screensavers); [forum thread quoting Req 4.5](https://forum.developer.roku.com/t/static-analysis-blocks-a-dedicated-screensaver-false-positive-in-channel-screensaver-req-4-5/11503)). Irrelevant for personal sideloading, relevant if Paul ever wants to publish it.

## 4. Gotchas

- **Roku OS versions:** squashfs sideloads need Roku OS 8.0+ ([developer-setup](https://developer.roku.com/dev/docs/developer-setup)); current devices run Roku OS 15.x in 2026 (observed in a Nov-2026 forum report of a Streaming Stick on OS 15.3 — [forum](https://forum.developer.roku.com/t/scenegraph-slideshow-preventing-system-screensaver-during-active-photo-playback/11707)). Any Roku from the last several years is fine.
- **Resolutions:** SceneGraph apps are authored against a design resolution and scale; manifest `ui_resolutions` supports `sd`, `hd`, `fhd` (default `sd,hd`) — declare `hd,fhd` and author at 1920×1080. Icons required: `mm_icon_focus_fhd` (540×405) and `mm_icon_focus_hd` (290×218); splash screens `splash_screen_hd` (1280×720) / `splash_screen_fhd` (1920×1080) ([channel-manifest](https://developer.roku.com/dev/docs/channel-manifest)). 4K (UHD) is not listed as a `ui_resolutions` value on the fetched manifest page; SceneGraph graphics upscale from FHD. (**UNVERIFIED** whether `uhd` is accepted there on current OS.)
- **Idle-time + memory:** the system only launches the selected screensaver after the configured idle time and silently falls back to a default one if memory is short at that moment ([dev-environment](https://developer.roku.com/dev/docs/dev-environment)) — keep the texture budget modest.
- **Certification-style constraints even for a dev app:** no audio, no video, no interaction ([Screensavers](https://developer.roku.com/dev/docs/screensavers)); screensaver launch kills background tasks of the suspended app ([instant-resume](https://developer.roku.com/dev/docs/instant-resume)). Burn-in protection rules: none found (**UNVERIFIED**).
- **Dev-mode security posture:** enabling dev mode disables some device protections and sideloaded channels aren't certified — fine on a personal device, documented only indirectly via the Developer Tools License Agreement accepted during setup ([developer-setup](https://developer.roku.com/dev/docs/developer-setup)).
- **The retired fishtank:** Roku's built-in "Aquatic Life" aquarium screensaver is being removed **December 1, 2026**, with devices switched to the default Roku City screensaver (announced Nov 2026; covered by [Cord Cutters News](https://cordcuttersnews.com/roku-is-removing-a-popular-feature-next-month) and the [r/Roku thread](https://www.reddit.com/r/Roku/comments/1xlwbdh/aquarium_screensaver_being_deleted_permanently)). **UNVERIFIED against an official Roku announcement** — this is the project's timely motivation (one search, per scope).

## 5. Recommended build path

For an experienced developer new to BrightScript/SceneGraph:

- **Rendering: programmatic SceneGraph animation.** Video loops are prohibited in screensavers, so the choice is made for you. It's also the better fit: a handful of small PNG sprites with `Animation`/`Vector2DFieldInterpolator` motion is cheap, loops forever, and scales to any resolution.
- **Art strategy:** author a small set of species sprites (3–5 fish shapes × 2–3 color variants) at display size in FHD, each fish as 2 layers (body + tail/fins) so a slow `FloatFieldInterpolator` on the tail layer's scale/rotation gives a swimming wiggle without sprite frames. Pebble bottom + coral as 2–3 large background PNGs in parallax Groups; keep total resident textures well under two full-HD images where possible, reuse identical URIs across fish of the same variant (free texture sharing). Slow side-to-side camera pan = one wide background Group whose `translation` is driven by a long repeating loop interpolator (~60–120 s cycle).
- **Fish behavior:** rather than one interpolator per fish, drive position from a `Timer` observer (e.g. 10–20 Hz) doing simple waypoint logic in BrightScript, plus per-fish `Animation` nodes for wiggle/turn. Keep callbacks short — they run on the render thread ([Timer](https://developer.roku.com/docs/references/scenegraph/event-functions/timer.md)).
- **Dev loop:** install the [RokuCommunity BrightScript VS Code extension](https://marketplace.visualstudio.com/items?itemName=RokuCommunity.brightscript) (uses `roku-deploy`); edit → F5-style deploy → zip+POST to `http://<roku-ip>/plugin_install` in one step, with telnet 8087 for screensaver debugging ([Screensavers](https://developer.roku.com/dev/docs/screensavers)). Start from Roku's screensaver samples in the [rokudev samples repo](https://gitlab.com/rokudev/samples) ("screen savers" section, per the [Screensavers doc](https://developer.roku.com/dev/docs/screensavers)) and the [Hello World](https://gitlab.com/rokudev/hello-world) layout.
- **First milestone:** prove the one uncertain link early — that a sideloaded screensaver shows up in Settings > Theme > Screensavers (§1, UNVERIFIED point). Sideloading a minimal `RunScreenSaver()` app that draws one Poster answers that in ten minutes.

## Notes

- All developer.roku.com pages fetched live 2026-11-03 from their `/dev/docs/...` canonical URLs.
- NotebookLM was attempted but is currently failing authentication (CSRF error at creation); no notebook was created.
- Research constraint honored: no code or project scaffold was created; this file is the only artifact.
