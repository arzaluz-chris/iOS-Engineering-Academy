---
id: m42-l02
title: Keychain, Data Protection and biometrics
description: "Choose how each secret and file is protected at rest, and use Face ID and Touch ID in a way that actually protects something. You go deeper into kSecAttrAccessible, bind a Keychain item to the current biometric enrollment with SecAccessControl, see why an LAContext check alone can be bypassed, detect enrollment changes, and pick file Data Protection classes."
module: m42
order: 2
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l01, m31-l03]
objectives:
  - Choose a kSecAttrAccessible class from three questions and explain what each class does to backups and migration.
  - Protect a Keychain item with SecAccessControl so that reading it requires Face ID or Touch ID of the currently enrolled person.
  - Explain the difference between event-bound and Keychain-bound biometric authentication, and why OWASP fails the first for sensitive data.
  - Use LAContext to check availability, pick a policy, and detect biometric enrollment changes.
  - Assign file Data Protection classes and know which one a new file gets by default.
terms:
  - term: Access control (SecAccessControl)
    definition: "An object created with SecAccessControlCreateWithFlags and stored in kSecAttrAccessControl. It combines an accessibility class with conditions such as biometryCurrentSet or devicePasscode that the system enforces each time the item is used."
  - term: biometryCurrentSet
    definition: "An access-control flag: the item can only be used after Face ID or Touch ID matches the enrollment that existed when the item was created. Adding or removing a finger, or re-enrolling Face ID, invalidates the item."
  - term: Event-bound authentication
    definition: "Using LAContext.evaluatePolicy as a yes/no gate in app code. The secret it guards is already readable by the app, so modifying the app's logic bypasses the gate."
  - term: Keychain-bound authentication
    definition: "Storing the secret in a Keychain item with an access control, so the system releases it only after a successful match. The check happens outside the app's process."
  - term: Data Protection class
    definition: "The per-file policy that decides when its encryption key is available: Complete (only while unlocked), CompleteUnlessOpen, CompleteUntilFirstUserAuthentication (the default) or None."
  - term: LAContext
    definition: "LocalAuthentication's object for evaluating a policy (biometrics, or biometrics with passcode fallback) and for passing an authenticated context to the Keychain."
mastery:
  - Pick and justify an accessibility class and access-control flags for a refresh token, a transfer-signing secret and a cached statement.
  - Write a Keychain save and read that requires the currently enrolled biometrics, and handle cancellation separately from failure.
  - Spot event-bound biometric checks in a code review and rewrite them as Keychain-bound.
  - Explain to a product owner what a Face ID match does and doesn't prove about who is using the app.
  - Write files with the Complete protection class and say when that breaks background work.
resources: [keychain-services, security-keychain-accessibility, uikit-encrypting-files, apple-platform-security, owasp-mastg]
cards:
  - id: m42-l02-c1
    front: What does kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly do that the others don't?
    back: "It refuses to store anything on a device without a passcode, and removing the passcode deletes the items. Per Apple Platform Security, these items don't sync to iCloud Keychain, aren't backed up and aren't in escrow keybags. It's foreground-only."
  - id: m42-l02-c2
    front: biometryAny vs biometryCurrentSet?
    back: "biometryAny keeps working after fingers are added or Face ID is re-enrolled. biometryCurrentSet invalidates the item when the enrollment changes, so someone who learns the passcode and enrolls their own face can't use it."
  - id: m42-l02-c3
    front: Why does OWASP fail an app that protects a token with LAContext.evaluatePolicy alone?
    back: "The API only returns success or failure to the app; the token is already in the app's reach, so an attacker who changes the app's logic skips the check. Storing the token in the Keychain with an access control makes the system release it only after a match (MASTG-TEST-0266)."
  - id: m42-l02-c4
    front: What does a successful Face ID match prove?
    back: "That someone enrolled on this device (or, with a passcode fallback, someone who knows the passcode) was present just now. It doesn't prove they're the account holder, and the app never sees biometric data, only a yes or no."
  - id: m42-l02-c5
    front: Which Data Protection class does a new file get if you don't choose?
    back: "NSFileProtectionCompleteUntilFirstUserAuthentication (Class C): unreadable after a reboot until the first unlock, then readable even while locked. Use .complete for files that should be unreadable whenever the device is locked."
---

## The idea in one sentence

Every secret and every file on the device gets a protection level you choose on purpose, and when you want Face ID or Touch ID to guard something, you let the Keychain enforce it, because a biometric check that only returns `true` to your code is a check an attacker can skip.

