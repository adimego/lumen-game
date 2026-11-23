#!/bin/sh
# Static checks for the iOS scaffold. Does not compile, sign, or launch a simulator.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
python3 - "$ROOT" << 'PY'
import plistlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
errors = []

def load(path):
    return plistlib.loads(path.read_bytes())

info = load(root / "ios/Lumen/Info.plist")
privacy = load(root / "ios/Lumen/PrivacyInfo.xcprivacy")
ents = load(root / "ios/Lumen/Lumen.entitlements")

for key in info:
    if key.endswith("UsageDescription"):
        errors.append(f"Info.plist requests a permission it should not: {key}")
if "NSAppTransportSecurity" in info:
    errors.append("Info.plist weakens App Transport Security")
if info.get("ITSAppUsesNonExemptEncryption") is not False:
    errors.append("encryption export flag is missing or not false")
if privacy.get("NSPrivacyTracking") is not False:
    errors.append("privacy manifest says the app tracks")
if privacy.get("NSPrivacyTrackingDomains"):
    errors.append("privacy manifest lists tracking domains")
if privacy.get("NSPrivacyAccessedAPITypes"):
    errors.append("privacy manifest declares a required-reason API the app code does not call")
types = {item.get("NSPrivacyCollectedDataType") for item in privacy.get("NSPrivacyCollectedDataTypes", [])}
for required in (
    "NSPrivacyCollectedDataTypeName",
    "NSPrivacyCollectedDataTypeEmailAddress",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypeGameplayContent",
    "NSPrivacyCollectedDataTypeOtherUserContent",
):
    if required not in types:
        errors.append(f"privacy manifest missing {required}")
for item in privacy.get("NSPrivacyCollectedDataTypes", []):
    if item.get("NSPrivacyCollectedDataTypeTracking") is not False:
        errors.append("a collected data type is marked as tracking")
    purposes = item.get("NSPrivacyCollectedDataTypePurposes") or []
    if purposes != ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]:
        errors.append(f"unexpected purpose for {item.get('NSPrivacyCollectedDataType')}")

sign_in = ents.get("com.apple.developer.applesignin")
if sign_in != ["Default"]:
    errors.append(f"Sign in with Apple entitlement is {sign_in!r}")
for key in ents:
    if key != "com.apple.developer.applesignin":
        errors.append(f"unexpected entitlement {key}")

swift = "\n".join(path.read_text() for path in (root / "ios/Lumen").glob("*.swift"))
banned = [
    "NSAllowsArbitraryLoads",
    "ATTrackingManager",
    "ASIdentifierManager",
    "AppTrackingTransparency",
    "import StoreKit",
    "stripe",
    "Stripe",
    "serverTrust",
    "authenticationMethod",
]
for word in banned:
    if word in swift:
        errors.append(f"Swift contains {word}")
if swift.count("evaluateJavaScript") < 1:
    errors.append("expected a narrow JavaScript bridge")
if "message.body" in swift and "evaluateJavaScript" in swift.split("message.body")[0]:
    pass
if "window.__lumenNativeDeliver" not in swift:
    errors.append("native bridge deliver function is missing")
if "lumen-local://app/index.html" not in swift:
    errors.append("game is not loaded from the bundled scheme")
if "https://lumon" in swift or "load(URLRequest(url: URL(string: \"https:" in swift:
    errors.append("game web view loads a remote page")

vendor = (root / "ios/Vendor/firebase/firebase-auth.js").read_text()
if "https://www.gstatic.com/firebasejs" in vendor:
    errors.append("vendored Firebase auth still imports from gstatic")
if 'from"./firebase-app.js"' not in vendor:
    errors.append("vendored Firebase auth import was not rewritten")

html = (root / "index.html").read_text()
for needle in ("UGC_POLICY_START", "signInApple", "deleteAccount", "lumenBoardName", "Sign in with Apple"):
    if needle not in html:
        errors.append(f"index.html missing {needle}")
if ".split('@')" in html:
    errors.append("public name still falls back to the email local-part")
if "save.publicName" in html:
    errors.append("public name was added to the cloud save object")

rules = (root / "firestore.rules").read_text()
for needle in ("match /reports/", "match /blocks/", "allow delete: if isOwner(uid);"):
    if needle not in rules:
        errors.append(f"firestore.rules missing {needle}")
if "hasOnly(['v', 'save', 'updatedAt'])" not in rules:
    errors.append("cloud save rule shape changed")

icon = root / "ios/Lumen/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
data = icon.read_bytes()
if data[25] != 2:
    errors.append("app icon is not an opaque RGB PNG")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("native static check passed")
print("not compiled, not signed, not simulator-tested")
PY
