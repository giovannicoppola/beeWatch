#!/usr/bin/env bash
#
# Helper for capturing App Store screenshots in the simulators.
#
# What it automates: booting the right simulators, building, and installing.
# What it CANNOT automate: pasting your API key, navigating to each screen, and
# adding the complication to a watch face — those are manual UI steps (see
# AppStoreSubmission.md §8). Run the numbered functions as you go.
#
# Usage:
#   ./capture-screenshots.sh boot          # boot iPhone + Watch sims
#   ./capture-screenshots.sh build         # build & install the app
#   ./capture-screenshots.sh shot <name>   # screenshot the focused/last-booted sim
#   ./capture-screenshots.sh iphone <name> # screenshot the iPhone sim -> screenshots/iphone
#   ./capture-screenshots.sh watch <name>  # screenshot the Watch sim   -> screenshots/watch
#
set -euo pipefail

IPHONE="iPhone 16 Pro Max"                 # 6.9" -> 1290x2796
WATCH="Apple Watch Ultra 2 (49mm)"         # 49mm -> 410x502
SCHEME="beeWatch"                          # iOS scheme (embeds watch app + complications)
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(dirname "$HERE")/beeWatch.xcodeproj"

iphone_udid() { xcrun simctl list devices | grep -F "$IPHONE (" | head -1 | grep -oE '[0-9A-F-]{36}'; }
watch_udid()  { xcrun simctl list devices | grep -F "$WATCH ("  | head -1 | grep -oE '[0-9A-F-]{36}'; }

case "${1:-}" in
  boot)
    xcrun simctl boot "$(iphone_udid)" || true
    xcrun simctl boot "$(watch_udid)"  || true
    open -a Simulator
    echo "Booted. Open Xcode and Run the '$SCHEME' scheme onto '$IPHONE' to install."
    ;;
  build)
    xcodebuild -project "$PROJ" -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$IPHONE" build
    echo "Built. Install/run from Xcode for a live session with your API key."
    ;;
  iphone)
    out="$HERE/screenshots/iphone/${2:-shot}.png"
    xcrun simctl io "$(iphone_udid)" screenshot "$out" && echo "Saved $out"
    ;;
  watch)
    out="$HERE/screenshots/watch/${2:-shot}.png"
    xcrun simctl io "$(watch_udid)" screenshot "$out" && echo "Saved $out"
    ;;
  shot)
    out="$HERE/screenshots/${2:-shot}.png"
    xcrun simctl io booted screenshot "$out" && echo "Saved $out"
    ;;
  *)
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
    ;;
esac
