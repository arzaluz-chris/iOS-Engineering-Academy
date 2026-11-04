---
id: m42-l04
title: Network security, ATS and pinning
description: "Keep data in transit protected and decide when pinning is worth its cost. You learn what App Transport Security enforces by default and which exceptions App Review asks you to justify, audit an ATS configuration, pin CA public keys with NSPinnedDomains or in a URLSessionDelegate, plan pin rotation so you don't lock out your own customers, and remember why no network setting hides a secret compiled into the app."
module: m42
order: 4
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l03, m30-l05]
objectives:
  - List what App Transport Security requires by default and where it doesn't apply.
  - Audit an NSAppTransportSecurity dictionary and say which exceptions need a justification in App Review.
  - Explain certificate vs public-key pinning and leaf vs CA pinning, and what pinning does and doesn't protect against.
  - Configure NSPinnedDomains and implement equivalent pinning in a URLSessionDelegate that keeps default trust evaluation.
  - Plan pin rotation with backup keys and measure which app versions a certificate change would break.
  - Explain why API secrets in the binary stay exposed regardless of TLS or pinning.
terms:
  - term: App Transport Security (ATS)
    definition: "The system policy that requires HTTPS with TLS 1.2 or later, forward secrecy and strong certificates for connections made through the URL Loading System (URLSession and web views), unless Info.plist adds exceptions."
  - term: Pinning
    definition: "Limiting which server identities the app accepts to a set you ship with it, on top of normal certificate validation. Apple's ATS form pins public keys (SPKI SHA-256 digests) of CA or leaf certificates."
  - term: SPKI
    definition: "SubjectPublicKeyInfo: the DER-encoded public key structure inside an X.509 certificate. Pinning its SHA-256 digest survives certificate renewal with the same key."
  - term: NSPinnedDomains
    definition: "An ATS Info.plist key (iOS 14 and later) mapping domains to pinned CA identities, leaf identities, or both, each given as SPKI-SHA256-BASE64."
  - term: Server trust evaluation
    definition: "The default check that a server's certificate chains to a trusted root, matches the host name, hasn't expired and is correctly signed. Pinning can only add to it, never replace it."
mastery:
  - Read an Info.plist and list every ATS weakening, with which ones App Review will ask about.
  - Write an NSPinnedDomains entry that pins two CA keys for an API domain and its direct subdomains.
  - Implement a URLSessionDelegate that evaluates trust first and then checks pinned keys, without ever accepting an unevaluated trust.
  - Given app versions and a planned certificate change, compute which versions break and decide whether to ship new pins first.
  - Explain to a teammate why moving an API key into an obfuscated string doesn't fix a leaked secret.
resources: [foundation-urlsession, information-property-list, owasp-mastg, owasp-masvs, apple-platform-security]
cards:
  - id: m42-l04-c1
    front: What does ATS require by default?
    back: "HTTPS with TLS 1.2 or later, AES-128 or AES-256, forward secrecy through ECDHE, and a server certificate with an RSA key of at least 2048 bits or an ECC key of at least 256 bits, signed with SHA-256 or better. It applies to the URL Loading System, not to Network framework or CFNetwork calls."
  - id: m42-l04-c2
    front: Which ATS exceptions does Apple say need a justification?
    back: "NSAllowsArbitraryLoads, NSAllowsArbitraryLoadsForMedia, NSAllowsArbitraryLoadsInWebContent, NSExceptionAllowsInsecureHTTPLoads and NSExceptionMinimumTLSVersion."
  - id: m42-l04-c3
    front: In NSPinnedDomains, what does NSIncludesSubdomains cover?
    back: "The domain plus subdomains with one more label: example.org covers math.example.org but not advanced.math.example.org."
  - id: m42-l04-c4
    front: Apple's three rules for a long-term pinning strategy?
    back: "Pin public keys rather than whole certificates; pin the issuing CA's keys rather than the leaf; pin a set of keys so you can rotate. And plan what the app does when pinning fails."
  - id: m42-l04-c5
    front: Does pinning stop someone extracting an API key from the app?
    back: "No. Pinning protects traffic from a third party in the middle. The device owner has the binary and can read strings in it (Module 21) or hook the app. Keep secret keys on your server."
---

## The idea in one sentence

App Transport Security already makes every `URLSession` request use modern TLS, so your job is to keep it that way, add pinning only when the threat model calls for it and with a rotation plan, and never rely on the network layer to hide something the app itself contains.

> [!note] Sources and what was checked
> From Apple: `NSAppTransportSecurity`, "Preventing Insecure Network Connections", `NSExceptionDomains`, `NSIncludesSubdomains`, `NSAllowsLocalNetworking`, `NSPinnedDomains`, `NSPinnedCAIdentities`, `NSPinnedLeafIdentities`, "Performing manual server trust authentication", `urlSession(_:didReceive:completionHandler:)`, `SecTrustEvaluateWithError`, `SecTrustCopyCertificateChain`, `SecCertificateCopyKey`, `SecKeyCopyExternalRepresentation`, the January 2021 developer news article "Identity Pinning: How to configure server certificates for your app", and the support article on trusting manually installed certificates. From OWASP: MASVS-NETWORK-1 and -2 and the iOS MASTG tests named below. All read in November 2026. The delegate was type-checked against the iOS SDK, not run. The ATS audit and the pin-matching models are pure Swift, compiled and run with Swift 6.3. All key digests in this lesson are fake.

