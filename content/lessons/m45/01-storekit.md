---
id: m45-l01
title: In-app purchases with StoreKit 2
description: "StoreKit 2 turns a purchase into a signed transaction you verify, deliver and finish. You load products, start a purchase the way Apple recommends for SwiftUI, listen to Transaction.updates from launch, compute access from current entitlements, make consumable delivery safe against crashes, test with a StoreKit configuration file and the sandbox, and check a monetization plan against the App Review Guidelines by number."
module: m45
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l06, m29-l06]
objectives:
  - Describe the four product types and which of them appear in current entitlements.
  - Load products, start a purchase and handle every PurchaseResult case, including pending.
  - Listen to Transaction.updates from launch and finish transactions only after delivering the content.
  - Compute what the person has access to from verified, unrevoked, unexpired transactions.
  - Deliver consumables idempotently so a crash before finish() never double-credits.
  - Test purchases with a StoreKit configuration file, StoreKitTest and the sandbox, and apply App Review Guidelines 2.1(b), 3.1.1, 3.1.2 and 3.1.3(e).
terms:
  - term: Product
    definition: "StoreKit's type for an in-app purchase configured in App Store Connect: id, displayName, description, displayPrice, type, and subscription info. You get instances from Product.products(for:)."
  - term: Transaction
    definition: "A record of a purchase, signed by the App Store in JWS format. StoreKit hands it to you wrapped in a VerificationResult. Key fields: productID, productType, purchaseDate, expirationDate, revocationDate, isUpgraded."
  - term: VerificationResult
    definition: "An enum with .verified(value) and .unverified(value, error). StoreKit verifies the signature for you; you decide what to do with unverified values (usually: don't grant access)."
  - term: Transaction.updates
    definition: "An async sequence of transactions created or updated outside the current purchase call: Ask to Buy approvals, offer code redemptions, App Store purchases, purchases on other devices, and unfinished transactions at launch."
  - term: Current entitlements
    definition: "Transaction.currentEntitlements: the latest transaction for each non-consumable, active auto-renewable subscription and non-renewing subscription the person is entitled to. Refunded or revoked products and consumables don't appear."
  - term: finish()
    definition: "Tells the App Store you delivered the content or enabled the service. Until you call it, the transaction stays unfinished and is delivered again through Transaction.updates at launch."
mastery:
  - Write a store type that loads products, listens for updates from launch, and refreshes entitlements after every verified transaction.
  - Handle success, pending, cancellation and thrown errors from a purchase, and finish only verified, delivered transactions.
  - Compute the unlocked products or tier for a list of transactions on a given day, ignoring consumables, revoked, expired, upgraded and unverified records.
  - Deliver consumable credits so that a re-delivered transaction is detected and ignored.
  - Set up a local StoreKit configuration file and write a StoreKitTest test, citing Apple's steps.
  - Decide whether a feature must use in-app purchase, citing the guideline number.
resources: [storekit-product, storekit-transaction-updates, xcode-storekit-testing, app-review-guidelines, swift-task, swiftui-environment, swift-sendable]
cards:
  - id: m45-l01-c1
    front: What does Transaction.currentEntitlements include, and what does it leave out?
    back: "The latest transaction for each non-consumable, each auto-renewable subscription that is subscribed or in grace period, and each non-renewing subscription. Refunded or revoked products and consumables aren't included."
  - id: m45-l01-c2
    front: When must an app start listening to Transaction.updates, and why?
    back: "As soon as it launches. Unfinished transactions are delivered to the updates listener once, right after launch, and Ask to Buy approvals, offer codes, App Store purchases and other devices' purchases arrive there too. Without the listener, the app can miss them."
  - id: m45-l01-c3
    front: What are the PurchaseResult cases and what does each mean?
    back: ".success(VerificationResult<Transaction>): verify, deliver, then finish(). .pending: needs action such as Ask to Buy; if it completes, it arrives through Transaction.updates. .userCancelled: do nothing. The call can also throw a PurchaseError or StoreKitError."
  - id: m45-l01-c4
    front: When do you call AppStore.sync()?
    back: "Only from an explicit action like a Restore Purchases button. It shows a system prompt to authenticate. StoreKit keeps transactions current on its own, including after reinstalling or on a new device."
  - id: m45-l01-c5
    front: Pantry sells groceries and a Pantry Pro subscription. Which must use in-app purchase?
    back: "Pantry Pro does: 3.1.1 requires in-app purchase to unlock features. The groceries must not: 3.1.3(e) says physical goods and services consumed outside the app use other methods, such as Apple Pay or card entry."
---

## The idea in one sentence