> [!note] Sources and what was checked
> Behavior comes from Apple's documentation for `kSecAttrAccessible` and its values, `SecAccessControlCreateWithFlags`, `SecAccessControlCreateFlags` and each flag, `kSecUseAuthenticationContext`, the LocalAuthentication overview, `LAPolicy`, `LAContext.domainState` and `evaluatedPolicyDomainState`, "Restricting keychain item accessibility", "Accessing Keychain Items with Face ID or Touch ID", "Logging a User into Your App with Face ID or Touch ID", `FileProtectionType` and "Encrypting Your App's Files"; from Apple Platform Security's "Keychain data protection", "Data Protection classes" and "Uses for Optic ID, Face ID, and Touch ID"; and from MASTG-TEST-0266, 0268 and 0270. All read in November 2026. The Security, LocalAuthentication and file-protection blocks were type-checked against the iOS SDK, not run: they need a device. The decision and authentication models are pure Swift, compiled and run with Swift 6.3.

## Where Module 31 left off

Module 31 stored a refresh token with `KeychainStore`, chose `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` because background refreshes need it, and listed the five accessibility classes. This lesson adds three things: what those classes mean underneath, how to require the person's presence at read time, and how files get the same treatment.

## Accessibility classes, underneath

Apple Platform Security describes the Keychain as one SQLite database managed by the `securityd` daemon, with each item's secret value encrypted under a per-row key that "always requires a round trip through the Secure Enclave." Accessibility classes decide **when the class key that unlocks those row keys is available**:

| Keychain class | Equivalent file class | Available |
| --- | --- | --- |
| `kSecAttrAccessibleWhenUnlocked` | `NSFileProtectionComplete` | Only while unlocked |
| `kSecAttrAccessibleAfterFirstUnlock` | `NSFileProtectionCompleteUntilFirstUserAuthentication` | After the first unlock since boot |
| `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | (none) | Only while unlocked, only with a passcode |

Two details from the same guide matter for a bank:

- **`ThisDeviceOnly` survives a backup only as dead weight.** Those items are "always protected with the UID when being copied from the device during a backup, rendering it useless if it's restored to a different device." The UID is a key fused into the device's hardware. That's why a session token stored `ThisDeviceOnly` doesn't follow the customer to a new phone, where they should sign in again anyway.
- **`WhenPasscodeSetThisDeviceOnly` is the strictest.** These items "don't sync to iCloud Keychain," "aren't backed up," "aren't included in escrow keybags," and "if the passcode is removed or reset, the items are rendered useless."

Choosing a class comes down to three questions. As a pure function:

```swift
struct SecretNeeds {
    let readWhileLocked: Bool      // background refresh, notification extension
    let moveToNewDevice: Bool      // restore from an encrypted backup onto another phone
    let requirePasscode: Bool      // refuse to store at all on a phone without a passcode
}

func accessibility(for needs: SecretNeeds) -> String? {
    if needs.requirePasscode {
        // Only one class needs a passcode, and it's foreground-only and never migrates.
        guard !needs.readWhileLocked, !needs.moveToNewDevice else { return nil }
        return "kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly"
    }
    let base = needs.readWhileLocked ? "kSecAttrAccessibleAfterFirstUnlock" : "kSecAttrAccessibleWhenUnlocked"
    return needs.moveToNewDevice ? base : base + "ThisDeviceOnly"
}

