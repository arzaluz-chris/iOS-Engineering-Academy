---
id: m45-l04
title: Sign in with Apple and CloudKit
description: "Two Apple services that handle identity and data for you, each with rules you must follow. You add Sign in with Apple with ASAuthorizationAppleIDProvider or SignInWithAppleButton, keep the one-time name and email, check credential state at launch, and respect the private email relay. Then you choose CloudKit containers and databases, save records with optimistic locking, merge serverRecordChanged conflicts the way Apple prescribes, subscribe to changes, and see what CKSyncEngine (iOS 17) takes off your hands."
module: m45
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m45-l03, m31-l06, m42-l02]
objectives:
  - Implement Sign in with Apple, request name and email, and store them on the first authorization.
  - Check the credential state at launch and react to authorized, revoked, notFound and transferred.
  - Explain the private email relay and what the App Review Guidelines require of login and account deletion.
  - Describe CloudKit's containers, the public, private and shared databases, record zones, records and their limits.
  - Save records with the default save policy and resolve serverRecordChanged by merging into the server record.
  - Subscribe to database changes, and say what CKSyncEngine handles and what it leaves to you.
terms:
  - term: User identifier
    definition: "ASAuthorizationAppleIDCredential.user: a stable, opaque string that identifies the person for all apps of your developer team. Key your accounts on it, not on the email."
  - term: Credential state
    definition: "ASAuthorizationAppleIDProvider's answer for a stored user identifier: authorized, revoked (sign them out), notFound (no relationship yet) or transferred (the app moved to another team; migrate the identifier)."
  - term: Private email relay
    definition: "An address Apple generates when the person hides their email, ending in @privaterelay.appleid.com and similar domains. It forwards to the person's verified address, is the same across your team's apps, and only accepts mail from domains you register."
  - term: CKContainer
    definition: "The conduit to an app's iCloud data. Each container has a public database, and per person a private and a shared database. The default container's identifier is the bundle ID prefixed with iCloud."
  - term: Record change tag
    definition: "CKRecord.recordChangeTag: the server's version marker. A save with the default policy succeeds only if the record's tag matches the server's; otherwise the server returns serverRecordChanged."
  - term: CKSyncEngine
    definition: "A CloudKit class (iOS 17) that schedules sync for a private or shared database, sends your pending changes in batches, fetches remote changes, retries transient errors and hands you events. You persist its state and resolve conflicts."
mastery:
  - Write the SwiftUI sign-in flow that requests scopes, extracts the credential and treats cancellation as no error.
  - Merge sign-in responses so the first-time name and email are never overwritten with nil.
  - Choose the launch action for each credential state, and handle the revoked notification.
  - Pick the right database and subscription type for a feature, and say what needs an iCloud account.
  - Resolve a serverRecordChanged conflict with a three-way merge into the server record, and explain why merging into the client copy fails again.
  - Split pending changes into requests that respect the 250-record limit.
resources: [keychain-services, app-review-guidelines, swift-actor, swift-sendable, swiftdata]
cards:
  - id: m45-l04-c1
    front: When does Sign in with Apple give you the person's name and email?
    back: "Only the first time they authorize your app (or after they stop using Sign in with Apple with it and reconnect). Later sign-ins on any device return nil for them. Store them immediately; the email is also in the identity token."
  - id: m45-l04-c2
    front: What should an app do with each ASAuthorizationAppleIDProvider.CredentialState?
    back: "authorized: continue. revoked: sign out and clear local account data. notFound: show sign-in. transferred: the app moved to a different team; migrate the user identifier. Also observe credentialRevokedNotification."
  - id: m45-l04-c3
    front: Which CloudKit databases need an iCloud account?
    back: "The private and shared databases always do. The public database can be read without one, but writing to it needs an account so CloudKit can identify the author. Private data counts against the person's iCloud quota; public data against the app's."
  - id: m45-l04-c4
    front: How do you resolve CKError.serverRecordChanged?
    back: "The error carries the client, server and ancestor records. Merge your changes into the server record (it has the current change tag) and save that. Merging into the client or ancestor copy fails again with the old tag."
  - id: m45-l04-c5
    front: What does CKSyncEngine handle, and what is still your job?
    back: "It schedules sync, creates a database subscription, sends pending changes in batches (at most 250 records per request), fetches changes and retries transient errors. You persist its state serialization, provide records for batches, apply fetched changes, and resolve errors like serverRecordChanged."
---

## The idea in one sentence

Sign in with Apple gives you **a stable identity with as little personal data as the person chooses**, and CloudKit gives you **storage in the person's own iCloud account**; both work only if you respect what they hand you once, and what they refuse to do for you.

