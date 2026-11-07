# App Store readiness audit — LUMEN: Orbital Conquest

Date of this audit: 7 November 2026. Repository revision audited before these changes: `e8539e9` (service worker `lumen-v25`).

This audit does not say the app will be approved. Placeholder configuration, unpublished rules, and missing device tests are called out as not compliant.

## Sources read on 7 November 2026

- App Review Guidelines, <https://developer.apple.com/app-store/review/guidelines/>. Apple’s news post says this revision was published on 16 October 2026: <https://developer.apple.com/news/?id=92th7e5i>.
- Privacy manifest files, <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>.
- TN3183, required-reason APIs, <https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest>.
- Firebase “Authenticate Using Apple” for the web SDK, including token revocation with `revokeAccessToken`, <https://firebase.google.com/docs/auth/web/apple>.
- Firebase iOS `RevokeTokenRequest.swift`, which sends `tokenType` `"3"` (authorization code) to Identity Toolkit `v2/accounts:revokeToken`. Retrieved from the firebase-ios-sdk main branch on 7 November 2026.
- TN3194, account deletion and Sign in with Apple revocation, <https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple>. The page title was retrieved; the body did not come back as extractable text in this environment.
- Sign in with Apple Human Interface Guidelines, <https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple>. The page title was retrieved; the body did not come back as extractable text. The iOS screen uses the system `SignInWithAppleButton`. The web button uses the words “Sign in with Apple”, a black button at least 44 points tall, and sits above the Google button at the same width.

## What the repository actually is

One HTML file (`index.html`), a service worker, icons, a web manifest, and Firestore rules. There was no Xcode project, Info.plist, entitlement file, or privacy manifest.

Observed behavior:

- Campaign, skirmish, daily challenge, friendly rooms, and ranked play. Friendly rooms use PeerJS and WebRTC. Messages are lobby state and move commands. The only `msg` payloads found are fixed host strings such as a disconnection notice. There is no text field for player chat.
- Optional Google sign-in through Firebase Auth. Project id `lumon-4397e`. The client config is embedded in `index.html`.
- Cloud save at `users/{uid}` with a fixed field list in `firestore.rules`.
- Daily leaderboard names and times are world-readable. The old code posted `displayName` or the part of the email before `@`.
- Ratings and matchmaking tickets, including the name, are readable by any signed-in player.
- No payment code, no StoreKit, no Stripe, no advertising SDK, no Analytics SDK, and no IDFA API.
- Clipboard write and the system share sheet are used only when the player taps Share or Copy for a room invite. Battery status is read locally when the browser offers it. No camera, microphone, photo library, contacts, location, notification, or tracking permission is requested.

## Guideline-by-guideline

### 5.1 Privacy, tracking, and purpose strings

Not a tracking app. `NSPrivacyTracking` is false. There is no `NSUserTrackingUsageDescription` and the Swift target does not link App Tracking Transparency. ATT is not applicable. Adding an ATT prompt would ask for permission the game does not use.

No purpose strings were added. The app does not call a protected API that requires one. Share and copy are user-initiated. That is intentional.

The privacy manifest declares name, email, user id, gameplay content, and other user content (the posted public name), each linked to the account, not used for tracking, and used for app functionality. Required-reason API categories are an empty array. The Swift code does not call UserDefaults, disk-space, file-timestamp, boot-time, or active-keyboard APIs. System frameworks are not declared here.

The in-app privacy text is a draft. The public URL is `https://example.com/REPLACE_ME/lumen-privacy`. The button does not open a placeholder URL. Guideline 5.1.1(i) is not met until a real policy is hosted and entered in the app and in App Store Connect.

### 5.1.1(v) Account deletion and Sign in with Apple revocation

The game creates Firebase accounts, so in-app deletion is required. The control is real and fails closed:

- It first tries to delete a daily score or the rating. Live rules still say `allow delete: if false` for those collections. That call fails, and the function returns without deleting the Auth user or the cloud save.
- After someone publishes the rules in this repo, it deletes the owner’s daily rows it knows about, the rating, the queue ticket, the block document, remembered report ids, and the user save. It then reauthenticates. Apple revocation uses `revokeAccessToken` for the web popup access token, or the Identity Toolkit authorization-code request used by the Firebase iOS SDK for the native sheet. Google revocation posts the fresh access token to `https://oauth2.googleapis.com/revoke`. Then it calls `deleteUser`.
- If revocation fails after rows were removed, the message says the Auth user was kept. It does not say the account was deleted.
- The on-device campaign save is not wiped.

This is not compliant yet. The live rules block deletion, the Apple provider key is not in Firebase as part of this work, and reports filed from another device are not removed. TN3194 requires the Apple token to be revoked. That call cannot succeed until Firebase has the Apple private key.

### 4.8 Sign in with Apple

Google is a third-party login for the game’s own account. The exceptions in 4.8 (a client for a single third-party service, an enterprise account, and so on) do not apply. An equivalent login is required. The limit-data, hide-my-email, and no-advertising-interactions properties are what Sign in with Apple is for.

The title screen shows a black “Sign in with Apple” button above “Sign in with Google”, both at least 44 points tall and the same width. The native Account sheet uses the system button above a bordered Google button of the same height. Google in the iOS shell still uses the existing web popup, limited to an allowlisted set of Google, Firebase, and Apple hosts, and is not verified. If Apple’s provider is not enabled, the client shows that no account was created.