let cases: [(String, SecretNeeds)] = [
    ("refresh token", SecretNeeds(readWhileLocked: true, moveToNewDevice: false, requirePasscode: false)),
    ("transfer-signing secret", SecretNeeds(readWhileLocked: false, moveToNewDevice: false, requirePasscode: true)),
    ("saved username", SecretNeeds(readWhileLocked: false, moveToNewDevice: true, requirePasscode: false)),
    ("push-decryption key", SecretNeeds(readWhileLocked: true, moveToNewDevice: false, requirePasscode: true)),
]
for (name, needs) in cases {
    print(name + ":", accessibility(for: needs) ?? "no class fits, change the requirements")
}
```

```output
refresh token: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
transfer-signing secret: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
saved username: kSecAttrAccessibleWhenUnlocked
push-decryption key: no class fits, change the requirements
```

The last case is the useful one. A notification service extension runs while the phone may be locked, so it can't use a passcode-only, foreground-only class. When requirements conflict, the answer is to change a requirement (decrypt on the server, or show a generic notification), not to weaken the class silently.

> [!note] Synchronizable items
> Apple's `kSecAttrAccessible` page: an item marked `kSecAttrSynchronizable` (iCloud Keychain) can only use a class "whose name does not end with ThisDeviceOnly." Banking credentials usually shouldn't sync; device-bound tokens and keys never can.

## Requiring the person, not just an unlocked phone

An accessibility class answers "is the device in a state where this can be read?" It doesn't answer "is the owner holding it?" Apple's "Restricting keychain item accessibility" gives the banking example itself: "If your app provides direct control over a bank account, you can check for the presence of the authorized user at the very last minute before retrieving login credentials from the keychain. This helps secure the account even if the user hands the device in an unlocked state to someone else."

You do that with an **access control** in `kSecAttrAccessControl`, created by `SecAccessControlCreateWithFlags(_:_:_:_:)`. It takes an accessibility class (so you don't also set `kSecAttrAccessible`) and flags from `SecAccessControlCreateFlags`:

| Flag | Requires | After enrollment changes |
| --- | --- | --- |
| `.userPresence` | Biometry **or** the device passcode. Apple: equivalent to `biometryAny`, `or`, `devicePasscode` | Still usable |
| `.biometryAny` | Face ID or Touch ID, any enrolled face or finger | Still usable |
| `.biometryCurrentSet` | Face ID or Touch ID, the enrollment that existed when the item was saved | "The item is invalidated if fingers are added or removed for Touch ID, or if the user re-enrolls for Face ID" |
| `.devicePasscode` | The device passcode | Not affected |
| `.applicationPassword` | An app-specific password, prompted at creation and at every read | Not affected |
| `.privateKeyUsage` | Needed for Secure Enclave private keys (Lesson 3) | |

`.and` and `.or` combine constraints.

For a transfer-signing secret in a banking app, MASTG's tests push toward **`.biometryCurrentSet` without passcode fallback**:

- MASTG-TEST-0270 fails an app that uses "any flag except the kSecAccessControlBiometryCurrentSet flag for any sensitive data resource worth protecting." Its reasoning: "An attacker who obtains the device passcode could add a new fingerprint or facial representation via system settings and use it to authenticate in the app."
- MASTG-TEST-0268 flags `.userPresence` and `.devicePasscode` for sensitive resources, because a passcode is "more susceptible to compromise (e.g., through shoulder surfing)." It adds that this is "not inherently a vulnerability" but a weakness "in high-security applications (e.g., finance, government, health)."

Apple's own sample uses `.userPresence`, which is the right default for many apps. A bank typically chooses the stricter flag and gives people another way in (the account password, then re-enable biometrics) when biometry isn't available. Don't lock someone out of their money because their thumb is wet.

### The Keychain-bound version

```swift ios
import Foundation
import LocalAuthentication
import Security

enum ProtectedItemError: Error {
    case accessControl(String)
    case unexpectedStatus(OSStatus)
}

/// A secret that can only be read after Face ID or Touch ID matches someone enrolled *now*,
/// on this device, while it's unlocked and has a passcode.
struct TransferSigningSecret {
    let service = "com.example.harborbank.transfer-signing"
    let account: String

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ secret: Data) throws {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            let reason = error.map { String(describing: $0.takeRetainedValue()) } ?? "unknown"
            throw ProtectedItemError.accessControl(reason)
        }

        SecItemDelete(itemQuery as CFDictionary)        // replace any previous enrollment
        var attributes = itemQuery
        attributes[kSecAttrAccessControl as String] = access
        attributes[kSecValueData as String] = secret
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw ProtectedItemError.unexpectedStatus(status) }
    }

    /// Shows the Face ID or Touch ID prompt. Returns nil if the person cancels.
    func read(reason: String) throws -> Data? {
        let context = LAContext()
        context.localizedReason = reason

        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecUserCanceled:
            return nil
        default:
            throw ProtectedItemError.unexpectedStatus(status)
        }
    }
}
```

What each part does:

- **`SecAccessControlCreateWithFlags`** returns `nil` and fills the error pointer on failure; the `Unmanaged<CFError>` is taken with `takeRetainedValue()`. The accessibility class goes in here, not in `kSecAttrAccessible`.
- **Saving replaces.** Module 31 preferred update-then-add. Here delete-then-add is deliberate: enabling biometric unlock again after an enrollment change should create a fresh item bound to the new enrollment. Saving doesn't prompt; reading does.
- **The context** carries the prompt text (`localizedReason`, which Apple says should explain why, without your app's name, since the dialog already shows it). Apple on `kSecUseAuthenticationContext`: without it, "a new context will be created, used once, and discarded"; with an already-authenticated context the operation "will succeed without asking user for authentication." That's how you avoid two prompts in a row for one action.
- **The match happens outside your process.** Apple's sample article: "The Secure Enclave passes back a pass/fail result that gates keychain item access. No user space or operating system software ever has access to the underlying authentication data."
- **Cancel is not failure.** `errSecUserCanceled` means the person chose not to authenticate; show the screen again, don't sign them out. Any other failure, including the item having been invalidated by an enrollment change, leads to "sign in with your password, then turn biometric unlock on again."
- **Call it off the main thread.** Apple's `SecAccessControlCreateWithFlags` page warns that using protected items "may block execution on the main thread." Module 31's actor pattern applies.

> [!warning] NSFaceIDUsageDescription
> Apple: "Without this key, the system won't allow your app to use Face ID." Add the purpose string to Info.plist before you test on a Face ID device.

## What biometrics prove, and what they don't

From Apple's LocalAuthentication overview: "your app never gains access to any of the underlying authentication data," and "you receive only a Boolean result indicating authentication success or failure." Apple Platform Security says the same: the app "is notified only as to whether the authentication was successful."

So a successful Face ID match tells you that **someone enrolled on this device was present a moment ago**. It doesn't tell you:

- **that it's the account holder.** Whoever is enrolled passes. A family member whose face or finger the owner enrolled is, to your app, the owner.
- **that nobody enrolled since you last checked**, unless you used `.biometryCurrentSet` or compared the enrollment state (below).
- **anything, if you allowed passcode fallback,** beyond "someone knew the passcode."
- **anything to your server.** The server sees a request. If the result of the match is a Boolean inside the app, a modified app can send the same request without the match. Lesson 3 binds a signing key to biometrics so the server can verify a signature, and Lesson 7 adds App Attest.

Apple's own advice in "Logging a User into Your App with Face ID or Touch ID": "Use biometrics as a supplement to something you're already doing. Don't depend on biometrics as your only authentication option."

### Event-bound vs Keychain-bound

MASTG-TEST-0266 names the most common mistake. `LAContext` "provides user authentication (Touch ID, Face ID, device passcode), returning only a success or failure result. However, it does not securely store secrets or enforce any security. This makes it susceptible to logic manipulation (e.g., bypassing an `if authenticated { ... }` check)." The test fails an app when, for a sensitive resource, `evaluatePolicy` is used and there's no access control requiring user presence.

Here's the difference as a model. The "system" side is a stand-in for the Keychain and Secure Enclave, which your code can't reach inside; the hook is a stand-in for an attacker who has modified the app so that the evaluation returns `true`:

```swift
// A model, not the real system: the "system" side holds the secret and does the matching.
struct Enrollment: Equatable {
    let stateHash: String        // changes whenever a face or finger is added or removed
}