A purchase in StoreKit 2 is **a signed transaction that you verify, turn into access, and then finish**, and because transactions can arrive at any time (another device, a parent approving Ask to Buy, a refund), access is something you recompute from the transaction history, never a flag you set once.

> [!note] Sources and what was checked
> From Apple's documentation, read in November 2026: `Product`, `products(for:)`, `purchase(options:)`, `PurchaseAction`, `Product.PurchaseResult`, `Transaction`, `Transaction.updates`, `currentEntitlements`, `unfinished`, `all`, `finish()`, `VerificationResult`, `AppStore.sync()`, `AppStore.canMakePayments`, `StoreView`, "Setting up StoreKit Testing in Xcode", "Testing In-App Purchases with sandbox" and `SKTestSession`; and the App Review Guidelines page (last updated October 16, 2026). The StoreKit and SwiftUI code is type-checked against the iOS SDK, not run; no purchase was made, in the sandbox or anywhere else. The Xcode and App Store Connect steps are Apple's, quoted and not performed. The entitlement and ledger models are plain Swift, compiled and run with Swift 6.3.

## Products and the four types

Pantry, the grocery app from Module 44, wants to sell three things: **Pantry Pro** (meal plans and price alerts) as a monthly or yearly subscription, a one-time **Recipes pack**, and small **tips** for the delivery team. In App Store Connect each becomes an in-app purchase with a product identifier, and in code each is a `Product`. `Product.ProductType` has four values:

| Type | Example | Bought | In current entitlements? |
| --- | --- | --- | --- |
| `.consumable` | A tip, 100 coins | Again and again; used up | No |
| `.nonConsumable` | Recipes pack | Once, kept forever | Yes |
| `.autoRenewable` | Pantry Pro monthly | Renews until cancelled | Yes, while subscribed or in grace period |
| `.nonRenewable` | A season pass | For a fixed time, no renewal | Yes, the latest one |

The last column comes from `currentEntitlements`: it emits "a transaction for each non-consumable," "the latest transaction for each auto-renewable subscription that has a `RenewalState` state of `subscribed` or `inGracePeriod`," and "the latest transaction for each non-renewing subscription, including finished ones." And: "Products that the App Store has refunded or revoked don't appear in the current entitlements. Consumable Apple In-App Purchases also don't appear."

Loading products is one call. From `products(for:)`: "If any identifiers are invalid or the App Store can't find them, the App Store excludes them from the return value." So an empty array isn't an error; it usually means a typo in an identifier or a product that isn't set up yet. The method throws only for system errors.

Before showing a store at all, check `AppStore.canMakePayments`. Apple: "If the value is false, a person can't authorize payments, so don't offer Apple In-App Purchases." Screen Time restrictions and device management profiles cause that.

## The store

Pantry keeps everything StoreKit-related in one main-actor type. The paywall view starts purchases, as Apple recommends for SwiftUI, and passes the results in:

```swift ios
import StoreKit
import SwiftUI

@MainActor
@Observable
final class PantryStore {
    static let productIDs = ["pantry.pro.monthly", "pantry.pro.yearly", "pantry.recipes"]

    private(set) var products: [Product] = []
    private(set) var unlockedProductIDs: Set<String> = []
    private var updatesTask: Task<Void, Never>?

    /// Call once, as early as possible at launch.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            await Self.listenForTransactions { [weak self] (result: VerificationResult<Transaction>) in
                await self?.process(result)
            }
        }
        Task {
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
        } catch {
            products = []
        }
    }

    /// Access is recomputed from StoreKit, never toggled by hand.
    func refreshEntitlements() async {
        unlockedProductIDs = await Self.verifiedEntitlementIDs()
    }

    /// Returns a message for the paywall.
    func handle(_ result: Product.PurchaseResult) async -> String {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return "The purchase couldn't be verified."
            }
            await refreshEntitlements()          // deliver first...
            await transaction.finish()           // ...then finish
            return "Unlocked. Thank you!"
        case .pending:
            return "Waiting for approval. You'll get access as soon as it's approved."
        case .userCancelled:
            return ""
        @unknown default:
            return ""
        }
    }

    private func process(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await refreshEntitlements()
        await transaction.finish()
    }

    // The two loops run off the main actor and hop back to it for each result.

    private nonisolated static func listenForTransactions(
        _ handle: @Sendable (VerificationResult<Transaction>) async -> Void
    ) async {
        for await result in Transaction.updates {
            await handle(result)
        }
    }

    private nonisolated static func verifiedEntitlementIDs() async -> Set<String> {
        var unlocked: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                unlocked.insert(transaction.productID)
            }
        }
        return unlocked
    }
}

struct PaywallView: View {
    let store: PantryStore
    @Environment(\.purchase) private var purchase
    @State private var message = ""

    var body: some View {
        List {
            ForEach(store.products, id: \.id) { (product: Product) in
                Button {
                    Task { await buy(product) }
                } label: {
                    LabeledContent(product.displayName, value: product.displayPrice)
                }
                .disabled(store.unlockedProductIDs.contains(product.id))
            }
            Button("Restore Purchases") {
                Task { await restore() }
            }
            Text(message)
        }
        .task {
            await store.loadProducts()
        }
    }

    private func buy(_ product: Product) async {
        do {
            let result = try await purchase(product)
            message = await store.handle(result)
        } catch {
            message = "The purchase didn't go through. Try again."
        }
    }

    private func restore() async {
        do {
            try await AppStore.sync()
            await store.refreshEntitlements()
        } catch {
            message = "Couldn't reach the App Store."
        }
    }
}
```

