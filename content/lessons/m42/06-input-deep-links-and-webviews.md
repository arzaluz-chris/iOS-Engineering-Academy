---
id: m42-l06
title: Validating input, deep links and web content
description: "Treat everything that enters the app from outside as hostile until it's been parsed into a type you trust. You compare naive host checks with an allowlist, turn a payment link into a draft that can only be reviewed and confirmed, block open redirects, and harden a WKWebView: what it may navigate to, which messages its JavaScript bridge accepts, and what files it can read."
module: m42
order: 6
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l05, m25-l06]
objectives:
  - Identify the untrusted entry points of an iOS app and explain why a verified universal link still carries untrusted data.
  - Validate URLs with exact allowlists and explain how contains and hasSuffix checks are bypassed.
  - Turn a deep link into a draft that only navigates, with strict rules for every parameter.
  - Prevent open redirects in a post-login next parameter.
  - Configure a WKWebView with a navigation allowlist, an origin-checked JavaScript bridge, App-Bound Domains and narrow file access.
terms:
  - term: Untrusted input
    definition: "Any data the app didn't produce itself: URLs, push payloads, pasteboard contents, files from other apps, web content, and API responses."
  - term: Allowlist
    definition: "A list of exactly what's accepted (hosts, paths, parameters, characters). Everything else is rejected. The opposite, a blocklist, rejects known-bad values and accepts the rest."
  - term: Open redirect
    definition: "A flaw where a parameter such as next= can send the user to an attacker's site after a trusted step, like signing in."
  - term: JavaScript bridge
    definition: "A WKScriptMessageHandler registered with a WKUserContentController, which lets page scripts send messages to native code."
  - term: App-Bound Domains
    definition: "A WebKit feature (iOS 14) where an app lists up to 10 domains in WKAppBoundDomains; web views that set limitsNavigationsToAppBoundDomains can only navigate there, and others lose script injection and message handlers."
mastery:
  - Write a host check that rejects lookalike, suffix, userinfo, scheme and port tricks, with a test table.
  - Parse a payment link into a validated draft, rejecting unknown and duplicate parameters, and never execute an action from a link.
  - Implement a safe next-path check for redirects after sign-in.
  - Configure a WKWebView navigation delegate and message handler that accept only your own pages and a fixed set of actions.
  - Review WebView code for file access, JavaScript injection and inspectability problems.
resources: [xcode-universal-links, xcode-custom-url-scheme, foundation-urlcomponents, uikit-open-url-contexts, owasp-mastg]
cards:
  - id: m42-l06-c1
    front: Why isn't a universal link trusted input?
    back: "The system verifies that your domain belongs to your app, but anyone can write a link to that domain with any path and parameters. Validate every part, and limit links to navigation."
  - id: m42-l06-c2
    front: What's wrong with host.hasSuffix("harborbank.example")?
    back: "evilharborbank.example passes. Compare the lowercased host against an exact set of allowed hosts, and also check scheme, port and that there's no user info."
  - id: m42-l06-c3
    front: When is UIOpenURLContext's sourceApplication set?
    back: "Only when the app that opened the URL belongs to your developer team; it's nil for other teams' apps and system apps like Safari (OWASP MASTG-TEST-0371). Use it to trust your own app suite, not to identify anyone else."
  - id: m42-l06-c4
    front: Three checks for a WKScriptMessage before acting on it?
    back: "It came from the main frame (frameInfo.isMainFrame); its frame's securityOrigin is https and your host; and the body matches a small, fixed vocabulary of actions with validated parameters."
  - id: m42-l06-c5
    front: How narrow should loadFileURL(_:allowingReadAccessTo:) be?
    back: "The directory that holds only the files that page needs, never the app's Documents or container root. MASTG-TEST-0333 checks for overly broad file read access in WebViews."
---

## The idea in one sentence

Everything that reaches your code from outside the app is attacker-controlled until proven otherwise, so you parse it once at the boundary into a type that can only hold valid values, accept only what's on an explicit allowlist, and make sure no input can do more than navigate.

> [!note] Sources and what was checked
> From Apple: "Defining a custom URL scheme for your app" and "Supporting universal links in your app" (the security warning quoted in Module 25), `scene(_:openURLContexts:)`, `UIScene.OpenURLOptions.sourceApplication`, `WKUserContentController.add(_:contentWorld:name:)`, `WKScriptMessage.frameInfo`, `WKFrameInfo.securityOrigin`, `WKContentWorld`, `webView(_:decidePolicyFor:decisionHandler:)`, `WKWebpagePreferences.allowsContentJavaScript`, `limitsNavigationsToAppBoundDomains`, `loadFileURL(_:allowingReadAccessTo:)` and `isInspectable`. From WebKit's blog: "App-Bound Domains" (June 2020). From OWASP: MASVS-PLATFORM-1, -2 and MASVS-CODE-4, their MASWE lists, and the iOS MASTG tests named below. All read in November 2026. The UIKit and WebKit blocks were type-checked against the iOS SDK, not run. The URL, payment-link, redirect and navigation-policy code is pure Swift with Foundation, compiled and run with Swift 6.3; it avoids URL shapes whose parsing might differ between Foundation on Linux and on Apple platforms.