> [!note] Sources and what was checked
> From Apple's documentation, read in November 2026: "Implementing User Authentication with Sign in with Apple", `ASAuthorizationAppleIDProvider` and `credentialState(forUserID:)`, `CredentialState`, `ASAuthorizationAppleIDCredential` and its properties, `SignInWithAppleButton`, "Authenticating users with Sign in with Apple", "Communicating using the private email relay service", "Processing changes for Sign in with Apple accounts", "Transferring your apps and users to another team", the REST API's "Revoke tokens"; and for CloudKit "Deciding whether CloudKit is right for your app", "Enabling CloudKit in your app", `CKContainer`, `CKDatabase`, `CKRecord`, `recordChangeTag`, `CKError.Code.serverRecordChanged`, `CKSubscription`, `CKDatabaseSubscription`, `CKQuerySubscription`, `CKAccountStatus` and `CKSyncEngine`. App Review Guidelines 4.8 and 5.1.1(v). AuthenticationServices and CloudKit code is type-checked against the iOS SDK, not run; no account was signed in and no container was created. The account-merge, change-tag and batching models are plain Swift, compiled and run with Swift 6.3.

## Sign in with Apple

Pantry has accounts, so people can see orders on the web. It already offers "Continue with Google". Guideline **4.8 Login Services** then applies: an app that uses "a third-party or social login service ... to set up or authenticate the user's primary account" must "also offer as an equivalent option another login service" that "limits data collection to the user's name and email address," "allows users to keep their email address private," and "does not collect interactions with your app for advertising purposes without consent." Sign in with Apple has those properties, which is why most apps in Pantry's position add it. (4.8 lists exceptions, such as apps that use only the company's own account system.)