What each part does, and where the rule comes from:

- **`@Environment(\.purchase)`** gives a `PurchaseAction`. Apple's `purchase(options:)` page says to use `PurchaseAction` "for apps that use SwiftUI," `purchase(confirmIn:options:)` for UIKit, and `purchase(options:)` itself for watchOS. The action "automatically includes the UI context": it presents the confirmation sheet near the right scene. You call it like a function because it has `callAsFunction(_:options:)`.
- **Three results, plus errors.** Apple's `PurchaseResult` example verifies `.success`, delivers, and calls `finish()`; for `.pending` it says "the purchase requires action from the customer. If the transaction completes, it's available through `Transaction.updates`." So pending isn't failure: say so in the UI and let the listener grant access later. Cancellation needs no message. A thrown error (`PurchaseError`, `StoreKitError`) is the network or the store failing.
- **Verify, deliver, finish, in that order.** `finish()` "indicates to the App Store that the app delivered the purchased content or enabled the service." Finish before delivering and a crash in between loses the purchase. Not finishing at all leaves it in `Transaction.unfinished`.
- **The listener starts at launch.** From `Transaction.updates`: "Create a Task to iterate through the transactions from the listener as soon as your app launches. If your app has unfinished transactions, the updates listener receives them once, immediately after the app launches. Without the Task to listen for these transactions, your app may miss them." Pantry calls `store.start()` from the app's `init`, before any view appears. A purchase made through `purchase` itself comes back as `.success`, not through `updates`, which is why both paths call `refreshEntitlements()`.
- **The loops run off the main actor.** `listenForTransactions` and `verifiedEntitlementIDs` are `nonisolated`, so iterating StoreKit's sequences doesn't occupy the main actor, and each result hops back with `await` (Module 29's isolation rules). Apple's own listener example does the same thing from a class that isn't main-actor isolated, with `Task(priority: .background)`.
- **`[weak self]`** keeps the endless loop from owning the store. Pantry's store lives for the whole process, so the task is never cancelled; a shorter-lived owner would cancel it, as Apple's sample does in `deinit`.
- **Restore calls `AppStore.sync()`**, and only from the button. Apple: it "displays a system prompt that asks users to authenticate," so "call this function only in response to an explicit user action," and "in regular operations, there's no need to call `sync()`" because a reinstalled app "automatically has all transactions available to it upon initial launch." Guideline 3.1.1 still asks for "a restore mechanism for any restorable in-app purchases," so the button stays.

> [!tip] StoreKit views
> If the paywall doesn't need a custom design, `StoreView(ids:)` and `ProductView(id:)` (iOS 17) load products, show localized names and prices, and run the purchase themselves. Apple: with these views "you don't need to call any other API to initiate a purchase." Your listener and entitlement code stay exactly the same.

### Unverified transactions

`VerificationResult` has two cases. StoreKit has already checked the App Store's signature; `.unverified(transaction, error)` means that check failed. Apple's samples handle it "based on your business model". Pantry doesn't grant access for unverified transactions, and doesn't finish them either. For the most control, Apple suggests verifying the `jwsRepresentation` on your own server with the App Store Server Library. A server that grants cloud features should do that rather than trust what the device says.

## Access is computed, not stored

Pantry asks one question everywhere: **what does this person have right now?** The answer follows the same rules as Apple's `Transaction.updates` example: skip revoked transactions ("Remove access to the product identified by `transaction.productID`"), skip expired subscriptions, skip upgraded ones ("there is an active transaction for a higher level of service"), and grant the rest. Here is that logic with days as integers, so it runs anywhere and can be tested:

```swift
enum ProductKind {
    case consumable, nonConsumable, autoRenewable
}

/// The fields of StoreKit's Transaction that decide access, with days as plain integers.
struct PurchaseRecord {
    let id: Int
    let productID: String
    let kind: ProductKind
    var expirationDay: Int? = nil       // subscriptions only
    var revocationDay: Int? = nil       // set when refunded or revoked
    var isUpgraded = false              // replaced by a higher level in the same group
    var isVerified = true               // StoreKit's VerificationResult
}

func entitlements(from records: [PurchaseRecord], today: Int) -> Set<String> {
    var unlocked: Set<String> = []
    for record in records {
        guard record.isVerified else { continue }
        guard record.revocationDay == nil else { continue }
        switch record.kind {
        case .consumable:
            continue                                    // delivered once, never an entitlement
        case .nonConsumable:
            unlocked.insert(record.productID)
        case .autoRenewable:
            if record.isUpgraded { continue }
            if let expiration = record.expirationDay, expiration <= today { continue }
            unlocked.insert(record.productID)
        }
    }
    return unlocked
}

let history = [
    PurchaseRecord(id: 1, productID: "pantry.recipes", kind: .nonConsumable),
    PurchaseRecord(id: 2, productID: "pantry.tips.small", kind: .consumable),
    PurchaseRecord(id: 3, productID: "pantry.pro.monthly", kind: .autoRenewable, expirationDay: 40, isUpgraded: true),
    PurchaseRecord(id: 4, productID: "pantry.pro.yearly", kind: .autoRenewable, expirationDay: 395),
    PurchaseRecord(id: 5, productID: "pantry.themes", kind: .nonConsumable, revocationDay: 12),
    PurchaseRecord(id: 6, productID: "pantry.export", kind: .nonConsumable, isVerified: false),
]

for today in [30, 400] {
    print("day \(today):", entitlements(from: history, today: today).sorted())
}
```

```output
day 30: ["pantry.pro.yearly", "pantry.recipes"]
day 400: ["pantry.recipes"]
```

- **The tip is never an entitlement.** Consumables are delivered (the next section) and that's the end of their role.
- **The monthly plan doesn't count on day 30** even though it hasn't expired: the person upgraded to yearly, and `isUpgraded` says another transaction carries the access.
- **The refunded themes pack is gone.** Refunds arrive through `Transaction.updates` with a `revocationDate`; recomputing access handles them with no special code path. A boolean `isPro` saved in `UserDefaults` at purchase time would keep a refunded person unlocked forever.
- **The unverified export is ignored**, matching the store's `guard case .verified`.
- **Day 400 is past the yearly expiration**, so only the one-time Recipes pack remains. In the real app, a renewal produces a new transaction and the latest one is what `currentEntitlements` returns.

The store's `refreshEntitlements()` does the same thing with real data: `currentEntitlements` already drops consumables, revoked products and expired subscriptions, and the code re-checks `revocationDate` and verification. Run it at launch, after every transaction, and when the app returns to the foreground, and the UI reads `unlockedProductIDs`.

## Consumables: deliver exactly once

Consumables are the risky case. The person pays, the app adds 100 coins, and the app crashes before `finish()`. On the next launch `Transaction.updates` hands over the same unfinished transaction again. Deliver again and the person gets 200 coins for one payment. Every transaction has a unique `id`; record the ids you've delivered **in the same write as the balance**, and delivery becomes idempotent (Module 37's offline outbox used the same trick for pushes):