## What ATS gives you for free

Apple: "ATS requires that all HTTP connections made with the URL Loading System, typically using the `URLSession` class, use HTTPS." It's on by default for any app built with the iOS 9 SDK or later. On top of normal certificate checks, ATS requires:

- a server certificate signed with "an RSA key of at least 2048 bits, or an Elliptic-Curve Cryptography (ECC) key of at least 256 bits," and "SHA-256 or greater";
- "TLS protocol version 1.2 or later";
- "the AES-128 or the AES-256 symmetric cipher";
- "perfect forward secrecy (PFS) through Elliptic Curve Diffie-Hellman Ephemeral (ECDHE) key exchange."

Two boundaries to know:

- **ATS covers the URL Loading System.** "ATS doesn't apply to calls your app makes to lower-level networking interfaces like the Network framework or CFNetwork. In these cases, you take responsibility for ensuring the security of the connection." MASTG-TEST-0323 and 0344 look for exactly that.
- **A delegate can tighten, not loosen.** From "Preventing Insecure Network Connections": when ATS is enabled, "you can no longer loosen trust evaluation requirements" in a delegate, "but you can still tighten them — for example, to implement certificate pinning."

That's MASVS-NETWORK-1 ("The app secures all network traffic according to the current best practices") mostly handled by the platform, as long as you don't switch it off.

## Exceptions, and auditing them

Exceptions live under `NSAppTransportSecurity` in Info.plist. Apple's advice is consistent: "Always look for ways to improve server security before adding ATS exceptions," and "If you must use an exception, make it as limited in scope as possible." Some exceptions "require you to provide justification, and might trigger additional App Store review": `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsForMedia`, `NSAllowsArbitraryLoadsInWebContent`, `NSExceptionAllowsInsecureHTTPLoads` and `NSExceptionMinimumTLSVersion`.

One rule surprises people: "If you specify an exception domain dictionary, ATS ignores any global configuration keys, like `NSAllowsArbitraryLoads`, for that domain. This is true even if you leave the domain-specific dictionary empty." An empty entry for your API domain keeps full ATS there even if someone turned it off globally.

An audit as a function you could run in CI against the built Info.plist:

```swift
struct DomainException {
    var includesSubdomains = false
    var allowsInsecureHTTPLoads = false
    var minimumTLSVersion: String? = nil
    var requiresForwardSecrecy = true
}

struct ATSConfiguration {
    var allowsArbitraryLoads = false
    var allowsArbitraryLoadsInWebContent = false
    var allowsLocalNetworking = false
    var exceptionDomains: [String: DomainException] = [:]
}

/// Lists every weakening of ATS, marking the ones Apple says need a justification in App Review.
func audit(_ ats: ATSConfiguration) -> [String] {
    var findings: [String] = []
    if ats.allowsArbitraryLoads {
        findings.append("NSAllowsArbitraryLoads: ATS off for every domain not listed below [justify]")
    }
    if ats.allowsArbitraryLoadsInWebContent {
        findings.append("NSAllowsArbitraryLoadsInWebContent: web views may load anything [justify]")
    }
    if ats.allowsLocalNetworking {
        findings.append("NSAllowsLocalNetworking: unqualified names and local addresses allowed")
    }
    for domain in ats.exceptionDomains.keys.sorted() {
        let exception = ats.exceptionDomains[domain]!
        let scope = exception.includesSubdomains ? "\(domain) and subdomains" : domain
        if exception.allowsInsecureHTTPLoads {
            findings.append("\(scope): plain HTTP allowed [justify]")
        }
        if let version = exception.minimumTLSVersion, version != "TLSv1.2", version != "TLSv1.3" {
            findings.append("\(scope): accepts \(version) [justify]")
        }
        if !exception.requiresForwardSecrecy {
            findings.append("\(scope): forward secrecy not required")
        }
    }
    return findings
}

let shipped = ATSConfiguration(
    allowsArbitraryLoads: true,
    exceptionDomains: [
        "api.harborbank.example": DomainException(),
        "legacy-rates.example.net": DomainException(includesSubdomains: true, allowsInsecureHTTPLoads: true, minimumTLSVersion: "TLSv1.0"),
    ])
let findings = audit(shipped)
for finding in findings { print("-", finding) }
print(findings.isEmpty ? "ATS defaults intact" : "\(findings.count) weakening(s)")
```