The capability comes first: Signing & Capabilities > + Capability > Sign in with Apple, which adds the `com.apple.developer.applesignin` entitlement (Apple's sample setup, quoted, not performed). Then the button. In SwiftUI, `SignInWithAppleButton` (iOS 14) builds the request and reports the result:

```swift ios
import AuthenticationServices
import SwiftUI

/// What Pantry's server needs from a successful sign-in.
struct AppleSignInResult: Sendable {
    let userID: String
    let givenName: String?
    let familyName: String?
    let email: String?
    let identityToken: String?
    let authorizationCode: String?
}

struct SignInView: View {
    let onSignedIn: (AppleSignInResult) -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { (request: ASAuthorizationAppleIDRequest) in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { (result: Result<ASAuthorization, any Error>) in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)

            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let signIn = AppleSignInResult(
                userID: credential.user,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName,
                email: credential.email,
                identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
                authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            )
            onSignedIn(signIn)
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
                return                                   // the person closed the sheet
            }
            errorMessage = "Sign in with Apple didn't complete. Try again."
        }
    }
}
```

- **Scopes are a request.** The person can edit their name, and choose "Hide My Email" in the sheet. You get what they decide.
- **`user`** is "an identifier for the authenticated user." Key Pantry's account on it, never on the email, which can be a relay address or change.
- **`identityToken`** is "a JSON Web Token (JWT) that securely communicates information about the user," and **`authorizationCode`** is "a short-lived token" proving the app may talk to the server on the person's behalf. Both are `Data` encoded as UTF-8. Send them to Pantry's server, which validates the token with Apple and exchanges the code for tokens. The device doesn't decide that someone is signed in; the server does.
- **`fullName` comes from the person, not Apple.** Its documentation: "Apple doesn't receive the user's full name shared with the system UI," and "to help prevent cross-site scripting attacks, validate and sanitize the user-submitted first and last name values before storing on your app servers."
- **Cancel isn't an error to show.** `ASAuthorizationError.canceled` means they closed the sheet.

In UIKit, Apple's sample does the same with `ASAuthorizationAppleIDProvider().createRequest()`, an `ASAuthorizationController`, its delegate and a presentation context provider. The sample also shows `performExistingAccountSetupFlows()`: on the login screen, asking for both an Apple ID and an iCloud Keychain password credential at once, so returning people can continue with one tap.

### Name and email arrive once

This is the rule that causes the most production bugs. From "Authenticating users with Sign in with Apple": the API "shares it with your app the first time the user logs in using Sign in with Apple. If the user then uses Sign in with Apple on another device, the API doesn't ask for the user's name or email again." The email stays available in the identity token, "but it doesn't include other information about the user, such as their name. When you receive user information from the API response, immediately store it locally so your app can access it again in the event of a process or network failure."

So account updates must **merge**, never overwrite:

```swift
/// Pantry's account record on its own server, keyed by the stable Sign in with Apple user identifier.
struct Account {
    var name: String?
    var email: String?
}

/// Name and email arrive only on the first authorization; later sign-ins carry nil.
/// Merge, never overwrite with nil.
func signIn(userID: String, name: String?, email: String?, accounts: inout [String: Account]) -> String {
    var account = accounts[userID] ?? Account()
    let isNew = accounts[userID] == nil
    if let name { account.name = name }
    if let email { account.email = email }
    accounts[userID] = account
    return (isNew ? "created " : "signed in ") + "\(account.name ?? "?") <\(account.email ?? "?")>"
}

var accounts: [String: Account] = [:]
let user = "001234.abcd.0420"
print(signIn(userID: user, name: "Ana Ruiz", email: "x7k2p9@privaterelay.appleid.com", accounts: &accounts))
print(signIn(userID: user, name: nil, email: nil, accounts: &accounts))        // second device
print(signIn(userID: "009999.ffff.0101", name: nil, email: nil, accounts: &accounts))
```

```output
created Ana Ruiz <x7k2p9@privaterelay.appleid.com>
signed in Ana Ruiz <x7k2p9@privaterelay.appleid.com>
created ? <?>
```

- **The second line** is the same person on their iPad: no name, no email, and the account keeps both. Code that did `account.name = name` would erase them.
- **The third line** is the failure Apple warns about: a first sign-in whose response was lost (the app crashed before reaching the server). The account exists with no name. Pantry saves the first response in the Keychain until the server confirms it (Module 42), and asks for a name in its own UI if it's still missing. For the email, the server reads it from the identity token.

### The private email relay

From "Communicating using the private email relay service": relay addresses "end in @private.icloud.com, @privaterelay.appleid.com, or @icloud.com," route to one of the person's verified addresses, and "are the same for a user across all apps written by a single development team." To send mail to them, "you must register your outbound emails or email domains and use Sender Policy Framework (SPF)." There's a cap: "Each private relay email address has a daily limit of 100 emails." And if the person turns forwarding off, "the relay server rejects all future emails sent to that address." Pantry's server also receives `email-disabled` and `email-enabled` notifications (and account deletion events) if it registers an endpoint, per "Processing changes for Sign in with Apple accounts."

Practical consequences: never require a "real" email after Sign in with Apple, don't treat a relay address as fake, and send order receipts from a registered domain.

### Checking the credential at launch

The person can stop using Sign in with Apple with Pantry at any time in Settings. Apple's sample "checks the status of the saved user credentials immediately after launch":

```swift ios
import AuthenticationServices

/// The state of the stored Apple user identifier. Errors count as "not found", which shows sign-in.
func appleCredentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
    do {
        return try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
    } catch {
        return .notFound
    }
}
```

The four states and what Pantry does with each, from their documentation:

```swift
enum CredentialState {
    case authorized, revoked, notFound, transferred
}

/// What Pantry does at launch for the stored Sign in with Apple user identifier.
func launchAction(for state: CredentialState) -> String {
    switch state {
    case .authorized:
        return "continue signed in"
    case .revoked:
        return "sign out, clear local account data, show sign-in"
    case .notFound:
        return "show sign-in"
    case .transferred:
        return "keep the session, migrate the user identifier on the server"
    }
}

for state in [CredentialState.authorized, .revoked, .notFound, .transferred] {
    print("\(state): \(launchAction(for: state))")
}
```

```output
authorized: continue signed in
revoked: sign out, clear local account data, show sign-in
notFound: show sign-in
transferred: keep the session, migrate the user identifier on the server
```

- **revoked**: "The given user's authorization has been revoked and they should be signed out."
- **notFound**: "The user hasn't established a relationship with Sign in with Apple."
- **transferred**: "The app has been transferred to a different team, and you need to migrate the user's identifier." User identifiers are team-scoped; after a transfer, the new team's server maps old to new through Apple's transfer identifiers.

While the app runs, `ASAuthorizationAppleIDProvider.credentialRevokedNotification` "indicates the user's credentials have been revoked and they should be signed out." Observe it from the session owner.

### Account deletion

Guideline 5.1.1(v): "If your app supports account creation, you must also offer account deletion within the app." For a Sign in with Apple account, Pantry's server deletes the person's data and revokes Apple's tokens with the REST API's revoke endpoint (`POST https://appleid.apple.com/auth/revoke` with the refresh or access token), which "invalidate[s] the tokens and associated user authorizations for a user when they are no longer associated with your app." The app calls Pantry's server; the server, which holds the tokens and the client secret, calls Apple.

## CloudKit

Pantry wants shopping lists to follow the person across their iPhone, iPad and Mac without Pantry storing them. That's CloudKit's job. Module 31 noted that SwiftData can sync through CloudKit for you; this section is what's underneath, for when you need control (custom conflict rules, sharing, or a store SwiftData doesn't cover).

### Containers, databases, zones, records

Setup, from "Enabling CloudKit in your app" (quoted, not performed): add the iCloud capability, select CloudKit, which "creates an iCloud container and adds the Push Notifications capability," named after the bundle identifier "prefixed with iCloud." "Once you've created a container, you can't delete or rename it." You need an iCloud account signed in on the simulator or device to save records.