```swift
/// Consumable delivery that survives a crash between delivering and finishing.
struct CoinLedger {
    private(set) var balance = 0
    private(set) var delivered: Set<UInt64> = []    // persisted with the balance, in one write

    /// Returns true if this call delivered the coins, false if the transaction was already handled.
    mutating func deliver(transactionID: UInt64, coins: Int) -> Bool {
        guard !delivered.contains(transactionID) else { return false }
        balance += coins
        delivered.insert(transactionID)
        return true
    }
}

var ledger = CoinLedger()
var unfinished: [UInt64] = []

// The purchase succeeds; the app delivers, then crashes before calling finish().
print("purchase 501:", ledger.deliver(transactionID: 501, coins: 100))
unfinished.append(501)

// Next launch: Transaction.updates emits the unfinished transaction again.
for id in unfinished {
    print("relaunch \(id):", ledger.deliver(transactionID: id, coins: 100))
}
unfinished.removeAll()          // finish() called this time

print("purchase 502:", ledger.deliver(transactionID: 502, coins: 250))
print("balance:", ledger.balance)
```

```output
purchase 501: true
relaunch 501: false
purchase 502: true
balance: 350
```

The replay is harmless: the ledger recognizes 501, the app finishes it, and the balance is right. If the coins live on a server, send the transaction (its `jwsRepresentation`) and let the server deduplicate by id; that also stops a modified client from inventing purchases. And remember 3.1.1: "Any credits or in-game currencies purchased via in-app purchase may not expire."

