---
id: m42-l03
title: CryptoKit and the Secure Enclave
description: "Use Apple's cryptography instead of inventing your own. You see how a homemade cipher falls apart, then hash, authenticate, encrypt, agree on keys and sign with CryptoKit, compare secrets in constant time, and create a Secure Enclave signing key that only works after Face ID, so the server can verify that a transfer was approved on this device."
module: m42
order: 3
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l02]
objectives:
  - Explain why a homemade cipher fails, with a concrete break.
  - Choose between a hash, an HMAC, authenticated encryption and a signature for a given job.
  - Use CryptoKit for SHA-256, HMAC, AES-GCM, ChaChaPoly, P-256 key agreement with HKDF and P-256 signatures.
  - Compare secret values in constant time and say why an early-exit comparison leaks.
  - Create a Secure Enclave P-256 signing key with an access control, and state the Secure Enclave's limits.
terms:
  - term: Hash
    definition: "A fixed-size fingerprint of some bytes (SHA-256 here). Anyone can compute it, so it detects accidental change but proves nothing about who made the data."
  - term: HMAC
    definition: "A message authentication code built from a hash and a secret key. Only holders of the key can create or verify it."
  - term: Authenticated encryption (AEAD)
    definition: "Encryption that also produces a tag, so opening fails if the ciphertext was changed. AES-GCM and ChaCha20-Poly1305 are both AEAD ciphers."
  - term: Nonce
    definition: "A value used once per encryption with a given key. Apple: \"It's critical that nonces are unique per call to encryption APIs.\""
  - term: Secure Enclave
    definition: "A hardware key manager isolated from the main processor. It creates P-256 keys, never exports them in plain form, and performs signing and key agreement inside itself."
  - term: Constant-time comparison
    definition: "A comparison whose running time doesn't depend on where the first differing byte is, so timing doesn't reveal how much of a guess was right."
mastery:
  - Break a repeating-key XOR cipher with a known prefix, and explain which property of real ciphers prevents that.
  - Pick the right CryptoKit primitive for checking a downloaded file, protecting a cache, deriving a session key and approving a transfer.
  - Write a constant-time comparison and explain why CryptoKit's HMAC verification is the better choice when you have a key.
  - Generate a Secure Enclave signing key bound to biometrics, sign a payload, and verify it with the public key.
  - Explain what happens to Secure Enclave keys on a new phone or after a restore.
resources: [apple-platform-security, security-storing-keys-keychain, keychain-services, owasp-masvs]
cards:
  - id: m42-l03-c1
    front: Hash, HMAC, encryption or signature? Proving to the server that a request came from the key on this phone.
    back: "A signature. The private key (ideally in the Secure Enclave) signs; the server verifies with the public key you registered. A hash proves nothing about who; an HMAC needs the server to hold the same secret."
  - id: m42-l03-c2
    front: What goes wrong if you reuse an AES-GCM nonce with the same key?
    back: "Apple: nonces must be \"unique per call to encryption APIs in order to protect the integrity of the encryption.\" Let CryptoKit pick a random nonce (don't pass one) and store the combined box: nonce, ciphertext and tag."
  - id: m42-l03-c3
    front: Three limits of the Secure Enclave?
    back: "Hardware support is required (iOS devices with A7 or later); it works only with NIST P-256 keys (signing and key agreement); it can't import existing keys. Its keys only work on the device that created them."
  - id: m42-l03-c4
    front: Why is `==` on two MAC byte arrays a problem?
    back: "An early-exit comparison returns at the first different byte, so response time can reveal how many leading bytes of a guess were right. Use HMAC.isValidAuthenticationCode, or compare every byte with XOR and OR."
  - id: m42-l03-c5
    front: What is a SecureEnclave key's dataRepresentation?
    back: "Not the private key: an encrypted blob that only the same Secure Enclave can turn back into a usable key. Store it in the Keychain as a generic password and recreate the key with init(dataRepresentation:authenticationContext:)."
---

## The idea in one sentence

Cryptography is the part of security where being almost right means being wrong, so you use CryptoKit's tested primitives for the job each one does, keep keys in the Keychain or the Secure Enclave, and let the hardware sign transfers so the server can check that this device and this person approved them.

