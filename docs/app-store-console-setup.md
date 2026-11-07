# Console steps still required

This file is a checklist for a person. Nothing here was run against the live Firebase project or Apple Developer account. Do not treat the iOS target as production-ready until every item is done and the readiness check is clean.

The readiness check fails on purpose today:

```sh
sh scripts/appstore-readiness-check.sh --strict
```

A Release build of `ios/Lumen.xcodeproj` runs that command and stops. Debug builds still open the game and show a “not submission-ready” banner.

## Apple Developer

1. Join the Apple Developer Program with the account that will publish the game.
2. Register a real bundle id. `com.example.lumen.orbitalconquest` in `ios/Config/AppStore.xcconfig` is a placeholder.
3. Enable Sign in with Apple for that App ID. The entitlement file already requests the Default Sign in with Apple capability.
4. Create a Sign in with Apple key (Key ID plus a `.p8` private key) and a Services ID if the website will use Apple’s web flow. Put the private key in the Firebase console only. Do not add it to the repository or the app binary.
5. Replace `LUMEN_DEVELOPMENT_TEAM` with the Team ID. Leave `DEVELOPMENT_TEAM` empty until Xcode signing is set up on a Mac, then set the real team so the app can be signed.
6. Host the privacy policy and terms on HTTPS addresses you control. Replace `LUMEN_PRIVACY_POLICY_URL`, `LUMEN_TERMS_URL`, and `LUMEN_SUPPORT_URL`. The same three placeholders are in `index.html` as `LUMEN_LINKS`. The in-app drafts in `docs/legal/` are not the published policy.
7. In App Store Connect, create the app, set the privacy policy URL, complete the age-rating questionnaire, the privacy nutrition labels, export compliance, and screenshots. `ITSAppUsesNonExemptEncryption` is false because the app uses ordinary HTTPS and CryptoKit’s SHA-256 for the Apple nonce, not a custom cipher. Confirm that answer yourself before you submit.
8. Do not submit from this tree while `scripts/appstore-readiness-check.sh --strict` fails.

## Firebase project `lumon-4397e`

The web client config is already in `index.html`. This work did not change it and did not deploy rules.

1. Authentication: Google is the provider the current web game uses. Also enable Apple. Enter the Services ID, Team ID, Key ID, and Apple private key in the OAuth code-flow section. Firebase’s own Apple guide requires that before `revokeAccessToken` can revoke an Apple token: <https://firebase.google.com/docs/auth/web/apple>.
2. Add the iOS bundle id to the Firebase project as an Apple app if Firebase asks for it. Do not commit a downloaded `GoogleService-Info.plist` unless you intend to. This shell signs in through the existing web SDK and does not embed a second config file.
3. Authorized domains: keep the website domain. The iOS shell does not load the game from a website; it loads the bundled page on `lumen-local://app/`.
4. Publish `firestore.rules` only when you mean to change production. The updated file lets an owner delete a rating and a daily score, lets a signed-in player create a report, and lets an owner store a block list. Until that publish, account deletion stops before it changes the account, and report writes fail. The game says so. Do not describe those features as live before the publish.
5. After publishing, delete a test account from the app and confirm the Auth user, `users/{uid}`, `ratings/{uid}`, `daily/{day}/scores/{uid}`, `queue/{uid}`, and `blocks/{uid}` are gone. Confirm an Apple account’s token revocation with Firebase’s Apple provider configured. If revocation fails, the client keeps the Auth user and says the cloud rows were already removed.

## What this Mac agent could not do

Xcode, a simulator, a signing certificate, and an Apple ID were not available. Do not describe the Swift target as compiled, signed, archived, or device-tested until a Mac does those steps.

On a Mac:

```sh
xcodebuild -project ios/Lumen.xcodeproj -scheme Lumen -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Then exercise Sign in with Apple, Google sign-in, a failed deletion before the rules publish, a successful deletion after it, a daily board report and block, ranked matchmaking skipping a blocked id, safe areas on a notched phone and an iPad, VoiceOver on the native Account sheet, and an archive only after the placeholders are gone.