## Testing

There are two environments before production, both from Apple's documentation (steps quoted, not performed for this lesson):

**StoreKit Testing in Xcode** is "a local test environment for testing in-app purchases without requiring a connection to App Store servers." Create a StoreKit configuration file (File > New > File from Template, filter for "storekit", choose StoreKit Configuration File; a synced file pulls products from App Store Connect, a local one you edit by hand). Then activate it: Edit Scheme > Run > Options > StoreKit Configuration. "Only one can be active at a time." Prices in a local file are placeholders. It's where you test failures, Ask to Buy, refunds and renewals without waiting.

The same environment is scriptable with the StoreKitTest framework in a test target. A test like this one isn't compiled for the lesson; it needs a test bundle and the configuration file, and the API names come from `SKTestSession`'s documentation:

```swift illustrative
import StoreKit
import StoreKitTest
import Testing

@Test @MainActor
func refundRemovesPro() async throws {
    let session = try SKTestSession(configurationFileNamed: "Pantry")
    session.disableDialogs = true
    session.clearTransactions()

    let transaction = try await session.buyProduct(identifier: "pantry.pro.yearly")
    let store = PantryStore()
    await store.refreshEntitlements()
    #expect(store.unlockedProductIDs.contains("pantry.pro.yearly"))

    try session.refundTransaction(identifier: Int(transaction.id))
    await store.refreshEntitlements()
    #expect(!store.unlockedProductIDs.contains("pantry.pro.yearly"))
}
```

`SKTestSession` also has `askToBuyEnabled`, `expireSubscription(productIdentifier:)`, `failTransactionsEnabled` and a `timeRate` for fast renewals.

**The sandbox** uses "real product information from App Store Connect" with test accounts that aren't charged. Development builds from Xcode and TestFlight builds use it. Apple's prerequisites: an active developer account, the Paid Applications Agreement signed by the Account Holder, products set up in App Store Connect, and Sandbox Apple Accounts created there. On iOS the sandbox account appears in Settings > Developer "after the first time you use the device to attempt a purchase in a development-signed app," with settings to change the renewal rate and clear purchase history.

Most bugs show up in the pure entitlement logic, which plain unit tests cover in milliseconds. StoreKitTest checks the integration, and the sandbox is the last check before review.

## App Review: which guideline says what

From the App Review Guidelines, last updated October 16, 2026. Quote the number when you argue a design with your team:

- **3.1.1 In-App Purchase.** "If you want to unlock features or functionality within your app, (by way of example: subscriptions, in-game currencies, game levels, access to premium content, or unlocking a full version), you must use in-app purchase." License keys, QR codes and similar mechanisms aren't allowed. Credits may not expire, and restorable purchases need a restore mechanism.
- **3.1.1(a)** covers entitlements for linking to other purchase methods in specific regions. Its text notes that these entitlements "are not required for developers to include buttons, external links, or other calls to action in their United States storefront apps." The rules vary by storefront; read the current text before you design anything around it.
- **3.1.2 Subscriptions.** Under 3.1.2(a) a subscription must "provide ongoing value," "the subscription period must last at least seven days and be available across all of the user's devices." 3.1.2(c): "Before asking a customer to subscribe, you should clearly describe what the user will get for the price."
- **3.1.3(e) Goods and Services Outside of the App.** "If your app enables people to purchase physical goods or services that will be consumed outside of the app, you must use purchase methods other than in-app purchase." Pantry's groceries are paid with Apple Pay or a card; Pantry Pro is in-app purchase. Same app, two payment systems, each required.
- **2.1(b).** "If you offer in-app purchases in your app, make sure they are complete, up-to-date, visible to the reviewer and functional." If a product can't be found in the app, explain why in the review notes.
- **4.10.** You "may not monetize built-in capabilities provided by the hardware or operating system, such as Push Notifications, the camera." "Pro unlocks notifications" is a rejection.

## Common mistakes

> [!error] An isPro flag saved at purchase time
> It never learns about refunds, family sharing changes, expirations or purchases on another device. Recompute from `currentEntitlements` at launch, after each transaction and on returning to the foreground.

> [!error] Starting the updates listener in the paywall
> The paywall may never appear in a session where an Ask to Buy approval or an unfinished transaction arrives. Start it at launch, once.

> [!error] Finishing before delivering
> A crash between the two loses a paid purchase. Deliver (and persist) first, then `finish()`.

> [!error] Treating pending as failure
> "Purchase failed" for an Ask to Buy request confuses the parent and the child. Say it's waiting; the listener grants access when it's approved.

