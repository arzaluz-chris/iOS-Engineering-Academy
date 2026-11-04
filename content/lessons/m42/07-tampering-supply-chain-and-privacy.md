---
id: m42-l07
title: Jailbreak detection, tampering, supply chain and privacy
description: "Know what an app can and can't defend on a device its owner controls. You see why jailbreak detection and obfuscation only raise an attacker's cost, use App Attest and DeviceCheck as signals your server verifies, review dependency changes in Package.resolved and binary SDK signatures, and connect privacy manifests and required-reason APIs to the security review. The lesson closes the module with Harbor Bank's controls mapped to MASVS."
module: m42
order: 7
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l06, m21-l04]
objectives:
  - Explain why client-side jailbreak detection, anti-tampering and obfuscation can be bypassed, and when they're still worth adding.
  - Describe the App Attest flow (key, attestation, assertions) and DeviceCheck's per-device bits, and what the server must verify.
  - Implement the server-side bookkeeping for assertions, one-time challenges and counters, and test it.
  - Review a Package.resolved diff for supply-chain risks and enforce resolved versions in CI.
  - Relate privacy manifests, required-reason APIs and SDK signatures to MASVS-PRIVACY and MASVS-CODE.
terms:
  - term: Jailbreak
    definition: "Removing iOS's restrictions so the device owner can run code outside the sandbox and modify other apps. It undermines platform controls the rest of MASVS relies on."
  - term: App Attest
    definition: "A DeviceCheck service (iOS 14) where the app generates a Secure Enclave key, Apple attests that it belongs to a genuine instance of your app, and the app then signs requests with it so your server can verify them."
  - term: Assertion
    definition: "An App Attest signature over a hash of client data that includes a server challenge. The server checks the signature, the challenge and a counter that must increase."
  - term: DeviceCheck bits
    definition: "Two per-device bits stored on Apple's servers, which your server reads and sets with a single-use token from DCDevice. Apple's examples: devices that already used a promotional offer, or that you've flagged as fraudulent."
  - term: Package.resolved
    definition: "SwiftPM's lock file. It pins each dependency's identity, location, version (or branch) and exact commit revision."
  - term: Software supply chain
    definition: "Everything that ends up in your binary that you didn't write: packages, binary SDKs, their dependencies, and the tools that build them."
mastery:
  - Explain to a product owner what a jailbreak detection SDK can and can't promise, and where its result should go.
  - Write the server-side checks for an App Attest assertion and explain each one's purpose.
  - Read a Package.resolved diff and flag changed sources, moved tags, branch pins and new dependencies.
  - Choose CI settings that make dependency resolution reproducible.
  - Map a banking app's controls to MASVS groups and name what's still client-side only.
resources: [owasp-masvs, owasp-mastg, privacy-manifest-files, swiftpm-docs, app-review-guidelines]
cards:
  - id: m42-l07-c1
    front: Why can't an app reliably detect that it's running on a jailbroken device?
    back: "The check runs inside a process the attacker controls, so it can be hooked or patched to return \"not jailbroken.\" OWASP: resilience measures \"cannot assure a 100% effectiveness.\" Apple: \"a compromised app can falsify the results.\" Treat the result as a hint for the server."
  - id: m42-l07-c2
    front: What does the server check on an App Attest assertion?
    back: "The signature over SHA-256(authenticatorData || SHA-256(clientData)) with the stored public key; the RP ID hash matches your App ID; the counter is greater than the last one; and the embedded challenge matches the one it issued."
  - id: m42-l07-c3
    front: When do App Attest keys stop working?
    back: "They survive app updates but not reinstallation, device migration or restoring from a backup. Then the app generates and attests a new key. Use one key per user account per device."
  - id: m42-l07-c4
    front: Two Package.resolved changes that deserve a security question in review?
    back: "A dependency's location changed (possible lookalike repository) and a version stayed the same while its revision changed (a moved tag). Also: new dependencies and branch pins."
  - id: m42-l07-c5
    front: How do you make CI use exactly the dependency versions you reviewed?
    back: "Commit Package.resolved and resolve with --force-resolved-versions (also spelled --disable-automatic-resolution or --only-use-versions-from-resolved-file), which fails if the file is out of date."
---

## The idea in one sentence

On a device its owner controls, any check that runs only in your app can be removed, so jailbreak detection and obfuscation are speed bumps; what actually protects a bank is evidence its server can verify (App Attest, Secure Enclave signatures) plus control over what code goes into the app in the first place.

> [!note] Sources and what was checked
> From OWASP: MASVS-RESILIENCE (the group page and controls 1 to 4), the MAS-R profile, MASVS-CODE-3, MASVS-PRIVACY 1 to 4, and MASTG-TEST-0240, 0241, 0273, 0275 and 0281. From Apple: the DeviceCheck overview, `DCAppAttestService` and its methods, "Establishing your app's integrity", "Validating apps that connect to your server", "Assessing fraud risk", `DCDevice` and "Accessing and modifying per-device data", "Verifying the origin of your XCFrameworks", `binaryTarget(name:url:checksum:)` and "Distributing binary frameworks as Swift packages", "Privacy manifest files", "Describing use of required reason API", and the "Third-party SDK requirements" page. All read in November 2026. SwiftPM's flags come from `swift build --help` and `swift package resolve --help` in the Swift 6.3 toolchain; the Package.resolved format from a file that toolchain generated. The DeviceCheck block was type-checked against the iOS SDK, not run. The verifier, the risk policy and the dependency review are pure Swift, compiled and run with Swift 6.3; all package names, URLs and revisions are invented.