- **`CKContainer`** is "a conduit to your app's databases." `CKContainer.default()` is the app's own.
- **Three databases.** `CKDatabase`'s overview: a **public** database "accessible to all users of your app," a **private** database "accessible only to the user of the current device," and a **shared** database with "records that other iCloud users share with them." The public one is readable without an iCloud account, but "CloudKit requires an iCloud account for writing to the public database so it can identify the authors of any changes. All access to the private and shared databases requires an iCloud account."
- **Quota.** "Data in the private database counts toward the user's iCloud storage quota." Public data counts toward the app's container quota.
- **Record zones** group records inside a database. Pantry uses a custom zone in the private database, because "the default record zone in the user's private database ... doesn't participate in database subscriptions."
- **`CKRecord`** is "a collection of key-value pairs." "The data that a record stores must not exceed 1 MB. Assets don't count toward this limit." In development you can add fields by saving them; in production, "the server returns an error if you try to specify an unknown record type or try to save a record that contains unknown keys." So the schema is deployed from development to production in CloudKit Dashboard before release.

Check the account before syncing. `CKContainer.accountStatus()` returns `.available`, `.noAccount`, `.restricted`, `.couldNotDetermine` or `.temporarilyUnavailable`; for the last one Apple says: "Don't delete any cached data and don't enqueue any CloudKit operations," and wait for the `CKAccountChanged` notification. Apple's guidance for no account at all: "design your app to run gracefully with or without an active iCloud account." Pantry keeps lists locally and syncs when it can, the offline-first shape from Module 37.

### Saving, and the conflict you must handle

Every saved record gets a new **change tag**. From `recordChangeTag`: "When you save your copy of the record, the server compares your record's token with the token on the server. If the two tokens match, the server interprets that you modified the latest version of the record and that it can apply your changes immediately. If the two tokens don't match, the server checks your app's save policy." The default save policy, `.ifServerRecordUnchanged`, then fails with `CKError.Code.serverRecordChanged`. That's the optimistic concurrency Module 31 described for your own server, built into CloudKit.

Apple tells you exactly what to do: the error carries three records, the client's, the server's and the ancestor (the version both started from), and "your app needs to merge all changes into the record for the `CKRecordChangedErrorServerRecordKey` key and attempt a new save using that record. Merging into either of the other two copies of the record results in another conflict error because those records have the old record change tag."

Here's that rule with a stand-in server, so you can watch the tags:

```swift
/// A CloudKit-like record: fields plus the change tag the server assigned to this version.
struct Record {
    var fields: [String: String]
    var changeTag: Int
}

enum SaveError: Error {
    case serverRecordChanged(server: Record)
}

/// The server's rule for the default save policy: accept a save only if it's based on
/// the current version (same change tag), then give it a new tag.
struct Server {
    private(set) var current = Record(fields: ["title": "Weekly shop", "store": "Sol", "note": ""], changeTag: 1)

    mutating func save(_ record: Record) throws -> Record {
        guard record.changeTag == current.changeTag else {
            throw SaveError.serverRecordChanged(server: current)
        }
        current = Record(fields: record.fields, changeTag: current.changeTag + 1)
        return current
    }
}

/// Three-way merge: start from the server's copy (it has the current tag) and apply the
/// fields this device changed since the ancestor, unless the server changed them too.
func merge(ancestor: Record, client: Record, server: Record) -> Record {
    var merged = server
    for (key, value) in client.fields where value != ancestor.fields[key] {
        if server.fields[key] == ancestor.fields[key] {
            merged.fields[key] = value                    // only this device changed it
        }                                                 // both changed it: the server's value stays
    }
    return merged
}

func show(_ record: Record) -> String {
    let fields = record.fields.keys.sorted().map { "\($0)=\(record.fields[$0]!)" }
    return "tag \(record.changeTag): " + fields.joined(separator: ", ")
}

var server = Server()
let ancestor = server.current                 // both devices fetched tag 1

var tablet = ancestor
tablet.fields["store"] = "Retiro"
tablet.fields["title"] = "Big weekly shop"
print("tablet saved", show(try server.save(tablet)))

var phone = ancestor
phone.fields["note"] = "Ring twice"
phone.fields["title"] = "Weekly shop + party"
do {
    _ = try server.save(phone)
} catch SaveError.serverRecordChanged(let serverRecord) {
    print("phone conflict, server has", show(serverRecord))

    do {
        _ = try server.save(merge(ancestor: ancestor, client: phone, server: phone))
    } catch {
        print("merging into the client copy fails again")
    }

    let merged = merge(ancestor: ancestor, client: phone, server: serverRecord)
    print("phone saved", show(try server.save(merged)))
}
```

```output
tablet saved tag 2: note=, store=Retiro, title=Big weekly shop
phone conflict, server has tag 2: note=, store=Retiro, title=Big weekly shop
merging into the client copy fails again
phone saved tag 3: note=Ring twice, store=Retiro, title=Big weekly shop
```

- **The phone's save fails** because it's based on tag 1 and the server is at tag 2.
- **Merging into the phone's own copy fails again**: same content rules, but still tag 1. This is the mistake Apple's documentation warns about.
- **Merging into the server's copy works**: the phone's note (only the phone changed it) goes in, the tablet's store stays, and the title, changed on both, keeps the server's value. That last choice is a per-field policy; Module 31's conflict strategies (sets merge, progress takes the max, text needs a rule) apply unchanged.

