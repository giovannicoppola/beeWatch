# beeWatch — App Store Submission Package

Everything needed to submit **beeWatch** to the App Store. Copy the text fields
straight into App Store Connect. Items marked **⚠️ ACTION** need a decision or an
asset from you before you can submit.

- **App name (internal):** beeWatch
- **Bundle ID (iOS app):** `com.beewatch.ios`
- **Bundle ID (watch app):** `com.beewatch.ios.watchkitapp`
- **Bundle ID (complications ext.):** `com.beewatch.ios.watchkitapp.complications`
- **Version / Build:** 1.0 / 1
- **Primary platform:** iOS + watchOS (Apple Watch app with WidgetKit complications)

> beeWatch is an independent, third-party client for **Beeminder**. The metadata
> below deliberately uses "for Beeminder" as a descriptor and includes a
> non-affiliation line. Do **not** use the Beeminder logo/bee mascot in a way
> that implies endorsement. See "Trademark & rights" at the bottom.

---

## 1. App information (static)

| Field | Value | Notes |
|---|---|---|
| **App Name** | `beeWatch for Beeminder` | 22/30 chars. Alt: just `beeWatch` if you want to avoid the descriptor. |
| **Subtitle** | `Beeminder goals on your wrist` | 29/30 chars. |
| **Primary category** | Productivity | |
| **Secondary category** | Health & Fitness | Optional; fits habit/goal tracking. |
| **Content rights** | Does **not** contain third-party content | You wrote all the code/copy. |
| **Age rating** | 4+ | No objectionable content. Answer "None" to all questionnaire items. |
| **Price** | Free (Tier 0) | ⚠️ ACTION — confirm; set in Pricing. |
| **Copyright** | `2026 Giovanni Coppola` | Format ASC expects: `YYYY Name`. |

### Localizations
Primary language: **English (U.S.)**. All copy below is en-US. Add more later if
wanted.

---

## 2. Metadata copy (paste into ASC)

### Promotional text (max 170 chars — editable anytime without review)
```
Log your Beeminder goals in a single tap, right from your wrist. See what's due, get reminders only when it matters, and keep a live complication on your watch face.
```
(159 chars)

### Description (max 4000 chars)
```
beeWatch puts your Beeminder goals on your wrist. Log data in seconds, see what's due at a glance, and stop derailing just because you forgot to check in.

Built for Apple Watch first, beeWatch works on its own — no need to pull out your phone to stay on the road.

WHAT IT DOES

• Goals at a glance — your goals are sorted by urgency, so the one closest to derailing is always on top.
• One-tap logging — quick-entry buttons are built from your most frequent values for each goal, so repetitive check-ins take a single tap.
• Confirm before you commit — a quick confirmation step prevents accidental entries.
• Complications — put your most urgent goal, or a specific goal, right on your watch face. See your safety buffer and the time left before you derail without opening the app.
• Reminders that respect you — get nudged only when a goal actually needs data, and log straight from the notification.
• Recent history — glance at your latest datapoints for context before you log.
• iPhone companion — enter your Beeminder API key once on iPhone and it syncs to the watch.

WHO IT'S FOR

If you use Beeminder to hold yourself to your goals — steps, writing, studying, workouts, weight, anything you track — beeWatch makes the "did I log it?" moment fast enough that you actually do it.

REQUIREMENTS

beeWatch is an independent, third-party client for Beeminder. You'll need a free Beeminder account (beeminder.com) and your personal API key, which the app helps you find. An internet connection is required to sync with Beeminder.

Not affiliated with, endorsed by, or sponsored by Beeminder Corp. "Beeminder" is a trademark of Beeminder Corp.
```

### Keywords (max 100 chars, comma-separated, no spaces)
```
beeminder,goal,goals,habit,tracker,quantified,akrasia,productivity,complication,streak,data,log
```
(96 chars — count it after any edit; ASC counts commas.)
> Don't repeat words already in the app name/subtitle ("beeWatch", "wrist") —
> Apple indexes those separately. Avoid "watch"/"apple" (ignored/blocked).

### What's New in This Version (max 4000 chars)
For the initial 1.0 release, ASC uses the Description; you can put a short line:
```
First release of beeWatch — log your Beeminder goals from your wrist, with urgency-sorted goals, one-tap entry, smart reminders, and watch-face complications.
```
(Keep this file's git history updated per release; see the per-release template
at the bottom.)

---

## 3. URLs (required / recommended)

| Field | Value | Status |
|---|---|---|
| **Support URL** (required) | e.g. `https://giovannicoppola.github.io/beeWatch/` | ⚠️ ACTION — you have a `docs/` GitHub Pages site; confirm it has a support/contact section, or add one. |
| **Marketing URL** (optional) | same as above or a dedicated page | Optional. |
| **Privacy Policy URL** (required) | host `AppStore/PrivacyPolicy.md` content as a web page | ⚠️ ACTION — publish the included privacy policy and paste its URL. |