## The attacker who owns the device

Lesson 1's profiles: MAS-L1 trusts the OS; MAS-L2 doesn't; MAS-R also treats "the primary user of the device" as the adversary. A customer who jailbreaks their own phone, or a fraudster with a jailbroken phone and a modified copy of your app, can read your app's memory, change its code, and call its functions with any arguments.

MASVS-RESILIENCE has four controls for that situation: validate platform integrity (1), anti-tampering (2), anti-static analysis such as obfuscation (3), and anti-dynamic analysis such as debugger and hook detection (4). OWASP is direct about their limits:

- "The absence of these measures does not in itself constitute a vulnerability."
- They "cannot assure a 100% effectiveness, as the reverse engineer will always have full access to the device and will therefore end up succeeding given enough time and resources."
- MAS-R "is meant to augment and not replace MAS-L1 and MAS-L2."
- And, from the group page: "Anti-tampering or obfuscation techniques must not be used as a substitute for proper security architecture."

Apple makes the same point when it explains App Attest: "You can't rely on your app's logic to perform security checks on itself because a compromised app can falsify the results."

### Jailbreak detection

MASTG-TEST-0240 describes what detection code typically looks for: "the app may check for the presence of a third-party app store (e.g. Sileo, Zebra, ...), or for the presence of certain files or directories that are indicative of a jailbroken device." Commercial SDKs add more checks of the same kind. Every one of them runs in your process, and the attacker can:

- hook the function that returns the result, or the system calls it uses;
- patch the binary so the check is skipped;
- use a jailbreak that hides its files from apps.

That's why the useful question isn't "can we detect jailbreaks?" but "what do we do with a signal that's sometimes wrong and sometimes forged?" Reasonable answers for a bank:

- **Report it, don't decide with it.** Send the result to the server as one input to fraud scoring, next to signals the server can verify.
- **Don't block on it alone.** False positives lock out legitimate customers (OWASP's group page warns that detection can produce "false positives, potentially excluding legitimate users"), and true positives only stop attackers who didn't bother to bypass it.
- **Use it to raise cost where cost matters.** If your threat model has an attacker automating fraud with modified app copies, making each new copy take more work has value. That's the honest pitch for MAS-R measures, and for obfuscation of security-relevant code (MASTG-TEST-0391).

The same applies to debugger detection, hook detection and integrity checks of your own binary: they make analysis slower, and they can be removed.

## Signals the server can verify

The way out is to move the decision to a place the attacker doesn't control, and give it evidence that's hard to forge. Apple's DeviceCheck framework has two services for that.

### App Attest

From Apple's overview: "You use the `DCAppAttestService` class to generate a special cryptographic key on the device, and have Apple attest to the validity of that key. You then use that key to assert the validity of your app whenever you request sensitive data from your server." The private key lives in the Secure Enclave, "from where no process can ever directly read or modify it."

The flow, from "Establishing your app's integrity" and "Validating apps that connect to your server":

1. **Check support.** `isSupported` is `false` on Macs (including iOS apps on Apple silicon) and in most extensions. Apple: "gracefully bypass the service" and change the server to stop requiring assertions for that client.
2. **Generate a key** with `generateKey()`, once per user account per device. Apple: "Don't reuse a key among multiple users on a device because this weakens security protections." Store the key ID; "there's no way to use the key without the identifier, and no way to get the identifier later."
3. **Attest it.** Get a one-time challenge from your server ("at least 16 bytes"), hash it, call `attestKey(_:clientDataHash:)`, and send the attestation object and key ID to the server. The server validates the certificate chain up to Apple's App Attest root, the nonce, the App ID hash, a counter of 0 and the environment, then stores the public key for that user and device. "A compromised version of your app could falsify the verification result," so this validation only happens on the server.
4. **Assert per sensitive request.** Get a fresh challenge, build client data containing the request and the challenge, and call `generateAssertion(_:clientDataHash:)`. The server checks the signature with the stored public key, the App ID hash, that "the authenticator data's counter value is greater than the value from the previous assertion," and that the challenge matches.
5. **Start over** when the key disappears: keys "remain valid through regular app updates, but don't survive app reinstallation, device migration, or restoration of a device from a backup."

On the device it's a few calls:

```swift ios
import CryptoKit
import DeviceCheck
import Foundation

enum AppAttestError: Error {
    case unsupported
}

/// Once per user account on this device. Send `keyID` and `attestation` to the server,
/// which verifies the attestation with Apple's root certificate and stores the public key.
func registerAppAttestKey(serverChallenge: Data) async throws -> (keyID: String, attestation: Data) {
    let service = DCAppAttestService.shared
    guard service.isSupported else { throw AppAttestError.unsupported }
    let keyID = try await service.generateKey()
    let clientDataHash = Data(SHA256.hash(data: serverChallenge))
    let attestation = try await service.attestKey(keyID, clientDataHash: clientDataHash)
    return (keyID, attestation)
}

/// For each sensitive request: `clientData` contains the request body and a fresh server challenge.
func assertion(for clientData: Data, keyID: String) async throws -> Data {
    let clientDataHash = Data(SHA256.hash(data: clientData))
    return try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
}

/// DeviceCheck: a single-use token your server exchanges with Apple to read or set two bits for this device.
func deviceCheckToken() async throws -> Data? {
    guard DCDevice.current.isSupported else { return nil }
    return try await DCDevice.current.generateToken()
}
```