The same logic with real `CKRecord`s:

```swift ios
import CloudKit

enum ListSyncError: Error {
    case missingResult
}

/// Copies fields this device changed since `ancestor` into `server`, unless the server changed them too.
func mergeChanges(from local: CKRecord, ancestor: CKRecord, into server: CKRecord, keys: [String]) {
    for key in keys {
        let localValue = local[key] as? String
        let ancestorValue = ancestor[key] as? String
        let serverValue = server[key] as? String
        guard localValue != ancestorValue, serverValue == ancestorValue else { continue }
        if let localValue {
            server[key] = localValue
        } else {
            server[key] = nil
        }
    }
}

/// Saves a shopping list record, merging once if another device saved it first.
func saveList(_ record: CKRecord, ancestor: CKRecord, in database: CKDatabase) async throws -> CKRecord {
    let (results, _) = try await database.modifyRecords(saving: [record], deleting: [])
    guard let result = results[record.recordID] else { throw ListSyncError.missingResult }
    switch result {
    case .success(let saved):
        return saved
    case .failure(let error):
        guard let ckError = error as? CKError,
              ckError.code == .serverRecordChanged,
              let serverRecord = ckError.serverRecord else {
            throw error
        }
        mergeChanges(from: record, ancestor: ancestor, into: serverRecord, keys: ["title", "store", "note"])
        let (retryResults, _) = try await database.modifyRecords(saving: [serverRecord], deleting: [])
        guard let retry = retryResults[serverRecord.recordID] else { throw ListSyncError.missingResult }
        return try retry.get()
    }
}

/// True when the person's iCloud account can be used for the private database.
func iCloudIsAvailable(_ container: CKContainer) async -> Bool {
    (try? await container.accountStatus()) == .available
}
```

`modifyRecords(saving:deleting:savePolicy:atomically:)` defaults to `.ifServerRecordUnchanged`, the policy that detects conflicts. `.changedKeys` and `.allKeys` overwrite instead; with them, the last device to save silently wins, which is the "client wins" strategy Module 31 showed losing data. A second conflict on the retry is possible if a third device saved in between; production code loops a few times with the newest server record.

### Subscriptions

To learn about changes from other devices, save a subscription; when records change, CloudKit "sends push notifications to all devices with that subscription except for the one that makes the original changes." The types, from their pages:

| Subscription | Watches | Databases |
| --- | --- | --- |
| `CKDatabaseSubscription` | Any change in the database's custom zones | Private and shared only |
| `CKQuerySubscription` | Records of one type matching a predicate | Public and private only |
| `CKRecordZoneSubscription` | Changes in one zone | Private only |

For silent pushes, set `notificationInfo.shouldSendContentAvailable = true` and enable the Background fetch and Remote notifications modes. Apple's guidance on handling them: "Because the system coalesces notifications, don't rely on them for specific changes. ... Consider notifications an indication of remote changes," then fetch changes since your last server change token. Create subscriptions once ("record that state on-device") and in development first: "Attempting to create a subscription directly in the production environment results in an error."

```swift ios
import CloudKit

/// Run once (remember success in UserDefaults). The zone must be a custom zone.
func subscribeToListChanges(in database: CKDatabase) async throws {
    let subscription = CKDatabaseSubscription(subscriptionID: "shopping-list-changes")
    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true      // silent push, no permission prompt
    subscription.notificationInfo = notificationInfo
    _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
}
```

### CKSyncEngine

Fetching changes with tokens, sending changes in batches, retrying on network errors and rate limits, keeping a subscription: that's a lot of code every CloudKit app writes. `CKSyncEngine` (iOS 17) does it. From its documentation: create one "early in your app's launch process and specify a database to sync"; it "periodically pushes and pulls database and record zone changes"; it creates a `CKDatabaseSubscription` if none exists; and it retries transient errors itself (`networkFailure`, `networkUnavailable`, `requestRateLimited`, `zoneBusy` and others).

What it leaves to you:

- **Its state.** "It's your responsibility to persist that state to disk and make it available across app launches." The engine sends a `stateUpdate` event; you save the serialization and pass it back next launch.
- **Your records.** You tell it what changed (`state.add(pendingRecordZoneChanges:)`), and it asks for the actual records batch by batch. "Each batch is bounded by the server's per-request limit of 250 records (saves plus deletes combined)."
- **Conflicts.** "If you try to save a record and get a `serverRecordChanged`, you need to handle that error yourself."
- **Scope.** It needs the CloudKit and Remote notifications entitlements, and: "Don't use `CKSyncEngine` to sync your app's public database."

A skeleton of Pantry's engine owner. It keeps records in memory to stay short; the real one reads and writes the local store:

```swift ios
import CloudKit

actor ShoppingListSync: CKSyncEngineDelegate {
    private var engine: CKSyncEngine?
    private var records: [CKRecord.ID: CKRecord] = [:]                  // stands in for the local store
    private var savedState: CKSyncEngine.State.Serialization?            // persisted to disk in the app

    func start(database: CKDatabase) {
        guard engine == nil else { return }
        let configuration = CKSyncEngine.Configuration(database: database, stateSerialization: savedState, delegate: self)
        engine = CKSyncEngine(configuration)
    }

    func listChanged(_ record: CKRecord) {
        records[record.recordID] = record
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            savedState = update.stateSerialization
        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications {
                records[modification.record.recordID] = modification.record
            }
        case .sentRecordZoneChanges(let sent):
            for failure in sent.failedRecordSaves where failure.error.code == .serverRecordChanged {
                if let serverRecord = failure.error.serverRecord {
                    // Merge the local edits into serverRecord here, then save it as pending again.
                    records[serverRecord.recordID] = serverRecord
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(serverRecord.recordID)])
                }
            }
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        let snapshot = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { (recordID: CKRecord.ID) -> CKRecord? in
            snapshot[recordID]
        }
    }
}
```

- **An actor** satisfies the delegate's `Sendable` requirement and serializes access to the local records; the engine calls its async methods from its own tasks.
- **`RecordZoneChangeBatch(pendingChanges:recordProvider:)`** "walks your pending changes in order and stops once the batch is full," so the 250 limit takes care of itself. The filter by `context.options.scope` is required: "Returning changes outside that scope causes the send to fail with `invalidArguments`."
- **The conflict branch** is where `mergeChanges` from the previous section goes. As written, the server's version simply wins, a placeholder you replace with the merge.

If you batch requests yourself (without the engine), the solve exercise is the splitting you need.

## Common mistakes

> [!error] Overwriting the name and email on later sign-ins
> They come only the first time. Merge; never assign nil over a stored value.

> [!error] Keying accounts on the email
> Relay addresses, hidden emails and changed addresses break it. Use the `user` identifier.

> [!error] Never checking credential state
> A person who revoked Pantry in Settings stays signed in on the device. Check at launch and observe `credentialRevokedNotification`.

> [!error] No in-app account deletion
> Guideline 5.1.1(v) requires it for apps with account creation. For Sign in with Apple, also revoke the tokens on the server.

> [!error] Resolving serverRecordChanged with .allKeys
> It makes the error go away by discarding the other device's changes. Merge into the server record instead.

> [!error] Merging into the client record
> It still has the old change tag, so the save fails again.

> [!error] Treating a silent push as the data
> Notifications are coalesced and payloads trimmed. A notification means "fetch changes," nothing more.

## Exercises

````exercise
id: m45-l04-e1
type: prediction
prompt: "Two devices start from the same change tag. What does this print?"
code: |
  struct Server {
      var title = "Groceries"
      var changeTag = 7

      /// Returns the new change tag, or nil when the save is based on an old version.
      mutating func save(title newTitle: String, basedOn tag: Int) -> Int? {
          guard tag == changeTag else { return nil }
          title = newTitle
          changeTag += 1
          return changeTag
      }
  }

  var server = Server()
  let phoneTag = server.changeTag
  let tabletTag = server.changeTag
  print(server.save(title: "Party", basedOn: tabletTag) ?? -1)
  print(server.save(title: "BBQ", basedOn: phoneTag) ?? -1)
  print(server.save(title: "BBQ", basedOn: server.changeTag) ?? -1)
  print(server.title, server.changeTag)
output: |
  8
  -1
  9
  BBQ 9
hints:
  - "Both devices read tag 7 before either saved."
  - "The third save is based on whatever the server holds at that moment."
solution: |
  ```output
  8
  -1
  9
  BBQ 9
  ```

  - The tablet saves first, based on tag 7, which matches: the title becomes "Party" and the tag 8.
  - The phone's save is based on 7, but the server is at 8: rejected. That's `serverRecordChanged`.
  - The third save is based on the current tag, so it succeeds, but notice what it did: it replaced "Party" without looking at it. Basing a save on the server's tag without merging is the `.allKeys` overwrite in disguise. The right retry merges the phone's change into the server's record.
````

````exercise
id: m45-l04-e2
type: comprehension
prompt: "A person signed in to Pantry with Apple on their iPhone a year ago. Today they sign in on a new iPad. What does the credential contain?"
choices:
  - text: "The same user identifier, and nil for fullName and email."
    correct: true
    why: "Name and email are shared only the first time; on another device the API doesn't ask again. The identifier is stable for your team."
  - text: "A new user identifier for the new device, with name and email."
    correct: false
    why: "The identifier is per person and team, not per device."
  - text: "The same identifier, name and email as the first time."
    correct: false
    why: "Apple: 'If the user then uses Sign in with Apple on another device, the API doesn't ask for the user's name or email again.'"
  - text: "Nothing, because Sign in with Apple only works on the first device."
    correct: false
    why: "It works on every device signed in with that Apple Account."
