---
id: m42-l01
title: Threat modeling and OWASP MASVS
description: "Decide what to protect before deciding how. You list a banking app's assets, attackers and entry points, look for threats with STRIDE, rank them by likelihood and impact, and map each one to the OWASP MASVS control groups, the MASWE weaknesses under them and the MASTG tests a security reviewer will run."
module: m42
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l03, m21-l05]
objectives:
  - Describe an app's assets, attackers, entry points and trust boundaries in a short threat model.
  - Use the six STRIDE categories as prompts to find threats in a mobile app.
  - Rank threats by likelihood and impact and record the residual risk after a mitigation.
  - Name the eight MASVS control groups and explain how MASVS controls, MASWE weaknesses and MASTG tests connect.
  - Choose between the MAS testing profiles L1, L2, R and P for an app, and explain where regulation fits without overstating it.
terms:
  - term: Threat model
    definition: "A structured answer to four questions: what are we working on, what can go wrong, what are we going to do about it, and did we do a good enough job."
  - term: Asset
    definition: "Something worth protecting: a credential, personal data, money movement, a key, or the integrity of the app itself."
  - term: Trust boundary
    definition: "A line where data passes between parts with different levels of trust, such as from another app into yours, from the network into the app, or from the app to your server."
  - term: STRIDE
    definition: "A mnemonic for six threat categories: Spoofing, Tampering, Repudiation, Information disclosure, Denial of service and Elevation of privilege."
  - term: MASVS
    definition: "OWASP's Mobile Application Security Verification Standard: 24 platform-neutral controls in eight groups (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY)."
  - term: MASWE
    definition: "OWASP's Mobile Application Security Weakness Enumeration: specific weaknesses that sit between a MASVS control and the MASTG tests that check for it."
  - term: MASTG
    definition: "OWASP's Mobile Application Security Testing Guide: platform-specific tests (MASTG-TEST-xxxx), techniques, tools and demos for verifying the MASVS."
mastery:
  - Write a one-page threat model for a feature, with assets, attackers, entry points and ranked threats.
  - Turn a vague worry ("someone could steal the token") into a STRIDE threat with a likelihood, an impact and a MASVS group.
  - Trace a finding from a MASVS control to a MASWE weakness and an iOS MASTG test, and say which profile it belongs to.
  - Explain to a product manager why the app's own checks can't be the last line of defense.
resources: [owasp-masvs, owasp-mastg, apple-platform-security]
cards:
  - id: m42-l01-c1
    front: What are the four questions of a threat model?
    back: "What are we working on? What can go wrong? What are we going to do about it? Did we do a good enough job? (The Threat Modeling Manifesto, as quoted by OWASP's Threat Modeling Cheat Sheet.)"
  - id: m42-l01-c2
    front: Name the eight MASVS control groups.
    back: "MASVS-STORAGE, MASVS-CRYPTO, MASVS-AUTH, MASVS-NETWORK, MASVS-PLATFORM, MASVS-CODE, MASVS-RESILIENCE and MASVS-PRIVACY. MASVS v2 has 24 controls across them."
  - id: m42-l01-c3
    front: How do MASVS, MASWE and MASTG relate?
    back: "A MASVS control is the requirement (MASVS-STORAGE-2, \"the app prevents leakage of sensitive data\"). MASWE lists the weaknesses that violate it (MASWE-0005, sensitive data in logs). MASTG has platform tests for each weakness (MASTG-TEST-0297 on iOS)."
  - id: m42-l01-c4
    front: What does MAS-L2 assume that MAS-L1 doesn't?
    back: "L1 trusts the OS and treats other apps as adversaries. L2 also assumes the OS can't be trusted (jailbroken device) and that a third party may have physical access. OWASP recommends L2 for apps with high-risk data and sensitive functionality, such as financial apps."
  - id: m42-l01-c5
    front: Why rank threats by likelihood times impact?
    back: "It's a cheap, explicit way to order work: a likely, severe threat comes before an unlikely, moderate one. OWASP's cheat sheet notes it ignores the cost of fixing, so teams sometimes add that as a third factor."
---

## The idea in one sentence

Before you pick a single security control, write down what the app protects, who wants it and how they could reach it; then rank those threats and check each one against OWASP's MASVS, so the controls you build in the rest of this module are the ones that matter for your app.