- The async forms of `generateKey`, `attestKey` and `generateAssertion` are the Swift translations Apple's pages mention for the completion-handler methods.
- If `attestKey` fails with `serverUnavailable`, Apple says to "retry attestation again using the same key and client data hash later"; for any other error, discard the key ID and generate a new key next time.
- **Know what it doesn't prove.** Apple: "App Attest can't definitively pinpoint a device with a compromised operating system." A modified OS could, with effort, misuse a genuine app's key; Apple's "Assessing fraud risk" adds a server-to-server receipt with a metric, "the number of attested keys associated with a given device over the past 30 days," where a high number can indicate one compromised device serving many fake clients.

### The server's bookkeeping

Most of the assertion checks are cryptography the server does with standard libraries. The part that's easy to get wrong is the state: one-time challenges, their lifetime, the counter, and which user a key belongs to. As a model, with the signature check reduced to a Boolean:

```swift
// Server-side bookkeeping for App Attest assertions, after the cryptographic checks.
// `signatureValid` stands in for verifying the signature with the stored public key.
struct Assertion {
    let keyID: String
    let challenge: String
    let counter: UInt32
    let signatureValid: Bool
}

enum Verdict: Equatable {
    case accepted
    case rejected(String)
}

struct AttestedKey {
    let userID: String
    var lastCounter: UInt32
}

final class AssertionVerifier {
    private var keys: [String: AttestedKey]
    private var openChallenges: [String: Int]       // challenge -> time it was issued (seconds)
    private let challengeLifetime = 300

    init(keys: [String: AttestedKey], openChallenges: [String: Int]) {
        self.keys = keys
        self.openChallenges = openChallenges
    }

    func verify(_ assertion: Assertion, from userID: String, now: Int) -> Verdict {
        guard var key = keys[assertion.keyID] else { return .rejected("unknown key") }
        guard key.userID == userID else { return .rejected("key belongs to another user") }
        guard assertion.signatureValid else { return .rejected("bad signature") }
        guard let issued = openChallenges.removeValue(forKey: assertion.challenge) else {
            return .rejected("challenge unknown or already used")
        }
        guard now - issued <= challengeLifetime else { return .rejected("challenge expired") }
        guard assertion.counter > key.lastCounter else { return .rejected("counter did not increase") }
        key.lastCounter = assertion.counter
        keys[assertion.keyID] = key
        return .accepted
    }
}

let verifier = AssertionVerifier(
    keys: ["key-9f2": AttestedKey(userID: "u-17", lastCounter: 4)],
    openChallenges: ["c-01": 1_000, "c-02": 1_000, "c-03": 1_000, "c-04": 500])

let attempts: [(String, Assertion, String, Int)] = [
    ("normal transfer", Assertion(keyID: "key-9f2", challenge: "c-01", counter: 5, signatureValid: true), "u-17", 1_030),
    ("replayed request", Assertion(keyID: "key-9f2", challenge: "c-01", counter: 5, signatureValid: true), "u-17", 1_040),
    ("old counter", Assertion(keyID: "key-9f2", challenge: "c-02", counter: 5, signatureValid: true), "u-17", 1_050),
    ("another user's key", Assertion(keyID: "key-9f2", challenge: "c-03", counter: 6, signatureValid: true), "u-88", 1_060),
    ("stale challenge", Assertion(keyID: "key-9f2", challenge: "c-04", counter: 7, signatureValid: true), "u-17", 1_070),
    ("tampered body", Assertion(keyID: "key-9f2", challenge: "c-03", counter: 8, signatureValid: false), "u-17", 1_080),
    ("next transfer", Assertion(keyID: "key-9f2", challenge: "c-03", counter: 9, signatureValid: true), "u-17", 1_090),
]
for (label, assertion, user, now) in attempts {
    print(label + ":", verifier.verify(assertion, from: user, now: now))
}
```

```output
normal transfer: accepted
replayed request: rejected("challenge unknown or already used")
old counter: rejected("counter did not increase")
another user's key: rejected("key belongs to another user")
stale challenge: rejected("challenge expired")
tampered body: rejected("bad signature")
next transfer: accepted
```

Why each check exists:

- **Key belongs to the user.** Apple asks you to store the key "with the user for the specific device" and to "make sure that the public key doesn't already have an association with another user." A key attested for one account can't authorize another account's transfer.
- **Signature before state changes.** A forged request (bad signature) doesn't consume the challenge, so an attacker can't burn your customer's challenges by sending junk.
- **One-time challenges.** `removeValue` both checks and consumes. The replay fails even though its signature is valid, because it's the same challenge.
- **Expiry.** A challenge issued long ago is rejected. Five minutes here; pick what fits your flows.
- **Counter.** It must be greater than the last accepted one. The "old counter" attempt also burned challenge `c-02`: a challenge gets one valid-signature attempt, which is the conservative choice.

The real verifier must also check the RP ID hash against your App ID, and the `validationCategory` and `bundleVersion` extensions Apple lists. Apple's "Attestation Object Validation Guide" is the reference to test it against.

### DeviceCheck bits

