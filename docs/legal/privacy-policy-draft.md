# Privacy draft for LUMEN: Orbital Conquest

**DRAFT. Not a published policy. Not legal advice. Do not host this file as the live policy and do not paste its placeholder URL into App Store Connect.**

Reviewed against the repository on 7 November 2026. A legal entity name, postal address, email address, and phone number were not in the repository. Those fields are left blank on purpose.

## Who this draft is about

Assumption, not verified: one independent developer publishes the game. Replace this sentence with the legal name of the publisher before publication.

The game is LUMEN: Orbital Conquest. The Firebase project id observed in the client config is `lumon-4397e`. That config is a client identifier already shipped in the web game. It is not a server secret. Security depends on Firebase Authentication and the Firestore rules.

## What is stored on the device

The browser or WebView keeps a local save under the key `lumen_save_v1`. It includes campaign progress, difficulty, audio and graphics settings, stats, achievements, cosmetics, and daily results. A separate key remembers whether a cloud save is waiting to upload.

These additional keys are not part of the cloud save document:

- a public leaderboard name, if you set one
- player ids you have blocked on this device
- whether you accepted the draft terms on this device
- ids of reports filed from this device, so account deletion can try to remove them

Firebase Authentication may also keep its session in IndexedDB. Firestore may keep a local cache.

If the browser exposes battery status, the game reads it only to reduce graphics. That value is not written to Firebase. iOS does not provide that API to the page.

## Account data

Signing in is optional. Offline campaign, skirmish, and local daily play work without an account.

If you sign in with Google, or with Apple once that provider is enabled, Firebase Authentication receives the account identifier, display name, email address, and profile-photo URL that the provider supplies. Apple can hide the email behind a private relay address. The title screen shows the display name, not the email. The profile photo is loaded from the provider URL and is not copied into the Firestore save.

The cloud save is the same progress document, stored at `users/{account id}`.

## Public and signed-in game records

If you post a daily time, Firestore stores your public name, the time, and a timestamp at `daily/{day}/scores/{account id}`. Those score documents are world-readable. Your email is not posted. Names that look like email addresses or match the on-device objectionable-name filter are replaced with “Player” before posting. A modified client can still bypass that filter. The server rule rejects a name containing `@` only after the updated rules are published.

Ranked play stores a rating document and a short-lived matchmaking ticket. Signed-in players can read ratings and tickets, including the public name. Friendly multiplayer rooms do not show that public name. Room slots say “You”, “Host”, or “Player”. Match traffic is structured moves, not free-form chat. The host can show fixed status text such as a disconnection notice. Players do not type messages to each other.

## Reports and blocks

Blocking a player hides that player’s leaderboard name on this device and skips that player in ranked matchmaking on this device. It is not a ban for everyone else. The block list can be copied to `blocks/{account id}` only after the updated rules are published. Until then the copy fails and the local block still works.

A report writes a document the client cannot read: reporter id, target id, context (`daily` or `ranked`), the reason `name`, a short snapshot of the name, and a timestamp. The write fails until the rules are published. The game does not claim the report was stored when the write fails. There is no moderation staff in this repository, and no support address to receive a report another way.

## Other services the game contacts

- Google Firebase Authentication and Cloud Firestore, for the account and the records above
- On the website only: the Firebase JavaScript SDK from `gstatic.com`, and the PeerJS library from jsDelivr or unpkg. The iOS shell bundles those scripts instead of downloading them.
- PeerJS public broker (the library default when no host is set) and STUN servers at Google and Cloudflare, so two devices can open a WebRTC match. Those services see network addresses as part of connecting the match.
- The identity provider’s profile-photo host, if a photo URL is present

No advertising SDK, analytics SDK, IDFA, or payment SDK is included. The game does not sell digital goods.

## Children

The repository does not market the game as being for children and does not ask for a birth date. Public names, Google sign-in, and third-party connection services make it a poor fit for the App Store Kids Category without a separate review. This draft does not claim compliance with children’s privacy statutes.

## Retention and deletion

Local progress stays on the device until you clear the site data or uninstall the app. Deleting the account does not erase that local campaign.

Account deletion, once the published rules allow it, deletes the cloud save, rating, daily score rows for days stored in the local save, the matchmaking ticket, the block document, and report ids remembered on this device. It then asks Firebase to revoke the Apple token, or asks Google to revoke the Google access token from a fresh sign-in, and deletes the Firebase account. If a step fails, the game says so and does not claim the account is gone.

Reports filed from another device, and daily rows for days no longer in the local save, are not deleted by this client. Ratings and daily scores cannot be deleted at all until someone publishes the rules in this repo. That publish has not been done from this work.

## Contact

Not configured. Do not invent an email address for this draft.
