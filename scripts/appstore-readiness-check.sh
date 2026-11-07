#!/bin/sh
# Reports unresolved App Store placeholders.
# --strict exits 1 while any placeholder remains. Release archives use --strict.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
STRICT=0
if [ "${1:-}" = "--strict" ]; then
  STRICT=1
fi

fail=0
note() {
  echo "NOT READY: $1"
  fail=1
}
ok() {
  echo "OK: $1"
}

cfg="$ROOT/ios/Config/AppStore.xcconfig"
plist="$ROOT/ios/Lumen/Info.plist"
html="$ROOT/index.html"

if [ ! -f "$cfg" ] || [ ! -f "$plist" ] || [ ! -f "$html" ]; then
  note "missing App Store config, Info.plist, or index.html"
else
  expanded=$(sed 's/\$()//g' "$cfg")
  echo "$expanded" | grep -q 'REPLACE_ME' && note "ios/Config/AppStore.xcconfig still contains REPLACE_ME"
  echo "$expanded" | grep -q 'example.com' && note "ios/Config/AppStore.xcconfig still points at example.com"
  echo "$expanded" | grep -q 'com.example' && note "bundle id still uses com.example"
  echo "$expanded" | grep -q 'LUMEN_DEVELOPMENT_TEAM = REPLACE_ME' && note "Apple Team ID is REPLACE_ME"
  grep -q 'LumenPrivacyPolicyURL' "$plist" || note "Info.plist has no privacy URL key"
  grep -q 'REPLACE_ME/lumen-privacy' "$html" && note "the game page still has a placeholder privacy URL"
  grep -q 'REPLACE_ME/lumen-terms' "$html" && note "the game page still has a placeholder terms URL"
  grep -q 'REPLACE_ME/lumen-support' "$html" && note "the game page still has a placeholder support URL"
fi

if [ "$fail" -eq 0 ]; then
  ok "no submission placeholders found"
else
  echo "This tree is not submission-ready. Replace placeholders before an App Store archive."
fi

if [ "$STRICT" -eq 1 ] && [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