`DCDevice` is older (iOS 11) and simpler: your server sends Apple a single-use token from the app and can read or set "two binary digits of data per device, while maintaining user privacy." The bits are kept by Apple, not by your app. Apple's examples: "identify devices that have already taken advantage of a promotional offer that you provide, or to flag a device that you've determined to be fraudulent." You decide what the bits mean and when to reset them, "for example, when a user sells the device to someone else." Treat each token as single-use. DeviceCheck says nothing about app integrity; it's a per-device memory.

### Putting the signals together

None of these is a verdict on its own. The server combines them with what it already knows (amount, payee history, device history) into a decision. Exercise 5 writes a small policy: a failed assertion blocks, the unsupported case and a client-reported jailbreak only add risk, and risk leads to step-up authentication before it leads to blocking.

## The supply chain

MASVS-CODE-3: "The app only uses software components without known vulnerabilities." Its MASWE list includes MASWE-0044, "Dependencies with Known Vulnerabilities," and MASWE-0048, "Malicious Code Included in the App." A dependency runs in your process with every permission your app has: Keychain access, network, the data on screen. Lesson 1 listed "a compromised dependency" as an attacker for that reason.

### Package.resolved

SwiftPM's `Package.resolved` pins every dependency. Generated by the Swift 6.3 toolchain, an entry looks like this (version 3 of the format):

```json
{
  "originHash" : "…",
  "pins" : [
    {
      "identity" : "money-format",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/example/money-format.git",
      "state" : {
        "revision" : "3333333ccccccc…",
        "version" : "2.0.0"
      }
    }
  ],
  "version" : 3
}
```

The `revision` is the exact commit. The `version` is the tag that pointed to it when it was resolved. That gives you two rules:

- **Commit it**, for apps. It's what makes two builds use the same code.
- **Make CI refuse to change it.** `swift package resolve --help` lists `--force-resolved-versions` (also spelled `--disable-automatic-resolution` and `--only-use-versions-from-resolved-file`): "Only use versions from the Package.resolved file and fail resolution if it is out-of-date." Then a dependency only changes in a pull request someone reviewed.

And read the diff when it changes. A review aid as code:

```swift
import Foundation

struct Resolved: Decodable {
    struct Pin: Decodable {
        struct State: Decodable {
            let revision: String
            let version: String?
            let branch: String?
        }
        let identity: String
        let location: String
        let state: State
    }
    let pins: [Pin]
    let version: Int
}

func review(old: Resolved, new: Resolved) -> [String] {
    let before = Dictionary(uniqueKeysWithValues: old.pins.map { ($0.identity, $0) })
    let after = Dictionary(uniqueKeysWithValues: new.pins.map { ($0.identity, $0) })
    var notes: [String] = []
    for identity in Set(before.keys).union(after.keys).sorted() {
        switch (before[identity], after[identity]) {
        case (nil, let added?):
            notes.append("ADDED \(identity) \(added.state.version ?? "no version") from \(added.location)")
        case (_?, nil):
            notes.append("REMOVED \(identity)")
        case (let old?, let new?):
            if old.location != new.location {
                notes.append("SOURCE CHANGED \(identity): \(old.location) -> \(new.location)")
            }
            if new.state.version == nil {
                notes.append("UNVERSIONED \(identity): tracks branch \(new.state.branch ?? "?") at \(new.state.revision.prefix(7))")
            } else if old.state.version == new.state.version && old.state.revision != new.state.revision {
                notes.append("SAME VERSION, NEW COMMIT \(identity) \(new.state.version!): \(old.state.revision.prefix(7)) -> \(new.state.revision.prefix(7))")
            } else if old.state.version != new.state.version {
                notes.append("updated \(identity) \(old.state.version ?? "?") -> \(new.state.version!)")
            }
        case (nil, nil):
            break
        }
    }
    return notes
}

let main = """
{ "pins" : [
  { "identity" : "charts-kit", "kind" : "remoteSourceControl", "location" : "https://github.com/example/charts-kit.git",
    "state" : { "revision" : "1111111aaaaaaa", "version" : "3.1.0" } },
  { "identity" : "keychain-helpers", "kind" : "remoteSourceControl", "location" : "https://github.com/example/keychain-helpers.git",
    "state" : { "revision" : "2222222bbbbbbb", "version" : "1.4.2" } },
  { "identity" : "money-format", "kind" : "remoteSourceControl", "location" : "https://github.com/example/money-format.git",
    "state" : { "revision" : "3333333ccccccc", "version" : "2.0.0" } }
], "version" : 3 }
"""
let pullRequest = """
{ "pins" : [
  { "identity" : "charts-kit", "kind" : "remoteSourceControl", "location" : "https://github.com/example/charts-kit.git",
    "state" : { "revision" : "4444444ddddddd", "version" : "3.2.0" } },
  { "identity" : "keychain-helpers", "kind" : "remoteSourceControl", "location" : "https://github.com/examp1e/keychain-helpers.git",
    "state" : { "revision" : "5555555eeeeeee", "version" : "1.4.2" } },
  { "identity" : "money-format", "kind" : "remoteSourceControl", "location" : "https://github.com/example/money-format.git",
    "state" : { "revision" : "6666666fffffff", "branch" : "main" } },
  { "identity" : "analytics-lite", "kind" : "remoteSourceControl", "location" : "https://github.com/example/analytics-lite.git",
    "state" : { "revision" : "7777777aaaaaaa", "version" : "0.9.1" } }
], "version" : 3 }
"""

do {
    let old = try JSONDecoder().decode(Resolved.self, from: Data(main.utf8))
    let new = try JSONDecoder().decode(Resolved.self, from: Data(pullRequest.utf8))
    for note in review(old: old, new: new) { print(note) }
} catch {
    print("not a Package.resolved:", error)
}
```

