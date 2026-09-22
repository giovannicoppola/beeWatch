# beeWatch — App Store Submission Package

Everything needed to submit **beeWatch** to the App Store. Copy the text fields
straight into App Store Connect. Items marked **⚠️ ACTION** still need something
from you; everything else is done and verified in the repo.

**Status (2026-09-22):** the build side is finished — a signed App Store IPA
containing all three bundles builds and exports cleanly from the command line
(see §6). What's left is human work: screenshots, a demo account, and pasting the
metadata into App Store Connect.

- **App name (internal):** beeWatch
- **Bundle ID (iOS app):** `com.beewatch.ios`
- **Bundle ID (watch app):** `com.beewatch.ios.watchkitapp`
- **Bundle ID (complications ext.):** `com.beewatch.ios.watchkitapp.complications`
- **Version / Build:** 1.0 / 2
- **Primary platform:** iOS + watchOS (Apple Watch app with WidgetKit complications)

> beeWatch is an independent, third-party client for **Beeminder**. The metadata
> below deliberately uses "for Beeminder" as a descriptor and includes a
> non-affiliation line. Do **not** use the Beeminder logo/bee mascot in a way
> that implies endorsement. See "Trademark & rights" at the bottom.

---

## 1. App information (static)

| Field | Value | Notes |
|---|---|---|
| **App Name** | `beeWatch for Beeminder` | 22/30 chars. **Chosen** — nominative use, helps people searching "Beeminder" find it. |
| **Subtitle** | `Beeminder goals on your wrist` | 29/30 chars. |
| **Primary category** | Productivity | |
| **Secondary category** | Health & Fitness | Optional; fits habit/goal tracking. |
| **Content rights** | Does **not** contain third-party content | You wrote all the code/copy. |
| **Age rating** | 4+ | No objectionable content. Answer "None" to all questionnaire items. |
| **Price** | Free | ⚠️ ACTION — confirm; set in Pricing. |
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
goal,goals,habit,tracker,quantified,akrasia,productivity,complication,streak,datapoint,log
```
(90 chars — count it after any edit; ASC counts commas.)
> "beeminder" was dropped from this list on purpose: it's now in the **app name**,
> and Apple indexes name and keywords separately — repeating it wastes characters.
> Same reason "beeWatch" and "wrist" aren't here. Avoid "watch"/"apple"
> (ignored/blocked).

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
| **Support URL** (required) | `https://giovannicoppola.github.io/beeWatch/support.html` | ✅ Written — `docs/support.html`. Goes live on the next push to the Pages branch. |
| **Marketing URL** (optional) | `https://giovannicoppola.github.io/beeWatch/` | ✅ Existing landing page. |
| **Privacy Policy URL** (required) | `https://giovannicoppola.github.io/beeWatch/privacy.html` | ✅ Written — `docs/privacy.html`. Goes live on the next push. |

Both pages are plain HTML reusing the site's `style.css`, linked from the landing
page's nav and footer. The support page's contact channel is **GitHub Issues**
(`github.com/giovannicoppola/beeWatch/issues`) — chosen over a personal email so
the address isn't published for scraping. Apple accepts an issue tracker as a
support channel, but the repo must stay **public** and you must actually answer
there.

`AppStore/PrivacyPolicy.md` is kept as the Markdown source of the same text —
edit it and `docs/privacy.html` together.

> ⚠️ ACTION — after pushing, confirm both URLs load over HTTPS before you submit.
> A dead support URL is a routine rejection.

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
| **Contact** | Your name, email, phone. This is private to the review team — unlike the public support URL, it's fine to give your real email here. |
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

All of this is **done and verified** — a signed App Store IPA has been built and
exported end to end.

