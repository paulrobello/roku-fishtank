# Reddit release post — Reef Tank

A ready-to-adapt release post plus target subreddits. Post from Paul's account; adapt the
intro per sub (Reddit penalizes identical crossposts) and check each sub's self-promotion
rules first. Capture a 20–30 s video of the tank (day → dusk → night) before posting —
video outperforms static images several-fold; until then the image links are placeholders.

## Title options

1. I replaced Roku's retiring "Aquatic Life" screensaver with my own procedurally animated reef tank — free and open source
2. Roku is killing the Aquatic Life screensaver in December, so I spent a month building a replacement
3. My Roku now runs a fully procedural reef tank I wrote in BrightScript (free, open source, sideload it in 5 minutes)

## Master post (adapt per sub)

```markdown
Roku is retiring its built-in "Aquatic Life" screensaver on December 1. I liked that
screensaver, so I built a replacement: **Reef Tank** — a free, open-source (MIT) screensaver
channel for Roku.

**What it is:** a tropical reef tank where nothing is a video loop. Every fish is
procedurally animated — each species has its own behavior brain, so tangs graze the rocks,
a royal gramma backs tail-first into its den, a mandarin hops along the sand line, a
lionfish just hangs, and a school of chromis moves as a boids flock. Bubbles rise, seaweed
sways, caustics scroll over the sand. After real sunset (computed from actual sunrise/
sunset times for your location) the tank crossfades to a moonlit night mode with glowing
coral and a small group of flashlight fish that blink in the dark.

Highlights:

- 9 rigged fish species with per-species behavior state machines (cruise, dart, graze, hide, school, weave behind the rockwork)
- Boids flocking school + a night-only flashlight fish group
- Day/night cycle driven by real solar times, with a moonlight crossfade
- Settings screen on the Roku for fish density, camera drift and night mode
- Runs at 60 fps on a Roku Ultra; every visual is deterministic and seeded
- 175 unit tests + a screenshot regression gate, because of course

**The catch:** Roku doesn't allow sideloading into the Channel Store for personal projects,
so it's a developer-mode sideload — takes about 5 minutes with the remote (Home x3, Up x2,
Right, Left, Right, Left, Right), and it's free. Full instructions in the README.

Source + install guide: https://github.com/paulrobello/roku-fishtank

Happy to answer anything about the BrightScript/SceneGraph side — the whole thing is one
codebase that also runs in a browser simulator, which is how I screenshot-tested a TV app.
```

## Where to post

| Subreddit | Fit | Angle to lead with |
|---|---|---|
| r/Roku | Primary audience | "Aquatic Life is being removed, here's a free replacement" — practical, for users. Check self-promo rules; a comment-heavy Q&A posture lands better than a link drop. |
| r/sideproject | Strong | The build story: one month, replacement for a beloved screensaver, open sourced. |
| r/proceduralgeneration | Strong, small | Tech angle: boids + steering behaviors + rigged sprite animation under SceneGraph constraints (no shaders, no additive blending, no flipbook). |
| r/ReefTank | Fun crosspost | "I can't keep a real reef so I built a virtual one for my TV" — hobbyists will judge the fish; keep it light, mention species by name. |
| r/Aquariums | Optional | Same angle as r/ReefTank; lower signal, bigger reach. Read the rules — some aquarium subs restrict non-hobby content. |

Skip r/programming and r/gamedev (wrong shape: not an article, not a game), and skip
r/cordcutters (release posts are off-topic there).

## Posting notes

- Vary the first two sentences per sub and keep the body otherwise similar; Reddit's
  filters and users both penalize copy-paste crossposts.
- Link the GitHub repo as the main link; put the video/GIF in the post body where the sub
  allows direct media, since a text-plus-link post hides the visual hook.
- Expect "why do I need dev mode / is this safe" questions on r/Roku — the honest answer
  (free, dev mode is official and reversible, only one sideloaded app per slot, source is
  open) is in the README's Installing section.
- Night-mode video segment matters: the dusk crossfade + glowing coral is the most
  shareable moment.
- The Dec 1 removal date is the news hook — posting in the window before it (now through
  Dec 1) is materially better timing than after.