```output
ADDED analytics-lite 0.9.1 from https://github.com/example/analytics-lite.git
updated charts-kit 3.1.0 -> 3.2.0
SOURCE CHANGED keychain-helpers: https://github.com/example/keychain-helpers.git -> https://github.com/examp1e/keychain-helpers.git
SAME VERSION, NEW COMMIT keychain-helpers 1.4.2: 2222222 -> 5555555
UNVERSIONED money-format: tracks branch main at 6666666
```

Each line is a question for the pull request's author:

- **ADDED**: who maintains it, what does it collect (privacy manifest, below), and does it need to be in a banking app at all?
- **updated**: normal, but read the release notes, and check for known vulnerabilities in the version you're moving to (MASTG-TEST-0273 and 0275 scan dependency files and SBOMs for that).
- **SOURCE CHANGED**: `examp1e` with a digit one. The identity stays `keychain-helpers` because SwiftPM derives it from the last path component, so a lookalike repository slips in under the same name. Reject unless there's an explanation.
- **SAME VERSION, NEW COMMIT**: the tag `1.4.2` now points somewhere else. Tags can be moved; a moved tag in a security-relevant package is a red flag.
- **UNVERSIONED**: a branch pin follows whatever is pushed next. Fine for your own packages during development, not for a release.

The model reads only fields shown above; `kind` and `originHash` are ignored. The sample files are trimmed versions of the real format.

### Binary SDKs

Some SDKs ship as binaries (XCFrameworks), where you can't read the code. Two protections exist:

- **Checksums for SwiftPM binary targets.** `binaryTarget(name:url:checksum:)` requires a checksum, computed with `swift package compute-checksum`. Apple: when "the remote archive's checksum doesn't match the checksum in the package manifest, Xcode displays an error."
- **Signature verification in Xcode.** Apple's "Verifying the origin of your XCFrameworks": Xcode records who signed an XCFramework, and "the build system fails with an error if the code signature's subsequently removed, becomes invalid, or a different developer signs an update." The error reads "[XCFramework name] is not signed with the expected identity and may have been compromised." Apple's advice if nobody can explain the change: restore the expected version or remove the framework, and "audit your software development and deployment environment carefully."

Apple also requires, for a list of commonly used SDKs, both "the privacy manifest for any SDK listed" and, "where the listed SDKs are used as binary dependencies," signatures. Module 21 covered the dates.

## Privacy manifests, from the security side

Module 21 covered privacy manifests (`PrivacyInfo.xcprivacy`) and required-reason APIs, and Module 41 the App Store privacy details. Three security-relevant points to add:

- **They're the supply chain's privacy report.** Apple's SDK requirements page: "When you prepare to distribute your app, Xcode will combine the privacy manifests across all the third-party SDKs used by your app into a single, easy-to-use report." Read it when `Package.resolved` gains a dependency. An SDK that declares tracking domains or data collection you didn't expect is a finding.
- **Required-reason APIs exist because of fingerprinting.** File timestamps, boot time, disk space, keyboards and user defaults can be combined into a device identifier. Apple's rule: declared reasons "must be consistent with your app's functionality," and "you may not use the APIs or derived data for tracking." Fraud teams sometimes want exactly such signals; MASVS-PRIVACY-2 says a fingerprint used for fraud detection "should be isolated and not repurposed for audience measurement."
- **MASVS-PRIVACY is part of the standard.** PRIVACY-1 "minimizes access to sensitive data and resources" (including making "third-party SDKs operate based on user consent, not by default"); PRIVACY-3 "is transparent about data collection and usage"; PRIVACY-4 "offers user control over their data." MASTG-TEST-0281, "Undeclared Known Tracking Domains," is a P-profile test a reviewer can run against your manifest.

## Harbor Bank, end to end

The module's controls, mapped back to Lesson 1:

| Threat | Control | Where | MASVS |
| --- | --- | --- | --- |
| T1 token copied from a file | Keychain, `AfterFirstUnlockThisDeviceOnly` | Lesson 2 | STORAGE-1 |
| T2 traffic through a rogue CA | ATS defaults, CA-key pinning with backup | Lesson 4 | NETWORK-1, -2 |
| T3 link sends money | Links produce drafts; confirmation required | Lesson 6 | PLATFORM-1, CODE-4 |
| T4 someone else approves | Secure Enclave key with `.biometryCurrentSet`, signature verified by the server | Lessons 2, 3 | AUTH-2, AUTH-3 |
| T5 account number in logs | Privacy options, redaction, allowlisted telemetry | Lesson 5 | STORAGE-2 |
| T6 balance in the snapshot | Privacy cover, `privacySensitive` | Lesson 5 | PLATFORM-3 |
| T7 repackaged app | App Attest assertions verified by the server; client signals as risk input | This lesson | RESILIENCE-1, -2 |
| T8 disputed transfer | Signed approvals with server challenge, stored by the server | Lessons 3, 7 | AUTH-3 |