## Every entry point is input

MASVS-CODE-4 is "The app validates and sanitizes all untrusted inputs," and OWASP lists where they come from: "the UI, IPC, the network, the file system, etc." Lesson 1's entry points, as input:

| Entry point | Who controls the content |
| --- | --- |
| Custom URL scheme (`harborbank://...`) | Any app, any web page. Module 25: "If multiple apps register the same scheme, the app the system targets is undefined." |
| Universal link (`https://harborbank.example/...`) | Your domain is verified, but anyone can write a link with any path and query |
| Push notification payload | Your server, or whoever compromises the path to it |
| Pasteboard, files shared into the app | Other apps and the person |
| Web content in a `WKWebView` | The web page, its scripts and anything it embeds |
| API responses | Your server; also anything between, if TLS were broken (Lesson 4) |

Apple's warning, from both linking articles: links "offer a potential attack vector into your app, so make sure to validate all URL parameters and discard any malformed URLs. In addition, limit the available actions to those that don't risk the user's data." OWASP's MASWE-0029, "Insecure Deep Links," and MASWE-0050, "Unsafe Handling of Untrusted Data," cover the same ground; MASTG-TEST-0370 and 0395 test input validation in custom-scheme and universal-link handlers.

## Host checks that look right

The most common deep-link and WebView bug is a host check that accepts more than intended. Three versions side by side:

```swift
import Foundation

// Three ways to decide whether a link "belongs to us". Two are wrong.
func naiveContains(_ url: URL) -> Bool {
    url.absoluteString.contains("harborbank.example")
}

func naiveSuffix(_ url: URL) -> Bool {
    (url.host ?? "").hasSuffix("harborbank.example")
}

let allowedHosts: Set<String> = ["harborbank.example", "www.harborbank.example"]

func isOurs(_ url: URL) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.scheme?.lowercased() == "https",
          components.user == nil, components.password == nil,
          components.port == nil,
          let host = components.host?.lowercased()
    else { return false }
    return allowedHosts.contains(host)
}

let candidates = [
    "https://harborbank.example/pay",
    "https://evilharborbank.example/pay",
    "https://harborbank.example.attacker.test/pay",
    "https://attacker.test/?next=harborbank.example",
    "https://harborbank.example@attacker.test/pay",
    "http://harborbank.example/pay",
    "https://harborbank.example:8443/pay",
]
print("contains  suffix  allowlist  url")
for text in candidates {
    let url = URL(string: text)!
    let row = [naiveContains(url), naiveSuffix(url), isOurs(url)].map { $0 ? "yes" : "no " }
    print(row[0] + "       " + row[1] + "     " + row[2] + "        " + text)
}
```

```output
contains  suffix  allowlist  url
yes       yes     yes        https://harborbank.example/pay
yes       yes     no         https://evilharborbank.example/pay
yes       no      no         https://harborbank.example.attacker.test/pay
yes       no      no         https://attacker.test/?next=harborbank.example
yes       no      no         https://harborbank.example@attacker.test/pay
yes       yes     no         http://harborbank.example/pay
yes       yes     no         https://harborbank.example:8443/pay
```

- **`contains`** on the whole string accepts every row, including one where your domain only appears in a query parameter.
- **`hasSuffix`** on the host fixes some of that, but `evilharborbank.example` ends with `harborbank.example` too. If you must match subdomains, compare against `"." + domain` *and* the exact domain, and even then prefer listing hosts.
- **User info.** In `https://harborbank.example@attacker.test/pay`, `harborbank.example` is the user name and the host is `attacker.test`. Anything that eyeballs the start of the string is fooled; `URLComponents` isn't, and the allowlist also rejects any URL with user info.
- **Scheme and port** matter: `http` loses TLS, and a different port can be a different service.
- **Lowercase before comparing.** Host names aren't case-sensitive.

The rule behind all of it: **parse with `URLComponents`, then compare exact values against an allowlist.**

## Links navigate, they don't act

Harbor Bank wants "pay by link": a customer shares `https://harborbank.example/pay?to=...&amount=...&note=...` and the recipient's app opens a payment. Lesson 1's T3 was the version where the link sends the payment. The safe version produces a **draft**, the person reviews it on the normal payment screen and confirms with authentication (Lesson 2 and 3), and every parameter has a precise rule:

```swift
import Foundation

/// A payment link can only fill in a form. The person still reviews and confirms in the app.
struct PaymentDraft: Equatable {
    let payee: String
    let amountInCents: Int
    let note: String
}

enum LinkError: Error, Equatable {
    case notOurs, unknownPath, missing(String), invalid(String), unexpected(String)
}

func parseAmount(_ text: String) -> Int? {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2, let whole = parts.first, !whole.isEmpty, whole.count <= 6,
          whole.allSatisfy({ $0.isASCII && $0.isNumber }), let units = Int(whole) else { return nil }
    var cents = 0
    if parts.count == 2 {
        let fraction = parts[1]
        guard fraction.count == 2, fraction.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(fraction) else { return nil }
        cents = value
    }
    let total = units * 100 + cents
    return (1...1_000_000_00).contains(total) ? total : nil
}

func draft(from url: URL) throws(LinkError) -> PaymentDraft {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.scheme == "https", components.host == "harborbank.example",
          components.user == nil, components.port == nil else { throw .notOurs }
    guard components.path == "/pay" else { throw .unknownPath }

    var values: [String: String] = [:]
    for item in components.queryItems ?? [] {
        guard ["to", "amount", "note"].contains(item.name) else { throw .unexpected(item.name) }
        guard values[item.name] == nil else { throw .invalid(item.name) }      // no duplicates
        values[item.name] = item.value ?? ""
    }
    guard let payee = values["to"] else { throw .missing("to") }
    guard payee.count >= 6, payee.count <= 34,
          payee.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { throw .invalid("to") }
    guard let amountText = values["amount"] else { throw .missing("amount") }
    guard let cents = parseAmount(amountText) else { throw .invalid("amount") }
    let note = values["note"] ?? ""
    guard note.count <= 140, !note.contains(where: { $0.isNewline }) else { throw .invalid("note") }
    return PaymentDraft(payee: payee, amountInCents: cents, note: note)
}

let links = [
    "https://harborbank.example/pay?to=ACC77310042&amount=25.50&note=Dinner",
    "https://harborbank.example/pay?to=ACC77310042&amount=25.5",
    "https://harborbank.example/pay?to=ACC77310042&amount=-10",
    "https://harborbank.example/pay?to=ACC77310042&amount=1e9",
    "https://harborbank.example/pay?to=ACC77310042&amount=10&amount=9000",
    "https://harborbank.example/pay?to=ACC77310042&amount=10&confirm=true",
    "https://harborbank.example/pay?to=ACC%2F..%2F1&amount=10",
    "https://harborbank.example/transfer/execute?to=ACC77310042",
]
for link in links {
    do {
        let result = try draft(from: URL(string: link)!)
        print("draft:", result.payee, result.amountInCents, "cents,", result.note.isEmpty ? "no note" : "note \"\(result.note)\"")
    } catch {
        print("rejected:", error)
    }
}
```

```output
draft: ACC77310042 2550 cents, note "Dinner"
rejected: invalid("amount")
rejected: invalid("amount")
rejected: invalid("amount")
rejected: invalid("amount")
rejected: unexpected("confirm")
rejected: invalid("to")
rejected: unknownPath
```

What each rule is for:

- **Money is parsed into integer cents**, from a strict format: up to six digits, optionally a period and exactly two digits. `25.5`, `-10` and `1e9` are all rejected. `Double("1e9")` would happily return a billion; floating-point never touches the amount.
- **Unknown parameters are errors**, not ignored. `confirm=true` does nothing in this parser, but a future developer might add a feature that reads it. Rejecting unknown keys keeps the link's vocabulary exactly what you reviewed.
- **Duplicates are errors.** With `amount=10&amount=9000`, which one wins depends on whoever reads the query. Refusing both removes the ambiguity.
- **Percent-decoding happens before validation.** `URLComponents` decodes `ACC%2F..%2F1` to `ACC/../1`, which fails the letters-and-digits rule. Validate decoded values.
- **The path is exact.** `/transfer/execute` isn't a route, so the link is rejected, not "best effort" mapped to something nearby.
- **Typed throws** (`throws(LinkError)`) make the set of failures part of the signature, so tests can check each rejection reason.

The draft goes to the same screen a manual payment uses. If the payee is new, the bank's usual new-payee checks apply. The link never skips a step a manual payment has.

### Where links arrive

Module 25 covered the scene delegate methods. The security-relevant part:

```swift ios
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let ourApps: Set<String> = ["com.example.harborbank.business"]

    // Custom scheme: any app or web page can send this.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else { return }
        // Set only when the sender belongs to our team; nil for every other app and for Safari.
        let fromOurApp = context.options.sourceApplication.map { ourApps.contains($0) } ?? false
        handle(context.url, fromOurApp: fromOurApp)
    }

    // Universal link: the domain is verified, the rest of the URL is still whatever the sender wrote.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handle(url, fromOurApp: false)
    }

    private func handle(_ url: URL, fromOurApp: Bool) {
        // Parse into a route or a payment draft (pure, unit-tested functions), then navigate.
        // Nothing here moves money: a draft is shown for review and confirmed with authentication.
    }
}
```

`sourceApplication` is "the bundle ID of the app that originated the request," but OWASP's MASTG-TEST-0371 notes the platform limit: "Apple only populates sourceApplication when the calling app belongs to the same Apple Developer Team. Apps from other teams or system apps (e.g. Notes, Safari) will have sourceApplication set to nil." It can tell you that a link came from your own business app; it can't identify anyone else. Treat `false` as the normal case.

## Redirects after sign-in

A related bug: the sign-in screen accepts `?next=` so the app (or the web view) returns to where the person was. If `next` can be a full URL, a phishing link can send someone through your real sign-in and then to a lookalike page that asks them to "confirm" their card. The fix is the same pattern: accept only relative paths inside your app, from a fixed set of roots. Exercise 5 builds it.

## Other inputs, briefly

- **Push payloads** are input from the network. Decode them with `Codable` into types with validated fields, and route through the same draft and route types as links. Never put an action in a push ("approve transfer 123") that the app executes without the normal screen.
- **API responses**: decode strictly. A response that doesn't match the schema is an error, not something to coerce. MASTG-TEST-0386 looks for object deserialization of untrusted data; if you use `NSKeyedUnarchiver`, use secure coding with an explicit list of classes, or better, use `Codable`.
- **Files shared into the app**: check type and size before parsing, and parse in a way that fails cleanly.

## WKWebView

A `WKWebView` runs someone's HTML and JavaScript inside your app. MASVS-PLATFORM-2 ("The app uses WebViews securely") is about keeping that from becoming a way into native code or local files. Its MASWE list names the risks: MASWE-0033 "Sensitive Native Functionality Exposed in WebViews," MASWE-0034 "WebViews Allow Access to Local Resources with Untrusted Content," MASWE-0035 "WebViews Loading Untrusted Content," and MASWE-0063 "Debug Mechanisms Not Disabled."

For Harbor Bank the web view shows the help center, which is your content. Everything else (news articles, partner sites) opens in Safari or `SFSafariViewController`, where it can't reach your bridge.

### What may load

Decide navigation with a pure function you can test:

```swift
import Foundation

enum NavigationDecision: String {
    case allow = "allow in web view"
    case openExternally = "open in Safari"
    case cancel = "cancel"
}

let webContentHosts: Set<String> = ["help.harborbank.example"]

/// The web view shows only our help pages. Other web links leave the app; everything else stops.
func decide(_ url: URL, isMainFrame: Bool) -> NavigationDecision {
    guard let scheme = url.scheme?.lowercased() else { return .cancel }
    switch scheme {
    case "https":
        let host = url.host?.lowercased() ?? ""
        if webContentHosts.contains(host) { return .allow }
        return isMainFrame ? .openExternally : .cancel
    case "about":
        return url.absoluteString == "about:blank" ? .allow : .cancel
    default:
        return .cancel             // http, file, data, javascript, custom schemes, tel...
    }
}

let requests: [(String, Bool)] = [
    ("https://help.harborbank.example/cards/lost", true),
    ("https://help.harborbank.example/embed/video", false),
    ("https://ads.tracker.test/pixel", false),
    ("https://news.example.org/article", true),
    ("http://help.harborbank.example/cards/lost", true),
    ("file:///private/var/mobile/Containers/Data/secrets.json", true),
    ("harborbank://transfer?to=ACC1&amount=900", true),
    ("about:blank", false),
]
for (text, isMainFrame) in requests {
    print(decide(URL(string: text)!, isMainFrame: isMainFrame).rawValue.padding(toLength: 18, withPad: " ", startingAt: 0), text)
}
```

```output
allow in web view  https://help.harborbank.example/cards/lost
allow in web view  https://help.harborbank.example/embed/video
cancel             https://ads.tracker.test/pixel
open in Safari     https://news.example.org/article
cancel             http://help.harborbank.example/cards/lost
cancel             file:///private/var/mobile/Containers/Data/secrets.json
cancel             harborbank://transfer?to=ACC1&amount=900
allow in web view  about:blank
```

- **Your own pages** load in the web view, in the main frame or an iframe.
- **Other https pages** leave the app if the person tapped a link (main frame) and are cancelled if a page tries to load them into an iframe.
- **Everything else is cancelled**: plain `http`, `file:` URLs, and your own custom scheme. A help page that could navigate to `harborbank://transfer...` would turn any injected link into a deep link from *inside* your app.

