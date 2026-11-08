# YouTube description — pending update

The live showcase video (https://youtu.be/KN0P7S0MsjQ) needs its description's performance
line made precise (Reddit feedback 2026-11-08: distinguish measured from untested devices).
Applying it needs `videos.update`, which the upload-only token cannot call (403) — it
requires a separate one-time browser consent with the full `youtube` scope (Paul at the
keyboard), per vault `Knowledge/youtube-upload-scope-limits-and-verification`.

## v2 description (full replacement text)

```
Roku is retiring the built-in "Aquatic Life" screensaver on December 1, 2026. Reef Tank is my free, open-source replacement — a procedurally animated tropical reef that turns your TV into an aquarium.

0:00 Day — grazing, schooling and darting fish
0:15 Night — moonlight, glowing coral, bioluminescent sparkles

Every fish is rigged and animated in code (BrightScript/SceneGraph). Each species has its own behavior brain: blue tangs graze the rocks, a royal gramma backs tail-first into its den, a mandarin hops the sand, lionfish hang in the current, and a school of green chromis flocks with boids math. After sunset (computed from real sunrise/sunset times) the tank crossfades to a moonlit night with flashlight fish.

Measured on a Roku Ultra 4850X at normal density: 60 fps day, 56 night. Other Roku models (including the older Ultra 4800X) are untested. Installing takes about 5 minutes: enable developer mode on the remote, sideload from a computer, enable it under Settings > Theme > Screensavers. Free, MIT licensed.

Source + install guide: https://github.com/paulrobello/roku-fishtank
Install walkthrough video: coming — see the README's Installing section meanwhile.

#roku #screensaver #aquarium #opensource #procedural
```

## How to apply (next session or Paul-approved run)

1. Run the loopback consent with the full `youtube` scope (Desktop client secret from
   ParVault `PA_GOOGLE_YT_UPLOAD_CLIENT_SECRET_JSON`), store the token under a distinct
   name (e.g. `~/.config/youtube/edit-token.json`).
2. `videos.update` resending the ENTIRE snippet (title unchanged, description = v2 above,
   categoryId 28, tags list unchanged) plus status (public, not made for kids) — omitted
   fields are cleared.
3. Verify via oEmbed (reads fine unauthenticated) or the channel page.