A ready-to-publish policy is in `AppStore/PrivacyPolicy.md`. The simplest path:
drop it into your existing `docs/` Jekyll site (rename to `privacy.md` with front
matter) so it's served at `…/privacy`.

---

## 4. App Privacy ("nutrition label")

beeWatch has **no backend of its own** and (as currently written) **no analytics
or third-party tracking SDKs**. All data the user enters is sent directly to
Beeminder at the user's request; the API key is stored on device and synced
between the user's own iPhone and Watch via Apple's WatchConnectivity.

**Recommended answers** (verify before you certify — this is a legal attestation):

- **Do you or your third-party partners collect data from this app?** → **No,
  we do not collect data from this app.**
  - Rationale: you don't receive or process the data on your own servers; there
    are no analytics/ad SDKs. The data flows only between the user and Beeminder.

> ⚠️ ACTION — This "No collection" answer is only correct while there is **no**
> analytics/crash-reporting/ads SDK in the app. If you add Firebase, Sentry,
> TelemetryDeck, etc., you must update these answers (typically: Identifiers,
> Usage Data, Diagnostics; "not linked", "not used for tracking").

If a reviewer pushes back because the app transmits user content to Beeminder,
the accurate framing is: *data is transmitted to a third-party service (Beeminder)
solely to provide the core functionality, at the user's direction, and is not
collected by the developer.*

---

## 5. App Review Information

| Field | Value |
|---|---|
| **Sign-in required?** | Yes — the app needs a Beeminder API key. |
| **Demo account** | ⚠️ ACTION — create a **dedicated demo Beeminder account** with a few sample goals and provide its **username + API key** here. **Do NOT use your personal key.** |
| **Contact** | Your name, email, phone (for the review team). |
| **Notes** | Use the block below. |

### Review notes (paste into "Notes")
```
beeWatch is a third-party client for Beeminder (https://www.beeminder.com), a goal-tracking service. It is not affiliated with Beeminder Corp.

To test:
1. Launch the iPhone app, open Settings, and paste the demo API key provided above (the app links to beeminder.com/api/v1/auth_token.json where a real user finds theirs). The key then syncs to the paired Apple Watch automatically.
   - Alternatively, enter the same API key directly in the Apple Watch app's Settings screen; the watch works independently of the phone.
2. The goal list loads, sorted by urgency. Tap a goal to view details and recent entries.
3. Tap a quick-entry value, confirm, and the datapoint is sent to Beeminder; the list refreshes.
4. Complications: on the watch, long-press the face → Edit → add a beeWatch complication (e.g. "Most Urgent Goal") to see live buffer/time-to-derail.

Demo account username: <DEMO_USERNAME>
Demo API key: <DEMO_API_KEY>
```

---

## 6. Build, compliance & signing

| Item | Value / Action |
|---|---|
| **Export compliance** | App uses only standard HTTPS (Beeminder API over TLS). In Info.plist you can set `ITSAppUsesNonExemptEncryption = NO` to skip the per-build prompt. ⚠️ ACTION — add that key, or answer "No" to the "non-exempt encryption" question at upload. |
| **Bitcode** | N/A (deprecated). |
| **Signing** | Distribution certificate + App Store provisioning profiles for all three bundle IDs (app, watch app, complications extension). Xcode "Automatically manage signing" handles this. |
| **App group** | `group.com.beewatch` must be in the App IDs' capabilities for all targets (used for the complication cache). ⚠️ Verify it's registered on the portal. |
| **Upload** | Archive the **iOS app** scheme (the watch app + complications are embedded and go up in the same archive) → Distribute App → App Store Connect. |

---

## 7. Required assets & specs

### 7a. App icon (marketing)
- **1024 × 1024 px**, PNG or JPG, **no alpha channel, no transparency, no rounded
  corners** (Apple rounds it).