The navigation delegate calls this for navigations (top-level and frames), not for every image or script a page loads; those are governed by the page and ATS.

### The bridge, and the rest of the configuration

```swift ios
import UIKit
import WebKit

/// Forwards script messages without the user content controller keeping the controller alive.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

final class HelpCenterViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private let helpHost = "help.harborbank.example"
    private var webView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = WKWebViewConfiguration()
        configuration.limitsNavigationsToAppBoundDomains = true      // with WKAppBoundDomains in Info.plist
        configuration.userContentController.add(WeakScriptMessageHandler(self), contentWorld: .page, name: "help")

        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)
        self.webView = webView

        if let start = URL(string: "https://help.harborbank.example/") {
            webView.load(URLRequest(url: start))
        }
    }

    // Navigation: only our help pages load here; other https links leave the app; everything else stops.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.scheme?.lowercased() == "https" else {
            decisionHandler(.cancel)
            return
        }
        if url.host?.lowercased() == helpHost {
            decisionHandler(.allow)
            return
        }
        if navigationAction.targetFrame?.isMainFrame ?? true {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    // The bridge: a tiny vocabulary, accepted only from our page's main frame.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let origin = message.frameInfo.securityOrigin
        guard message.frameInfo.isMainFrame,
              origin.protocol == "https", origin.host == helpHost,
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        switch action {
        case "openCardSettings":
            showCardSettings()
        case "contactSupport":
            showSupportChat()
        default:
            return                                    // unknown actions are ignored, not guessed at
        }
    }

    private func showCardSettings() {}
    private func showSupportChat() {}
}
```

Each part, and the rule behind it:

- **App-Bound Domains.** WebKit's blog: an app lists up to 10 domains in the `WKAppBoundDomains` Info.plist key. Once that key exists, "all WKWebView instances in the application default to a mode where JavaScript injection, custom style sheets, cookie manipulation, and message handler use is denied." A web view that sets `limitsNavigationsToAppBoundDomains` gets those APIs back for app-bound domains, and "any attempt to navigate away from an app-bound domain will fail." It's a second wall behind the navigation delegate, enforced by WebKit.
- **The navigation delegate** applies the policy from the tested function. `targetFrame` is `nil` for links that open a new window, so those count as main-frame taps. Apple: "If you implement this method, always execute the `decisionHandler` block."
- **The bridge checks where a message came from.** `frameInfo` is "the frame that sent the message," and its `securityOrigin` "consists of a host name, a protocol, and a port number." An ad iframe or a page you navigated to by mistake can call `window.webkit.messageHandlers.help.postMessage` just as easily as your page; the origin check is what tells them apart.
- **A fixed vocabulary.** The bridge maps a handful of action names to native screens. It never takes a URL, a file path, a JavaScript string or an amount from the page and acts on it. MASTG-TEST-0376 looks for native bridges in WebViews; the smaller the vocabulary, the easier that review.
- **The weak forwarder.** `WKUserContentController` keeps a strong reference to its message handlers, so adding `self` directly creates a retain cycle with the view controller. The forwarder breaks it.
- **The `.page` content world** is the page's own JavaScript namespace (what `add(_:name:)` uses by default); messages from page scripts arrive there. If you inject your own scripts, run them in a separate `WKContentWorld` so page scripts can't tamper with their variables; Apple notes a content world "doesn't apply to the current document or DOM," which the page can still change.

Three more settings, not shown above because the defaults are right:

- **JavaScript off for untrusted content.** If a web view must show HTML you don't control (an email body, a partner's terms page), set `WKWebpagePreferences.allowsContentJavaScript` to `false`; Apple: the web view then "doesn't execute JavaScript code referenced by the web content," including inline scripts and `javascript:` URLs. And don't add a bridge to that web view.
- **File access.** `loadFileURL(_:allowingReadAccessTo:)` grants the page read access to a directory. Pass the folder that holds only that page's files, never Documents or the container. MASTG-TEST-0333 checks for "Overly Broad File Read Access in WebViews."
- **Inspection.** `isInspectable` "defaults to false" (iOS 16.4 and later). Leave it that way in release builds; turn it on only in Debug.

And two things not to do: don't build JavaScript by interpolating data into `evaluateJavaScript` (MASTG-TEST-0379 and 0380 look for that, especially sensitive data written into the DOM), and don't use `UIWebView`, which is long deprecated (MASTG-TEST-0331).

## Common mistakes

> [!error] `if url.host?.contains("harborbank") == true`
> Accepts `harborbank.attacker.test`, `notharborbank.example` and more. Parse with `URLComponents` and compare against an exact set.