solution: |
  The `user` identifier is the same, so Pantry's server finds the existing account. `fullName` and `email` are nil, which is why the server must keep the values it stored the first time, and never overwrite them with nil. The email is still available in the identity token if the server needs it.
````

````exercise
id: m45-l04-e3
type: find-errors
prompt: "Mark every real problem in this CloudKit save."
code: |
  func save(_ list: CKRecord) async {
      let database = CKContainer.default().publicCloudDatabase
      do {
          _ = try await database.modifyRecords(saving: [list], deleting: [], savePolicy: .allKeys)
      } catch {
          // Try again from scratch
          let fresh = CKRecord(recordType: "ShoppingList", recordID: list.recordID)
          fresh["title"] = list["title"]
          _ = try? await database.modifyRecords(saving: [fresh], deleting: [])
      }
  }
choices:
  - text: "A person's shopping list goes in the public database, readable by every user of the app."
    correct: true
  - text: ".allKeys overwrites whatever another device saved instead of detecting the conflict."
    correct: true
  - text: "The retry builds a new record without the server's change tag, so it can't succeed as an update and loses every other field."
    correct: true
  - text: "Errors are swallowed by try?, so failures disappear silently."
    correct: true
  - text: "modifyRecords can't be called from an async function."
    correct: false
    why: "It's an async method (iOS 15); awaiting it is how it's meant to be used."
rubric:
  - I flagged the wrong database.
  - I flagged the overwrite policy.
  - I flagged the retry that discards the server record.
  - I flagged the swallowed errors.
solution: |
  - Personal data belongs in the **private** database (in a custom zone, so database subscriptions work). The public database is "accessible to all users of your app."
  - Use the default `.ifServerRecordUnchanged`, so a conflict is reported.
  - On `serverRecordChanged`, take `ckError.serverRecord`, merge the local changes into it, and save that; a brand-new `CKRecord` has no change tag and none of the other fields.
  - Report or retry failures deliberately (network errors after a delay, `serverRecordChanged` by merging), and surface them to the sync status.
````

````exercise
id: m45-l04-e4
type: fill-in
prompt: "Complete the sign-in request and the launch check."
code: |
  SignInWithAppleButton(.signIn) { (request: ASAuthorizationAppleIDRequest) in
      request.[[1]] = [.fullName, .email]
  } onCompletion: { (result: Result<ASAuthorization, any Error>) in
      handle(result)
  }

  let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: storedUserID)
  switch state {
  case .authorized: break
  case .[[2]]: signOutAndClearLocalData()
  case .notFound: showSignIn()
  case .[[3]]: migrateUserIdentifier()
  @unknown default: showSignIn()
  }

  // Key the account on credential.[[4]], never on the email.
blanks:
  - id: "1"
    answers: ["requestedScopes"]
  - id: "2"
    answers: ["revoked"]
  - id: "3"
    answers: ["transferred"]
  - id: "4"
    answers: ["user"]
solution: |
  - `requestedScopes` asks for name and email; the person decides what to share.
  - `.revoked`: the person stopped using Sign in with Apple with Pantry; sign out.
  - `.transferred`: the app moved to another team; migrate the identifier.
  - `credential.user` is the stable identifier for the person across your team's apps.
````

````exercise
id: m45-l04-e5
type: solve
prompt: |
  CloudKit accepts at most 250 records per request, saves and deletes combined. Write `batches(_:limit:)`, which splits pending changes into consecutive groups of at most `limit`, keeping their order. A `limit` below 1 counts as 1. No empty groups.

  Expected output:

  ```output
  [250, 250, 100]
  true true
  0
  [1, 1, 1]
  ```
starter: |
  enum Change: Equatable {
      case save(String)
      case delete(String)
  }

  func batches(_ changes: [Change], limit: Int) -> [[Change]] {
      // your code
      return []
  }

  var pending: [Change] = []
  for index in 1...600 {
      pending.append(index % 4 == 0 ? .delete("item-\(index)") : .save("item-\(index)"))
  }

  let requests = batches(pending, limit: 250)
  print(requests.map(\.count))
  print(requests[2].first == .save("item-501"), requests[2].last == .delete("item-600"))
  print(batches([], limit: 250).count)
  print(batches([.save("a"), .delete("b"), .save("c")], limit: 0).map(\.count))
hints:
  - "Fill a current group; when it reaches the limit, append it and start a new one."
  - "Don't forget the last, partly filled group."
rubric:
  - Counts saves and deletes together and keeps the original order.
  - Produces no empty groups, including for empty input.
  - Clamps a non-positive limit instead of looping forever or crashing.
