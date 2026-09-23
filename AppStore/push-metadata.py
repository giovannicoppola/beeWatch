#!/usr/bin/env python3
"""Push beeWatch's App Store metadata and screenshots to App Store Connect.

Reads the copy from AppStoreSubmission.md's sibling constants below and writes it
to the 1.0 version via the App Store Connect API.

The API cannot create an app record -- do that once in the ASC web UI (bundle ID
com.beewatch.ios), then run this.

Usage:
    python3 AppStore/push-metadata.py --issuer <ISSUER_ID>              # dry run
    python3 AppStore/push-metadata.py --issuer <ISSUER_ID> --apply      # write
    python3 AppStore/push-metadata.py --issuer <ISSUER_ID> --apply --screenshots

Requires: cryptography (already installed). The private key is read from
~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8 and never printed.
"""

import argparse
import hashlib
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEY_ID = "PCLQ5K922S"
BUNDLE_ID = "com.beewatch.ios"
VERSION_STRING = "1.0"
LOCALE = "en-US"
API = "https://api.appstoreconnect.apple.com"

REPO = Path(__file__).resolve().parent.parent
SHOTS = REPO / "AppStore" / "screenshots"

# ---------------------------------------------------------------- copy ------

NAME = "beeWatch for Beeminder"
SUBTITLE = "Beeminder goals on your wrist"

PROMOTIONAL_TEXT = (
    "Log your Beeminder goals in a single tap, right from your wrist. See what's "
    "due, get reminders only when it matters, and keep a live complication on "
    "your watch face."
)

KEYWORDS = "goal,goals,habit,tracker,quantified,akrasia,productivity,complication,streak,datapoint,log"

WHATS_NEW = (
    "First release of beeWatch — log your Beeminder goals from your wrist, "
    "with urgency-sorted goals, one-tap entry, smart reminders, and watch-face "
    "complications."
)

SUPPORT_URL = "https://giovannicoppola.github.io/beeWatch/support.html"
MARKETING_URL = "https://giovannicoppola.github.io/beeWatch/"

DESCRIPTION = """beeWatch puts your Beeminder goals on your wrist. Log data in seconds, see what's due at a glance, and stop derailing just because you forgot to check in.

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

Not affiliated with, endorsed by, or sponsored by Beeminder Corp. "Beeminder" is a trademark of Beeminder Corp."""

# Which ASC screenshot set each folder belongs to. If ASC rejects a display type
# it will say so plainly -- the enum moves as Apple adds device sizes.
SCREENSHOT_SETS = [
    ("iphone", "APP_IPHONE_67"),
    ("watch", "APP_WATCH_ULTRA"),
]

# ------------------------------------------------------------- plumbing -----


def make_token(issuer: str) -> str:
    """Mint an ES256 JWT for the ASC API. Never logs key material."""
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, utils as asym_utils
    import base64

    key_path = Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
    if not key_path.exists():
        sys.exit(f"private key not found at {key_path}")
    private_key = serialization.load_pem_private_key(key_path.read_bytes(), password=None)

    def b64(data: bytes) -> bytes:
        return base64.urlsafe_b64encode(data).rstrip(b"=")

    header = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    now = int(time.time())
    payload = b64(json.dumps({
        "iss": issuer,
        "iat": now,
        "exp": now + 900,
        "aud": "appstoreconnect-v1",
    }).encode())
    signing_input = header + b"." + payload

    der = private_key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = asym_utils.decode_dss_signature(der)
    raw = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return (signing_input + b"." + b64(raw)).decode()


class Client:
    def __init__(self, token: str):
        self.token = token

    def request(self, method, path, body=None, raw=None, content_type=None, base=None):
        url = path if path.startswith("http") else (base or API) + path
        data = raw if raw is not None else (json.dumps(body).encode() if body else None)
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        if content_type:
            req.add_header("Content-Type", content_type)
        elif body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as resp:
                payload = resp.read()
                return json.loads(payload) if payload and resp.status != 204 else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            try:
                errors = json.loads(detail).get("errors", [])
                detail = "\n".join(
                    f"  [{x.get('status')}] {x.get('title')}: {x.get('detail')}" for x in errors
                ) or detail
            except Exception:
                pass
            sys.exit(f"\n{method} {url}\nHTTP {e.code}\n{detail}\n")

    get = lambda self, p: self.request("GET", p)
    post = lambda self, p, b: self.request("POST", p, b)
    patch = lambda self, p, b: self.request("PATCH", p, b)


# ---------------------------------------------------------------- steps -----


def find_app(api: Client):
    apps = api.get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}").get("data", [])
    if not apps:
        sys.exit(
            f"No app found for bundle ID {BUNDLE_ID}.\n"
            "The ASC API cannot create app records -- create it once in the web UI\n"
            "(My Apps -> + -> New App), then re-run."
        )
    app = apps[0]
    print(f"  app: {app['attributes']['name']} ({app['id']})")
    return app["id"]


