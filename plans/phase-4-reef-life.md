# Phase 4: Reef life extras

PRD: `PRD.md` § P4. Depends on `plans/phase-2-fish-life.md` (brain, rig) and `plans/phase-1-day-tank.md` (scene stack). Within the cut order (PRD), invertebrates are cut before surface/caustics.

## Tasks

### P4.1: Anemone and clownfish hosting
The anemone is built from tentacle segment chains (P1.4 technique) with a current-driven sway. The clownfish pair gets a "host" state that keeps them within a radius of the anemone, nuzzling in and out and partly occluded by the tentacles.
- Verify: unit test confirms the clownfish never leave the host radius over 10k steps. Paul reviews in the preview.
- Depends on: P2.6, P4.6.

### P4.2: Swaying soft coral
Soft corals and sea fans get the same chain-sway technique with phase offsets driven by one shared "current" value.
- Verify: preview shows coherent current motion across all swaying elements.
- Depends on: P1.4, P4.6.

### P4.3: Invertebrates
- A cleaner shrimp walks along the rock with antenna wiggle.
- A crab scuttles side-to-side on the sand with pauses.
- A starfish moves very slowly on the rock or front glass.

All use the brain tick with a ground-constrained steering mode.
- Verify: each one is visible and moving within 5 minutes at `?seed=1`. They stay on their surfaces (unit test on the ground constraint).
- Depends on: P2.3, P4.6.

### P4.4: Water surface ripple
A top-edge surface strip made of two offset alpha PNGs scrolling and bobbing, with its tint following day/night.
- Verify: no seam at the loop point in the preview at `?speed=10x`.
- Depends on: P1.2, P4.6.

### P4.5: Caustics
Two tileable alpha caustic textures scrolling in different directions, blended by opacity over the sand and rock layers and masked by the art. Intensity is lowered at night.
- Verify: no visible tile seam (Playwright frame at 4 offsets, reviewed). Budget and 60 fps hold on the device.
- Depends on: P1.2, P4.6.

### P4.6 (art track): Extras art
Anemone tentacle segments, soft coral/fan segments, shrimp, crab, starfish, surface strips and caustic tiles (tileable, checked with an offset-wrap test), with provenance.
- Verify: Paul approves. The texture total stays within the budget.
- Depends on: P1.6, P0.8.

## Exit
All extras are live in the preview and on the device, `make checkall` is green with updated baselines, and the device holds 60 fps at Normal density with the full worst-case texture set.