> [!note] Sources and what was checked
> The MASVS control text, the MASWE weakness lists, the MASTG test titles and the MAS testing profiles were read on mas.owasp.org in November 2026, along with the project's news posts about MASVS v2.1.0, MASWE v1.0.0 and MASTG v2.0.0. The four questions and STRIDE come from OWASP's Threat Modeling Cheat Sheet and Microsoft's Threat Modeling Tool documentation. The ranking code is a model, compiled and run with Swift 6.3. Nothing in this lesson is legal advice.

## Why start with a model

Module 21 showed that a secret compiled into the binary isn't secret, and Module 31 stored tokens in the Keychain. Those were answers. A threat model is the list of questions they answer, written down before the code exists, so that:

- you spend effort where an attacker would, not where it's easy to add a check;
- you can say why a control exists when someone wants to remove it;
- a security reviewer can compare what you meant to protect with what you built.

OWASP's Threat Modeling Cheat Sheet organizes the work around the four questions from the Threat Modeling Manifesto:

1. **What are we working on?** A short description of the app or feature and a diagram of how data moves.
2. **What can go wrong?** The threats.
3. **What are we going to do about it?** Mitigations, or a recorded decision to accept a risk.
4. **Did we do a good enough job?** Review it with the people who build and run the system, and revisit it when the design changes.

The cheat sheet is blunt that there's "no universally accepted industry standard for the threat modeling process." What matters is that the answers exist and are kept current.

## What are we working on: Harbor Bank

The running example for this module is **Harbor Bank**, a fictional retail banking app. It shows balances and transactions, lets a signed-in person pay a saved payee or a new one, and has an in-app help center. The backend is your team's API at `api.harborbank.example`.

### Assets

| Asset | Why it matters |
| --- | --- |
| Session tokens (access and refresh) | Whoever holds them is the customer, as far as the API knows |
| Transfer authorization | Moving money is the action fraud wants |
| Account data: balances, transactions, account numbers | Personal and financial data; useful for social engineering |
| Device-bound keys (Lesson 3, Lesson 7) | Prove that a request came from this install on this device |
| The app's own integrity | A modified copy can skip client-side checks |

### Attackers

Write down who, and what they can do. Vague attackers ("hackers") lead to vague controls.

| Attacker | Realistic capabilities |
| --- | --- |
| Another app on the same phone | Opens your URL schemes, reads the general pasteboard, can't read your container |
| Someone on the same network | Sees and can tamper with traffic that isn't protected by TLS |
| A person holding the unlocked phone | Uses the app as the owner would, sees the screen and the app switcher |
| A thief with a locked phone | Can't unlock it without the passcode; may try to read data from backups or a computer it synced with |
| The customer, turned adversary | Jailbreaks the device, modifies the app, replays requests, disputes transfers |
| A compromised dependency | Runs code inside your process with all your app's permissions (Lesson 7) |

### Entry points and trust boundaries

Every place data crosses into the app from something you don't control is an entry point: URLs and universal links, push notification payloads, the pasteboard, files opened from other apps, web content in a `WKWebView`, responses from your own API, and the UI itself. Each one is a **trust boundary**: on one side the data was produced by someone else; on the other side your code acts on it. Lessons 4 to 6 cover the network, the platform and input boundaries one at a time.

## What can go wrong: STRIDE

**STRIDE** is a mnemonic for six categories of threat, originally from Microsoft and used by OWASP's cheat sheet "as prompts while reviewing the system model." Each category violates a property you want. OWASP's table, with Harbor Bank examples added:

| Category | Violates | Harbor Bank example |
| --- | --- | --- |
| **S**poofing | Authentication | A stolen refresh token lets someone act as the customer |
| **T**ampering | Integrity | A modified app sends a transfer without the confirmation step |
| **R**epudiation | Accounting | A customer disputes a transfer and the server has no reliable record of who approved it |
| **I**nformation disclosure | Confidentiality | An account number written to the device log |
| **D**enial of service | Availability | Repeated failed sign-ins lock a legitimate customer out |
| **E**levation of privilege | Authorization | A crafted link makes the app perform an action the user didn't ask for |

Walk each entry point and each asset and ask the six questions. The output is a list of concrete threats, each with a sentence that names the attacker, the entry point and the asset. "A link from another app opens a prefilled transfer and the app sends it without confirmation" is a threat; "deep links are risky" isn't.

## Ranking

You'll find more threats than you can fix in one release. OWASP's cheat sheet: "In theory, ranking should be based on the mathematical product of an identified threat's likelihood and its impact," and it adds that this ignores the cost of the fix. A three-point scale for each factor is coarse enough to agree on in a meeting:

```swift
enum MASVSGroup: String {
    case storage = "STORAGE", crypto = "CRYPTO", auth = "AUTH", network = "NETWORK"
    case platform = "PLATFORM", code = "CODE", resilience = "RESILIENCE", privacy = "PRIVACY"
}

enum STRIDE: String {
    case spoofing = "S", tampering = "T", repudiation = "R"
    case informationDisclosure = "I", denialOfService = "D", elevationOfPrivilege = "E"
}

struct Threat {
    let id: String
    let summary: String
    let category: STRIDE
    let likelihood: Int   // 1 unlikely, 2 possible, 3 likely
    let impact: Int       // 1 minor, 2 serious, 3 severe
    let group: MASVSGroup

    var score: Int { likelihood * impact }
    var band: String {
        switch score {
        case 6...: "high"
        case 3...5: "medium"
        default: "low"
        }
    }
}

let threats = [
    Threat(id: "T1", summary: "Refresh token copied from an unencrypted file", category: .informationDisclosure, likelihood: 2, impact: 3, group: .storage),
    Threat(id: "T2", summary: "API traffic read through a user-installed CA", category: .informationDisclosure, likelihood: 1, impact: 3, group: .network),
    Threat(id: "T3", summary: "Link opens a prefilled transfer and sends it", category: .elevationOfPrivilege, likelihood: 2, impact: 3, group: .platform),
    Threat(id: "T4", summary: "Someone with the unlocked phone approves a transfer", category: .spoofing, likelihood: 2, impact: 3, group: .auth),
    Threat(id: "T5", summary: "Account number in logs ends up in a support ticket", category: .informationDisclosure, likelihood: 3, impact: 2, group: .storage),
    Threat(id: "T6", summary: "Balance visible in the app switcher snapshot", category: .informationDisclosure, likelihood: 3, impact: 1, group: .platform),
    Threat(id: "T7", summary: "Repackaged app calls the API with checks removed", category: .tampering, likelihood: 1, impact: 2, group: .resilience),
    Threat(id: "T8", summary: "Customer disputes a transfer the server can't attribute", category: .repudiation, likelihood: 1, impact: 3, group: .auth),
]

let ranked = threats.sorted { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }
for threat in ranked {
    print(threat.id, threat.category.rawValue, threat.score, threat.band, "MASVS-\(threat.group.rawValue)", "|", threat.summary)
}
```

```output
T1 I 6 high MASVS-STORAGE | Refresh token copied from an unencrypted file
T3 E 6 high MASVS-PLATFORM | Link opens a prefilled transfer and sends it
T4 S 6 high MASVS-AUTH | Someone with the unlocked phone approves a transfer
T5 I 6 high MASVS-STORAGE | Account number in logs ends up in a support ticket
T2 I 3 medium MASVS-NETWORK | API traffic read through a user-installed CA
T6 I 3 medium MASVS-PLATFORM | Balance visible in the app switcher snapshot
T8 R 3 medium MASVS-AUTH | Customer disputes a transfer the server can't attribute
T7 T 2 low MASVS-RESILIENCE | Repackaged app calls the API with checks removed
```

How to read it:

- **The scores are judgments, written down.** "Likelihood 2" for T1 says: a token in a plain file is reachable through backups or a jailbroken device, but it isn't something every attacker gets. The value of the table is that the team argues about the number once, in the open.
- **The sort is stable on purpose.** Score first, then id, so the list doesn't reshuffle between runs and a review diff shows only real changes.
- **Each threat names a MASVS group.** That's the bridge to the standard: it tells you which controls to read and which tests a reviewer will run.
- **Low isn't "ignore".** T7 is low for this app because the server checks everything that matters (Lesson 7 makes that true). For a game with in-app currency, the same threat could be high.

T2 is worth a second look. The likelihood is low because, per Apple's support article on certificate trust, a root certificate installed from a downloaded or emailed profile "isn't automatically trusted for SSL": the person has to turn it on under Settings > General > About > Certificate Trust Settings. (Certificates installed through MDM are trusted automatically, which matters on managed devices.) The impact is severe because everything in the session would be readable. Lesson 4 is about whether pinning is worth its cost against that threat.

## What are we going to do about it: MASVS

The **OWASP Mobile Application Security Verification Standard** is the reference most mobile security reviews use. In OWASP's words, it "is the industry standard for mobile app security," meant both for developers and for testers "to ensure completeness and consistency of test results." The current major version is **MASVS v2**; its v2.1.0 release in January 2024 added the MASVS-PRIVACY group. It has **24 controls in eight groups**:

| Group | What it covers (OWASP's wording) | Controls |
| --- | --- | --- |
| MASVS-STORAGE | "Secure storage of sensitive data on a device (data-at-rest)" | 1 stores sensitive data securely; 2 prevents leakage |
| MASVS-CRYPTO | "Cryptographic functionality used to protect sensitive data" | 1 current strong cryptography used correctly; 2 key management |
| MASVS-AUTH | "Authentication and authorization mechanisms used by the mobile app" | 1 secure protocols; 2 local authentication per platform best practices; 3 additional authentication for sensitive operations |
| MASVS-NETWORK | "Secure network communication ... (data-in-transit)" | 1 all traffic secured; 2 identity pinning for endpoints under the developer's control |
| MASVS-PLATFORM | "Secure interaction with the underlying mobile platform and other installed apps" | 1 IPC used securely; 2 WebViews used securely; 3 the UI used securely |
| MASVS-CODE | "Security best practices for data processing and keeping the app up-to-date" | 1 up-to-date platform; 2 enforced updates; 3 no components with known vulnerabilities; 4 validates and sanitizes untrusted input |
| MASVS-RESILIENCE | "Resilience to reverse engineering and tampering attempts" | 1 platform integrity; 2 anti-tampering; 3 anti-static analysis; 4 anti-dynamic analysis |
| MASVS-PRIVACY | "Privacy controls to protect user privacy" | 1 minimizes access; 2 prevents identification; 3 transparent about collection; 4 user control over data |

The controls are deliberately abstract. MASVS-STORAGE-2 in full is "The app prevents leakage of sensitive data." To make that testable, OWASP added two layers below it.

### From control to test

- **MASWE** (Mobile Application Security Weakness Enumeration) lists concrete weaknesses, each tied to the MASVS controls it violates. Its v1.0.0 release has 78 weaknesses, numbered MASWE-0001 to MASWE-0078 in MASVS order.
- **MASTG** (Mobile Application Security Testing Guide) has platform-specific tests. Since MASTG v2.0.0, released in June 2026, "every test [is] linked to a specific MASWE weakness." OWASP calls the result a traceability chain: "MASVS control → MASWE weakness → MASTG test → MASTG demo."

Here's that chain for two Harbor Bank threats, with the titles as they appear on mas.owasp.org:

| Threat | MASVS control | MASWE weakness | iOS MASTG tests |
| --- | --- | --- | --- |
| T5, account number in logs | MASVS-STORAGE-2 | MASWE-0005 Insertion of Sensitive Data into Logs | MASTG-TEST-0296 Sensitive Data Exposure in Logs; MASTG-TEST-0297 Sensitive Data Exposure Through Logging APIs |
| T4, someone else approves a transfer | MASVS-AUTH-2, MASVS-AUTH-3 | MASWE-0020 Local Authentication Can Be Bypassed; MASWE-0023 Step-Up Authentication Not Implemented for Sensitive Actions | MASTG-TEST-0266 References to APIs for Event-Bound Biometric Authentication; MASTG-TEST-0270 References to APIs Detecting Biometric Enrollment Changes |

Reading the actual test is the fastest way to know what a reviewer will look for. MASTG-TEST-0266, for example, fails an app that gates a secret with `LAContext.evaluatePolicy` alone instead of a Keychain item with an access control (Lesson 2 explains why). When you write a mitigation in your threat model, link the test that would prove it.

> [!tip] Test IDs change; controls don't
> MASTG v2 replaced many v1 tests (MASTG-TEST-0053 "Checking Logs for Sensitive Data" is now marked deprecated in favor of the v2 tests above). Cite the MASVS control and MASWE ID in your documents, and look up the current MASTG tests when you need them.

### Testing profiles

MASVS v2 moved the old verification levels out of the standard and into the MASTG as **testing profiles**. OWASP's attacker model for each:

| Profile | Attacker model | Recommended for |
| --- | --- | --- |
| MAS-L1 Essential Security | "Other applications installed on the device are adversaries"; the OS is trusted | "all mobile apps as a baseline" |
| MAS-L2 Advanced Security | Also: the OS "cannot be trusted" (rooted or jailbroken), and "a third party with or without physical access is viewed as an adversary" | "apps that handle high-risk sensitive data and contain sensitive functionality" |
| MAS-R Resilient Security | Also: "the primary user of the device is viewed as an adversary" | Apps that need to protect their own logic and business assets; it "is meant to augment and not replace MAS-L1 and MAS-L2" |
| MAS-P Baseline Privacy | Privacy rather than adversaries | "all mobile apps that deal with user-sensitive data" |

A banking app is the textbook L2 case. OWASP's L2 page names "Financial apps that provide access to sensitive information such as credit card numbers or that let the user move funds." Whether you also adopt R-profile measures (jailbreak detection, obfuscation) is a threat-model decision that Lesson 7 examines; OWASP is explicit that their absence "does not inherently introduce vulnerabilities."

## Regulatory context

Banking apps live inside regulation, and interviewers for banking roles expect you to know that it exists without pretending to be a lawyer. Keep three facts straight:

- **Regulation sets obligations for the bank; it rarely names iOS APIs.** Data protection law, payment-card rules and banking supervision decide things like what data you may keep, how customers authenticate for payments, and what must be reported after an incident. The bank's compliance and security teams interpret them.
- **Standards like MASVS are how engineering shows its part.** OWASP's own L2 page says financial apps "typically need to demonstrate compliance with standards and regulations such as PCI DSS, the Gramm-Leach-Bliley Act, and the Sarbanes-Oxley Act" (US examples; other jurisdictions have their own). A threat model with MASVS mappings and passing MASTG tests is evidence you can hand to the people doing that demonstrating.
- **Ask, don't guess.** If a requirement comes from regulation ("transaction approval must use strong authentication"), get the exact wording and its source from compliance, and record it in the threat model next to the control that meets it. This course doesn't state what any specific law requires.

## Did we do a good enough job

A threat model that lives in a wiki page nobody opens isn't doing its job. Practical habits:

- **Keep it next to the code**, in the repository, and update it in the same pull request as a design change (a new entry point, a new SDK, a new kind of data).
- **Record residual risk.** After a mitigation, re-score the threat. If it's still high, the model says so instead of implying it's fixed. Exercise 5 builds that.
- **Prove mitigations with tests.** Lessons 4 to 6 turn several controls into pure functions you can unit-test (pin matching, URL allowlists, log redaction). The MASTG test IDs tell a reviewer where to look.
- **Re-review on change.** OWASP's cheat sheet: the model "must be reviewed by all stakeholders, not just the development or security teams."

## Common mistakes

> [!error] Starting with controls instead of assets
> "Add jailbreak detection and pinning" isn't a plan. Without assets and attackers you can't tell whether pinning addresses a likely threat or whether jailbreak detection protects anything the server doesn't already check.

> [!error] Trusting the app to enforce rules the server should enforce
> A transfer limit checked only in the app is a suggestion. MASVS-AUTH-1 says enforcement "must be on the remote endpoint." The app's checks are for usability; the server's are for security.

> [!error] Vague threats
> "Data could leak" can't be ranked or tested. Name the attacker, the entry point and the asset: "an account number in a log line reaches a support ticket."

> [!error] Treating MASVS-RESILIENCE as a substitute for the rest
> OWASP: resilience controls "provide additional protection against threat-specific attacks. All apps must also fulfill the rest of the OWASP MASVS controls according to their threat model."

> [!error] Citing a regulation you haven't read
> Saying "PSD2 requires X" or "PCI requires Y" in a design review without the source text is how wrong requirements end up in code. Quote it from compliance or don't quote it.

## Exercises

````exercise
id: m42-l01-e1
type: prediction
prompt: "What does this program print?"
code: |
  func band(likelihood: Int, impact: Int) -> String {
      let score = likelihood * impact
      switch score {
      case 6...: return "high"
      case 3...5: return "medium"
      default: return "low"
      }
  }

  print(band(likelihood: 3, impact: 3))
  print(band(likelihood: 2, impact: 3))
  print(band(likelihood: 1, impact: 3))
  print(band(likelihood: 2, impact: 2))
  print(band(likelihood: 1, impact: 2))
output: |
  high
  high
  medium
  medium
  low
hints:
  - "Multiply first, then find the range."
  - "The ranges are 6 and up, 3 to 5, and everything else."
solution: |
  ```output
  high
  high
  medium
  medium
  low
  ```

  The scores are 9, 6, 3, 4 and 2. Six and above is high, three to five is medium, below three is low. Notice that a severe-impact threat (impact 3) only lands in "high" if it's at least possible (likelihood 2): an unlikely but severe threat is medium. That's the scale doing its job, but it's also why you should re-check severe threats by hand: an impact-3 item scored medium may still deserve a mitigation before a lower-impact high one.
````

````exercise
id: m42-l01-e2
type: comprehension
prompt: "Harbor Bank writes `print(\"login ok for \\(accountNumber)\")` in a sign-in handler, and the line ships. Which MASVS control does that violate?"
choices:
  - text: "MASVS-STORAGE-2: the app prevents leakage of sensitive data."
    correct: true
    why: "Logs are one of the unintentional leaks STORAGE-2 covers; its weakness list includes MASWE-0005, Insertion of Sensitive Data into Logs."
  - text: "MASVS-STORAGE-1: the app securely stores sensitive data."
    correct: false
    why: "STORAGE-1 is about data the app means to store. A log line is an unintended side effect, which is STORAGE-2's territory."
  - text: "MASVS-NETWORK-1: the app secures all network traffic."
    correct: false
    why: "Nothing is sent over the network here; the leak is on the device."
  - text: "MASVS-RESILIENCE-3: the app implements anti-static analysis mechanisms."
    correct: false
    why: "Resilience controls are about reverse engineering. Removing the log line, not obfuscating it, is the fix."
solution: |
  **MASVS-STORAGE-2.** OWASP describes it as covering cases "when sensitive data is unintentionally stored or exposed to publicly accessible locations; typically as a side-effect of using certain APIs, system capabilities such as backups or logs." Its MASWE list includes MASWE-0005, "Insertion of Sensitive Data into Logs," and on iOS the MASTG tests for it include MASTG-TEST-0296 and MASTG-TEST-0297.

  STORAGE-1 is the control for data you store on purpose (tokens in the Keychain, files with Data Protection). Lesson 5 covers logs, with redaction you can test.
````

````exercise
id: m42-l01-e3
type: fill-in
prompt: "Complete the STRIDE categories and the property each violates, following OWASP's table."
code: |
  Spoofing                 violates [[1]]
  Tampering                violates Integrity
  [[2]]                    violates Accounting
  Information disclosure   violates [[3]]
  Denial of service        violates [[4]]
  Elevation of privilege   violates Authorization
blanks:
  - id: "1"
    answers: ["Authentication", "authentication"]
  - id: "2"
    answers: ["Repudiation", "repudiation"]
  - id: "3"
    answers: ["Confidentiality", "confidentiality"]
  - id: "4"
    answers: ["Availability", "availability"]
solution: |
  ```text
  Spoofing                 violates Authentication
  Tampering                violates Integrity
  Repudiation              violates Accounting
  Information disclosure   violates Confidentiality
  Denial of service        violates Availability
  Elevation of privilege   violates Authorization
  ```

  Repudiation is the one people forget in mobile work. For a bank it's concrete: a customer says "I didn't send that transfer," and the question is whether the server can show which authenticated session and device approved it. MASWE-0025, "Lack of Non-Repudiation for Critical Actions," sits under MASVS-AUTH-3. The fix is mostly server-side (signed, attributable records); the app's part is to make the approval a deliberate, authenticated step.
````

````exercise
id: m42-l01-e4
type: find-errors
prompt: "A teammate drafts a threat model section for a new \"pay by link\" feature. Mark every real problem."
code: |
  Feature: harborbank://pay?to=ACC123&amount=50 opens the app and pays.

  Attackers: hackers.
  Threats:
    - Deep links are risky.               (medium)
    - Someone could change the amount.     (low: we validate it in the app)
  Mitigations:
    - Add jailbreak detection.
    - Obfuscate the binary so nobody can find the link handler.
  Compliance: PSD2 requires that links pay without confirmation.
choices:
  - text: "The attacker isn't described: who can send the link and what can they do?"
    correct: true
  - text: "The threats are vague; neither names an entry point, attacker and asset in one sentence."
    correct: true
  - text: "The feature pays directly from a link. Links should only fill in a draft that the person confirms."
    correct: true
  - text: "\"We validate it in the app\" doesn't lower the impact; the server must enforce limits and authorization."
    correct: true
  - text: "Jailbreak detection and obfuscation don't address the threat; any app or web page can open the link."
    correct: true
  - text: "The compliance line cites a requirement with no source, and it's implausible."
    correct: true
  - text: "Custom URL schemes can't carry query parameters, so the feature can't work as described."
    correct: false
    why: "They can. URLComponents parses the query of a custom-scheme URL like any other; Module 25 did exactly that."
rubric:
  - I asked for a concrete attacker (another app, a web page, a message) and their capabilities.
  - I rewrote at least one threat with attacker, entry point and asset.
  - I changed the design so the link only prefills and the person confirms.
  - I moved enforcement to the server.
  - I rejected R-profile controls as a mitigation for this threat and flagged the unsourced compliance claim.
solution: |
  Six real problems:

  1. **"Hackers"** isn't an attacker model. Here it's: any app on the phone or any web page can open `harborbank://` (Module 25: any app can register the same scheme, and anyone can link to it).
  2. **Vague threats.** Rewrite as "A link sent in a message opens Harbor Bank and pays a stranger without the customer noticing" (elevation of privilege, MASVS-PLATFORM-1, MASWE-0029 Insecure Deep Links).
  3. **The design is the bug.** Apple's own deep-link guidance says to "limit the available actions to those that don't risk the user's data." A link should open a prefilled draft that the person reviews and confirms with authentication (Lesson 6).
  4. **App-side validation** doesn't lower likelihood or impact against a modified app or a direct API call. The server enforces amounts, payees and authorization.
  5. **Jailbreak detection and obfuscation** are R-profile measures against a different attacker. They do nothing against a link from another app.
  6. **The compliance line** has no source, and a payments rule requiring payment *without* confirmation is the opposite of what you'd expect. Get the actual text from compliance.

  The scheme-and-query claim is false: query parameters work on custom schemes.
````

````exercise
id: m42-l01-e5
type: solve
prompt: |
  Write `residualScores(_:mitigations:)`. Each mitigation lowers one threat's likelihood by some levels, never below 1; several mitigations for the same threat add up. Return each threat's id with its score before and after, sorted by the score after (highest first), then by id. Print each row with `still high` when the score after is 6 or more, `ok` otherwise.

  Expected output for the data in the starter:

  ```output
  T4 6 -> 6 still high
  T1 6 -> 3 ok
  T3 6 -> 3 ok
  T5 6 -> 2 ok
  ```
starter: |
  struct Threat {
      let id: String
      let likelihood: Int
      let impact: Int
  }

  struct Mitigation {
      let threatID: String
      let control: String
      let lowersLikelihoodBy: Int
  }

  func residualScores(_ threats: [Threat], mitigations: [Mitigation]) -> [(id: String, before: Int, after: Int)] {
      // your code
      return []
  }

  let threats = [
      Threat(id: "T1", likelihood: 2, impact: 3),
      Threat(id: "T3", likelihood: 2, impact: 3),
      Threat(id: "T4", likelihood: 2, impact: 3),
      Threat(id: "T5", likelihood: 3, impact: 2),
  ]
  let mitigations = [
      Mitigation(threatID: "T1", control: "Keychain, ThisDeviceOnly", lowersLikelihoodBy: 1),
      Mitigation(threatID: "T3", control: "Links only navigate", lowersLikelihoodBy: 2),
      Mitigation(threatID: "T5", control: "Redacting logger", lowersLikelihoodBy: 1),
      Mitigation(threatID: "T5", control: "Log review in CI", lowersLikelihoodBy: 1),
  ]
hints:
  - "Start from the threat's likelihood and apply every mitigation whose threatID matches."
  - "max(1, likelihood - levels) keeps the floor at 1."
  - "Sort with a closure that compares `after` first and falls back to `id`."
rubric:
  - Applies every matching mitigation and never goes below likelihood 1.
  - Keeps impact unchanged.
  - Sorts by residual score, then id.
  - Prints the four expected lines.
solution: |
  ```swift
  struct Threat {
      let id: String
      let likelihood: Int
      let impact: Int
  }

  struct Mitigation {
      let threatID: String
      let control: String
      let lowersLikelihoodBy: Int
  }

  func residualScores(_ threats: [Threat], mitigations: [Mitigation]) -> [(id: String, before: Int, after: Int)] {
      var result: [(id: String, before: Int, after: Int)] = []
      for threat in threats {
          var likelihood = threat.likelihood
          for mitigation in mitigations where mitigation.threatID == threat.id {
              likelihood = max(1, likelihood - mitigation.lowersLikelihoodBy)
          }
          result.append((threat.id, threat.likelihood * threat.impact, likelihood * threat.impact))
      }
      return result.sorted { $0.after != $1.after ? $0.after > $1.after : $0.id < $1.id }
  }

  let threats = [
      Threat(id: "T1", likelihood: 2, impact: 3),
      Threat(id: "T3", likelihood: 2, impact: 3),
      Threat(id: "T4", likelihood: 2, impact: 3),
      Threat(id: "T5", likelihood: 3, impact: 2),
  ]
  let mitigations = [
      Mitigation(threatID: "T1", control: "Keychain, ThisDeviceOnly", lowersLikelihoodBy: 1),
      Mitigation(threatID: "T3", control: "Links only navigate", lowersLikelihoodBy: 2),
      Mitigation(threatID: "T5", control: "Redacting logger", lowersLikelihoodBy: 1),
      Mitigation(threatID: "T5", control: "Log review in CI", lowersLikelihoodBy: 1),
  ]

  for row in residualScores(threats, mitigations: mitigations) {
      let verdict = row.after >= 6 ? "still high" : "ok"
      print(row.id, "\(row.before) -> \(row.after)", verdict)
  }
  ```

  ```output
  T4 6 -> 6 still high
  T1 6 -> 3 ok
  T3 6 -> 3 ok
  T5 6 -> 2 ok
  ```

  T4 has no mitigation yet, so it stays at the top, which is exactly what the table should tell the team. T3 drops from 2 to the floor of 1 (the second level of reduction is lost), and T5's two mitigations stack to bring likelihood from 3 to 1.

  Mitigations lower likelihood, not impact, in this model. Some controls do reduce impact (a daily transfer limit enforced on the server caps the damage), and a fuller version would let a mitigation change either factor.
````

````exercise
id: m42-l01-e6
type: design
prompt: "Harbor Bank is adding a home-screen widget that shows the account balance. Write the threat-model entry for it: assets, attackers, entry points, at least three STRIDE threats with likelihood and impact, the MASVS group for each, and the mitigation you'd propose."
rubric:
  - Names the balance (and any account identifier) as the asset and the widget's data path (shared container, timeline refresh) as an entry point.
  - Includes a person who can see the locked or unlocked phone, and data at rest in a shared container.
  - Has at least three concrete threats with scores and MASVS groups (STORAGE, PLATFORM, PRIVACY or AUTH).
  - Proposes mitigations such as an opt-in setting, hiding the amount until unlocked, and minimal data in the shared container with the right protection class.
solution: |
  A reasonable entry:

  - **Assets:** the balance; the account name or last digits shown with it; the token the widget's timeline uses to fetch data, if any.
  - **Entry points:** the widget on the home and lock screen (anyone who sees the phone); the shared app-group container the app writes for the widget; the widget extension's network request.
  - **Attackers:** someone near the phone (locked or unlocked); a thief with the locked phone; another app (can't read the app group; only your team's apps can join it).

  | Threat | STRIDE | L × I | MASVS |
  | --- | --- | --- | --- |
  | Balance readable on the lock screen by anyone nearby | I | 3 × 2 = 6 | PLATFORM-3 |
  | Full account number in the shared container, readable while locked because of its protection class | I | 1 × 2 = 2 | STORAGE-1 |
  | Widget extension holds a long-lived token that can do more than read a balance | E | 1 × 3 = 3 | AUTH-1 |
  | Balance shown without the customer having chosen it | I | 2 × 2 = 4 | PRIVACY-1 |

  **Mitigations:** make the widget opt-in; show the amount only when the device is unlocked (or show "Unlock to view"); write only the balance and a display name to the shared container, never a full account number, with a protection class that matches when the widget needs it (Lesson 2); if the widget fetches, give it a read-only, short-lived credential scoped to balances, enforced by the server.

  Re-score after mitigations and keep the table with the feature's code.
````

## Summary

- A threat model answers four questions: what you're building, what can go wrong, what you'll do about it, and whether that was enough. Write down assets, attackers with real capabilities, entry points and trust boundaries.
- STRIDE's six categories (spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege) are prompts for finding threats. A good threat names the attacker, the entry point and the asset.
- Rank by likelihood × impact, keep the scores visible, and re-score after mitigations to record residual risk.
- MASVS v2 has 24 controls in eight groups: STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY. MASWE lists the weaknesses under each control and MASTG v2 has the platform tests, so a finding traces from requirement to test.
- The MAS profiles are L1 (baseline), L2 (untrusted OS and physical access; recommended for financial apps), R (resilience, an addition, never a replacement) and P (privacy). Regulation sets the bank's obligations; get its exact text from compliance and map it to controls instead of guessing.