Every row whose last line of defense is the server is a control a modified app can't remove. The rows that are client-only (T5, T6) protect against accidents and bystanders, which is what they're for.

## Common mistakes

> [!error] Blocking customers on a jailbreak check alone
> It stops honest people with false positives and lets through anyone who hooks the check. Send it to the server as a risk signal.

> [!error] Verifying App Attest in the app
> Apple: "A compromised version of your app could falsify the verification result." Attestations and assertions are verified on your server, which also keeps the counter and challenges.

> [!error] One App Attest key for every account on the device
> Apple says to create a key per user account per device; sharing one makes it hard to detect a compromised device serving many accounts.

> [!error] Not committing Package.resolved, or letting CI update it
> Then the release build may contain code nobody reviewed. Commit it and resolve with `--force-resolved-versions`.

> [!error] Accepting an XCFramework signature change without asking
> Xcode's error says the framework "may have been compromised." Confirm the change with the vendor before clicking Accept Change.

## Exercises

````exercise
id: m42-l07-e1
type: prediction
prompt: "A simplified assertion check keeps the last counter and the used challenges. What does it print?"
code: |
  struct AssertionState {
      var lastCounter: UInt32 = 4
      var usedChallenges: Set<String> = []

      mutating func accept(counter: UInt32, challenge: String) -> Bool {
          guard !usedChallenges.contains(challenge), counter > lastCounter else { return false }
          usedChallenges.insert(challenge)
          lastCounter = counter
          return true
      }
  }

  var state = AssertionState()
  print(state.accept(counter: 5, challenge: "a"))
  print(state.accept(counter: 6, challenge: "a"))
  print(state.accept(counter: 5, challenge: "b"))
  print(state.accept(counter: 9, challenge: "b"))
  print(state.lastCounter, state.usedChallenges.count)
output: |
  true
  false
  false
  true
  9 2
hints:
  - "A rejected call doesn't change the state in this version."
  - "After the first call, lastCounter is 5."
solution: |
  ```output
  true
  false
  false
  true
  9 2
  ```

  1. Counter 5 > 4 and `a` is new: accepted; the state is now 5 and `{a}`.
  2. `a` was used: rejected (a replay).
  3. Counter 5 isn't greater than 5: rejected. Because both conditions are checked before anything changes, `b` is not consumed.
  4. Counter 9 > 5 and `b` is still unused: accepted.
  5. The last counter is 9 and two challenges were used.

  The lesson's verifier differs on step 3: it consumes the challenge once the signature is valid, even if the counter check then fails. Either is defensible; consuming is stricter (one try per challenge). Counters don't have to increase by one: App Attest's counter counts every assertion the key made, including ones your server never saw.
````

````exercise
id: m42-l07-e2
type: comprehension
prompt: "A vendor pitches a jailbreak detection SDK with \"100% protection against compromised devices.\" Which response matches OWASP's and Apple's documentation?"
choices:
  - text: "Detection runs inside a process the attacker controls, so it can be bypassed; at best it raises cost, and its result should feed server-side risk decisions."
    correct: true
    why: "OWASP: resilience measures \"cannot assure a 100% effectiveness\"; Apple: \"a compromised app can falsify the results.\""
  - text: "With the SDK, MASVS-L2 controls become unnecessary."
    correct: false
    why: "OWASP: MAS-R \"is meant to augment and not replace MAS-L1 and MAS-L2.\""
  - text: "Without the SDK the app fails MASVS, because the absence of jailbreak detection is a vulnerability."
    correct: false
    why: "OWASP: \"The absence of these measures does not in itself constitute a vulnerability.\""
  - text: "App Attest makes jailbreak detection unnecessary because it detects compromised operating systems."
    correct: false
    why: "Apple: \"App Attest can't definitively pinpoint a device with a compromised operating system.\""
solution: |
  **It raises cost and should feed the server.** The four quotes are the module's position in one place:

  - OWASP on resilience: "cannot assure a 100% effectiveness, as the reverse engineer will always have full access to the device."
  - OWASP on MAS-R: "meant to augment and not replace MAS-L1 and MAS-L2."
  - OWASP: absence "does not in itself constitute a vulnerability."
  - Apple on App Attest: it "can't definitively pinpoint a device with a compromised operating system."

  Whether to buy the SDK is a threat-model decision: is automated fraud with modified apps a ranked threat, and does making each attempt more expensive change the numbers?
````

````exercise
id: m42-l07-e3
type: fill-in
prompt: "Complete the App Attest calls."
code: |
  let service = DCAppAttestService.shared
  guard service.[[1]] else { return }
  let keyID = try await service.[[2]]()
  let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: challenge)))
  // ... later, per sensitive request:
  let assertion = try await service.[[3]](keyID, clientDataHash: Data(SHA256.hash(data: clientData)))
blanks:
  - id: "1"
    answers: ["isSupported"]
  - id: "2"
    answers: ["generateKey"]
  - id: "3"
    answers: ["generateAssertion"]