Not production-ready until the Firebase Apple provider and the Apple Developer App ID are configured.

### 1.2 User-generated content

Applicable to public names on the daily board and ranked records. Not applicable to chat, custom profiles, or creator mini-games. No chat controls were added.

Implemented:

- Names containing `@`, a URL, control characters, or a small on-device objectionable list are not posted. The public name falls back to the display name and then to “Player”. The email local-part is no longer posted.
- The public name is stored in its own localStorage key, not in the cloud save, so the existing `validSave` allow-list still accepts the save.
- Daily rows have Block and Report. Ranked has Block opponent and Report name after a human opponent id exists. Block hides the name locally and skips that id in matchmaking. Report writes a Firestore document and, if the write is denied, says the report was not stored. Block still applies locally.
- The terms draft forbids unlawful, hateful, harassing, and sexually explicit names.

Not met:

- No published contact method. The support URL is a placeholder. 1.2 asks for a way to reach the developer.
- No person is assigned to review reports, so “timely responses” is an operational gap, not something this code can claim.
- The name filter is client-side and short. The server, after the rules are published, only rejects `@`. A modified client can still post another string.
- A block is not a global ban.

### 3.1.1 Payments, StoreKit, and external purchase links

Not applicable. There is no digital product, currency, subscription, loot box, or paywall. StoreKit was not added. A Restore Purchases button would do nothing, so it was not added.

Guideline 3.1.1(a), as updated 16 October 2026, allows external purchase links on the United States storefront without the entitlement, and allows them on some other storefronts with a StoreKit External Purchase Link Entitlement. This project’s instruction is stricter: no external digital-payment links. None were added. Stripe and Link were not added.

### 4.2 Minimum functionality

The game itself is a full RTS: fifteen campaign sectors, skirmish, daily maps, friendly rooms for up to six players, and ranked play. That is lasting gameplay, not a brochure.

The iOS target is still a SwiftUI shell around that HTML game in a WebView. Native screens cover account, Sign in with Apple, deletion, privacy, and terms. The game files are bundled and served from `lumen-local://`, not loaded from a website. Guideline 4.2 says an app should be more than a repackaged website, and 4.2.2 rejects simple web clippings. A reviewer can still decide the native shell is incidental. This audit does not call the shell compliant with 4.2.

Guideline 2.5.2 says an app should not download code that changes its behavior. The website still loads Firebase and PeerJS from CDNs. The iOS shell vendors Firebase JS SDK 10.12.2 and PeerJS 1.5.5, with the Firebase import rewritten to a relative path, so those libraries are in the bundle. Network calls after that are account, database, and matchmaking traffic, not those scripts. This was not executed in a simulator, so the module load is not proven.

### 4.7, Kids Category, safe area

4.7 is about software that is not embedded in the binary. The game page is an app resource. 4.7 is not the main path. It would become relevant if the shell started offering a catalog of remote games.

Kids Category (1.3 and 5.1.4) is not applicable as a target. Do not select it. Google sign-in, public names, and third-party connection services conflict with that category. The age rating questionnaire is a human step. The repo has cartoon fleet combat and no chat.

The web layout already uses `viewport-fit=cover` and `safe-area-inset`. The WebView is edge to edge so those insets can apply. The native Account button sits in the SwiftUI safe area and hides during play so it does not cover Pause and Mute. No Live Activity was added, so there is no Dynamic Island presentation to review. None of this was checked on a device.

### Permissions at launch

No permission prompt is shown at launch. Sign in with Apple appears when the player taps the button. Deletion asks for confirmation and then, only if the rules allow the data delete, asks the provider to reauthenticate.

## Resolved in this change

- iOS SwiftUI target, Info.plist, Sign in with Apple entitlement, privacy manifest, asset catalog, and a Release submission gate.
- Bundled game with a scheme handler that only serves the game files and the vendored scripts. Main-frame navigation off that scheme is cancelled. The sign-in popup is a separate visible WebView without a path that accepts bad TLS certificates.
- Sign in with Apple bridged into the existing Firebase web session. No second copy of the Firebase config and no Apple private key in the app.
- Account deletion that stops cleanly on today’s live rules and continues only when deletes are allowed.
- Public-name filter, local block, and report writes that admit failure.
- Draft privacy text and terms, with assumptions labeled and no invented contact details.
- Cloud save field allow-list left as it was, so existing saves still match the current rules.

## Still required before any claim of readiness

- Replace every `REPLACE_ME`, `example.com`, and `com.example` value. Confirm `sh scripts/appstore-readiness-check.sh --strict` exits 0.
- Apple Developer App ID, Team ID, signing, and the Firebase Apple provider with the private key stored in Firebase.
- Publish `firestore.rules` deliberately. Then test deletion, reports, and blocks against the live project.
- Host the privacy policy and terms. Put the real URL in the app and in App Store Connect. Provide a real support contact for 1.2.
- A person has to review reports. The code does not do that.
- On a Mac: compile, run on a notched iPhone and an iPad, VoiceOver the native sheets, Sign in with Apple, Google sign-in, deletion, and an archive. This environment did not do those steps.
- Replace the upscaled 1024 icon if you want a master that was drawn at that size. It was flattened from `icon-512.png` onto the game background because the source had an alpha channel.