enum ReadError: Error {
    case authenticationFailed
    case itemInvalidated
}

/// Stands in for the Keychain plus the Secure Enclave. App code can't reach inside.
final class SystemKeychain {
    private var secret: String?
    private var boundTo: Enrollment?
    var currentEnrollment: Enrollment

    init(enrollment: Enrollment) { currentEnrollment = enrollment }

    func store(_ value: String, bindToCurrentSet: Bool) {
        secret = value
        boundTo = bindToCurrentSet ? currentEnrollment : nil
    }

    /// The match happens here, inside the system, not in the app.
    func read(faceMatches: Bool) throws -> String {
        if let boundTo, boundTo != currentEnrollment {
            secret = nil                           // the item is unusable from now on
            throw ReadError.itemInvalidated
        }
        guard faceMatches, let secret else { throw ReadError.authenticationFailed }
        return secret
    }
}

// Event-bound: the app asks "did it pass?" and then reads a secret it already holds.
func eventBoundRead(evaluate: () -> Bool, storedInApp: String) -> String? {
    evaluate() ? storedInApp : nil
}

let hookedEvaluate: () -> Bool = { true }       // what an instrumented app sees
print("event-bound:", eventBoundRead(evaluate: hookedEvaluate, storedInApp: "tx-key-41") ?? "denied")

let keychain = SystemKeychain(enrollment: Enrollment(stateHash: "A1"))
keychain.store("tx-key-41", bindToCurrentSet: true)

for (label, matches) in [("owner", true), ("hooked app, no match", false)] {
    do {
        print("keychain-bound, \(label):", try keychain.read(faceMatches: matches))
    } catch {
        print("keychain-bound, \(label):", error)
    }
}

keychain.currentEnrollment = Enrollment(stateHash: "B7")   // someone with the passcode added a face
for attempt in 1...2 {
    do {
        print("after new enrollment, try \(attempt):", try keychain.read(faceMatches: true))
    } catch {
        print("after new enrollment, try \(attempt):", error)
    }
}
```

```output
event-bound: tx-key-41
keychain-bound, owner: tx-key-41
keychain-bound, hooked app, no match: authenticationFailed
after new enrollment, try 1: itemInvalidated
after new enrollment, try 2: itemInvalidated
```

- **Event-bound** leaks the secret as soon as the evaluation is forced to `true`, because the secret was already in the app's hands.
- **Keychain-bound** doesn't care what the app believes. The match is done by the system; a hooked app that can't produce a real match gets nothing.
- **`biometryCurrentSet`** makes the item useless once the enrollment changes, even for a genuine match of the new face. That's the point: the new face wasn't there when the customer turned the feature on.

The model simplifies (real invalidation is enforced by the Secure Enclave, and the exact error your read gets isn't something to rely on), but the shape is right, and it's the shape MASTG tests for.

## LAContext for the cases that aren't secrets

`evaluatePolicy` still has honest uses: hiding balances until someone authenticates, confirming before showing a screen. Those are privacy conveniences, not protection, and they should be described that way in your threat model. The two main policies:

- **`.deviceOwnerAuthenticationWithBiometrics`**: Face ID or Touch ID only. Apple: it fails if biometry "is unavailable or not enrolled," and after too many failures biometry is "disabled system-wide" until the passcode is entered. Tapping the fallback button returns `userFallback`, and "your app should provide an alternate mechanism."
- **`.deviceOwnerAuthentication`**: biometry first, then the device passcode. It fails with `passcodeNotSet` if there's no passcode.

```swift ios
import Foundation
import LocalAuthentication