| Item | Status |
|---|---|
| **Version / build** | 1.0 (2), identical across all three bundles. The watch app and complications used to hardcode `1.0`/`1` in their `Info.plist`, so bumping the build number in the project never reached them — they now read `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. A mismatch here is an automatic upload rejection. |
| **Export compliance** | ✅ `ITSAppUsesNonExemptEncryption = false` is present in all three built bundles (iOS via `INFOPLIST_KEY_…`, watch + complications in their plists). No per-upload prompt. |
| **Signing** | ✅ Archive + export succeed. All three bundles sign with **Apple Distribution: Giovanni Coppola (VDG762YNX9)** using the *iOS Team Store Provisioning Profile* for each bundle ID (valid to 2027-01-29). |
| **App group** | ✅ `group.com.beewatch` is registered on all three App IDs and present in the distribution entitlements of the watch app and the complications extension. |
| **App icon** | ✅ 1024×1024, no alpha, in all three asset catalogs; `CFBundleIconName` set in every built bundle. |
| **Upload** | Archive the **iOS app** scheme — the watch app and complications are embedded and go up in the same archive. |

### Build it yourself (verified commands)

```sh
cd ~/github/beeWatch

xcodebuild -project beeWatch.xcodeproj -scheme beeWatch -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/beeWatch.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive \
  -archivePath build/beeWatch.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist AppStore/ExportOptions.plist \
  -allowProvisioningUpdates
```

`-allowProvisioningUpdates` is required: it lets Xcode refresh the profiles. Without
it the archive fails, because the only Apple Development certificate in the local
keychain ("Created via API") isn't in the team development profiles. That doesn't
affect distribution — the export re-signs everything with Apple Distribution.

Then upload `build/export/beeWatch.ipa` with Xcode's Organizer, Transporter, or:

```sh
xcrun altool --upload-app -f build/export/beeWatch.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

**Bump the build number for every upload** — App Store Connect rejects a build
number it has already seen. It lives in `beeWatch.xcodeproj/project.pbxproj`
(`CURRENT_PROJECT_VERSION`, 6 occurrences) and `project.yml` (3 occurrences); keep
the two in sync, since `project.yml` is the XcodeGen source — they were verified
to agree by regenerating into a scratch copy. The watch Settings
screen shows the running version and build, which is the quick way to confirm the
watch is running the build you think it is.

## 7. Required assets & specs

### 7a. App icon (marketing)
- **1024 × 1024 px**, PNG or JPG, **no alpha channel, no transparency, no rounded
  corners** (Apple rounds it).
- ✅ **Done.** All three asset catalogs carry a flattened 1024² `AppIcon.png` with
  no alpha, and every built bundle has `CFBundleIconName` set. ASC picks the
  marketing icon up from the uploaded build — there's nothing to upload by hand.
- Source art: `Gemini_Generated_Image_bwbopcbwbopcbwbo.png` (that original *does*
  have an alpha channel — keep using the flattened copies in `Assets.xcassets`,
  not the source, anywhere Apple asks for an icon).

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

> Ask me to drive the simulator capture for the app screens (list, detail,
> confirm, success) once you've booted a simulator and pasted the **demo** API key
> into it — I can navigate and capture from there. The
> **complication-on-a-face** shots realistically need your own watch, or the
> manual Edit-face step above.

---

## 9. Pre-submission checklist

Done in the repo:

- [x] App icon 1024² (no alpha) in all three asset catalogs
- [x] Version/build consistent across all bundles — 1.0 (2)
- [x] Export compliance key (`ITSAppUsesNonExemptEncryption = false`) in all bundles
- [x] App group `group.com.beewatch` registered and in the distribution entitlements
- [x] Signed App Store IPA builds and exports from the command line (§6)
- [x] Privacy policy page written (`docs/privacy.html`)
- [x] Support page written (`docs/support.html`), linked from the landing page
- [x] App name, subtitle, description, keywords finalised (§1, §2)

Left to do — these need you:

- [ ] **Push the repo** so the Pages site publishes `/support.html` and `/privacy.html`; load both over HTTPS to confirm
- [ ] **Demo Beeminder account** — create one with a few sample goals; put its username + API key in Review Notes (§5). *Do not use your personal key.*
- [ ] **Screenshots** — ≥1 iPhone (6.9"), ≥1 Apple Watch, ideally including a complication-on-face shot (§7b, §8)
- [ ] Create the app record in App Store Connect and paste the §1/§2 metadata
- [ ] Answer App Privacy as "no data collected" (§4) and the age questionnaire (all "None" → 4+)
- [ ] Set price (Free)
- [ ] Upload build 1.0 (2) and attach it to the version
- [ ] Submit for review

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
