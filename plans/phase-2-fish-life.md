# Phase 2: Fish life

PRD: `PRD.md` § P2. Depends on `plans/phase-1-day-tank.md` exit (scene stack, avoidance data, rig pipeline).

Species: royal blue tang, yellow tang, ocellaris clownfish pair, emperor angelfish, Moorish idol, royal gramma, lionfish, mandarin dragonet, plus a ~10-fish green chromis school.

## Tasks

### P2.1: Steering library (pure logic)
`components/lib/steer.brs` provides wander, seek, avoid-ellipse, lane-keep and speed clamp. It works on plain roAssociativeArrays with an injected clock and PRNG, and has no SceneGraph dependency.
- Verify: unit tests cover avoid (never enters an ellipse over 10k steps), lane-keep, and same seed giving the same path.
- Depends on: P0.4.

### P2.2: Fish rig component
`components/Fish/Fish.xml/.brs` holds a rig Group (body, tail, pectoral Posters from the species JSON), a looping tail/fin Animation whose speed scales with swim speed, and a turn that animates `scale.x` 1 → -1 with a slight body squash.
- Verify: the preview shows a rigged tang turning cleanly with no seam pops. Device fidelity holds.
- Depends on: P1.6.

### P2.3: Brain tick → Animation segments
`FishTank` brain Timer at ~8 Hz steers each fish and issues the next 0.5–1.5 s `Vector2DFieldInterpolator` segment, reusing one Animation per fish (no per-segment node creation). A dart stops and retargets mid-segment with a fast ease-out.
- Verify:
  - 60 fps on the device with 25 fish (`docs/perf.md` method).
  - Node count is constant over a 30-minute preview run (logged).
  - Darts are visible.
- Depends on: P2.1, P2.2.

### P2.4: Lane weaving
A fish requests a lane change and reparents only when its bounds are fully inside an occluder rect of the layer between the lanes. It then eases into the new lane's scale and tint.
- Verify: unit test confirms no lane switch occurs outside an occluder. In the preview, fish visibly go behind coral and emerge in another lane.
- Depends on: P2.3, P1.8.

### P2.5: Chromis school (boids)
Separation, alignment and cohesion plus a leader wander. The school shares one brain tick, all members share one URI, and the school avoids the ellipses.
- Verify: unit test confirms members stay within a radius bound and never overlap closer than a minimum distance. The preview shows the school wheeling as a group.
- Depends on: P2.3.

### P2.6: Bottom and hiding behaviors
A per-species state machine:
- Royal gramma hovers at cave mouths and backs into them.
- Mandarin dragonet grazes along the rock and sand edge with short hops.
- Lionfish hover-drifts slowly.
- Tangs, the angelfish and the idol cruise and graze on rock.

Clownfish anemone hosting lands in P4.
- Verify: each behavior is observable within 5 minutes in the preview at `?seed=1`, logged with state transitions.
- Depends on: P2.3.

### P2.7: Density and population config
`scene.json` holds the population per density (Calm / Normal / Busy). Normal is ~15 fish + 10 chromis. Background-lane fish may use a 2-part rig.
- Verify: Busy holds 60 fps on the 4850X, or Busy is capped to measured headroom.
- Depends on: P2.3.

### P2.8 (art track): Species art, batch A
Royal blue tang (from the style board), yellow tang, emperor angelfish, Moorish idol, generated in the style-board reference and rigged via `make art`. Provenance per species.
- Verify: Paul approves each species in the preview.
- Depends on: P1.6, P0.8.

### P2.9 (art track): Species art, batch B
Ocellaris clownfish, royal gramma, lionfish (long fins need extra rig layers), mandarin dragonet, and green chromis.
- Verify: Paul approves each species in the preview.
- Depends on: P1.6, P0.8.

## Exit
All species and behaviors are live in the preview and on the device, `make checkall` is green with updated baselines at fixed seed, and the device holds 60 fps at Normal density.