enum BiometricStatus {
    case available(LABiometryType)
    case unavailable(String)
}

func biometricStatus() -> BiometricStatus {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return .unavailable(error?.localizedDescription ?? "unknown reason")
    }
    return .available(context.biometryType)     // meaningful only after canEvaluatePolicy
}

/// An opaque value that changes when a face or finger is added or removed. Nil if none is enrolled.
func biometryStateHash() -> Data? {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return nil
    }
    if #available(iOS 18.0, *) {
        return context.domainState.biometry.stateHash
    } else {
        return context.evaluatedPolicyDomainState
    }
}

/// UI convenience only: hides the balance until someone authenticates. Protects nothing on its own.
func unlockBalanceView() async -> Bool {
    let context = LAContext()
    context.localizedCancelTitle = "Use Password"
    do {
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Show your balances")
    } catch {
        return false
    }
}
```

- **`canEvaluatePolicy`** tests every prerequisite. Apple: "Don't store the return value from this method because it might change," and `biometryType` "only contains a meaningful value after you run the `canEvaluatePolicy(_:error:)` method on the context at least once."
- **Enrollment state.** On iOS 18 and later, `domainState.biometry.stateHash` "will change" when "fingers, faces were removed or added"; it's `nil` when nothing is enrolled. On iOS 17 the older `evaluatedPolicyDomainState` gives the same signal; Apple marks it deprecated as of iOS 18. Apple notes these values only detect that a change happened, not what changed, and differ between apps. Exercise 5 turns stored and current hashes into a decision.
- **The async `evaluatePolicy`** returns `true` or throws. Apple: "Don't assume that a previous successful policy evaluation means that future evaluations will also succeed."

## Files: Data Protection classes

Files get the same treatment as Keychain items. Apple's "Encrypting Your App's Files" lists four levels; Apple Platform Security names them as classes:

| Class | `FileProtectionType` | Readable |
| --- | --- | --- |
| A: Complete Protection | `.complete` | Only while unlocked. Shortly after locking ("10 seconds, if the Require Password setting is Immediately") the class key is discarded |
| B: Protected Unless Open | `.completeUnlessOpen` | Files open at lock time stay usable; new files can be created while locked; closed files can't be reopened until unlock |
| C: Protected Until First User Authentication | `.completeUntilFirstUserAuthentication` | After the first unlock since boot, then always. **The default** for third-party app data |
| D: No Protection | `.none` | Always (still encrypted, but the key is protected only by the device UID) |

The default (C) protects against attacks that need a reboot, but a phone that's been unlocked once since boot and is now sitting locked on a table has its class C files readable. For downloaded statements, receipts and anything with account data, choose `.complete` unless background work needs the file:

```swift ios
import Foundation

/// Writes a statement so it can't be read while the device is locked.
func saveStatement(_ pdf: Data, named name: String) throws -> URL {
    let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true)
    let url = folder.appending(path: name)
    try pdf.write(to: url, options: [.atomic, .completeFileProtection])
    return url
}

/// Raises the class of a file that already exists.
func protectExistingFile(at url: URL) throws {
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                          ofItemAtPath: url.path(percentEncoded: false))
}