> [!note] Sources and what was checked
> API declarations and behavior come from Apple's CryptoKit documentation (`SHA256`, `HMAC` and `isValidAuthenticationCode`, `AES.GCM`, `AES.GCM.Nonce`, `AES.GCM.SealedBox.combined`, `ChaChaPoly`, `SharedSecret` and `hkdfDerivedSymmetricKey`, `P256.Signing`, `SecureEnclave`, `SecureEnclave.P256.Signing.PrivateKey` and its initializers, `Insecure`, "Storing CryptoKit Keys in the Keychain"), Security's "Protecting keys with the Secure Enclave", Swift's `SystemRandomNumberGenerator`, and MASVS-CRYPTO with MASTG-TEST-0311, read in November 2026. The open-source Swift Crypto implementation of `isValidAuthenticationCode` was read on GitHub. CryptoKit doesn't exist on Linux, so the CryptoKit and Secure Enclave blocks were type-checked against the iOS SDK and not run; their behavior is as documented, not observed. The homemade cipher and the comparison models are pure Swift, compiled and run with Swift 6.3. Nothing here is a real key or a real attack on a real system.

## Don't build your own

MASVS-CRYPTO-1 says "The app employs current strong cryptography and uses it according to industry best practices," and MASWE-0047 is literally "Using Non-Standard APIs for Security-Critical Functionality." Apple's CryptoKit overview gives the practical version: "Prefer CryptoKit over lower-level interfaces. CryptoKit frees your app from managing raw pointers, and automatically handles tasks that make your app more secure, like overwriting sensitive data during memory deallocation."

To see why, here's a cipher that looks reasonable to someone who hasn't studied the field: XOR each byte with a secret key, repeating the key as needed. It's fast, it's symmetric, and the output looks random:

```swift
// A homemade cipher: XOR every byte with a short repeating key. Don't ship this.
func xorWithRepeatingKey(_ bytes: [UInt8], key: [UInt8]) -> [UInt8] {
    var output: [UInt8] = []
    for (index, byte) in bytes.enumerated() {
        output.append(byte ^ key[index % key.count])
    }
    return output
}

let secretKey = Array("h4rb0r".utf8)                 // 6 bytes, "only we know it"
let first = xorWithRepeatingKey(Array("{\"amount\":250,\"to\":\"ACC-7731\"}".utf8), key: secretKey)
let second = xorWithRepeatingKey(Array("{\"amount\":9900,\"to\":\"ACC-1180\"}".utf8), key: secretKey)

// The attacker sees only ciphertexts, but knows every message starts with {"amount":
let knownPrefix = Array("{\"amount\":".utf8)
var recoveredKey: [UInt8] = []
for index in 0..<secretKey.count {
    recoveredKey.append(first[index] ^ knownPrefix[index])    // c ^ p = k
}
print("recovered key:", String(decoding: recoveredKey, as: UTF8.self))
print("second message:", String(decoding: xorWithRepeatingKey(second, key: recoveredKey), as: UTF8.self))

// And without a nonce, equal messages give equal ciphertexts.
let again = xorWithRepeatingKey(Array("{\"amount\":250,\"to\":\"ACC-7731\"}".utf8), key: secretKey)
print("same ciphertext twice:", again == first)
```

```output
recovered key: h4rb0r
second message: {"amount":9900,"to":"ACC-1180"}
same ciphertext twice: true
```

Three separate failures, each one a property real ciphers are designed to have:

1. **Known plaintext reveals the key.** XOR is its own inverse: if `c = p ^ k`, then `k = c ^ p`. App traffic is full of predictable bytes (JSON keys, headers), so an attacker always has some plaintext. Real ciphers don't let you compute the key from plaintext and ciphertext.
2. **No randomness per message.** The same message gives the same ciphertext, so an observer learns when two transfers are identical. AES-GCM and ChaChaPoly take a nonce, and CryptoKit generates a random one for you.
3. **No integrity.** Flip a ciphertext bit and the matching plaintext bit flips; nothing detects it. Authenticated encryption adds a tag, and opening fails if anything changed.

