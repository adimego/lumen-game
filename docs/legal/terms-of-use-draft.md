# Terms draft for LUMEN: Orbital Conquest

**DRAFT. Not published terms. Not legal advice. No legal entity, address, or contact method is stated because none was in the repository.**

## The game

LUMEN: Orbital Conquest is a real-time strategy game. You can play the campaign and skirmishes on the device without an account. Cloud save, the daily leaderboard, and ranked play need a sign-in and a network connection. Friendly multiplayer needs a network connection and does not require an account.

## Names and conduct

If you post a public name, a daily time, or a ranked rating, you will not use a name that is unlawful, hateful, harassing, sexually explicit, or that publishes someone else’s private information. The game may replace a name with “Player” and may hide a player you block on your device. That filter is incomplete. It does not review the name on the server beyond rejecting an `@` sign after the rules are published.

There is no player chat. Do not use a name as a way to send a message.

Reports are stored for a person to review only after the Firestore rules are published. This build does not promise a response time, because no moderator and no contact address are configured. Publishing a real support URL is required before App Store submission. Guideline 1.2 expects players to be able to reach the developer.

## Fair play

Scores and ratings are sent by the game running on the player’s device. There is no server-side anti-cheat. A rating is not an official competition.

## Accounts

Sign in with Google is the current provider. Sign in with Apple is in the client and does nothing useful until Apple’s provider, Services ID, Team ID, and private key are saved in the Firebase console. The private key must not be put in the app.

You can delete the Firebase account from the game. Deletion is refused, and the account is left in place, when the live rules still forbid deleting ratings or daily scores. Read the privacy draft for what deletion does and does not remove.

## Purchases

The game does not sell digital or physical goods. There is no store, no restore-purchases control, and no link to an outside payment page. If that ever changes, digital purchases have to go through StoreKit inside the iOS app. This draft is not permission to add another payment method.

## The software

The game is provided as it runs today. This draft does not grant a license to copy the art or the code beyond playing the game. Multiplayer connectivity depends on third parties and can fail.

## Contact

Not configured.