let statement = try saveStatement(Data("%PDF-1.7 ...".utf8), named: "statement-2026-10.pdf")
let attributes = try FileManager.default.attributesOfItem(atPath: statement.path(percentEncoded: false))
print(attributes[.protectionKey] as? FileProtectionType == .complete)
```

- **`.completeFileProtection`** in `Data.WritingOptions` creates and encrypts the file in one step, as Apple's article shows.
- **Existing files** change class through the `protectionKey` attribute (Apple's example uses the equivalent URL resource value).
- **Locking breaks access.** Reads and writes of a `.complete` file fail once the class key is gone. Apple suggests closing and reopening such files around `applicationProtectedDataWillBecomeUnavailable(_:)` and `applicationProtectedDataDidBecomeAvailable(_:)`. A background download that writes into a `.complete` file while locked will fail; write it as `.completeUnlessOpen` and raise the class later, or keep it in memory.
- **Data Protection needs a passcode.** Apple: it "is enabled automatically when the user sets an active passcode for the device." Without one, every class is effectively always available. That's an argument for `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` on the most sensitive Keychain items, which refuses to exist without a passcode.

> [!tip] One more place data lands
> SwiftData and Core Data stores are files too. Module 31's stores take the default class unless you set one. If the store holds transactions, decide its class with the same three questions.

## Common mistakes

> [!error] `if try await context.evaluatePolicy(...) { showToken() }`
> The event-bound pattern. The token was readable before the check, so the check only protects against people who don't modify the app. Store the token in the Keychain with an access control and let the read itself require the match (MASTG-TEST-0266).

> [!error] `.userPresence` or `.biometryAny` for a money-moving secret
> Both keep working after someone with the passcode enrolls a new face. For transfer approval use `.biometryCurrentSet`, and handle the invalidation with a password sign-in that re-enables biometrics.

> [!error] Treating cancel, lockout and invalidation the same
> `errSecUserCanceled` means "not now." A lockout means "use the passcode or password." An invalidated item means "set up biometric unlock again." Signing the person out for any of them is a bad experience and teaches them to turn the feature off.

> [!error] Leaving cached statements in the default class
> Class C files are readable whenever the phone has been unlocked once since boot. Write documents with account data with `.completeFileProtection`.

> [!error] Setting both kSecAttrAccessible and kSecAttrAccessControl
> The access control already contains the accessibility class. Apple: "You don't need to set the accessible attribute directly if you set it as part of the access control attribute instead." Keep one source of truth.

## Exercises

````exercise
id: m42-l02-e1
type: prediction
prompt: "This is the lesson's decision function, with shorter names. What does it print?"
code: |
  func accessibility(readWhileLocked: Bool, moveToNewDevice: Bool, requirePasscode: Bool) -> String {
      if requirePasscode {
          return readWhileLocked || moveToNewDevice ? "none fits" : "WhenPasscodeSetThisDeviceOnly"
      }
      let base = readWhileLocked ? "AfterFirstUnlock" : "WhenUnlocked"
      return moveToNewDevice ? base : base + "ThisDeviceOnly"
  }

  print(accessibility(readWhileLocked: false, moveToNewDevice: false, requirePasscode: false))
  print(accessibility(readWhileLocked: true, moveToNewDevice: true, requirePasscode: false))
  print(accessibility(readWhileLocked: false, moveToNewDevice: true, requirePasscode: true))
  print(accessibility(readWhileLocked: false, moveToNewDevice: false, requirePasscode: true))
output: |
  WhenUnlockedThisDeviceOnly
  AfterFirstUnlock
  none fits
  WhenPasscodeSetThisDeviceOnly
hints:
  - "The passcode question is checked first."
  - "Not moving to a new device adds the ThisDeviceOnly suffix."
solution: |
  ```output
  WhenUnlockedThisDeviceOnly
  AfterFirstUnlock
  none fits
  WhenPasscodeSetThisDeviceOnly
  ```

  1. Foreground-only and device-bound: `WhenUnlockedThisDeviceOnly`.
  2. Background and migratable: `AfterFirstUnlock`. That's a weak choice for anything sensitive; it's readable while locked and moves with encrypted backups.
  3. Requiring a passcode and wanting to migrate conflict: Apple Platform Security says `WhenPasscodeSetThisDeviceOnly` items "aren't backed up." The function refuses rather than picking something weaker.
  4. The strictest class.
````

````exercise
id: m42-l02-e2
type: comprehension
prompt: "A thief learns the customer's passcode by watching them, then adds their own face in Settings. Which access-control flag stops them from reading Harbor Bank's transfer-signing secret with their face?"
choices:
  - text: ".biometryCurrentSet"
    correct: true
    why: "The item is bound to the enrollment at creation; re-enrolling Face ID invalidates it."
  - text: ".biometryAny"
    correct: false
    why: "Apple: the item is still accessible by Face ID \"if the user is re-enrolled.\""
  - text: ".userPresence"
    correct: false
    why: "Equivalent to biometryAny or devicePasscode. The thief knows the passcode, so even the fallback works."
  - text: ".devicePasscode"
    correct: false
    why: "The thief knows the passcode."
solution: |
  **`.biometryCurrentSet`.** Apple's documentation: "The item is invalidated if fingers are added or removed for Touch ID, or if the user re-enrolls for Face ID." This is exactly the attack MASTG-TEST-0270 describes.

  It isn't free: after the customer legitimately changes their enrollment, the item stops working and the app has to fall back to the account password and recreate it. That's the trade a bank should make for transfer approval.
````

````exercise
id: m42-l02-e3
type: fill-in
prompt: "Complete the access control for a secret that should be readable only while unlocked, only on a device with a passcode, never migrated, and only after Face ID or Touch ID of the current enrollment."
code: |
  var error: Unmanaged<CFError>?
  let access = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessible[[1]],
      .[[2]],
      &error
  )
  let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.example.harborbank.transfer-signing",
      kSecAttrAccount as String: "primary",
      kSecAttr[[3]] as String: access as Any,
      kSecValueData as String: secret,
  ]
blanks:
  - id: "1"
    answers: ["WhenPasscodeSetThisDeviceOnly"]
  - id: "2"
    answers: ["biometryCurrentSet"]
  - id: "3"
    answers: ["AccessControl"]
solution: |
  ```swift illustrative
  var error: Unmanaged<CFError>?
  let access = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      .biometryCurrentSet,
      &error
  )
  let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.example.harborbank.transfer-signing",
      kSecAttrAccount as String: "primary",
      kSecAttrAccessControl as String: access as Any,
      kSecValueData as String: secret,
  ]
  ```

  The accessibility class goes inside the access control, and the access control goes in `kSecAttrAccessControl`. There's no separate `kSecAttrAccessible` entry. In real code, check for `nil` before using `access` (the lesson's `save(_:)` does); `as Any` here just mirrors Apple's sample. This fragment is illustrative because `secret` comes from elsewhere.
````

````exercise
id: m42-l02-e4
type: find-errors
prompt: "Review this \"Face ID unlock\" for Harbor Bank. Mark every real problem."
code: |
  func unlock() async {
      let context = LAContext()
      let ok = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "Harbor Bank wants to unlock")) ?? false
      if ok {
          let token = UserDefaults.standard.string(forKey: "refreshToken")!
          session.resume(with: token)
      } else {
          session.signOut()
      }
  }
choices:
  - text: "The refresh token is in UserDefaults, so it's readable without any authentication; Face ID guards nothing."
    correct: true
  - text: "It's event-bound: a modified app that forces `ok` to true gets the token (MASTG-TEST-0266)."
    correct: true
  - text: "Any failure signs the person out, including a simple cancel."
    correct: true
  - text: "The prompt includes the app's name, which the system dialog already shows."
    correct: true
  - text: "`.deviceOwnerAuthentication` falls back to the passcode, which a bank may not want for this action."
    correct: true
  - text: "LAContext can't be used from an async function."
    correct: false
    why: "evaluatePolicy has an async form; Apple's own sample calls it with try await."
rubric:
  - I moved the token to the Keychain with an access control.
  - I identified the event-bound pattern.
  - I separated cancel from failure.
  - I fixed the prompt text and considered the fallback policy.
solution: |
  Five problems:

  1. **`UserDefaults`** is a plist in the app container (Module 30). The token never needed Face ID to be read.
  2. **Event-bound.** Even with the token elsewhere in the app, the `if ok` is the only gate. Store the token (or better, a secret that unlocks it) in the Keychain with `SecAccessControlCreateWithFlags(..., .biometryCurrentSet, ...)` and read it with an `LAContext`; the read itself is the authentication.
  3. **Cancel signs out.** `try?` collapses cancel, lockout and failure into `false`. Handle them separately.
  4. **Prompt.** Apple: "Don't include the app name, which already appears in the authentication dialog." Say why: "Unlock your accounts."
  5. **Fallback.** For unlocking a session, passcode fallback may be acceptable; for approving transfers a bank usually requires biometrics or the account password (MASTG-TEST-0268). Decide per action and record it in the threat model.

  The force unwrap is also a crash waiting for a first launch, but that's a correctness bug, not one of the listed choices.
````

````exercise
id: m42-l02-e5
type: solve
prompt: |
  The app saves the biometric state hash when the customer turns on biometric unlock. Write `checkEnrollment(stored:current:)` returning one of five cases, and `nextStep(_:)` returning what the app does. A `nil` current value means nothing is enrolled; a `nil` stored value means the app never saved one.

  Expected output:

  ```output
  nil / H1: save H1, offer biometric unlock
  H1 / H1: biometric unlock allowed
  H1 / H2: ask for the account password, then re-enable biometrics
  H1 / nil: turn off biometric unlock, ask for the account password
  nil / nil: use the account password
  ```
starter: |
  enum EnrollmentCheck: Equatable {
      case firstRun(store: String)
      case unchanged
      case changed
      case biometricsRemoved
      case neverEnrolled
  }

  func checkEnrollment(stored: String?, current: String?) -> EnrollmentCheck {
      // your code
      return .neverEnrolled
  }

  func nextStep(_ check: EnrollmentCheck) -> String {
      // your code
      return ""
  }

  let observations: [(String?, String?)] = [(nil, "H1"), ("H1", "H1"), ("H1", "H2"), ("H1", nil), (nil, nil)]
  for (stored, current) in observations {
      print("\(stored ?? "nil") / \(current ?? "nil"):", nextStep(checkEnrollment(stored: stored, current: current)))
  }
hints:
  - "Switch on the tuple (stored, current) with optional patterns like `let now?`."
  - "Four combinations of nil and non-nil, and one of them splits into equal and different."
rubric:
  - Covers all four nil/non-nil combinations and compares the hashes when both exist.
  - Never treats a changed enrollment as unchanged.
  - Prints the five expected lines.
solution: |
  ```swift
  enum EnrollmentCheck: Equatable {
      case firstRun(store: String)
      case unchanged
      case changed
      case biometricsRemoved
      case neverEnrolled
  }

  /// `stored` is the hash the app saved last time; `current` is what the system reports now.
  /// A nil current value means no face or finger is enrolled.
  func checkEnrollment(stored: String?, current: String?) -> EnrollmentCheck {
      switch (stored, current) {
      case (nil, let now?): return .firstRun(store: now)
      case (nil, nil): return .neverEnrolled
      case (_?, nil): return .biometricsRemoved
      case (let before?, let now?): return before == now ? .unchanged : .changed
      }
  }

  func nextStep(_ check: EnrollmentCheck) -> String {
      switch check {
      case .firstRun(let hash): "save \(hash), offer biometric unlock"
      case .unchanged: "biometric unlock allowed"
      case .changed: "ask for the account password, then re-enable biometrics"
      case .biometricsRemoved: "turn off biometric unlock, ask for the account password"
      case .neverEnrolled: "use the account password"
      }
  }

  let observations: [(String?, String?)] = [(nil, "H1"), ("H1", "H1"), ("H1", "H2"), ("H1", nil), (nil, nil)]
  for (stored, current) in observations {
      print("\(stored ?? "nil") / \(current ?? "nil"):", nextStep(checkEnrollment(stored: stored, current: current)))
  }
  ```

  ```output
  nil / H1: save H1, offer biometric unlock
  H1 / H1: biometric unlock allowed
  H1 / H2: ask for the account password, then re-enable biometrics
  H1 / nil: turn off biometric unlock, ask for the account password
  nil / nil: use the account password
  ```

  In the app, `current` comes from `biometryStateHash()` in the lesson, as `Data` rather than `String`. The switch is exhaustive over the tuple, so the compiler proves every combination is handled.

  This check is a usability layer: it tells you to re-prompt before a read fails. The protection still comes from the Keychain item's `.biometryCurrentSet`, which the system enforces even if this code is bypassed.
````

````exercise
id: m42-l02-e6
type: explain
prompt: "A product owner asks: \"If Face ID succeeds, we know it's the customer, right? So can we skip the confirmation screen for transfers?\" Answer them."
code: |
  Proposal: Face ID success → send transfer immediately, no review screen.
rubric:
  - Explains that the app gets only a yes or no and that a match proves an enrolled person was present, not the account holder.
  - Mentions enrolled family members, passcode fallback and enrollment changes.
  - Explains that the server can't see a Boolean in the app and needs something verifiable (a key-bound signature).
  - Keeps a deliberate confirmation step for money movement.
solution: |
  Not quite. Face ID tells the app one thing: someone enrolled on this phone just matched. Apple's documentation says the app receives "only a Boolean result indicating authentication success or failure." It doesn't know who.

  - Anyone the customer enrolled passes. If the policy allows the passcode fallback, anyone who knows the passcode passes.
  - If someone learns the passcode and adds their own face, a plain Face ID check passes for them too, unless the secret is bound to the current enrollment (`.biometryCurrentSet`).
  - The server never sees the Face ID result. A modified app can send the transfer request without any match at all, so the server needs proof it can check: a signature from a key that only works after a biometric match (Lesson 3) and an App Attest assertion (Lesson 7).

  And the confirmation screen isn't redundant with Face ID: it's where the person sees the payee and amount. A link or a mis-tap can prefill a transfer (Lesson 6); the review step is what makes the approval deliberate. Keep the review, use Face ID as the approval on it, and have the server verify the signature.
````

## Summary

- Accessibility classes decide when a Keychain item's key is available. `ThisDeviceOnly` items are useless on another device; `WhenPasscodeSetThisDeviceOnly` items need a passcode, aren't backed up and vanish when the passcode is removed. When requirements conflict, change a requirement instead of weakening the class.
- `SecAccessControlCreateWithFlags` adds conditions checked at use: `.userPresence`, `.biometryAny`, `.biometryCurrentSet`, `.devicePasscode`. For money-moving secrets, `.biometryCurrentSet` stops someone who adds their own face with a stolen passcode.
- `LAContext.evaluatePolicy` returns only success or failure. Used alone as a gate it's event-bound and can be bypassed by modifying the app; put the secret in the Keychain with an access control so the system enforces the match (MASTG-TEST-0266).
- A match proves an enrolled person was present, not who they are, and proves nothing to your server. Detect enrollment changes with `domainState.biometry.stateHash` (iOS 18) or `evaluatedPolicyDomainState`, and handle cancel, lockout and invalidation differently.
- Files default to class C (readable after first unlock). Write files with account data using `.completeFileProtection`, and plan for those files being unreadable while the device is locked.