> [!error] Calling AppStore.sync() at launch
> It shows an authentication prompt. Only call it from a Restore Purchases button.

> [!error] Selling physical goods through in-app purchase
> Guideline 3.1.3(e) requires other payment methods for goods and services consumed outside the app.

## Exercises

````exercise
id: m45-l01-e1
type: prediction
prompt: "A simplified subscription check. What does it print?"
code: |
  struct Renewal {
      let productID: String
      let expirationDay: Int
      let isUpgraded: Bool
      let isRevoked: Bool
  }

  let renewals = [
      Renewal(productID: "pro.monthly", expirationDay: 15, isUpgraded: true, isRevoked: false),
      Renewal(productID: "pro.yearly", expirationDay: 30, isUpgraded: false, isRevoked: false),
      Renewal(productID: "family.yearly", expirationDay: 50, isUpgraded: false, isRevoked: true),
  ]

  for day in [10, 29, 30] {
      var active: [String] = []
      for renewal in renewals where !renewal.isRevoked && !renewal.isUpgraded && renewal.expirationDay > day {
          active.append(renewal.productID)
      }
      print(day, active.isEmpty ? "free" : active.joined(separator: ", "))
  }
output: |
  10 pro.yearly
  29 pro.yearly
  30 free
hints:
  - "The monthly plan was upgraded; the family plan was refunded."
  - "Expiring on day 30 means it isn't active on day 30."
solution: |
  ```output
  10 pro.yearly
  29 pro.yearly
  30 free
  ```

  - `pro.monthly` is skipped on every day: `isUpgraded` means a higher level carries the access, even though it hasn't expired on day 10.
  - `family.yearly` is skipped because it was revoked, despite the later expiration.
  - `pro.yearly` is active while `expirationDay > day`: true on 10 and 29, false on 30. The comparison is strict, so the expiration day itself is no longer covered.
````

````exercise
id: m45-l01-e2
type: comprehension
prompt: "A parent has Ask to Buy on. Their child taps Buy on Pantry Pro, and `purchase(product)` returns `.pending`. An hour later the parent approves. How does Pantry find out?"
choices:
  - text: "The approved transaction arrives through Transaction.updates, which Pantry has been iterating since launch."
    correct: true
    why: "Apple's pending case: 'If the transaction completes, it's available through Transaction.updates.' The listener verifies it, refreshes entitlements and finishes it."
  - text: "The original purchase call stays suspended until the parent decides, then returns .success."
    correct: false
    why: "It already returned .pending. Nothing resumes it."
  - text: "Pantry must call AppStore.sync() when it next launches."
    correct: false
    why: "sync() is for an explicit restore and shows an authentication prompt. Approvals arrive on their own."
  - text: "Pantry has to poll Product.products(for:) until the product shows as purchased."
    correct: false
    why: "Products describe what's for sale. Purchases are transactions."
solution: |
  `.pending` means "the purchase requires action from the customer." When that action completes, StoreKit emits the transaction on `Transaction.updates`. This is one of the reasons Apple says to start the listener as soon as the app launches: the approval can come while the person is anywhere in the app, or while it isn't running. In that case it's delivered at the next launch as an unfinished transaction.
````

````exercise
id: m45-l01-e3
type: find-errors
prompt: "Mark every real problem in this purchase code."
code: |
  @MainActor
  final class ProModel {
      var isPro = UserDefaults.standard.bool(forKey: "isPro")

      func buy(_ product: Product) async {
          do {
              let result = try await product.purchase()
              if case .success(let verification) = result {
                  let transaction = verification.unsafePayloadValue
                  await transaction.finish()
                  isPro = true
                  UserDefaults.standard.set(true, forKey: "isPro")
              } else {
                  print("Purchase failed")
              }
          } catch {
              print("Purchase failed")
          }
      }
  }
choices:
  - text: "It grants access without checking whether the transaction is verified."
    correct: true
  - text: "It finishes the transaction before delivering access."
    correct: true
  - text: "A stored isPro flag never learns about refunds, expirations or purchases from other devices."
    correct: true
  - text: "It reports .pending (Ask to Buy) as a failure, and nothing listens to Transaction.updates for the approval."
    correct: true
  - text: "purchase() must be called on a background thread."
    correct: false
    why: "purchase(options:) is itself @MainActor; calling it from the main actor is correct."
rubric:
  - I flagged the missing verification.
  - I flagged finish-before-deliver.
  - I flagged the stored flag.
  - I flagged pending handled as failure and the missing listener.
