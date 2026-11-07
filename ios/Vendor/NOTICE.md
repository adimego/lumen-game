Third-party code bundled with the iOS target so the app does not download these libraries at runtime.

- `firebase/` is Firebase JS SDK 10.12.2 (`firebase-app.js`, `firebase-auth.js`, `firebase-firestore.js`) from `https://www.gstatic.com/firebasejs/10.12.2/`. Copyright Google LLC. Apache License 2.0. The license header remains in each file. The absolute import of `firebase-app.js` was rewritten to `./firebase-app.js`. Logger name strings that embedded that same URL were rewritten with it. No other changes.
- `peerjs.min.js` is PeerJS 1.5.5 from `https://cdn.jsdelivr.net/npm/peerjs@1.5.5/dist/peerjs.min.js`. MIT License. The file matches the subresource hash already used by `index.html` (`sha384-x0YgkOr/3UOZP2CRDxGW9e0Q+2Qjyr3uJrm4xU32Y7ZCNAo7Cc7bjhrZMi/dwczu`).

The public website still loads Firebase and PeerJS from their CDNs. Only the iOS shell uses these copies.