solution: |
  ```swift illustrative
  let service = DCAppAttestService.shared
  guard service.isSupported else { return }
  let keyID = try await service.generateKey()
  let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: challenge)))
  // ... later, per sensitive request:
  let assertion = try await service.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: clientData)))
  ```

  `isSupported` first, because Macs and most extensions don't support the service. `generateKey()` once per user account per device; keep the ID. `attestKey` once, with a hash of a server challenge. `generateAssertion` for each sensitive request, with a hash of client data that includes a fresh challenge. Both objects go to the server, which does all the verification. The lesson's `registerAppAttestKey` and `assertion(for:keyID:)` are the type-checked versions; this fragment depends on `challenge` and `clientData` from elsewhere.
````

````exercise
id: m42-l07-e4
type: find-errors
prompt: "A pull request adds \"device integrity\" to Harbor Bank. Mark every real problem."
code: |
  // App
  if JailbreakDetector.isJailbroken() { exit(0) }
  let keyID = UserDefaults.standard.string(forKey: "attestKey") ?? (try await DCAppAttestService.shared.generateKey())
  let attestation = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data("harbor".utf8))))
  let verified = AttestationValidator.validate(attestation)      // runs in the app
  api.headers["X-Device-Trusted"] = verified ? "1" : "0"

  // Server
  if request.headers["X-Device-Trusted"] == "1" { allowTransfer() }
choices:
  - text: "exit(0) on a jailbreak signal blocks legitimate users on false positives and is trivially bypassed."
    correct: true
  - text: "The attestation uses a constant client data hash instead of a one-time server challenge, so it can be replayed."
    correct: true
  - text: "The attestation is validated in the app, which a compromised app can falsify."
    correct: true
  - text: "The server trusts a header the client sets."
    correct: true
  - text: "isSupported isn't checked before using the service."
    correct: true
  - text: "Storing the App Attest key ID in UserDefaults exposes the private key."
    correct: false
    why: "The key ID is only an identifier; the private key stays in the Secure Enclave. Apple suggests persisting the ID (for example, in a file)."
rubric:
  - I flagged the exit on jailbreak.
  - I flagged the constant challenge.
  - I flagged validation in the app and the trusted header.
  - I flagged the missing isSupported check.
solution: |
  Five problems:

  1. **`exit(0)`.** The app vanishes without explanation, false positives lock out customers, and the check is easy to patch. Report the signal instead.
  2. **Constant client data.** `"harbor"` makes every attestation identical in what it binds to. Apple: embed "the hash of a unique, one-time challenge from your server."
  3. **Validation in the app.** Apple: "A compromised version of your app could falsify the verification result." Send the attestation and key ID to the server.
  4. **`X-Device-Trusted`.** The server is trusting a value the client chose. Anyone can send `1`. The server must verify the attestation and then assertions itself.
  5. **No `isSupported` check.** On unsupported devices `generateKey` fails; handle that case explicitly.

  Persisting the key ID is correct and expected; Apple's own article says to record it because there's "no way to get the identifier later."
````

````exercise
id: m42-l07-e5
type: solve
prompt: |
  Write `decide(_:)` for a transfer. A failed server-verified assertion (`false`) blocks immediately. Otherwise add one risk point each for: App Attest unsupported (`nil`), a client-reported jailbreak, a new device for the account, and an amount of 100,000 cents or more. Zero points allows, one or two require step-up authentication, three or more block.

  Expected output:

  ```output
  rent, attested, known device: step-up
  coffee, attested: allow
  coffee, assertion failed: block
  coffee, jailbreak hint: step-up
  large, no App Attest, new device: block
  ```
starter: |
  struct TransferContext {
      let amountInCents: Int
      let assertionVerified: Bool?       // nil: App Attest isn't supported on this device
      let clientSaysJailbroken: Bool     // reported by the app, so an attacker can flip it
      let newDeviceForAccount: Bool
  }

  enum Decision: String {
      case allow
      case stepUp = "step-up"
      case block
  }

  func decide(_ context: TransferContext) -> Decision {
      // your code
      return .allow
  }

  let transfers = [
      ("rent, attested, known device", TransferContext(amountInCents: 120_000, assertionVerified: true, clientSaysJailbroken: false, newDeviceForAccount: false)),
      ("coffee, attested", TransferContext(amountInCents: 450, assertionVerified: true, clientSaysJailbroken: false, newDeviceForAccount: false)),
      ("coffee, assertion failed", TransferContext(amountInCents: 450, assertionVerified: false, clientSaysJailbroken: false, newDeviceForAccount: false)),
      ("coffee, jailbreak hint", TransferContext(amountInCents: 450, assertionVerified: true, clientSaysJailbroken: true, newDeviceForAccount: false)),
      ("large, no App Attest, new device", TransferContext(amountInCents: 500_000, assertionVerified: nil, clientSaysJailbroken: false, newDeviceForAccount: true)),
  ]
  for (label, context) in transfers {
      print(label + ":", decide(context).rawValue)
  }
hints:
  - "Compare the optional Bool directly: `context.assertionVerified == false` is true only for a failed assertion, not for nil."
  - "Count points in a variable, then switch on it."
rubric:
  - Blocks on a failed assertion and treats nil as a risk point, not a failure.
  - Treats the jailbreak report as one point, never as an automatic block.
  - Prints the five expected lines.