solution: |
  - `unsafePayloadValue` skips verification. Use `guard case .verified(let transaction) = verification`.
  - Deliver (and persist) first, then `finish()`.
  - Replace `isPro` with entitlements recomputed from `Transaction.currentEntitlements`.
  - Switch over all cases: `.pending` gets a "waiting for approval" message, `.userCancelled` gets nothing, and a launch-time `Transaction.updates` listener handles the approval and refunds.
  - Smaller: in SwiftUI, Apple recommends the `purchase` environment action over `product.purchase()`.
````

````exercise
id: m45-l01-e4
type: fill-in
prompt: "Complete Pantry's transaction handling."
code: |
  private nonisolated static func listenForTransactions(
      _ handle: @Sendable (VerificationResult<Transaction>) async -> Void
  ) async {
      for await result in Transaction.[[1]] {
          await handle(result)
      }
  }

  private func process(_ result: VerificationResult<Transaction>) async {
      guard case .[[2]](let transaction) = result else { return }
      await refreshEntitlements()
      await transaction.[[3]]()
  }

  private nonisolated static func verifiedEntitlementIDs() async -> Set<String> {
      var unlocked: Set<String> = []
      for await result in Transaction.[[4]] {
          if case .verified(let transaction) = result, transaction.revocationDate == nil {
              unlocked.insert(transaction.productID)
          }
      }
      return unlocked
  }
blanks:
  - id: "1"
    answers: ["updates"]
  - id: "2"
    answers: ["verified"]
  - id: "3"
    answers: ["finish"]
  - id: "4"
    answers: ["currentEntitlements"]
solution: |
  - `Transaction.updates` emits transactions created outside the purchase call, and unfinished ones once at launch.
  - `.verified` is the case of `VerificationResult` that passed StoreKit's signature check.
  - `finish()` comes after access is refreshed.
  - `Transaction.currentEntitlements` lists what the person is entitled to now: no consumables, nothing refunded or revoked.
````

````exercise
id: m45-l01-e5
type: solve
prompt: |
  Pantry's subscriptions come in two tiers: Pro (`pantry.pro.monthly`, `pantry.pro.yearly`) and Family (`pantry.family.yearly`), and Family includes everything in Pro. Write `currentTier(_:today:)`. It returns the highest tier among records that are verified, not upgraded, not revoked by `today` (a revocation on or before today counts), not expired (`expirationDay > today`), and for a known product. With no such record, it returns `.free`.

  Expected output:

  ```output
  day 10: family
  day 100: pro
  day 365: free
  free
  ```
starter: |
  enum Tier: Int, Comparable {
      case free = 0, pro = 1, family = 2

      static func < (lhs: Tier, rhs: Tier) -> Bool {
          lhs.rawValue < rhs.rawValue
      }
  }

  struct SubscriptionRecord {
      let productID: String
      let expirationDay: Int
      var revocationDay: Int? = nil
      var isUpgraded = false
      var isVerified = true
  }

  let tierByProduct: [String: Tier] = [
      "pantry.pro.monthly": .pro,
      "pantry.pro.yearly": .pro,
      "pantry.family.yearly": .family,
  ]

  func currentTier(_ records: [SubscriptionRecord], today: Int) -> Tier {
      // your code
      return .free
  }

  let records = [
      SubscriptionRecord(productID: "pantry.pro.monthly", expirationDay: 31, isUpgraded: true),
      SubscriptionRecord(productID: "pantry.family.yearly", expirationDay: 400, revocationDay: 90),
      SubscriptionRecord(productID: "pantry.pro.yearly", expirationDay: 365),
      SubscriptionRecord(productID: "pantry.family.yearly", expirationDay: 500, isVerified: false),
      SubscriptionRecord(productID: "pantry.unknown", expirationDay: 999),
  ]

  for today in [10, 100, 365] {
      print("day \(today): \(currentTier(records, today: today))")
  }
  print(currentTier([], today: 0))
hints:
  - "Start from .free and keep the max."
  - "`if let revoked = record.revocationDay, revoked <= today { continue }`"
rubric:
  - Skips unverified, upgraded, revoked-by-today and expired records.
  - Ignores product ids it doesn't know instead of crashing.
  - Returns the highest tier, and .free for no records.