def ensure_version(api: Client, app_id: str, apply: bool):
    versions = api.get(f"/v1/apps/{app_id}/appStoreVersions?filter[versionString]={VERSION_STRING}").get("data", [])
    if versions:
        v = versions[0]
        print(f"  version {VERSION_STRING}: {v['id']} (state {v['attributes'].get('appStoreState')})")
        return v["id"]
    print(f"  version {VERSION_STRING}: does not exist -> would create")
    if not apply:
        return None
    created = api.post("/v1/appStoreVersions", {
        "data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": VERSION_STRING},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    })
    return created["data"]["id"]


def push_app_info(api: Client, app_id: str, apply: bool):
    """Name and subtitle live on appInfoLocalizations, not the version."""
    infos = api.get(f"/v1/apps/{app_id}/appInfos").get("data", [])
    if not infos:
        print("  ! no appInfos returned; skipping name/subtitle")
        return
    editable = None
    for info in infos:
        if info["attributes"].get("appStoreState") not in ("READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"):
            editable = info
            break
    info = editable or infos[0]
    locs = api.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations").get("data", [])
    loc = next((l for l in locs if l["attributes"]["locale"] == LOCALE), None)
    attrs = {"name": NAME, "subtitle": SUBTITLE}
    if loc:
        print(f"  name/subtitle -> patch {loc['id']}")
        if apply:
            api.patch(f"/v1/appInfoLocalizations/{loc['id']}",
                      {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": attrs}})
    else:
        print(f"  name/subtitle -> create {LOCALE}")
        if apply:
            api.post("/v1/appInfoLocalizations", {
                "data": {
                    "type": "appInfoLocalizations",
                    "attributes": {**attrs, "locale": LOCALE},
                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}},
                }
            })


def push_version_localization(api: Client, version_id: str, apply: bool):
    attrs = {
        "description": DESCRIPTION,
        "keywords": KEYWORDS,
        "promotionalText": PROMOTIONAL_TEXT,
        "whatsNew": WHATS_NEW,
        "supportUrl": SUPPORT_URL,
        "marketingUrl": MARKETING_URL,
    }
    locs = api.get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations").get("data", [])
    loc = next((l for l in locs if l["attributes"]["locale"] == LOCALE), None)
    for field, value in attrs.items():
        print(f"    {field}: {len(value)} chars")
    if loc:
        print(f"  localization -> patch {loc['id']}")
        if apply:
            api.patch(f"/v1/appStoreVersionLocalizations/{loc['id']}",
                      {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": attrs}})
        return loc["id"]
    print(f"  localization -> create {LOCALE}")
    if not apply:
        return None
    created = api.post("/v1/appStoreVersionLocalizations", {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {**attrs, "locale": LOCALE},
            "relationships": {
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
            },
        }
    })
    return created["data"]["id"]


def upload_screenshots(api: Client, loc_id: str, apply: bool):
    existing = api.get(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets").get("data", [])
    by_type = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in existing}

    for folder, display_type in SCREENSHOT_SETS:
        files = sorted((SHOTS / folder).glob("*.png"))
        if not files:
            print(f"  {folder}: no PNGs, skipping")
            continue
        print(f"  {folder} -> {display_type}: {len(files)} file(s)")
        if not apply:
            for f in files:
                print(f"      {f.name}")
            continue

        set_id = by_type.get(display_type)
        if not set_id:
            created = api.post("/v1/appScreenshotSets", {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {
                        "appStoreVersionLocalization": {
                            "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                        }
                    },
                }
            })
            set_id = created["data"]["id"]

        for f in files:
            blob = f.read_bytes()
            reserved = api.post("/v1/appScreenshots", {
                "data": {
                    "type": "appScreenshots",
                    "attributes": {"fileName": f.name, "fileSize": len(blob)},
                    "relationships": {
                        "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}
                    },
                }
            })
            shot_id = reserved["data"]["id"]
            for op in reserved["data"]["attributes"]["uploadOperations"]:
                chunk = blob[op["offset"]: op["offset"] + op["length"]]
                req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
                for h in op.get("requestHeaders", []):
                    req.add_header(h["name"], h["value"])
                with urllib.request.urlopen(req):
                    pass
            api.patch(f"/v1/appScreenshots/{shot_id}", {
                "data": {
                    "type": "appScreenshots",
                    "id": shot_id,
                    "attributes": {
                        "uploaded": True,
                        "sourceFileChecksum": hashlib.md5(blob).hexdigest(),
                    },
                }
            })
            print(f"      uploaded {f.name}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--issuer", required=True, help="ASC API Issuer ID (UUID)")
    ap.add_argument("--apply", action="store_true", help="actually write (default: dry run)")
    ap.add_argument("--screenshots", action="store_true", help="also upload screenshots")
    args = ap.parse_args()

    mode = "APPLY" if args.apply else "DRY RUN (nothing will be written)"
    print(f"\n=== beeWatch -> App Store Connect [{mode}] ===\n")

    api = Client(make_token(args.issuer))
    app_id = find_app(api)
    push_app_info(api, app_id, args.apply)
    version_id = ensure_version(api, app_id, args.apply)
    if version_id:
        loc_id = push_version_localization(api, version_id, args.apply)
        if args.screenshots and loc_id:
            upload_screenshots(api, loc_id, args.apply)
    else:
        print("  (dry run: no version id, skipping localization)")

    print("\nDone." + ("" if args.apply else "  Re-run with --apply to write."))


if __name__ == "__main__":
    main()