solution: |
  ```swift
  struct TransferContext {
      let amountInCents: Int
      let assertionVerified: Bool?       // nil: App Attest isn't supported on this device
      let clientSaysJailbroken: Bool     // reported by the app, so an attacker can flip it
      let newDeviceForAccount: Bool
  }

  enum Decision: String {
      case allow
      case stepUp = "step-up"
      case block
  }

  func decide(_ context: TransferContext) -> Decision {
      if context.assertionVerified == false { return .block }         // verified on the server
      var risk = 0
      if context.assertionVerified == nil { risk += 1 }
      if context.clientSaysJailbroken { risk += 1 }                   // a hint, never a verdict
      if context.newDeviceForAccount { risk += 1 }
      if context.amountInCents >= 100_000 { risk += 1 }
      switch risk {
      case 0: return .allow
      case 1, 2: return .stepUp
      default: return .block
      }
  }

  let transfers = [
      ("rent, attested, known device", TransferContext(amountInCents: 120_000, assertionVerified: true, clientSaysJailbroken: false, newDeviceForAccount: false)),
      ("coffee, attested", TransferContext(amountInCents: 450, assertionVerified: true, clientSaysJailbroken: false, newDeviceForAccount: false)),
      ("coffee, assertion failed", TransferContext(amountInCents: 450, assertionVerified: false, clientSaysJailbroken: false, newDeviceForAccount: false)),
      ("coffee, jailbreak hint", TransferContext(amountInCents: 450, assertionVerified: true, clientSaysJailbroken: true, newDeviceForAccount: false)),
      ("large, no App Attest, new device", TransferContext(amountInCents: 500_000, assertionVerified: nil, clientSaysJailbroken: false, newDeviceForAccount: true)),
  ]
  for (label, context) in transfers {
      print(label + ":", decide(context).rawValue)
  }
  ```

  ```output
  rent, attested, known device: step-up
  coffee, attested: allow
  coffee, assertion failed: block
  coffee, jailbreak hint: step-up
  large, no App Attest, new device: block
  ```

  The asymmetry is the lesson: a failed assertion is evidence the server verified, so it's decisive; "unsupported" and "the client says jailbroken" are weak signals, so they only add risk. A real policy would weigh signals differently, learn from fraud outcomes and log every decision with its reasons (for disputes and audits), but it would keep that distinction.

  This runs on the server. If it ran in the app, a modified app would simply return `.allow`.
````

````exercise
id: m42-l07-e6
type: design
prompt: "Your team is about to add a third-party fraud-detection SDK (binary XCFramework) to Harbor Bank. Write the review checklist you'd run before merging, covering supply chain, privacy and how its output is used."
rubric:
  - Covers provenance (official source, signature recorded by Xcode, checksum for a binary target) and pinned versions in Package.resolved.
  - Covers the SDK's privacy manifest, required-reason APIs, tracking domains, consent and App Store privacy details.
  - Covers known vulnerabilities and what permissions and data the SDK can reach in the process.
  - Says the SDK's verdict goes to the server as a signal, with a defined behavior when the SDK fails.
solution: |
  **Provenance.** Obtained from the vendor's documented source; added as a SwiftPM binary target with a checksum (`swift package compute-checksum`) or as an XCFramework whose signing team Xcode records; the signing identity matches the vendor's published team. Pinned in `Package.resolved`; CI resolves with `--force-resolved-versions`. A future "not signed with the expected identity" error is escalated, not accepted.

  **Privacy.** The SDK ships a privacy manifest; we read the data types, tracking flag and tracking domains in Xcode's privacy report and update our App Store privacy details and our own manifest. Required-reason APIs it uses have reasons consistent with fraud prevention, and its fingerprinting signals are not shared with analytics (MASVS-PRIVACY-2). It doesn't initialize before our consent flow if it collects anything that requires consent.

  **Security.** No known vulnerabilities in the version (checked against an advisory database or the vendor's security notes); release notes reviewed. We list what it can reach in-process: network, Keychain items of our access group, the UI. It gets no tokens or customer data beyond what its contract requires.

  **Use of its output.** The SDK's result is sent to our server as one signal in the transfer risk policy (like Exercise 5), never as a local block. If the SDK crashes, times out or is missing (a modified app), the server sees no signal and treats that as risk, not as "clean." We monitor its error rate by app version.

  **Threat model.** The new entry ("compromised dependency with process access") goes into the module's table with a score and these mitigations, and the SDK's MASTG-relevant behavior (network pinning, logging) is checked like our own code.
````

## Summary

- On a device its owner controls, jailbreak detection, anti-tampering and obfuscation run inside the attacker's process. OWASP: they're not a vulnerability when absent, can't be 100% effective, and augment MAS-L1/L2 rather than replace them. Use their results as server-side risk signals.
- App Attest gives the server verifiable evidence: a Secure Enclave key attested by Apple, then assertions over client data with a one-time challenge and an increasing counter. Verify everything on the server, use one key per user per device, and plan for keys lost on reinstall, migration or restore. DeviceCheck adds two per-device bits, stored by Apple, for things like one-time offers and fraud flags.
- Commit `Package.resolved`, resolve with `--force-resolved-versions` in CI, and review every change: new dependencies, changed sources, moved tags and branch pins. Binary SDKs need checksums and a stable signing identity, which Xcode enforces.
- Privacy manifests from SDKs combine into Xcode's privacy report; required-reason APIs exist to stop fingerprinting, and MASVS-PRIVACY covers minimization, unlinkability, transparency and control.
- Harbor Bank's strongest controls are the ones whose last check is on the server: signed approvals, attested requests and enforced limits. Client-side controls protect against accidents and bystanders, which is still worth doing.