- Source art exists: `Gemini_Generated_Image_bwbopcbwbopcbwbo.png`. ⚠️ ACTION —
  export a flattened 1024² with no alpha. (The in-app icon set lives in
  `Assets.xcassets`; the 1024 marketing icon is uploaded/embedded via the asset
  catalog's App Icon "App Store" slot.)

### 7b. Screenshots — **the reality check**
App Store Connect has **two** screenshot sets for this app: **iPhone** and
**Apple Watch**. **There is no separate "complication" upload slot** — a
complication screenshot is just an Apple Watch screenshot that happens to show a
watch face with the complication on it. Include those in the Apple Watch set.

**Counts:** 1–10 images per set. Recommend **3–5** iPhone and **3–5** Apple Watch
(including 1–2 that show complications on a face).

**Dimensions (portrait; confirm current requirements in ASC as Apple revises them):**

| Set | Device to capture | Pixel size |
|---|---|---|
| iPhone (required) | iPhone 16 Pro Max / 6.9" | **1290 × 2796** (or 1320 × 2868) |
| iPhone (optional older) | iPhone 8 Plus / 6.5" | 1242 × 2688 |
| Apple Watch (required) | Ultra 2 / 49mm | **410 × 502** |
| Apple Watch (alt) | Series 10 / 46mm | 416 × 496 |

A single 6.9" iPhone set and a single 49mm watch set are enough — ASC scales them
to the smaller devices.

**Suggested shot list (what each image should show):**

iPhone:
1. Settings screen with the API-key field + the "success / switch to your watch"
   confirmation (the phone app's main job).
2. The green success checkmark after a successful key entry / sync.
3. (If the phone shows goals) the goal list — otherwise skip.

Apple Watch (this is the hero set — most shots should be here):
1. Goal list sorted by urgency (mix of green/blue/orange, one 💀 or red).
2. Goal detail with the large quick-entry buttons.
3. The confirmation dialog ("Log 20?").
4. The "Logged!" success overlay.
5. **Complication shot** — a watch face with the Rectangular complication showing
   a goal + time-to-derail, and/or the Circular gauge. (See capture plan below.)

### 7c. App previews (optional video)
Not required. Skip for 1.0.

---

## 8. How to actually capture the screenshots

I can't produce store-ready, *real* screenshots autonomously in this environment
because the app needs a configured account (live Beeminder data) and, for
complications, a watch face that has the complication added — which the simulator
doesn't let you script. Fabricating UI images and passing them off as real
screenshots would also violate App Store Review Guideline 2.3.3. So here's the
reliable path:

**Simulator route (fastest, no device needed):**
1. Boot simulators:
   ```
   xcrun simctl boot "iPhone 16 Pro Max"
   xcrun simctl boot "Apple Watch Ultra 2 (49mm)"
   ```
2. Build & run each scheme from Xcode onto those simulators.
3. Configure the app once (paste the demo API key) so real goals load.
4. Navigate to each screen in the shot list and capture:
   ```
   xcrun simctl io booted screenshot ~/Desktop/shot.png
   ```
   (Targets the focused simulator; run per device.)
5. **Complications on the simulator:** in the watch simulator, click the Digital
   Crown → long-press the face → **Edit** → add the beeWatch complication, then
   screenshot the face. This is a manual UI step.

**Device route (best-looking, needed for a real watch face):** run on your own
Apple Watch, set up the complication on your real face, and use the Watch's
screenshot (enable in Settings → General → Screenshots; press Crown + side
button). AirDrop to Mac.

Either way, drop the finished PNGs into `AppStore/screenshots/iphone/` and
`AppStore/screenshots/watch/` (folders created for you), then upload to ASC.

> Want me to drive the simulator capture for the app screens (list, detail,
> confirm, success)? I can attempt it if you first paste a demo API key into a
> booted simulator — but the **complication-on-a-face** shots realistically need
> your device or the manual Edit-face step above.

---

## 9. Pre-submission checklist

- [ ] App icon 1024² (no alpha) exported and set in the asset catalog
- [ ] iPhone screenshots (≥1, 6.9")
- [ ] Apple Watch screenshots (≥1), including complication-on-face shot(s)
- [ ] Name / subtitle / promo / description / keywords pasted
- [ ] Support URL live
- [ ] Privacy Policy URL live (see `PrivacyPolicy.md`)
- [ ] App Privacy answers completed (see §4)
- [ ] Demo Beeminder account created; username + key in Review Notes
- [ ] Export compliance handled (`ITSAppUsesNonExemptEncryption = NO`)
- [ ] App group `group.com.beewatch` registered for all targets
- [ ] Build 1.0 (1) uploaded and attached to the version
- [ ] Age rating questionnaire answered (all "None" → 4+)
- [ ] Price set (Free)

---

## Trademark & rights
- "Beeminder" is a trademark of **Beeminder Corp.** Using "for Beeminder" as a
  descriptor is generally acceptable nominative use, but do not imply affiliation
  or use their logo/branding. The non-affiliation line is included in the
  description and review notes.
- Consider a courtesy heads-up to Beeminder (they're developer-friendly and have
  an API/third-party-app policy) to avoid any dispute.

## Per-release "What's New" template
```
vX.Y
• <headline change>
• <fix/improvement>
Thanks for using beeWatch! Questions or bugs: <support email>.
```