> [!error] A link or push that performs an action
> "Approve", "pay", "delete" and "change limit" are buttons on screens, never URLs. Links produce routes and drafts; the person confirms.

> [!error] Ignoring unknown query parameters
> Today they do nothing; next year someone adds `skipConfirmation`. Reject parameters that aren't in the link's documented vocabulary.

> [!error] A JavaScript bridge without an origin check
> Any frame in the web view, including ads and third-party embeds, can post to your handler. Check `isMainFrame` and the security origin, and keep the action list short.

> [!error] `loadFileURL(page, allowingReadAccessTo: documentsDirectory)`
> The page, and anything injected into it, can read every file in Documents. Give it the narrowest folder that contains its own files.

## Exercises

````exercise
id: m42-l06-e1
type: prediction
prompt: "Each line prints the result of a suffix check and an exact host check. What does the program print?"
code: |
  import Foundation

  func naiveSuffix(_ text: String) -> Bool {
      (URL(string: text)?.host ?? "").hasSuffix("harborbank.example")
  }

  func exactHost(_ text: String) -> Bool {
      URL(string: text)?.host == "harborbank.example"
  }

  for text in ["https://harborbank.example/pay",
               "https://myharborbank.example/pay",
               "https://harborbank.example.attacker.test/pay",
               "https://harborbank.example@attacker.test/pay"] {
      print(naiveSuffix(text), exactHost(text))
  }
output: |
  true true
  true false
  false false
  false false
hints:
  - "Work out the host of each URL first. In the last one, what comes before @ is user info."
  - "hasSuffix only looks at the end of the host string."
solution: |
  ```output
  true true
  true false
  false false
  false false
  ```

  - The real host passes both.
  - `myharborbank.example` ends with `harborbank.example`, so the suffix check accepts a domain anyone could register.
  - `harborbank.example.attacker.test` ends with `attacker.test`; both reject it.
  - In `https://harborbank.example@attacker.test/pay` the host is `attacker.test`; `harborbank.example` is the user name. Both reject it, but a check on the raw string (like `hasPrefix("https://harborbank.example")`) would have accepted it.

  The exact check is right here. A complete one also requires `https`, no port and no user info, as the lesson's `isOurs` does.
````

````exercise
id: m42-l06-e2
type: comprehension
prompt: "Harbor Bank's `harborbank://` handler receives a URL whose `sourceApplication` is `nil`. What can you conclude?"
choices:
  - text: "Only that it didn't come from an app on your developer team; it could be Safari, Notes or any other app."
    correct: true
    why: "Apple fills sourceApplication only for apps from the same team; everything else is nil."
  - text: "That it came from Safari."
    correct: false
    why: "Safari is one possibility among many; nil doesn't identify the sender."
  - text: "That it's malicious and must be rejected."
    correct: false
    why: "Most legitimate links (from Messages, Mail, Safari) arrive this way. Validate the URL instead."
  - text: "That the system verified the link against your apple-app-site-association file."
    correct: false
    why: "That's universal links, which arrive as an NSUserActivity, not through openURLContexts."
solution: |
  **Only that the sender isn't one of your team's apps.** OWASP's MASTG-TEST-0371: "Apple only populates sourceApplication when the calling app belongs to the same Apple Developer Team. Apps from other teams or system apps (e.g. Notes, Safari) will have sourceApplication set to nil."

  So `sourceApplication` can unlock something extra for your own app suite (say, a hand-off from the business app), but it can't be the security check for anyone else. The URL itself still needs full validation in every case.
````

````exercise
id: m42-l06-e3
type: fill-in
prompt: "Complete the configuration for a web view that shows a partner's terms page you don't control: no JavaScript from the content, and no bridge."
code: |
  let preferences = WKWebpagePreferences()
  preferences.[[1]] = [[2]]
  let configuration = WKWebViewConfiguration()
  configuration.[[3]] = preferences
  let webView = WKWebView(frame: .zero, configuration: configuration)
  // No userContentController.add(...) here.
blanks:
  - id: "1"
    answers: ["allowsContentJavaScript"]
  - id: "2"
    answers: ["false"]
  - id: "3"
    answers: ["defaultWebpagePreferences"]
solution: |
  ```swift ios
  import WebKit

  @MainActor
  func makeTermsWebView() -> WKWebView {
      let preferences = WKWebpagePreferences()
      preferences.allowsContentJavaScript = false
      let configuration = WKWebViewConfiguration()
      configuration.defaultWebpagePreferences = preferences
      return WKWebView(frame: .zero, configuration: configuration)
  }
  ```

  With `allowsContentJavaScript` set to `false`, Apple says the web view "doesn't execute JavaScript code referenced by the web content. That includes JavaScript code found in inline `<script>` elements, `javascript:` URLs, and all other referenced JavaScript content." Without a message handler there's no bridge to reach. Navigation still needs the delegate from the lesson, so a link in the terms can't take the web view somewhere else.
