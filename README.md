# LUMEN: Orbital Conquest

## Cloud saves (optional Google sign-in)

Cloud saves are off until a Firebase web config is pasted into `index.html`
(search for `FIREBASE_CONFIG`; replace `null` with the config object from
Firebase console > Project settings > Your apps > Web app). With `null`, no account UI shows and no Firebase code loads.

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