Obfuscation schemes (Module 21's XOR-masked API key) and "encryption" with a key stored next to the data fail for the same reason: the attacker has everything the app has.

## Picking the primitive

Most cryptography mistakes in apps aren't broken algorithms; they're the wrong tool for the job:

| You need to | Use | Not |
| --- | --- | --- |
| Detect that a download changed by accident, or derive a stable identifier | **Hash** (SHA-256) | A hash to prove *who* produced something; anyone can recompute it |
| Check that a message came from someone holding a shared secret | **HMAC** with a `SymmetricKey` | A hash of "secret + message" built by hand |
| Keep data confidential and detect tampering | **AES-GCM** or **ChaChaPoly** (AEAD) | Encryption without a tag; ECB or CBC without a MAC |
| Agree on a key with the server without sending it | **Key agreement** (P-256 or Curve25519) followed by **HKDF** | The raw shared secret as a key |
| Prove to anyone with your public key that you approved this exact payload | **Signature** (P-256, ideally in the Secure Enclave) | An HMAC, which needs the verifier to hold your secret |

Apple keeps MD5 and SHA-1 under `Insecure`: "These algorithms aren't considered cryptographically secure, but the framework provides them for backward compatibility with older services that require them. For new services, avoid these algorithms." MASTG-TEST-0211 ("Broken Hashing Algorithms") looks for exactly those.

## CryptoKit in one block

Here are the five jobs from the table, in order:

```swift ios
import CryptoKit
import Foundation

let statement = Data("Statement 2026-10, account ACC-7731".utf8)

// 1. Hash: a fingerprint of the bytes. Anyone can compute it; it proves nothing about who did.
let digest = SHA256.hash(data: statement)
print("SHA-256:", digest.map { String(format: "%02x", $0) }.joined())

// 2. HMAC: a tag only holders of the key can produce or check.
let macKey = SymmetricKey(size: .bits256)
let tag = HMAC<SHA256>.authenticationCode(for: statement, using: macKey)
print("HMAC valid:", HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: statement, using: macKey))

// 3. Authenticated encryption: confidentiality and integrity in one call.
let fileKey = SymmetricKey(size: .bits256)
let sealed = try AES.GCM.seal(statement, using: fileKey)     // a fresh random nonce each call
let stored = sealed.combined!                                // nonce + ciphertext + tag
let opened = try AES.GCM.open(try AES.GCM.SealedBox(combined: stored), using: fileKey)
print("AES-GCM round trip:", opened == statement)

let chacha = try ChaChaPoly.seal(statement, using: fileKey)
print("ChaChaPoly round trip:", try ChaChaPoly.open(chacha, using: fileKey) == statement)

// 4. Key agreement: both sides derive the same symmetric key without sending it.
let phone = P256.KeyAgreement.PrivateKey()
let server = P256.KeyAgreement.PrivateKey()
let salt = Data("harborbank-channel-v1".utf8)
let info = Data("statement-export".utf8)
let phoneKey = try phone.sharedSecretFromKeyAgreement(with: server.publicKey)
    .hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt, sharedInfo: info, outputByteCount: 32)
let serverKey = try server.sharedSecretFromKeyAgreement(with: phone.publicKey)
    .hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt, sharedInfo: info, outputByteCount: 32)
let box = try ChaChaPoly.seal(statement, using: phoneKey)
print("server opens phone's box:", try ChaChaPoly.open(box, using: serverKey) == statement)

// 5. Signatures: the private key signs, anyone with the public key verifies.
let signingKey = P256.Signing.PrivateKey()
let signature = try signingKey.signature(for: statement)
let publicKeyDER = signingKey.publicKey.derRepresentation           // what you'd register with the server
let verifier = try P256.Signing.PublicKey(derRepresentation: publicKeyDER)
print("signature valid:", verifier.isValidSignature(signature, for: statement))
print("tampered valid:", verifier.isValidSignature(signature, for: Data("Statement 2026-10, account ACC-0000".utf8)))
```

The details that matter:

- **Keys come from CryptoKit.** `SymmetricKey(size: .bits256)` "generates a new random key." Don't derive keys from `Int.random` or from strings. Swift's `SystemRandomNumberGenerator` says it "uses a cryptographically secure algorithm whenever possible," and "whenever possible" isn't a guarantee you want for keys. MASTG-TEST-0311 flags C's `rand`, `random` and the `*rand48` family.
- **Don't pass a nonce.** `seal(_:using:nonce:)` defaults the nonce to `nil`, and CryptoKit creates a random one. Apple's `Nonce` page: "Don't reuse the same nonce for multiple calls to encryption APIs." Passing your own (a counter, a timestamp) is how reuse happens.
- **Store `combined`.** Apple: its layout is "nonce, ciphertext, then tag," and it's "only available when the Nonce size is the default size of 12 bytes," which is why it's optional for AES-GCM. `ChaChaPoly.SealedBox.combined` isn't optional.
- **Opening throws** if the key is wrong or a single byte changed. Treat that as "corrupt or tampered," not as an empty file.
- **The shared secret isn't a key.** Apple's `SharedSecret` page: it "isn't suitable as a symmetric cryptographic key by itself"; derive one with `hkdfDerivedSymmetricKey` (or the X9.63 KDF). The salt and `sharedInfo` bind the key to a purpose, so the same agreement used for two features gives two different keys.
- **Signatures are verified with the public key only.** `derRepresentation` is the form a server-side library can import. The tampered payload fails verification.

> [!note] Newer algorithms
> Apple's CryptoKit documentation also lists HPKE (iOS 17), SHA-3 and post-quantum key encapsulation with ML-KEM (iOS 26). They're for specific protocols; the table above covers what a typical banking app needs. If your security team specifies one of them, read its page for availability before adopting it.

## Comparing secrets

When your code compares a secret value with an attacker's guess (a MAC from a request, a one-time code, a token), **how** it compares matters. Swift's `==` on arrays may stop at the first difference. If the comparison's timing can be measured, each answer leaks how many leading bytes were right, and the attacker can guess byte by byte instead of all at once.

This model counts how many bytes each comparison looks at, which is what timing would reveal:

```swift
/// Returns at the first different byte. `steps` counts the bytes it looked at.
func earlyExitEquals(_ a: [UInt8], _ b: [UInt8], steps: inout Int) -> Bool {
    guard a.count == b.count else { return false }
    for index in a.indices {
        steps += 1
        if a[index] != b[index] { return false }
    }
    return true
}

/// Looks at every byte no matter where the first difference is.
func constantTimeEquals(_ a: [UInt8], _ b: [UInt8], steps: inout Int) -> Bool {
    guard a.count == b.count else { return false }
    var difference: UInt8 = 0
    for index in a.indices {
        steps += 1
        difference |= a[index] ^ b[index]
    }
    return difference == 0
}

let expectedTag: [UInt8] = [0x5A, 0x11, 0xC3, 0x7E, 0x02, 0x9B, 0x44, 0xD0]
let guesses: [[UInt8]] = [
    [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0x5A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0x5A, 0x11, 0xC3, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0x5A, 0x11, 0xC3, 0x7E, 0x02, 0x9B, 0x44, 0xD0],
]
for guess in guesses {
    var early = 0, constant = 0
    let match = earlyExitEquals(guess, expectedTag, steps: &early)
    _ = constantTimeEquals(guess, expectedTag, steps: &constant)
    print("match: \(match)  early-exit steps: \(early)  constant-time steps: \(constant)")
}
```

```output
match: false  early-exit steps: 1  constant-time steps: 8
match: false  early-exit steps: 2  constant-time steps: 8
match: false  early-exit steps: 4  constant-time steps: 8
match: true  early-exit steps: 8  constant-time steps: 8
```

The early-exit version's work grows with each correct leading byte; the constant-time version always does eight. XOR is zero only for equal bytes, and OR-ing every result together means a single difference anywhere leaves `difference` non-zero.

Two cautions:

- **Prefer the library.** With a key, call `HMAC<SHA256>.isValidAuthenticationCode(_:authenticating:using:)` instead of computing a MAC and comparing it yourself. Apple's page doesn't describe its timing, but the open-source Swift Crypto implementation of the same API (used on non-Apple platforms) compares with a constant-time `safeCompare` function. The model above is for understanding, and for comparing things that aren't MACs.
- **Length is public.** Both functions return early on different lengths. That's normal: the length of a MAC or a code isn't secret.

On a phone the more realistic timing attacker is against your **server**, which compares tokens and codes all day. Use the same rule there.

## The Secure Enclave

Apple's "Protecting keys with the Secure Enclave" explains what it adds over the Keychain. A Keychain key is encrypted at rest, but "to use the key, you must briefly copy a plain-text version of it into system memory." With the Secure Enclave, "you never handle the plain-text key": you ask the Secure Enclave to create the key and to perform operations with it, and "you receive only the output of these operations, such as encrypted data or a cryptographic signature verification outcome."

Its limits, in Apple's words:

- "Requires hardware support. Only iOS devices with an A7 or later processor" (and some Macs).
- "Works only with NIST P-256 elliptic curve keys. These keys can only be used for creating and verifying cryptographic signatures, or for elliptic curve Diffie-Hellman key exchange."
- "Can't encode preexisting keys. You must use the Secure Enclave to create the keys."
- "Only the Secure Enclave that created the key can make use of the key."

That last point is a feature for a bank: a key in the Secure Enclave **is** this device. It also means the key doesn't survive a move to a new phone, and the app needs a re-enrollment flow (sign in with the account password, maybe a code by SMS or a call, then create a new key and register it).

### A transfer-approval key

Put Lesson 2 and this lesson together: a P-256 signing key, created inside the Secure Enclave, usable only after Face ID or Touch ID matches the current enrollment. The server stores the public key when the customer turns the feature on, and every transfer approval carries a signature over the exact payload:

```swift ios
import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum DeviceKeyError: Error {
    case noSecureEnclave
    case accessControl
}

/// Creates a P-256 signing key inside the Secure Enclave that signs only after Face ID or Touch ID
/// matches the current enrollment. Register `publicKey` with the server; keep `blob` in the Keychain.
func makeTransferKey() throws -> (publicKey: P256.Signing.PublicKey, blob: Data) {
    guard SecureEnclave.isAvailable else { throw DeviceKeyError.noSecureEnclave }
    guard let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet],
        nil
    ) else { throw DeviceKeyError.accessControl }

    let key = try SecureEnclave.P256.Signing.PrivateKey(
        compactRepresentable: true, accessControl: access, authenticationContext: nil)
    return (key.publicKey, key.dataRepresentation)
}

/// Signs exactly the bytes the server will verify. The biometric prompt appears here.
func signTransfer(_ payload: Data, blob: Data) throws -> Data {
    let context = LAContext()
    context.localizedReason = "Approve this transfer"
    let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: blob, authenticationContext: context)
    return try key.signature(for: payload).derRepresentation
}
```

Line by line:

- **`SecureEnclave.isAvailable`** is Apple's check that "the device supports Secure Enclave access." When it's `false`, offer the feature without device binding or not at all; don't assume the hardware is there.
- **`.privateKeyUsage`** is required. Apple: without it, "key generation still succeeds, but signing operations that attempt to use it fail."
- **`.biometryCurrentSet`** is Lesson 2's flag, now on a key instead of a password item. The match is checked by the same hardware that holds the key.
- **The accessibility class.** CryptoKit's default for these keys is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (from the initializer's declaration). Transfer approval only happens in the foreground, so `WhenPasscodeSetThisDeviceOnly` is stricter at no cost.
- **`dataRepresentation` isn't the private key.** Apple's Keychain sample: "the Secure Enclave exports an encrypted block that only the same Secure Enclave can later use to restore the key." Store it as a generic password item (Module 31's `KeychainStore` works) and recreate the key with `init(dataRepresentation:authenticationContext:)`.
- **Sign what the server checks.** The payload should be the exact bytes of the transfer the person saw (payee, amount, currency) plus a one-time challenge from the server, so a signature can't be replayed for a second transfer. Lesson 7 does the same with App Attest.
- **The signature's DER form** is what server libraries usually accept.

On the server, verification is the last two lines of the CryptoKit tour: import the registered public key and check the signature against the payload. If it fails, the transfer doesn't happen, whatever the app claims.

> [!tip] What this buys over Lesson 2
> A Keychain-bound secret protects the secret on the device. A Secure Enclave signature gives the **server** something to verify: this payload was approved by the key registered for this customer on this device, after a biometric match of the enrollment that existed when they turned the feature on. That's the strongest evidence a phone can produce, and it's also what helps with repudiation (Lesson 1's T8).

## Key management

MASVS-CRYPTO-2: "The app performs key management according to industry best practices." For an app, that comes down to a few rules:

- **No keys in the binary.** MASTG-TEST-0213 and 0214 look for hardcoded keys in code and files. Module 21 showed how easily they come back out.
- **Keys live in the Keychain or the Secure Enclave.** Apple's "Storing CryptoKit Keys in the Keychain" shows the conversions: NIST keys as `SecKey` items, other keys and Secure Enclave blobs as generic passwords.
- **One key, one purpose.** Derive separate keys with HKDF's `sharedInfo` rather than reusing one key for encryption and MACs.
- **Plan rotation and loss.** Keys get rotated (MASWE-0015) and devices get replaced. A server that stores public keys per device can revoke one without touching the others.

## Common mistakes

> [!error] "We encrypt it with AES" and the key is in the app
> If the key ships in the binary or sits next to the ciphertext, the encryption protects nothing from anyone who has the app. Keys come from the Keychain, the Secure Enclave, or the server after authentication.

> [!error] Hashing to prove authenticity
> A SHA-256 of a payload proves nothing about who made it; anyone can recompute it after changing the payload. Use an HMAC with a shared key or a signature.

> [!error] Passing your own nonce
> A counter that resets on reinstall, or a timestamp with second precision, eventually repeats. Let CryptoKit generate the nonce and store the combined box.

> [!error] Comparing MACs or codes with `==`
> Use `HMAC.isValidAuthenticationCode`, or a constant-time comparison when there's no key involved.

> [!error] Treating Secure Enclave keys as portable
> They don't move with backups or to a new phone. Without a re-enrollment path, customers with new phones are locked out of the feature.

## Exercises

````exercise
id: m42-l03-e1
type: prediction
prompt: "This is the core of a constant-time comparison. What does it print?"
code: |
  let expected: [UInt8] = [0x0F, 0xF0, 0xAA]
  let received: [UInt8] = [0x0F, 0xF1, 0xA8]

  var difference: UInt8 = 0
  for index in expected.indices {
      difference |= expected[index] ^ received[index]
      print(index, difference)
  }
  print(difference == 0 ? "match" : "no match")
output: |
  0 0
  1 1
  2 3
  no match
hints:
  - "XOR of two equal bytes is 0; work out 0xF0 ^ 0xF1 and 0xAA ^ 0xA8 in binary."
  - "OR keeps every bit that was ever set."
solution: |
  ```output
  0 0
  1 1
  2 3
  no match
  ```

  - Index 0: `0x0F ^ 0x0F` is `0`, so `difference` stays 0.
  - Index 1: `0xF0 ^ 0xF1` is `0x01`; `0 | 1` is 1.
  - Index 2: `0xAA ^ 0xA8` is `0x02` (`1010 1010` vs `1010 1000`); `1 | 2` is 3.

  Once any bit is set it never clears, so one difference anywhere makes the result "no match," and the loop always runs to the end. `print` inside the loop is only there so you can watch; a real comparison prints nothing.
````

````exercise
id: m42-l03-e2
type: comprehension
prompt: "Harbor Bank caches the last statement on disk so it shows offline. Which is the right tool to keep it confidential and detect tampering?"
choices:
  - text: "AES.GCM.seal with a SymmetricKey stored in the Keychain, saving the combined box."
    correct: true
    why: "AEAD gives confidentiality and integrity; the key lives in the Keychain, and the combined box keeps nonce, ciphertext and tag together."
  - text: "SHA256 of the statement, stored next to it."
    correct: false
    why: "A hash isn't encryption, and an attacker who changes the file can recompute it."
  - text: "Insecure.MD5 of the statement, because it's faster."
    correct: false
    why: "Apple says to avoid the Insecure algorithms for new services, and it still wouldn't encrypt anything."
  - text: "P256.Signing signature of the statement."
    correct: false
    why: "A signature detects changes but doesn't hide the contents."
solution: |
  **AES-GCM (or ChaChaPoly) with a key from the Keychain.** It's the only option that both hides the statement and fails on open if a byte changed.

  Two more layers apply: write the file with `.completeFileProtection` (Lesson 2), so the system's own encryption also covers it while the phone is locked, and keep the key's accessibility class in line with when the app needs to read the cache.
````

````exercise
id: m42-l03-e3
type: fill-in
prompt: "Complete the key agreement so both sides derive a 32-byte key for one purpose."
code: |
  let shared = try phone.[[1]](with: server.publicKey)
  let key = shared.[[2]](using: SHA256.self,
                         salt: Data("harborbank-channel-v1".utf8),
                         sharedInfo: Data("statement-export".utf8),
                         outputByteCount: [[3]])
blanks:
  - id: "1"
    answers: ["sharedSecretFromKeyAgreement"]
  - id: "2"
    answers: ["hkdfDerivedSymmetricKey"]
  - id: "3"
    answers: ["32"]
solution: |
  ```swift illustrative
  let shared = try phone.sharedSecretFromKeyAgreement(with: server.publicKey)
  let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self,
                                           salt: Data("harborbank-channel-v1".utf8),
                                           sharedInfo: Data("statement-export".utf8),
                                           outputByteCount: 32)
  ```

  `sharedSecretFromKeyAgreement(with:)` gives a `SharedSecret`, which Apple says "isn't suitable as a symmetric cryptographic key by itself." HKDF turns it into a `SymmetricKey`; 32 bytes is a 256-bit key for AES-GCM or ChaChaPoly. The `sharedInfo` string names the purpose, so the same agreement used for another feature yields a different key. (The full version is step 4 of the CryptoKit block; this fragment depends on `phone` and `server` from there.)
````

````exercise
id: m42-l03-e4
type: find-errors
prompt: "A pull request adds \"encrypted\" storage for the customer's IBAN. Mark every real problem."
code: |
  let key = SymmetricKey(data: Data("HarborBank-Static-Key-2026!!!!!!".utf8))
  var counter: UInt8 = 0

  func store(_ iban: String) throws {
      counter += 1
      let nonce = try AES.GCM.Nonce(data: Data(repeating: counter, count: 12))
      let box = try AES.GCM.seal(Data(iban.utf8), using: key, nonce: nonce)
      UserDefaults.standard.set(box.ciphertext, forKey: "iban")
      UserDefaults.standard.set(SHA256.hash(data: Data(iban.utf8)).description, forKey: "iban-check")
  }
choices:
  - text: "The key is a string literal compiled into the app."
    correct: true
  - text: "The nonce comes from an 8-bit counter that wraps and resets on every launch, so nonces repeat."
    correct: true
  - text: "Only the ciphertext is stored; without the nonce and tag it can't be opened or verified."
    correct: true
  - text: "A plain SHA-256 of the IBAN is stored next to it; IBANs are guessable, so the hash can be checked against candidates."
    correct: true
  - text: "UserDefaults is a plain plist with no access control; use the Keychain for the IBAN or the key."
    correct: true
  - text: "AES-GCM is broken and should be replaced with ChaChaPoly."
    correct: false
    why: "Both are current AEAD ciphers. The problems here are how they're used, not the algorithm."
rubric:
  - I flagged the hardcoded key.
  - I flagged nonce reuse.
  - I flagged the missing nonce and tag.
  - I flagged the unsalted hash of a low-entropy value.
  - I moved storage out of UserDefaults.
solution: |
  Five problems:

  1. **Hardcoded key.** Anyone with the app has it (MASTG-TEST-0213). Generate a `SymmetricKey(size: .bits256)` once and keep it in the Keychain.
  2. **Nonce reuse.** `counter` starts at 0 each launch and an 8-bit value wraps after 255. Reusing a nonce with the same key breaks AES-GCM's guarantees; Apple says nonces must be "unique per call." Don't pass a nonce at all.
  3. **Only `ciphertext` is saved.** Opening needs the nonce and the tag. Store `box.combined`.
  4. **Hash of the IBAN.** An IBAN has structure and limited entropy; an unsalted SHA-256 lets anyone who knows a candidate confirm it. If you need a lookup key, use an HMAC with a secret key, or don't store one.
  5. **`UserDefaults`.** For a value this small, the simplest secure answer is to put the IBAN itself in the Keychain with a suitable class and skip the homemade encryption entirely.

  AES-GCM itself is fine.
````

````exercise
id: m42-l03-e5
type: solve
prompt: |
  A partner sends a 4-byte tag as hex in a header. Write `hexBytes(_:)`, which turns a hex string (upper or lower case) into bytes and returns `nil` for an odd length or any non-hex character, and `tagMatches(received:expected:)`, which returns `true` only for a valid hex string of the same length whose bytes equal `expected`, comparing in constant time.

  Expected output:

  ```output
  5a11c37e true
  5A11C37E true
  5a11c37f false
  5a11c3 false
  5a11c37g false
  (empty) false
  ```
starter: |
  func hexBytes(_ text: String) -> [UInt8]? {
      // your code
      return nil
  }

  func tagMatches(received: String, expected: [UInt8]) -> Bool {
      // your code
      return false
  }

  let expected: [UInt8] = [0x5A, 0x11, 0xC3, 0x7E]
  for received in ["5a11c37e", "5A11C37E", "5a11c37f", "5a11c3", "5a11c37g", ""] {
      print(received.isEmpty ? "(empty)" : received, tagMatches(received: received, expected: expected))
  }
hints:
  - "Work on `text.utf8` and convert each digit with a switch over ranges like UInt8(ascii: \"0\")...UInt8(ascii: \"9\")."
  - "Combine two digits with `high << 4 | low`."
  - "Reuse the XOR-and-OR loop from the lesson for the comparison."
rubric:
  - Rejects odd lengths and non-hex characters.
  - Accepts upper- and lower-case digits.
  - Compares every byte with XOR and OR, after checking the length.
  - Prints the six expected lines.
solution: |
  ```swift
  func hexBytes(_ text: String) -> [UInt8]? {
      let digits = Array(text.utf8)
      guard digits.count % 2 == 0 else { return nil }
      func value(_ digit: UInt8) -> UInt8? {
          switch digit {
          case UInt8(ascii: "0")...UInt8(ascii: "9"): return digit - UInt8(ascii: "0")
          case UInt8(ascii: "a")...UInt8(ascii: "f"): return digit - UInt8(ascii: "a") + 10
          case UInt8(ascii: "A")...UInt8(ascii: "F"): return digit - UInt8(ascii: "A") + 10
          default: return nil
          }
      }
      var bytes: [UInt8] = []
      var index = 0
      while index < digits.count {
          guard let high = value(digits[index]), let low = value(digits[index + 1]) else { return nil }
          bytes.append(high << 4 | low)
          index += 2
      }
      return bytes
  }

  func tagMatches(received: String, expected: [UInt8]) -> Bool {
      guard let bytes = hexBytes(received), bytes.count == expected.count else { return false }
      var difference: UInt8 = 0
      for index in bytes.indices {
          difference |= bytes[index] ^ expected[index]
      }
      return difference == 0
  }

  let expected: [UInt8] = [0x5A, 0x11, 0xC3, 0x7E]
  for received in ["5a11c37e", "5A11C37E", "5a11c37f", "5a11c3", "5a11c37g", ""] {
      print(received.isEmpty ? "(empty)" : received, tagMatches(received: received, expected: expected))
  }
  ```

  ```output
  5a11c37e true
  5A11C37E true
  5a11c37f false
  5a11c3 false
  5a11c37g false
  (empty) false
  ```

  The empty string parses to zero bytes, then fails the length check. Malformed input returns `false` the same way a wrong tag does, so the caller can't tell a typo from a forgery, which is what you want.

  In production, if you hold the key, compute the HMAC with CryptoKit and call `isValidAuthenticationCode` with the decoded bytes instead of comparing yourself.
````

````exercise
id: m42-l03-e6
type: explain
prompt: "An interviewer asks: \"Why would a bank sign transfer approvals with a Secure Enclave key instead of just sending the session token after Face ID?\" Explain."
code: |
  Option A: Face ID succeeds → app sends POST /transfers with the bearer token.
  Option B: Face ID unlocks a Secure Enclave key → app sends POST /transfers with the token
            and a signature over {payee, amount, currency, challenge}.
rubric:
  - Explains that in A the server can't tell whether Face ID happened; the token alone authorizes.
  - Explains that in B the signature requires the device's Secure Enclave key and, with biometryCurrentSet, a current biometric match.
  - Mentions the challenge to prevent replay and signing the exact displayed payload.
  - Mentions the limits (new device, re-enrollment) and that the server still enforces limits.
solution: |
  In option A, Face ID is a Boolean inside the app. The server receives a bearer token and nothing else; a stolen token, or a modified app that skips the prompt, produces exactly the same request. The server can't distinguish "approved with Face ID" from "not approved."

  In option B, the server receives something only one place can produce: a signature from a P-256 key that was created inside this device's Secure Enclave and never left it, with an access control that requires `.privateKeyUsage` and `.biometryCurrentSet`. The server verifies it with the public key it stored when the customer enrolled the device. That proves three things the token can't: the request came from that device, a biometric match of the enrollment that existed at setup happened, and the payload wasn't changed, because the signature covers the payee, amount and currency the person saw. Including a one-time server challenge stops an old signature from being replayed.

  It's not magic: a new phone means a new key and a re-enrollment flow, and the server still enforces limits, fraud checks and authorization. But it turns "the app says the customer approved" into evidence the bank can check, which also matters when a customer later disputes a transfer.
````

## Summary

- Don't invent cryptography. A repeating-key XOR falls to one known prefix, leaks equal messages and detects no tampering; real ciphers are designed against all three.
- Pick by job: hash for fingerprints, HMAC for shared-key authenticity, AES-GCM or ChaChaPoly for confidentiality with integrity, key agreement plus HKDF for deriving keys, P-256 signatures for proof anyone can verify. Avoid `Insecure.MD5` and `SHA1` for anything new.
- Let CryptoKit generate keys and nonces, store the combined sealed box, and treat a failed open as tampering.
- Compare secrets in constant time; with a key, use `HMAC.isValidAuthenticationCode`.
- The Secure Enclave creates P-256 keys that never leave it, performs signing inside, and binds keys to the device. With `.privateKeyUsage` and `.biometryCurrentSet`, a transfer signature proves to the server that this device and a current biometric match approved that payload. Plan for new devices, because the key doesn't move.