```output
- NSAllowsArbitraryLoads: ATS off for every domain not listed below [justify]
- legacy-rates.example.net and subdomains: plain HTTP allowed [justify]
- legacy-rates.example.net and subdomains: accepts TLSv1.0 [justify]
3 weakening(s)
```

- **The empty entry for `api.harborbank.example` produces no finding**, and that's correct: it restores full ATS for the API despite the global switch.
- **The global switch is still a finding.** Every other host, including ones a future SDK talks to, is unprotected. Someone added it "temporarily" to reach a development server; Apple's advice is to fix the server or scope the exception to that host.
- **Domain order is sorted** so the output is stable across runs and diffs cleanly in review.

A real version would read the plist with `PropertyListSerialization`. MASTG-TEST-0322 ("App Transport Security Configurations Allowing Cleartext Traffic") and 0342 ("References to Weak ATS TLS Policy Exceptions in Info.plist") are the reviewer's version of this check.

> [!tip] Debugging a blocked connection
> Apple's "Identifying the Source of Blocked Connections" covers the `nscurl` command-line tool, which tries a server with different ATS exceptions so you learn which one (if any) the server actually needs. Use it before adding a key.

## Pinning: what it's for

Default trust evaluation accepts any certificate that chains to a root the device trusts. Pinning narrows that to identities you chose. It addresses one threat: **someone who can get a certificate for your domain that the device will trust**. That includes a misissued or compromised CA, and roots added to the device (a root a person enabled in Certificate Trust Settings, or one pushed by device management, which Apple's support article says is trusted automatically).

It doesn't address:

- **the device owner.** On a device they control, someone can hook the app and disable the check. That's MASVS-RESILIENCE territory (Lesson 7).
- **bugs on your server** or anything after TLS terminates.
- **secrets inside the app** (last section).

Apple's position, from the identity pinning article: "Pinning certificates is not required. You should deploy pinning configurations with caution, and only if absolutely necessary," with the example of apps that "need to meet regulatory requirements that determine which specific Certificate Authorities (CAs) can be trusted." OWASP's MASVS-NETWORK-2 asks for "identity pinning for all remote endpoints under the developer's control" and maps to MASWE-0028, Insecure Identity Pinning. MASTG-TEST-0385, "Missing Certificate Pinning in ATS," checks first-party domains and says "the test case should not fail only because unrelated third-party domains are not pinned."

For a bank, the usual outcome of the threat model is: pin your own API domains, with CA keys and a backup, and don't pin domains you don't control.

### What to pin

| Choice | Survives | Breaks when |
| --- | --- | --- |
| Whole leaf certificate | Nothing | The certificate is renewed, even with the same key |
| Leaf public key (SPKI) | Renewal with the same key | The server rotates its key |
| Issuing CA public key | New leaf certificates and keys from that CA | You change CA, or the CA changes its intermediate key |
| A set of CA keys, including a backup | Moving between the pinned CAs | You move to a CA outside the set |

Apple's "Performing manual server trust authentication" gives the same order of preference: "Compare the server's credentials against a public key, instead of storing a single certificate," "Compare the issuing certificate authority's (CA's) keys, rather than using the leaf key," and "Use a set of keys or CAs, so you can rotate server credentials more gracefully."

## NSPinnedDomains

Since iOS 14, ATS can do the pinning for you. For each domain you give `NSPinnedCAIdentities`, `NSPinnedLeafIdentities`, or both, each an array of dictionaries with one key, `SPKI-SHA256-BASE64`: "the Base64-encoded SHA-256 digest of an X.509 certificate's DER-encoded ASN.1 Subject Public Key Info (SPKI) structure." The values below are placeholders, not real digests:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSPinnedDomains</key>
    <dict>
        <key>api.harborbank.example</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSPinnedCAIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>REPLACE-with-issuing-CA-SPKI-SHA256-base64=</string>
                </dict>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>REPLACE-with-backup-CA-SPKI-SHA256-base64=</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
```

The rules, from Apple's key reference:

- **CA identities** match if ATS "can find the SPKI digest of at least one Certificate Authority (CA) or sub-CA certificate in the chain presented by the server."
- **Leaf identities** match the leaf only; Apple suggests "including more than one leaf certificate to allow for server-side configuration changes."
- **Both present:** "both must produce a match."
- **Subdomains:** `NSIncludesSubdomains` applies to "subdomains of the domain that have one additional path component": `api.harborbank.example` covers `eu.api.harborbank.example` but not `v2.eu.api.harborbank.example`.
- **Pinning only adds.** "Pinning a certificate for a given domain has no impact on other security requirements or configuration."

Apple's article computes a digest from a PEM certificate with `openssl`: extract the public key, convert it to DER, hash with SHA-256, encode as Base64. Get the values from your server team's actual CA certificates, and keep the commands that produced them next to the plist.

Here are the matching rules as a model you can test, including the subdomain rule that catches people:

```swift
// Fake SPKI digests. Real ones are Base64 SHA-256 values, 44 characters long.
struct Certificate {
    let subject: String
    let spkiSHA256: String
}