solution: |
  ```swift
  enum Tier: Int, Comparable {
      case free = 0, pro = 1, family = 2

      static func < (lhs: Tier, rhs: Tier) -> Bool {
          lhs.rawValue < rhs.rawValue
      }
  }

  struct SubscriptionRecord {
      let productID: String
      let expirationDay: Int
      var revocationDay: Int? = nil
      var isUpgraded = false
      var isVerified = true
  }

  let tierByProduct: [String: Tier] = [
      "pantry.pro.monthly": .pro,
      "pantry.pro.yearly": .pro,
      "pantry.family.yearly": .family,
  ]

  func currentTier(_ records: [SubscriptionRecord], today: Int) -> Tier {
      var best = Tier.free
      for record in records {
          guard record.isVerified, !record.isUpgraded else { continue }
          if let revoked = record.revocationDay, revoked <= today { continue }
          guard record.expirationDay > today else { continue }
          guard let tier = tierByProduct[record.productID] else { continue }
          best = max(best, tier)
      }
      return best
  }

  let records = [
      SubscriptionRecord(productID: "pantry.pro.monthly", expirationDay: 31, isUpgraded: true),
      SubscriptionRecord(productID: "pantry.family.yearly", expirationDay: 400, revocationDay: 90),
      SubscriptionRecord(productID: "pantry.pro.yearly", expirationDay: 365),
      SubscriptionRecord(productID: "pantry.family.yearly", expirationDay: 500, isVerified: false),
      SubscriptionRecord(productID: "pantry.unknown", expirationDay: 999),
  ]

  for today in [10, 100, 365] {
      print("day \(today): \(currentTier(records, today: today))")
  }
  print(currentTier([], today: 0))
  ```

  ```output
  day 10: family
  day 100: pro
  day 365: free
  free
  ```

  - Day 10: the family plan is active (its refund comes on day 90), so Family wins over Pro.
  - Day 100: the family plan was refunded on day 90; the yearly Pro plan carries access.
  - Day 365: Pro yearly expires that day. The unverified family record and the unknown product never count, so the result is free.

  In the app, the same function runs over the verified transactions from `currentEntitlements`, and the tier map comes from your product configuration. Comparing tiers rather than checking one product id is what makes upgrades and downgrades inside a subscription group just work.
````

````exercise
id: m45-l01-e6
type: design
prompt: "Pantry's product manager proposes: a 3-day 'Pro week' subscription, a paid 'unlock notifications' option, Pro sold with a coupon code printed on grocery receipts that the app validates itself, grocery orders paid by in-app purchase so they show in Family Sharing, and coins that expire after a year. For each, say whether it's allowed, cite the guideline, and propose what Pantry should do instead."
rubric:
  - Rejects the 3-day subscription under 3.1.2(a) (at least seven days) and proposes a 7-day or longer period or a free trial offer.
  - Rejects charging for notifications under 4.10.
  - Rejects self-validated codes under 3.1.1 and proposes App Store offer codes or a promotional offer redeemed through StoreKit.
  - Rejects in-app purchase for groceries under 3.1.3(e) and keeps Apple Pay or card payment.
  - Rejects expiring coins under 3.1.1.
solution: |
  - **3-day subscription:** 3.1.2(a) requires a period of "at least seven days." Use a weekly or longer period; for trying Pro, a free trial is configured in App Store Connect (3.1.2(a) allows them).
  - **Paid notifications:** 4.10 forbids monetizing built-in capabilities such as push notifications. Notifications stay free; Pro can include smarter content in them, such as price alerts, which is a feature.
  - **Receipt coupon codes validated by the app:** 3.1.1 forbids unlocking with "license keys" or "QR codes" outside in-app purchase. Use offer codes the App Store redeems; the result arrives through `Transaction.updates`.
  - **Groceries through in-app purchase:** 3.1.3(e) requires other payment methods for physical goods. Keep Apple Pay and cards for orders.
  - **Expiring coins:** 3.1.1: "credits or in-game currencies purchased via in-app purchase may not expire." Purchased coins never expire.
````

## Summary

- `Product.products(for:)` loads what you sell; unknown identifiers are silently dropped. Check `AppStore.canMakePayments` before showing a store.
- In SwiftUI start purchases with the `purchase` environment action (`PurchaseAction`); handle `.success` (verify, deliver, `finish()`), `.pending` (wait for `Transaction.updates`), `.userCancelled` and thrown errors.
- Listen to `Transaction.updates` from launch: unfinished transactions, Ask to Buy approvals, offer codes, other devices and refunds arrive there.
- Compute access from `Transaction.currentEntitlements` (no consumables, nothing revoked): verified, not revoked, not expired, not upgraded. Never store a flag at purchase time.
- Make consumable delivery idempotent by transaction id, saved with the balance. Call `AppStore.sync()` only from Restore Purchases.
- Test with a StoreKit configuration file and StoreKitTest's `SKTestSession`, then the sandbox. Guidelines: 3.1.1 (in-app purchase for features, credits don't expire, restore), 3.1.2(a) (at least seven days), 3.1.3(e) (physical goods use other methods), 2.1(b) (purchases reviewable), 4.10 (no charging for built-in capabilities).