````

````exercise
id: m42-l06-e4
type: find-errors
prompt: "Review this bridge from a pull request. Mark every real problem."
code: |
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
      guard let body = message.body as? [String: String] else { return }
      switch body["action"] {
      case "open":
          if let url = URL(string: body["url"] ?? "") { UIApplication.shared.open(url) }
      case "readFile":
          let text = try? String(contentsOfFile: body["path"] ?? "", encoding: .utf8)
          webView.evaluateJavaScript("show('\(text ?? "")')")
      case "transfer":
          api.send(Transfer(to: body["to"]!, amount: Double(body["amount"]!)!))
      default:
          break
      }
  }
choices:
  - text: "No check of frameInfo.isMainFrame or the security origin, so any frame can call it."
    correct: true
  - text: "\"open\" passes any URL from the page to UIApplication.open, including your own custom scheme."
    correct: true
  - text: "\"readFile\" lets the page read any file the app can read, by path."
    correct: true
  - text: "The file contents are interpolated into JavaScript, which breaks on quotes and lets file contents run as script."
    correct: true
  - text: "\"transfer\" moves money from a web message, with force unwraps and a Double amount."
    correct: true
  - text: "message.body can't be a dictionary; WebKit only delivers strings."
    correct: false
    why: "WebKit converts JavaScript objects into dictionaries (and arrays, numbers, strings). The cast is fine; what's done with the values isn't."
rubric:
  - I flagged the missing origin and frame checks.
  - I flagged the unrestricted URL opening.
  - I flagged the arbitrary file read.
  - I flagged the JavaScript built by string interpolation.
  - I flagged money movement from the bridge.
solution: |
  Five problems:

  1. **No origin check.** Add `message.frameInfo.isMainFrame` and compare `securityOrigin.protocol` and `.host` with your help host.
  2. **`open` with any URL.** A page could open `harborbank://...` and turn into a deep-link sender inside your own app, or `tel:` links. Map named actions to specific screens instead.
  3. **`readFile` by path.** That's MASWE-0034's local resource access, by design. There's no safe version of "read the path the page asks for."
  4. **`evaluateJavaScript` with interpolated data.** A quote in the file ends the string and the rest runs as script (MASTG-TEST-0379, 0380). If you must send data to a page, pass it as JSON through a structured API and never put sensitive data into the DOM.
  5. **`transfer` from a web message.** The bridge must not move money. Open the native payment screen with a draft at most, with the same validation as a link (integer cents, payee rules), and let the person confirm.
````

````exercise
id: m42-l06-e5
type: solve
prompt: |
  Sign-in accepts a `next` parameter. Write `safeNextPath(_:)`: return `next` only if it's a relative path inside the app, otherwise `"/"`. Rules: it starts with `/` but not `//`; at most 200 characters; only ASCII, no whitespace, no backslash, no `@`; the first path segment (before any `?`) is one of `accounts`, `cards`, `pay`, `settings`; no `.` or `..` segments.

  Expected output:

  ```output
  /cards/4417 -> /cards/4417
  /pay?to=ACC77310042 -> /pay?to=ACC77310042
  https://attacker.test/login -> /
  //attacker.test/login -> /
  /\attacker.test -> /
  /accounts/../admin -> /
  /admin -> /
  /cards/ 4417 -> /
  nil -> /
  ```
starter: |
  func safeNextPath(_ next: String?) -> String {
      // your code
      return "/"
  }

  let inputs: [String?] = [
      "/cards/4417",
      "/pay?to=ACC77310042",
      "https://attacker.test/login",
      "//attacker.test/login",
      "/\\attacker.test",
      "/accounts/../admin",
      "/admin",
      "/cards/ 4417",
      nil,
  ]
  for input in inputs {
      print(input ?? "nil", "->", safeNextPath(input))
  }
hints:
  - "`//attacker.test` is a protocol-relative URL: browsers treat it as another host."
  - "Some URL parsers treat a backslash like a slash, so `/\\attacker.test` can become `//attacker.test`."
  - "Split off the query with split(separator: \"?\", maxSplits: 1, omittingEmptySubsequences: false), then split the path on \"/\"."
rubric:
  - Rejects absolute and protocol-relative URLs, backslashes, @ and whitespace.
  - Accepts only the four roots and rejects dot segments.
  - Returns "/" for nil and every rejection.
  - Prints the nine expected lines.