struct PinnedDomain {
    let includesSubdomains: Bool
    let caIdentities: Set<String>      // NSPinnedCAIdentities
    let leafIdentities: Set<String>    // NSPinnedLeafIdentities
}

let pinnedDomains: [String: PinnedDomain] = [
    "api.harborbank.example": PinnedDomain(
        includesSubdomains: true,
        caIdentities: ["CA-ISSUING-2025=", "CA-ISSUING-BACKUP="],
        leafIdentities: []),
]

/// The pinning rules that apply to a host, following NSPinnedDomains:
/// an exact match, or one extra label when NSIncludesSubdomains is true.
func pins(for host: String) -> PinnedDomain? {
    let host = host.lowercased()
    if let exact = pinnedDomains[host] { return exact }
    guard let dot = host.firstIndex(of: ".") else { return nil }
    let parent = String(host[host.index(after: dot)...])
    if let rule = pinnedDomains[parent], rule.includesSubdomains { return rule }
    return nil
}

enum PinResult: String {
    case match = "pin matched"
    case mismatch = "blocked by pin"
    case notPinned = "not pinned, default trust only"
}

/// chain[0] is the leaf; the rest are intermediates and the root.
func checkPins(host: String, chain: [Certificate]) -> PinResult {
    guard let rule = pins(for: host) else { return .notPinned }
    guard let leaf = chain.first else { return .mismatch }
    let caMatch = rule.caIdentities.isEmpty
        || chain.dropFirst().contains { rule.caIdentities.contains($0.spkiSHA256) }
    let leafMatch = rule.leafIdentities.isEmpty || rule.leafIdentities.contains(leaf.spkiSHA256)
    return caMatch && leafMatch ? .match : .mismatch
}

let legitimate = [
    Certificate(subject: "api.harborbank.example", spkiSHA256: "LEAF-2026A="),
    Certificate(subject: "Harbor Issuing CA", spkiSHA256: "CA-ISSUING-2025="),
    Certificate(subject: "Public Root CA", spkiSHA256: "ROOT-PUBLIC="),
]
let intercepted = [
    Certificate(subject: "api.harborbank.example", spkiSHA256: "LEAF-PROXY="),
    Certificate(subject: "Debugging Proxy CA", spkiSHA256: "CA-PROXY="),
]

let checks: [(String, [Certificate])] = [
    ("api.harborbank.example", legitimate),
    ("api.harborbank.example", intercepted),
    ("eu.api.harborbank.example", intercepted),
    ("v2.eu.api.harborbank.example", intercepted),
    ("cdn.harborbank.example", intercepted),
]
for (host, chain) in checks {
    print(host, "->", checkPins(host: host, chain: chain).rawValue)
}
```

```output
api.harborbank.example -> pin matched
api.harborbank.example -> blocked by pin
eu.api.harborbank.example -> blocked by pin
v2.eu.api.harborbank.example -> not pinned, default trust only
cdn.harborbank.example -> not pinned, default trust only
```

- **The intercepted chain** is what a TLS-inspecting proxy presents: a leaf for your host, issued by the proxy's own CA. If the device trusts that CA, default evaluation passes; the pin blocks it.
- **`v2.eu.api...`** has two extra labels, so the pin doesn't apply and only default trust protects it. If you serve an API there, list it explicitly.
- **`cdn.harborbank.example`** is a sibling of the pinned domain, not a subdomain of it. Pin the parent if you want both, or list each host.
- **"Not pinned" isn't "insecure".** Those hosts still get full ATS and default trust evaluation.

## Pinning in code

If you need pinning outside what `NSPinnedDomains` expresses (a pin set that comes from somewhere else, or behavior on failure that you control), implement `urlSession(_:didReceive:completionHandler:)`. The one rule that matters: **evaluate trust first**. A delegate that returns `.useCredential` without evaluating accepts any certificate at all; MASTG-TEST-0396, "References to URLSessionDelegate Bypassing Certificate Validation," exists for that bug.

```swift ios
import CryptoKit
import Foundation
import Security

/// Requires one of our CA public keys in the server's chain, on top of normal trust evaluation.
/// Prefer NSPinnedDomains in Info.plist; use this when you need pinning in code.
final class PinningDelegate: NSObject, URLSessionDelegate, Sendable {
    private let pinnedHost: String
    private let pinnedCAKeys: Set<String>       // Base64 SHA-256 of each CA's SubjectPublicKeyInfo