solution: |
  ```swift
  enum Change: Equatable {
      case save(String)
      case delete(String)
  }

  /// Splits pending changes into requests of at most `limit` changes (saves and deletes
  /// combined), keeping their order. A limit below 1 is treated as 1.
  func batches(_ changes: [Change], limit: Int) -> [[Change]] {
      let size = max(1, limit)
      var result: [[Change]] = []
      var current: [Change] = []
      for change in changes {
          current.append(change)
          if current.count == size {
              result.append(current)
              current = []
          }
      }
      if !current.isEmpty {
          result.append(current)
      }
      return result
  }

  var pending: [Change] = []
  for index in 1...600 {
      pending.append(index % 4 == 0 ? .delete("item-\(index)") : .save("item-\(index)"))
  }

  let requests = batches(pending, limit: 250)
  print(requests.map(\.count))
  print(requests[2].first == .save("item-501"), requests[2].last == .delete("item-600"))
  print(batches([], limit: 250).count)
  print(batches([.save("a"), .delete("b"), .save("c")], limit: 0).map(\.count))
  ```

  ```output
  [250, 250, 100]
  true true
  0
  [1, 1, 1]
  ```

  - 600 changes become 250 + 250 + 100, in order: the third request starts with item 501 and ends with item 600 (a delete, since 600 is a multiple of 4).
  - Order matters when a save and a delete of related records must reach the server in sequence.
  - With a limit of 0, a naive loop that waits for `current.count == 0` after appending would never flush; clamping to 1 avoids that. `CKSyncEngine`'s `RecordZoneChangeBatch(pendingChanges:recordProvider:)` does this splitting for you.
````

````exercise
id: m45-l04-e6
type: design
prompt: "Design Pantry's shared family shopping list: two adults edit the same list on their own devices, offline sometimes, and both sign in with Apple. Cover identity, which CloudKit database and zone each person's data lives in, how edits sync, how conflicts are resolved per field, what happens without an iCloud account, and account deletion."
rubric:
  - Uses the Sign in with Apple user identifier for Pantry's account and keeps first-time name and email.
  - Puts the owner's list in a custom zone of the private database, shared with the other adult so it appears in their shared database, with a database subscription or CKSyncEngine for each.
  - Keeps an offline local store and syncs through CKSyncEngine (or tokens and batches), persisting engine state.
  - Resolves serverRecordChanged with per-field rules (items merged as sets, checked state by most recent action or union, title keeps server value) by merging into the server record.
  - Works without iCloud (local only, explanation), and deletes server data and revokes Apple tokens on account deletion.
solution: |
  - **Identity:** Sign in with Apple; the account is keyed on `user`; name and email stored on first authorization and merged afterwards. Credential state is checked at launch.
  - **Storage:** the list lives in a custom zone in the owner's **private** database. Sharing it with the other adult (CloudKit sharing, not covered in this lesson) makes it appear in their **shared** database. Nothing goes in the public database.
  - **Sync:** each device has a local store (SwiftData) and a `CKSyncEngine` per database it syncs (private for the owner, shared for the participant), with its state serialization persisted. Edits go to the local store first and are added as pending changes; the engine sends and fetches when conditions allow.
  - **Conflicts:** on `serverRecordChanged`, merge into the server record: items as a set union minus items both sides deleted; an item's checked state by the latest action; the title keeps the server's value and the local one is shown as a suggestion. Then save the merged server record.
  - **No iCloud account:** the list works locally; the sharing button explains that iCloud is needed. With `.temporarilyUnavailable`, wait for `CKAccountChanged` without deleting caches.
  - **Deletion:** in-app account deletion (5.1.1(v)) deletes Pantry's server data and revokes the Sign in with Apple tokens; the person's iCloud data stays in their account under their control, and Pantry deletes its zone when asked.
````

## Summary

- Sign in with Apple: request `.fullName` and `.email`; key accounts on `credential.user`; send the identity token and authorization code to your server. Name and email arrive only the first time: store them immediately and merge later responses.
- Check `credentialState(forUserID:)` at launch: `authorized` continue, `revoked` sign out, `notFound` show sign-in, `transferred` migrate the identifier. Observe `credentialRevokedNotification`.
- Relay addresses forward to the person, are the same across your team's apps, need a registered sending domain, and allow 100 emails a day. Guidelines: 4.8 requires an equivalent privacy-focused login next to third-party logins; 5.1.1(v) requires in-app account deletion.
- CloudKit: a container has a public database and per-person private and shared databases. Private and shared need an iCloud account; public needs one only to write. Records are limited to 1 MB plus assets; use custom zones in the private database.
- The default save policy detects conflicts with change tags. On `serverRecordChanged`, merge your changes into `serverRecord` and save it; merging into the client copy fails again.
- Subscriptions signal "something changed," not the data. Database subscriptions work in private and shared databases; query subscriptions in public and private. Create them in development first.
- `CKSyncEngine` (iOS 17) schedules sync, batches sends (250 records per request), fetches changes and retries transient errors; you persist its state, provide records, apply changes and resolve conflicts. It isn't for the public database.
