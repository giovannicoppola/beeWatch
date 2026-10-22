# Apple Watch tour video

A 19-second narrated tour of the watch app, 1080×1920, for the landing page and social posts:
`docs/media/beewatch-watch-tour.mp4` and its poster frame `beewatch-watch-tour-poster.jpg`. It
runs on the **sample goals** (`-sample YES`, Debug builds only; see `Shared/Services/SampleGoals.swift`):
six invented goals, no Beeminder account, and a logged value stays in memory on the watch. The goal
list by urgency, logging a quick value with its confirmation, and the list reordered after it.

```
watch-runner/      a separate Xcode project (XcodeGen) whose UI test drives the installed watch app
watch-record.mjs   builds the watch app (Debug), installs it fresh, films the tour  -> build/watch-tour
retime.py          the film on its true timeline, at a steady 30 fps (run by watch-record.mjs)
narrate.py         one Kokoro line per caption, plus the end card
plan.py            which parts of the film to keep, so each scene lasts as long as its line
watch-compose.mjs  captions, the watch frame (watch-bezel.py), touch rings and the end card
mix.py             the narration, loudness-normalised
```

```sh
cd Tools/tour && npm install
export WATCH_SIM=<watchOS 11 simulator udid>   # an Apple Watch Ultra 2 (49mm), paired: see below
export KOKORO_PYTHON=<python with kokoro, soundfile, numpy>
npm run watch-record && npm run watch-voice && npm run watch-plan && npm run watch-video
```

Needs Xcode with XcodeGen, ffmpeg, Chrome (for the captions) and Python with Pillow. The
narration runs locally with [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) (Apache 2.0),
voice `af_heart`.

- **Pair the Watch with an iPhone simulator** (`simctl pair`, then boot both), as
  or the red "iPhone disconnected" glyph shows by the clock.
  A fresh iPhone simulator without beeWatch is best: nothing on it can send the watch an API key.
- **Use a watchOS 11 simulator**: the newest runtimes draw emoji as "?" boxes.
- The watch's clock can't be pinned, so it shows the time of the recording; `plan.py` ignores the
  top 16% of the screen so the minute ticking over isn't taken for motion.

## Why it is built this way

- **A separate runner project**, so `project.yml` never gains a target for a video. Its UI test
  drives the watch app by bundle id; `TourHost` is only there because XCUITest needs a watchOS app
  of its own to attach to.
- **The sample lives in `BeeminderAPI`**, behind `#if DEBUG`: every call answers from
  `SampleGoals` when it is on, so the list, the urgency colours, the entry screen and the refresh
  after logging all run their real code. A logged value updates the sample goal as Beeminder would
  (each day's worth buys a day of buffer).
- **The film decides the timing, not the log.** `plan.py` keeps every stretch where the screen
  moves, trims the still ones to fit the narration, gives the script's own holds priority over the
  runner's stalls, and always holds a scene's final state as long as the script did.
- **`retime.py`** works around the simulator encoder's timestamps, which put screens seconds early
  in anything decoded straight from `film.mp4`, and holds the last frame until the tour's end.

## Changing it

- Captions and touches are in `watch-runner/WatchTourTests/WatchTourTests.swift`; the words spoken
  are in `watch-narration.txt`, one line per caption, then one for the end card.
- If a line is longer than its scene, `mix.py` says which line to shorten.
- Once beeWatch is on the App Store, say so on the end card in `watch-compose.mjs`.