    init(pinnedHost: String, pinnedCAKeys: Set<String>) {
        self.pinnedHost = pinnedHost
        self.pinnedCAKeys = pinnedCAKeys
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              space.host == pinnedHost,
              let trust = space.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 1. The normal checks: chain to a trusted root, host name, expiry. Pinning only adds to them.
        guard SecTrustEvaluateWithError(trust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 2. One of our CA keys must appear above the leaf.
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        let matched = chain.dropFirst().contains { certificate in
            guard let digest = Self.spkiSHA256(of: certificate) else { return false }
            return pinnedCAKeys.contains(digest)
        }
        if matched {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// SPKI digest for EC P-256 keys. Other key types return nil and never match.
    static func spkiSHA256(of certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate),
              let raw = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              let publicKey = try? P256.Signing.PublicKey(x963Representation: raw) else { return nil }
        return Data(SHA256.hash(data: publicKey.derRepresentation)).base64EncodedString()
    }
}

let delegate = PinningDelegate(pinnedHost: "api.harborbank.example",
                               pinnedCAKeys: ["<base64 SPKI SHA-256 of the issuing CA>",
                                              "<base64 SPKI SHA-256 of the backup CA>"])
let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
```

How it follows Apple's article:

- **Check the challenge type and host first**, and hand everything else back with `.performDefaultHandling`.
- **`SecTrustEvaluateWithError`** runs the normal evaluation. Apple warns not to call it on the main run loop because "it might require network access to fetch intermediate certificates, or to perform revocation checking." With `delegateQueue: nil` the session calls the delegate on its own background queue.
- **`SecTrustCopyCertificateChain`** (iOS 15 and later) returns the chain with the leaf first; `dropFirst()` skips it, matching `NSPinnedCAIdentities` semantics.
- **The SPKI digest.** `SecKeyCopyExternalRepresentation` gives an elliptic-curve public key in X9.63 form ("04 || X || Y"), not SPKI. CryptoKit's `P256.Signing.PublicKey(x963Representation:)` reads that, and its `derRepresentation` is the DER-encoded SubjectPublicKeyInfo, which is what `SPKI-SHA256-BASE64` hashes. RSA keys would need their own SPKI encoding; this delegate deliberately doesn't match them, so a CA with an RSA key fails closed rather than open.
- **Accept with `.useCredential` only after both checks; otherwise `.cancelAuthenticationChallenge`.** The request then fails with a `URLError`, which your networking layer should report distinctly from "offline."
- **The delegate is `Sendable`**: immutable stored properties, as Swift 6 requires for an object the session calls from its own queue.

## Rotation, and not locking out your customers

Pinning turns a routine server change into a possible outage for every installed version that doesn't know the new key. Apple's note: "if the server deploys new certificates that alter the public keys, your app will refuse to connect. At that point, you'll need to update your app with a pinning configuration that reflects the new set of public keys." And customers who don't update stay broken.

A workable plan, following Apple's "Think long term" section:

1. **Pin CA keys, at least two.** The current issuing CA and a backup from a different CA that the server team has agreed they could move to in an emergency.
2. **Ship new pins before you need them.** Add the next key in a release, wait until the versions without it are a negligible share of active users, then switch the server. Exercise 5 computes that share.
3. **Plan the failure experience.** Apple: "plan to provide a fallback experience in your app if it's unable to connect to a server in the event of a pinning failure." For a bank that's usually a clear screen ("Update Harbor Bank to continue") rather than a generic error, plus monitoring of pin failures by app version.
4. **Test the failures.** Apple recommends "simulating various events and potential failure points when testing your app by acquiring additional public-key certificates for this purpose."

Some teams deliver pin sets from a server so they can change them without an app update. That channel then needs its own protection (a signed configuration verified with a key in the app), and it's one more system that can fail. Apple's article names an app update as the recovery path; if you build something else, put it in the threat model.

## Secrets in the binary

Module 21 showed that a string literal in Swift is readable with `strings`, and that XOR-masking it only hides it from people who don't look. TLS and pinning don't change that: they protect bytes **in transit** from a third party. The device owner holds the binary and can read it, or run the app under a debugger or hook and watch the request being built.

OWASP lists this as MASWE-0004, "Sensitive Data Hardcoded in the App Package," under MASVS-STORAGE-1, and MASTG-TEST-0213 and 0214 look for hardcoded keys in code and files. The fixes are architectural:

- **Third-party API keys** that cost money or grant access go on your server, which calls the third party on the app's behalf.
- **Per-user credentials** come from sign-in and live in the Keychain (Lesson 2).
- **Proof that a request came from your genuine app** is App Attest's job, verified on the server (Lesson 7), not a "secret" header value.
- **Public identifiers** (a client ID that only identifies the app, a public analytics key that can only submit events) are fine in the binary, as long as you've checked that's all they can do.

## Common mistakes

> [!error] NSAllowsArbitraryLoads to reach a development server
> It disables ATS for every host and needs a justification in App Review. Add an exception for the development host only, ideally in a Debug-only Info.plist, or put a proper certificate on the server.

> [!error] A delegate that accepts any server trust
> `completionHandler(.useCredential, URLCredential(trust: trust))` without `SecTrustEvaluateWithError` turns off certificate validation for that session. It's usually added "for staging" and shipped. MASTG-TEST-0396 looks for it.

> [!error] One pinned leaf certificate
> The next renewal takes the app offline for everyone. Pin public keys, prefer CA keys, and always include a backup.

> [!error] Pinning domains you don't control
> A third-party SDK's or CDN's certificates change on their schedule, not yours. OWASP's test scopes pinning to first-party endpoints for this reason.

> [!error] Expecting pinning to protect the API key
> Pinning doesn't stop the device owner from reading the binary or hooking the app. Move the key to the server.

## Exercises

````exercise
id: m42-l04-e1
type: prediction
prompt: "This applies NSPinnedDomains' subdomain rule. What does it print?"
code: |
  let pinned: [String: Bool] = [          // domain -> NSIncludesSubdomains
      "harborbank.example": true,
      "auth.harborbank.example": false,
  ]

  func rule(for host: String) -> String {
      if pinned[host] != nil { return host }
      guard let dot = host.firstIndex(of: ".") else { return "none" }
      let parent = String(host[host.index(after: dot)...])
      if pinned[parent] == true { return parent }
      return "none"
  }

  print(rule(for: "harborbank.example"))
  print(rule(for: "api.harborbank.example"))
  print(rule(for: "auth.harborbank.example"))
  print(rule(for: "eu.auth.harborbank.example"))
  print(rule(for: "v2.api.harborbank.example"))
output: |
  harborbank.example
  harborbank.example
  auth.harborbank.example
  none
  none
hints:
  - "An exact match wins. Otherwise only the parent one label up is considered."
  - "The parent of eu.auth.harborbank.example is auth.harborbank.example, whose entry says false."
solution: |
  ```output
  harborbank.example
  harborbank.example
  auth.harborbank.example
  none
  none
  ```

  - `harborbank.example` and `auth.harborbank.example` match exactly.
  - `api.harborbank.example` is one label below `harborbank.example`, which includes subdomains.
  - `eu.auth.harborbank.example`'s parent is `auth.harborbank.example`, which doesn't include subdomains. The grandparent `harborbank.example` isn't consulted: Apple says `NSIncludesSubdomains` covers subdomains "that have one additional path component."
  - `v2.api.harborbank.example` is two labels below `harborbank.example`, so nothing applies.

  An exact entry also shadows its parent: `auth.harborbank.example` gets its own pins, not the parent's. That's the behavior the model encodes by checking exact matches first.
````

````exercise
id: m42-l04-e2
type: comprehension
multiple: true
prompt: "Which of these ATS keys does Apple list as requiring a justification in App Review?"
choices:
  - text: "NSAllowsArbitraryLoads"
    correct: true
    why: "Arbitrary connection exceptions are the first item on Apple's list."
  - text: "NSExceptionAllowsInsecureHTTPLoads"
    correct: true
    why: "Per-domain nonsecure connections need a justification."
  - text: "NSExceptionMinimumTLSVersion"
    correct: true
    why: "Lowering the TLS version for a domain needs a justification."
  - text: "NSPinnedDomains"
    correct: false
    why: "Pinning strengthens ATS; it isn't an exception that weakens it."
  - text: "NSIncludesSubdomains"
    correct: false
    why: "It only changes the scope of the entry it's in."
solution: |
  Apple's list in "Preventing Insecure Network Connections": `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsForMedia`, `NSAllowsArbitraryLoadsInWebContent`, `NSExceptionAllowsInsecureHTTPLoads` and `NSExceptionMinimumTLSVersion`. Keys that only tighten the policy, like pinning, don't need one.
````

````exercise
id: m42-l04-e3
type: fill-in
prompt: "Complete the Info.plist entry that pins one CA key for the auth domain only (no subdomains)."
code: |
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>[[1]]</key>
      <dict>
          <key>auth.harborbank.example</key>
          <dict>
              <key>NSIncludesSubdomains</key>
              <[[2]]/>
              <key>[[3]]</key>
              <array>
                  <dict>
                      <key>[[4]]</key>
                      <string>REPLACE-with-CA-SPKI-SHA256-base64=</string>
                  </dict>
              </array>
          </dict>
      </dict>
  </dict>
blanks:
  - id: "1"
    answers: ["NSPinnedDomains"]
  - id: "2"
    answers: ["false"]
  - id: "3"
    answers: ["NSPinnedCAIdentities"]
  - id: "4"
    answers: ["SPKI-SHA256-BASE64"]
solution: |
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSPinnedDomains</key>
      <dict>
          <key>auth.harborbank.example</key>
          <dict>
              <key>NSIncludesSubdomains</key>
              <false/>
              <key>NSPinnedCAIdentities</key>
              <array>
                  <dict>
                      <key>SPKI-SHA256-BASE64</key>
                      <string>REPLACE-with-CA-SPKI-SHA256-base64=</string>
                  </dict>
              </array>
          </dict>
      </dict>
  </dict>
  ```

  `NSIncludesSubdomains` defaults to `NO`, so the `<false/>` is optional but documents the intent. In a real configuration, add a second `SPKI-SHA256-BASE64` entry for a backup CA; with only one, a CA change locks out every installed version.
````

````exercise
id: m42-l04-e4
type: find-errors
prompt: "Review this delegate from a pull request titled \"Fix staging SSL errors\". Mark every real problem."
code: |
  final class APIDelegate: NSObject, URLSessionDelegate {
      func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                      completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
          if let trust = challenge.protectionSpace.serverTrust {
              print("trusting \(challenge.protectionSpace.host)")
              completionHandler(.useCredential, URLCredential(trust: trust))
          } else {
              completionHandler(.performDefaultHandling, nil)
          }
      }
  }
  // Info.plist: NSAllowsArbitraryLoads = YES  (staging uses a self-signed cert)
choices:
  - text: "It accepts every server trust without calling SecTrustEvaluateWithError, which disables certificate validation."
    correct: true
  - text: "It doesn't check the authentication method or the host, so it applies to every server the session talks to."
    correct: true
  - text: "There's no build-configuration guard, so the staging workaround ships to production."
    correct: true
  - text: "NSAllowsArbitraryLoads turns off ATS for every domain and needs an App Review justification."
    correct: true
  - text: "URLCredential(trust:) is deprecated and should be replaced."
    correct: false
    why: "It's the documented way to accept a server trust after you've evaluated it, used in Apple's own article."
rubric:
  - I flagged the missing trust evaluation.
  - I flagged the missing method and host checks.
  - I flagged that the code isn't limited to staging builds.
  - I flagged the global ATS exception and proposed a scoped alternative.
solution: |
  Four problems:

  1. **No evaluation.** Any certificate for any host is accepted, so anyone on the network path can impersonate the API. This is exactly what MASTG-TEST-0396 looks for.
  2. **No method or host check.** Apple's article starts by checking `authenticationMethod == NSURLAuthenticationMethodServerTrust` and the host, and returns `.performDefaultHandling` otherwise.
  3. **Shipped to production.** Nothing limits this to staging.
  4. **`NSAllowsArbitraryLoads`** turns off ATS everywhere.

  The right fix is on the server side of staging: a certificate from an internal CA installed on test devices through a profile (or a public certificate), and no code change in the app. If you must trust a specific staging certificate in code, do it only in a Debug configuration, only for the staging host, and still evaluate trust after adding the anchor with `SecTrustSetAnchorCertificates`.
````

````exercise
id: m42-l04-e5
type: solve
prompt: |
  Write `releasesBroken(by:releases:)`. A release breaks if none of its pinned CA keys appear in the new chain's CA keys. Return the broken versions in the order given and the total share of active users on them. Then print the result for the three plans in the starter.

  Expected output:

  ```output
  move to the 2025 issuing CA: breaks 4.2 (6% of users)
  emergency switch to the backup CA: breaks 4.2, 4.3 (27% of users)
  new vendor: breaks 4.2, 4.3, 5.0 (100% of users)
  ```
starter: |
  struct AppRelease {
      let version: String
      let activeUsersPercent: Int
      let pinnedCAs: Set<String>
  }

