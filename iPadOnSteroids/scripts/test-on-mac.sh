#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo 'Run this script on a Mac with Xcode installed.' >&2
  exit 1
fi
if [[ -z "${SIMULATOR_ID:-}" ]]; then
  echo 'Choose an iPad simulator UUID from: xcrun simctl list devices available' >&2
  echo "Then run: SIMULATOR_ID='<UUID>' bash scripts/test-on-mac.sh" >&2
  exit 1
fi
xcodebuild -project iPadOnSteroids.xcodeproj -scheme iPadOnSteroids -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath .build test CODE_SIGNING_ALLOWED=NO
