# LUMEN: Orbital Conquest

## iOS App Store scaffold

`ios/Lumen.xcodeproj` is a SwiftUI shell around this game. It is not a signed App Store build. Read `docs/app-store-audit.md` and `docs/app-store-console-setup.md` before uploading anything. Release builds stop while the placeholder URLs and bundle id in `ios/Config/AppStore.xcconfig` remain. The drafts in `docs/legal/` are not a published privacy policy.

```sh
node tests/appstore-policy.test.mjs
sh scripts/native-static-check.sh
sh scripts/appstore-readiness-check.sh --strict
```

The last command exits 1 until a person replaces the placeholders. That is the submission gate.

## Cloud saves (optional Google sign-in)

The Firebase web config for project `lumon-4397e` is already in `index.html`. With that config, the account UI is shown and Firebase loads when the player signs in. Sign in with Apple is in the client and stays failed-closed until the Apple provider is enabled in the Firebase console.

Firebase setup:
1. Authentication > Sign-in method: enable **Google**.
2. Authentication > Settings > Authorized domains: add `adimego.github.io`.
3. Firestore Database: create it (production mode).

### Deploying the security rules
Either paste the contents of `firestore.rules` into Firebase console >
Firestore Database > Rules and press **Publish**, or with the CLI:

```
npm i -g firebase-tools && firebase login
firebase deploy --only firestore:rules --project <project-id>
```
(the CLI needs a `firebase.json` containing `{"firestore":{"rules":"firestore.rules"}}`).

The rules let a signed-in user read/write only `users/{their uid}`, with field and size limits on the save document.