  func releasesBroken(by newChainCAs: [String], releases: [AppRelease]) -> (versions: [String], users: Int) {
      // your code
      return ([], 0)
  }

  let releases = [
      AppRelease(version: "4.2", activeUsersPercent: 6, pinnedCAs: ["CA-ISSUING-2023="]),
      AppRelease(version: "4.3", activeUsersPercent: 21, pinnedCAs: ["CA-ISSUING-2023=", "CA-ISSUING-2025="]),
      AppRelease(version: "5.0", activeUsersPercent: 73, pinnedCAs: ["CA-ISSUING-2025=", "CA-ISSUING-BACKUP="]),
  ]

  let plans: [(String, [String])] = [
      ("move to the 2025 issuing CA", ["CA-ISSUING-2025=", "ROOT-PUBLIC="]),
      ("emergency switch to the backup CA", ["CA-ISSUING-BACKUP=", "ROOT-PUBLIC="]),
      ("new vendor", ["CA-OTHER=", "ROOT-OTHER="]),
  ]
hints:
  - "Set has isDisjoint(with:), which accepts any sequence."
  - "Join the versions with \", \" and print \"none\" if the list is empty."
rubric:
  - Treats a release as broken only when no pinned key appears in the chain.
  - Sums active users of broken releases.
  - Prints the three expected lines.
solution: |
  ```swift
  struct AppRelease {
      let version: String
      let activeUsersPercent: Int
      let pinnedCAs: Set<String>
  }

  /// Versions whose pins match none of the CA keys in the new chain, and the share of users they hold.
  func releasesBroken(by newChainCAs: [String], releases: [AppRelease]) -> (versions: [String], users: Int) {
      var versions: [String] = []
      var users = 0
      for release in releases where release.pinnedCAs.isDisjoint(with: newChainCAs) {
          versions.append(release.version)
          users += release.activeUsersPercent
      }
      return (versions, users)
  }

  let releases = [
      AppRelease(version: "4.2", activeUsersPercent: 6, pinnedCAs: ["CA-ISSUING-2023="]),
      AppRelease(version: "4.3", activeUsersPercent: 21, pinnedCAs: ["CA-ISSUING-2023=", "CA-ISSUING-2025="]),
      AppRelease(version: "5.0", activeUsersPercent: 73, pinnedCAs: ["CA-ISSUING-2025=", "CA-ISSUING-BACKUP="]),
  ]

  let plans: [(String, [String])] = [
      ("move to the 2025 issuing CA", ["CA-ISSUING-2025=", "ROOT-PUBLIC="]),
      ("emergency switch to the backup CA", ["CA-ISSUING-BACKUP=", "ROOT-PUBLIC="]),
      ("new vendor", ["CA-OTHER=", "ROOT-OTHER="]),
  ]
  for (plan, chain) in plans {
      let broken = releasesBroken(by: chain, releases: releases)
      let list = broken.versions.isEmpty ? "none" : broken.versions.joined(separator: ", ")
      print("\(plan): breaks \(list) (\(broken.users)% of users)")
  }
  ```

