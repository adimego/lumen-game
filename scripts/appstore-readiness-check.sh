#!/bin/sh
# Checks published legal URLs and the bundle id.
# Apple Team ID is printed as MANUAL and does not fail this check: it is an
# account value Adam sets before archive. Release builds still refuse to look
# submission-ready in the app while that value is TODO_APPLE_TEAM_ID.
# --strict exits 1 when a legal URL or the bundle id is still a placeholder.
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
manual() {
  echo "MANUAL: $1"
}

PRIVACY='https://adimego.github.io/lumen-game/privacy.html'
TERMS='https://adimego.github.io/lumen-game/terms.html'
SUPPORT='https://adimego.github.io/lumen-game/support.html'
BUNDLE='com.adimego.lumen'

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
  echo "$expanded" | grep -Fq "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE" || note "bundle id is not $BUNDLE"
  echo "$expanded" | grep -Fq "LUMEN_PRIVACY_POLICY_URL = $PRIVACY" || note "privacy URL is not $PRIVACY"
  echo "$expanded" | grep -Fq "LUMEN_TERMS_URL = $TERMS" || note "terms URL is not $TERMS"
  echo "$expanded" | grep -Fq "LUMEN_SUPPORT_URL = $SUPPORT" || note "support URL is not $SUPPORT"
  echo "$expanded" | grep -Fq 'LUMEN_DEVELOPMENT_TEAM = TODO_APPLE_TEAM_ID' && manual "Apple Team ID is TODO_APPLE_TEAM_ID. Paste the 10-character Team ID into ios/Config/AppStore.xcconfig before archive."
  echo "$expanded" | grep -Fq 'LUMEN_DEVELOPMENT_TEAM = TODO_APPLE_TEAM_ID' || echo "$expanded" | grep -Eq 'LUMEN_DEVELOPMENT_TEAM = [A-Z0-9]{10}$' || note "Apple Team ID is missing and is not the labeled TODO_APPLE_TEAM_ID"
  grep -q 'LumenPrivacyPolicyURL' "$plist" || note "Info.plist has no privacy URL key"
  grep -q 'LUMEN: Orbital Conquest' "$plist" || note "Info.plist display name is not LUMEN: Orbital Conquest"
  grep -q '2026 Adam Lyons' "$plist" || note "Info.plist copyright is not 2026 Adam Lyons"
  grep -Fq "$PRIVACY" "$html" || note "index.html is missing the privacy URL"
  grep -Fq "$TERMS" "$html" || note "index.html is missing the terms URL"
  grep -Fq "$SUPPORT" "$html" || note "index.html is missing the support URL"
  grep -q 'REPLACE_ME' "$html" && note "index.html still contains REPLACE_ME"
  for page in privacy.html terms.html support.html; do
    if [ ! -f "$ROOT/$page" ]; then
      note "missing $page"
    elif ! grep -q 'Adam Lyons' "$ROOT/$page"; then
      note "$page does not name Adam Lyons"
    fi
  done
  grep -q 'github.com/adimego/lumen-game/issues' "$ROOT/support.html" || note "support.html does not link to GitHub Issues"
  grep -q 'gameNav' "$ROOT/sw.js" || note "service worker does not separate game navigations from legal pages"
fi

if [ "$fail" -eq 0 ]; then
  ok "legal URLs and bundle id are set. Team ID remains a manual Apple Developer step."
else
  echo "This tree still has placeholder legal URLs or a placeholder bundle id."
fi

if [ "$STRICT" -eq 1 ] && [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
