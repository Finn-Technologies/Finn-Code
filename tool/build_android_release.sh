#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
cd "$ROOT_DIR"

REGISTRANT=android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java

if [[ -f "$REGISTRANT" ]] && grep -q 'integration_test' "$REGISTRANT"; then
  print -u2 "Removing dev-only plugin registrant left by integration tests."
  find android/app/src/main/java/io/flutter/plugins -type f \
    -name GeneratedPluginRegistrant.java -delete
fi

flutter build apk --release

if [[ ! -f "$REGISTRANT" ]]; then
  print -u2 "Expected the production plugin registrant at $REGISTRANT."
  exit 1
fi

if grep -q 'integration_test' "$REGISTRANT"; then
  print -u2 "Release registrant still contains the dev-only integration_test plugin."
  exit 1
fi

APK=build/app/outputs/flutter-apk/app-release.apk
if [[ ! -f "$APK" ]]; then
  print -u2 "Expected release APK at $APK."
  exit 1
fi

print "Android release build passed: $APK"