  ```output
  move to the 2025 issuing CA: breaks 4.2 (6% of users)
  emergency switch to the backup CA: breaks 4.2, 4.3 (27% of users)
  new vendor: breaks 4.2, 4.3, 5.0 (100% of users)
  ```

  This is the conversation to have before any certificate change. The planned move costs 6% of users (everyone still on 4.2), so the team either waits, or shows those users an update screen first. The backup CA only helps people on 5.0; 4.3 shipped without it. A new vendor outside every pin set is an outage for everyone: ship its key as a pin in a release well before the switch.

  The model counts only CA keys. A real chain check also involves leaf pins, if any, and the device's own trust evaluation.
````

````exercise
id: m42-l04-e6
type: design
prompt: "Harbor Bank's security team asks you to propose the network security setup for the next release. Write the proposal: ATS configuration, which domains to pin and how, the rotation plan, how failures appear to customers and to the team, and what you'd say about the API key a partner integration currently ships in Info.plist."
rubric:
  - Keeps ATS defaults and removes or scopes any exception, with nscurl used to verify.
  - Pins first-party API domains with at least two CA keys via NSPinnedDomains, and explicitly doesn't pin third-party domains.
  - Includes a rotation procedure tied to version adoption, and failure handling (update screen, monitoring by version).
  - Moves the partner key to the server and explains why pinning doesn't protect it.
solution: |
  A proposal along these lines:

  **ATS.** No global exceptions. The `legacy-rates` partner endpoint gets fixed by the partner (or proxied through our backend) instead of an `NSExceptionAllowsInsecureHTTPLoads` entry. A CI step reads the built Info.plist and fails if any weakening key appears (the lesson's audit, against the real plist).

  **Pinning.** `NSPinnedDomains` for `api.harborbank.example` and `auth.harborbank.example`, `NSIncludesSubdomains` on the API domain, `NSPinnedCAIdentities` with the current issuing CA's SPKI digest and a backup CA the server team has an account with. No leaf pins. No pins for the analytics SDK, maps or the help-center CDN: we don't control their certificates.

  **Rotation.** Every release ships the current and next CA keys. Before a server change we compute the share of active users on versions without the new key (Exercise 5) and only switch below an agreed threshold, after showing an update prompt to the remaining versions. Pin sets and the openssl commands that produced them are in the repository next to the plist.

  **Failures.** A pinning failure surfaces as a specific error in the networking layer; the app shows "Update Harbor Bank to continue" with a link to the App Store, not "No connection." The app reports the failure (host, app version, no personal data) to our telemetry so a misconfigured server is noticed within minutes.

  **The partner key.** It's in the bundle, so every customer has it and can read it with standard tools; TLS and pinning protect it from network observers, not from the device owner. Rotate it now, and route partner calls through our backend, which holds the key and enforces per-customer limits.
````

## Summary

- ATS requires HTTPS with TLS 1.2+, ECDHE forward secrecy, AES and strong certificates for the URL Loading System. Lower-level networking isn't covered, and a delegate can tighten trust but not loosen it.
- Keep exceptions as narrow as possible. `NSAllowsArbitraryLoads`, `...ForMedia`, `...InWebContent`, `NSExceptionAllowsInsecureHTTPLoads` and `NSExceptionMinimumTLSVersion` need a justification, and an exception-domain entry overrides the global keys for that domain.
- Pinning protects against a certificate for your domain that the device would trust anyway. Pin public keys, prefer CA keys, ship a set with a backup, and pin only your own endpoints.
- `NSPinnedDomains` pins SPKI SHA-256 digests; CA identities match any CA in the chain, leaf identities match the leaf, both must match if both are present, and `NSIncludesSubdomains` reaches one label down. In code, evaluate trust first, then check pins, and never accept an unevaluated trust.
- Plan rotation by version adoption, show a clear failure screen and monitor pin failures. No network setting hides a secret in the binary: keep secret keys on the server.
