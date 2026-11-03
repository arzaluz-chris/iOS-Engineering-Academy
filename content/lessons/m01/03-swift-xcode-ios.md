---
id: m01-l03
title: Apps, operating systems and the Swift, Xcode and iOS ecosystem
description: What an app is, what the operating system does, what frontend and backend mean, and how Swift, Xcode, the iOS SDK and an app's development cycle fit together.
module: m01
order: 3
level: beginner
minutes: 35
prerequisites: [m01-l02]
codeStatus: no-code
objectives:
  - Explain what the operating system does for an app.
  - Tell frontend, backend and operating system apart in a real app.
  - Describe how Swift, Xcode, the iOS SDK and the simulator relate to each other.
  - Put the stages of an iOS app's development cycle in order.
terms:
  - term: App
    definition: A program with a purpose for its user, packaged to be installed and run on an operating system.
  - term: Operating system
    definition: Software that manages the hardware and offers services to apps, such as the screen, networking, files and permissions. On the iPhone it's iOS.
  - term: Frontend
    definition: The part of a system the user interacts with. In this course, the iOS app.
  - term: Backend
    definition: The remote servers and services that store shared data and run the logic that shouldn't live on the device.
  - term: IDE
    definition: Integrated development environment; it brings together an editor, a compiler, a debugger and other tools. For iOS it's Xcode.
  - term: Terminal
    definition: A program for giving the computer orders by typing text commands.
  - term: SDK
    definition: Software development kit; the set of frameworks and tools for building apps for a platform.
  - term: Framework
    definition: A library of reusable code with a purpose, like UIKit or SwiftUI for building interfaces.
mastery:
  - Point out, in a banking app you use, what happens in the frontend, what happens in the backend and what iOS handles.
  - Explain what each piece contributes among Swift, Xcode, the iOS SDK and the simulator.
  - List, in order, the stages from writing code to publishing an app.
resources: [xcode-overview, xcode-requirements, apple-documentation, develop-in-swift]
cards:
  - id: m01-l03-c1
    front: How are Swift, Xcode and the iOS SDK related?
    back: "Swift is the language. Xcode is the IDE that includes the compiler, the debugger and the simulator. The iOS SDK is the set of frameworks (UIKit, SwiftUI, Foundation…) your code uses to reach the system's capabilities."
  - id: m01-l03-c2
    front: In a banking app, where is it checked that you have enough balance for a transfer?
    back: In the backend. The app can check first to give a good experience, but the decision that counts is the server's, because the device can't be trusted.
  - id: m01-l03-c3
    front: What does the operating system do for an app?
    back: "It manages the hardware and offers services: drawing on screen, networking, files, notifications, permissions and isolation between apps (sandbox)."
---

## The idea in one sentence

An iOS app is a program that lives inside iOS, uses system services through frameworks, usually talks to a backend, and is built with Swift in Xcode.

## What the operating system does

Your app doesn't control the hardware directly. It doesn't light up pixels or drive the network antenna. It asks **iOS**, the operating system, for those services, and iOS also decides what each app can and can't do.

Some services iOS gives every app:

- Drawing on screen and delivering the user's touches.
- Access to the network, files, camera, location and notifications.
- **Permissions**: the app asks for, say, camera access, and the user decides.
- **Isolation** (sandbox): each app has its own file space and can't read another app's files.
- Lifecycle: iOS decides when your app goes to the background or gets suspended to save battery.

That last point matters from day one: on iOS, **your app doesn't own its lifecycle**. The system does. You'll study it in detail in the iOS fundamentals stage.

## Frontend, backend and operating system

Take a banking app and a transfer:

| Piece | What it does in a transfer |
| --- | --- |
| Frontend (the iOS app) | Shows the form, checks that the amount is well formed, asks for confirmation with Face ID and shows the result. |
| Backend (the bank's servers) | Verifies identity and balance, applies anti-fraud rules, moves the money and records the operation. |
| Operating system (iOS) | Draws the interface, provides Face ID, encrypts network traffic and stores credentials in the Keychain. |

A rule you'll hear on any banking team: **the client can't be trusted**. The app can validate to give a good experience, but every decision that matters is made in the backend, because a device can be compromised.

## Swift, Xcode, the SDK and the simulator

They're separate pieces that you use together:

- **Swift** is the language: the rules for writing the code. It's open source and also runs outside Apple's platforms, on Linux for example.
- **Xcode** is Apple's IDE. It includes the editor, the Swift compiler, the debugger, the simulator and Instruments for measuring performance. It only runs on macOS; each version requires a minimum macOS version and ships with a specific version of Swift and of the SDK.
- **The iOS SDK** is the set of frameworks that lets you use what iOS offers: Foundation for basic types and networking, UIKit and SwiftUI for interfaces, and many more.
- **The simulator** runs your app on the Mac, imitating an iPhone. It's fast for development, but it isn't identical to a physical device: some capabilities, like certain sensors, can only really be tested on an iPhone.

> [!version] Current versions when this lesson was written (November 2026)
> Swift 6.4, Xcode 27 and iOS 27. Versions change every year; Apple's official Xcode requirements table, linked at the end, is the source to check.

One detail that keeps you from getting confused: **what belongs to the language and what belongs to the SDK**. `print`, `Int` and `Array` are part of Swift and exist on any platform. `UIViewController` or `NavigationStack` belong to Apple frameworks and only exist where that SDK is available.

## The terminal

Besides Xcode, you'll use the **terminal**: a window where you type commands. You'll use it to clone repositories with Git, create packages with `swift package init` and run tests with `swift test`. A lot of professional work, like continuous integration, happens without a graphical interface, so it pays to get comfortable with it early.

## An app's development cycle

The stages, in order:

1. **Define** what the feature has to do and how you'll know it's right (acceptance criteria).
2. **Write** the code in Xcode.
3. **Compile**: the compiler translates and checks.
4. **Run** on the simulator or on an iPhone.
5. **Test**: automated tests and manual review.
6. **Debug** whatever fails, with breakpoints and the console.
7. **Sign**: Apple requires every installed app to be signed with a developer certificate.
8. **Distribute for testing** with TestFlight.
9. **Publish** on the App Store after Apple's review.

Steps 2 through 6 repeat many times a day. The last three happen when a version is ready.

## Common mistakes

> [!error] Confusing Swift with iOS
> Swift is a language; iOS is an operating system. You can write Swift on Linux with no iOS involved, and there are iOS apps written in other languages, like Objective-C.

> [!error] Relying on the simulator for everything
> The simulator runs on your Mac's architecture and doesn't reproduce all the hardware. Before you call something done, test it on a physical device.

> [!error] Making security decisions in the app
> If the app alone decides whether an operation is allowed, someone with a modified device can bypass that decision. The rules that matter live in the backend.

````exercise
id: m01-l03-e1
type: comprehension
prompt: In a payments app, who should decide whether a $5,000 payment goes through?
choices:
  - text: The app, because it already knows the balance it showed on screen.
    correct: false
    why: The balance on screen may be out of date, and the app runs on a device that may have been tampered with.
  - text: The backend, using the bank's data and rules.
    correct: true
    why: It's the only trustworthy place for decisions that move money.
  - text: iOS, because it manages Face ID.
    correct: false
    why: iOS confirms the identity of whoever is using the device, but it knows nothing about the bank's rules or the balance.
solution: |
  The **backend** decides. The app can check first, to warn quickly when the balance is too low, but that check is only for the user experience. The decision that counts happens on the server. iOS contributes biometric authentication and the encrypted channel, not the business rule.
````

````exercise
id: m01-l03-e2
type: comprehension
multiple: true
prompt: Which of these are **part of the Swift language** and not of an Apple framework? Select all that apply.
choices:
  - text: "`print`"
    correct: true
    why: It's a function in the Swift standard library.
  - text: "`Int`"
    correct: true
    why: It's a type in the Swift standard library.
  - text: "`UIViewController`"
    correct: false
    why: It belongs to UIKit, a framework in the iOS SDK.
  - text: "`NavigationStack`"
    correct: false
    why: It belongs to SwiftUI, an Apple framework.
solution: |
  `print` and `Int` belong to the **Swift standard library** and exist on every platform where Swift runs, Linux included. `UIViewController` (UIKit) and `NavigationStack` (SwiftUI) belong to **Apple's SDK** and only exist on Apple's platforms. Knowing the difference helps you find the right documentation and understand which code you can test outside an iPhone.
````

````exercise
id: m01-l03-e3
type: design
prompt: |
  Pick a feature from an app you use every day (for example, "see this month's transactions" in your banking app) and describe:

  1. What the frontend does.
  2. What the backend does.
  3. Which iOS services are involved.
  4. One verifiable acceptance criterion for that feature.
hints:
  - Think about which data has to be stored on a server so you can see it from another device.
  - A verifiable acceptance criterion says what has to happen in a specific situation, for example with no connection.
rubric:
  - I clearly separated what happens on the device from what happens on the server.
  - I named at least one specific iOS service (networking, Keychain, notifications, biometrics, etc.).
  - No security or money decision was left to the app alone.
  - My acceptance criterion can be checked with a yes or a no.
solution: |
  An example with "see this month's transactions":

  1. **Frontend**: requests the transactions, shows a loading state, presents the list grouped by day, lets you filter, and shows a clear message when there's no connection.
  2. **Backend**: authenticates the session, looks up the account's transactions, applies permissions (only that person's accounts) and responds with paginated data.
  3. **iOS**: encrypted networking (HTTPS with App Transport Security), the Keychain for the session token, Face ID if the app protects access, and Dynamic Type for text size.
  4. **Acceptance criterion**: "With no connection, the screen shows the last saved transactions and a notice with the time of the last update; never a blank screen."
````

## Summary

- iOS manages the hardware and your app's lifecycle; your app asks for services through frameworks.
- Frontend, backend and operating system have different responsibilities; the decisions that matter go in the backend.
- Swift is the language, Xcode the IDE, the SDK the frameworks, and the simulator an approximation of an iPhone.
- The development cycle runs from defining acceptance criteria to publishing, with a constant loop of writing, compiling, testing and debugging.