solution: |
  ```swift
  /// Returns a path inside the app to open after sign-in, or "/" when `next` isn't one of ours.
  func safeNextPath(_ next: String?) -> String {
      guard let next, next.hasPrefix("/"), !next.hasPrefix("//"), next.count <= 200 else { return "/" }
      guard next.allSatisfy({ $0.isASCII && !$0.isWhitespace && $0 != "\\" && $0 != "@" }) else { return "/" }

      let path = next.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
      let segments = path.split(separator: "/")
      guard let first = segments.first, ["accounts", "cards", "pay", "settings"].contains(String(first)),
            !segments.contains(".."), !segments.contains(".") else { return "/" }
      return next
  }

  let inputs: [String?] = [
      "/cards/4417",
      "/pay?to=ACC77310042",
      "https://attacker.test/login",
      "//attacker.test/login",
      "/\\attacker.test",
      "/accounts/../admin",
      "/admin",
      "/cards/ 4417",
      nil,
  ]
  for input in inputs {
      print(input ?? "nil", "->", safeNextPath(input))
  }
  ```

  ```output
  /cards/4417 -> /cards/4417
  /pay?to=ACC77310042 -> /pay?to=ACC77310042
  https://attacker.test/login -> /
  //attacker.test/login -> /
  /\attacker.test -> /
  /accounts/../admin -> /
  /admin -> /
  /cards/ 4417 -> /
  nil -> /
  ```

  It's an allowlist of shapes and roots, written on the string itself, so it doesn't depend on how any URL parser treats odd input. Failing to `"/"` (home) instead of an error page keeps sign-in working when the parameter is junk.

  The returned path still goes through the app's normal router (Module 25), which applies its own rules. This function only decides whether the value is allowed to be a destination at all; the `/pay` route must still produce a draft, not a payment.
````

````exercise
id: m42-l06-e6
type: design
prompt: "Write the security section of the spec for Harbor Bank's \"pay by link\" feature: the link format, validation rules, what happens on open for a new and an existing payee, how the person confirms, what the server checks, and which MASVS controls and MASTG tests it maps to."
rubric:
  - Specifies a universal link on the bank's domain with an exact path and a closed set of parameters, each with a precise rule.
  - Says the link produces a draft on the normal payment screen, with new-payee checks and authenticated confirmation.
  - Puts enforcement (limits, payee checks, signature verification) on the server.
  - Maps to MASVS-PLATFORM-1 and MASVS-CODE-4 (MASWE-0029, MASWE-0050) and names MASTG-TEST-0395 or 0370.
solution: |
  **Format.** `https://harborbank.example/pay?to=<payee>&amount=<amount>&note=<note>`, a universal link (no custom scheme, which other apps can claim). Exact path `/pay`. Parameters: `to` 6 to 34 ASCII letters and digits (required); `amount` up to six digits with an optional period and two digits, parsed to integer cents, 0.01 to 1,000,000.00 (required); `note` up to 140 characters, no newlines (optional). Unknown or repeated parameters reject the link.

  **On open.** The link produces a `PaymentDraft` and opens the normal payment screen with the fields prefilled and editable. If `to` isn't a saved payee, the screen runs the same new-payee flow as manual entry (name check, warnings). Nothing is sent until the person taps Confirm and authenticates; the approval is signed with the Secure Enclave key (Lesson 3).

  **Server.** Verifies the signature and the one-time challenge, applies limits and fraud rules, and treats the link-sourced payment exactly like a manual one. It never trusts that the app validated anything.

  **Testing and mapping.** The parser is a pure function with a table of accepted and rejected links in the unit tests (like the lesson's). Maps to MASVS-PLATFORM-1 and MASVS-CODE-4; weaknesses MASWE-0029 (Insecure Deep Links) and MASWE-0050 (Unsafe Handling of Untrusted Data); reviewer tests MASTG-TEST-0395 (universal link handlers) and, if a scheme is ever added, MASTG-TEST-0370.
````

## Summary

- URLs, universal links, push payloads, the pasteboard, files, web content and API responses are all input. A verified universal link proves the domain, not the content.
- Parse with `URLComponents` and compare exact values against allowlists. `contains`, `hasSuffix` and prefix checks are bypassed by lookalike hosts, suffix tricks and user info; check scheme, port and user info too.
- Links navigate, they never act: turn them into drafts with strict rules (integer cents, closed parameter sets, no duplicates), confirmed by the person on the normal screen. `sourceApplication` only identifies your own team's apps.
- Prevent open redirects by accepting only relative paths under known roots.
- For `WKWebView`: allow navigation only to your own pages, send other links to Safari, check `frameInfo` and its security origin on every bridge message, keep a tiny action vocabulary, use App-Bound Domains, disable JavaScript for untrusted content, grant the narrowest file access, and leave `isInspectable` off in release.
