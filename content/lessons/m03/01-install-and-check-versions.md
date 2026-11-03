---
id: m03-l01
title: "Installing Xcode and checking which versions you have"
description: What Xcode includes, how to install it, how to find out for certain which Xcode and Swift versions you have, and how to read the official requirements table. No assumptions about your machine.
module: m03
order: 1
level: beginner
minutes: 35
prerequisites: [m01-l03]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - List what Xcode includes and what the Command Line Tools are.
  - Install Xcode and the simulator components you need.
  - Check from the terminal which Xcode and Swift versions are active.
  - Use the official requirements table to find the macOS, SDK and deployment targets that go with a given Xcode version.
terms:
  - term: Xcode
    definition: Apple's development environment. It includes an editor, the Swift compiler, SDKs, the simulator, a debugger and Instruments.
  - term: Command Line Tools
    definition: Apple's package of command-line tools (compilers, git and so on), which also exists without the full Xcode. It doesn't include the simulator or the editor.
  - term: SDK
    definition: The set of frameworks and tools for building for a specific platform and version, such as the iOS 27.2 SDK.
  - term: Simulator runtime
    definition: The operating system image the simulator runs, for example iOS 27.2. It's downloaded separately from Xcode.
  - term: Deployment target
    definition: The oldest operating system version your app can be installed on.
  - term: Compiler version and language mode
    definition: The Swift 6.x compiler can build code in Swift 5 mode or Swift 6 mode. The compiler version and the language mode are different things.
mastery:
  - Run xcodebuild -version, swift --version and xcode-select -p and interpret what each one shows.
  - Use the official table to say which macOS version a given Xcode version needs and which Swift version it ships with.
  - Install an iOS simulator runtime from Xcode's settings.
  - Explain why a lesson marked "Swift 6.4" can still work with a 6.3 compiler, and when it can't.
resources: [xcode-requirements, xcode-overview, xcode-components, swift-install]
cards:
  - id: m03-l01-c1
    front: Which command shows the active Xcode version?
    back: "`xcodebuild -version`. It shows the Xcode version and its build number."
  - id: m03-l01-c2
    front: What does `xcode-select -p` show?
    back: The active developer tools folder. If it points to the Command Line Tools instead of Xcode.app, commands will use those tools and not Xcode's.
  - id: m03-l01-c3
    front: Where do you check which macOS an Xcode version needs and which Swift it includes?
    back: On Apple Developer's official Xcode system requirements page.
  - id: m03-l01-c4
    front: What's the difference between the Swift compiler version and the language mode?
    back: "The compiler version is the installed tool (for example, 6.4.2). The language mode (Swift 5 or Swift 6) is the set of rules your code is compiled under; a 6.x compiler accepts both."
---

## The idea in one sentence

Before you write code you need to know **exactly which tools you have**, because sometimes the answer to "why won't this compile?" is "your version doesn't have that."

## What Xcode includes

Xcode isn't just an editor. It's a bundle of everything you need to build apps for Apple platforms:

| Piece | What it's for |
| --- | --- |
| Code editor | Writing and navigating your project |
| Swift compiler | Translating your code, as you saw in the lesson "From source code to a running program" |
| SDKs | The frameworks for iOS, macOS and the other platforms |
| Simulator | Running iOS apps on your Mac without an iPhone |
| Debugger (LLDB) | Pausing a program and inspecting its values |
| Instruments | Measuring performance, memory and energy use |

There's also a smaller package, the **Command Line Tools**, with compilers and terminal tools but no editor or simulator. Some tools will offer to install it. For this course you need **the full Xcode**.

## Current versions when this lesson was written

The course research, verified in November 2026, recorded:

| Component | Version | Date |
| --- | --- | --- |
| Xcode | 27.2 (build 27B52) | October 29, 2026 |
| Swift included in Xcode 27.2 | 6.4.2 | October 30, 2026 (announcement) |
| iOS SDK | 27.2 | October 26, 2026 |
| Minimum macOS for Xcode 27.2 | macOS Tahoe 26.6 | — |
| Processor | Xcode 27.2 only runs on Macs with Apple silicon | — |
| iOS deployment targets supported by Xcode 27 | iOS 15 to iOS 27 | — |

> [!version]
> These numbers go stale. The source that counts is Apple's official **Xcode system requirements** table, linked in this lesson's resources. For each Xcode version it lists the minimum macOS, the included Swift version, the SDKs and the deployment targets.

The course doesn't assume which version you have installed. You'll check it yourself in a minute.

## Installing Xcode

1. Check the official table to see which Xcode version your macOS version supports. If your Mac can't run the latest one, install the newest version it does support.
2. Install Xcode from the **Mac App Store** or, with your Apple account, from the Apple Developer downloads page, which also has older versions.
3. Open Xcode once. The first time, it may ask for permission to install additional components.
4. Install the **iOS simulator runtime**. According to Apple's documentation, runtimes are managed in *Xcode → Settings… → Components*. If you open a project for a platform that has no runtime installed, Xcode also shows a *Get* button next to the run destination.

The Xcode download is several gigabytes, and so is each simulator runtime. Make sure you have the disk space.

## Checking your versions

Open the **Terminal** app and run these three commands, one at a time.

```bash
xcodebuild -version
```

This shows the active Xcode version and its build number, on two lines. With Xcode 27.2, for example, the first line would say `Xcode 27.2` and the second `Build version 27B52`. **What matters is what your terminal shows**, not this example.

```bash
swift --version
```

This shows the version of the active Swift compiler. On macOS it starts with `Apple Swift version …`, followed by build details and the architecture (for example `arm64-apple-macosx…`). The Swift version that ships with each Xcode is in the official table.

```bash
xcode-select -p
```

This shows which tools folder is active. With Xcode installed in Applications, you'd normally see:

```plaintext
/Applications/Xcode.app/Contents/Developer
```

If it shows `/Library/Developer/CommandLineTools` instead, your terminal is using the Command Line Tools and not Xcode, and `xcodebuild` may fail with a message saying it requires Xcode. To select Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

`sudo` asks for your user password because the change affects the whole system.

### Checking from a program

You can also ask the compiler for its version from code. Save this as `version.swift` and run it with `swift version.swift`:

```swift
#if compiler(>=6.0)
print("Your compiler is Swift 6 or later.")
#else
print("Your compiler is older than Swift 6. Update Xcode.")
#endif
```

```output
Your compiler is Swift 6 or later.
```

Line by line:

1. `#if compiler(>=6.0)` is a **compilation condition**: the compiler evaluates it before building the program and only compiles one of the two branches.
2. If your compiler is 6.0 or later, this line is compiled.
3. `#else` starts the other branch.
4. With an older compiler, this line would be compiled instead.
5. `#endif` closes the condition.

You don't need to write this in your programs. It's here to show that the compiler version is a concrete fact the compiler itself knows.

## Compiler version vs. language mode

Two numbers that people often mix up:

- **Compiler version**: the installed tool. With Xcode 27.2, that's Swift 6.4.2.
- **Language mode**: the rules your code is compiled under, Swift 5 or Swift 6. Swift 6 mode turns on strict concurrency checking, among other things, which you'll study much later.

A 6.x compiler can build projects in Swift 5 mode or Swift 6 mode. That's why an old project can open in a new Xcode without being rewritten.

The course lessons state the Swift version they were written with (6.4). The code in the early stages only uses features that have been around much longer, and the course's automated tests run it with Swift 6.3. When a lesson uses something specific to one version, it will say so with an availability note.

## Common mistakes

> [!error] xcode-select: error: tool 'xcodebuild' requires Xcode
> The terminal is using the Command Line Tools. Install the full Xcode and select it with `sudo xcode-select -s /Applications/Xcode.app`.

> [!error] Following a tutorial written for a different version
> Menus, templates and names change between Xcode versions. If something isn't where the tutorial says, check your version with `xcodebuild -version` and look up the documentation for that version.

> [!error] Confusing the simulator's iOS version with your iPhone's
> The simulator runs the runtime you installed in Xcode, not the version on your phone. You can have several runtimes installed at once.

> [!error] Installing an Xcode your macOS doesn't support
> The Mac App Store usually offers the latest version. If your macOS doesn't support it, check the official table and download the right version from Apple Developer.

````exercise
id: m03-l01-e1
type: comprehension
prompt: You run `xcode-select -p` and the terminal shows `/Library/Developer/CommandLineTools`. What does that mean?
choices:
  - text: Xcode is set up correctly.
    correct: false
    why: With Xcode active, the path would be inside Xcode.app.
  - text: The terminal is using the Command Line Tools, not Xcode.
    correct: true
    why: That's the folder for the standalone Command Line Tools.
  - text: Xcode can't be installed on this Mac.
    correct: false
    why: The path only tells you which tools are active, not what can be installed.
  - text: Swift isn't installed.
    correct: false
    why: The Command Line Tools include a Swift compiler.
solution: |
  The terminal is using the **Command Line Tools**. They're enough to compile from the terminal, but they don't include the simulator or the editor, and `xcodebuild` needs the full Xcode. If you've already installed Xcode, select it:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app
  ```

  After that, `xcode-select -p` should show `/Applications/Xcode.app/Contents/Developer`.
````

````exercise
id: m03-l01-e2
type: prediction
prompt: You save this code as `hello.swift` and run it with `swift hello.swift`. Write exactly what appears in the terminal.
code: |
  print("Checking the environment")
  print(6 * 7)
  print("6 * 7")
  print(10 - 2 - 3)
output: |
  Checking the environment
  42
  6 * 7
  5
hints:
  - Anything in quotes is text and is printed as is.
  - "Without quotes, 6 * 7 is a multiplication that gets calculated."
solution: |
  ```output
  Checking the environment
  42
  6 * 7
  5
  ```

  1. Prints the text and a line break.
  2. `6 * 7` without quotes is an expression: it's calculated and **42** is printed. In Swift, `*` is multiplication.
  3. With quotes it's text: `6 * 7` is printed literally, as you saw in the lesson "From source code to a running program".
  4. Subtraction goes left to right: (10 − 2) − 3 = **5**.

  If you see exactly this, your Swift compiler works from the terminal.
````

````exercise
id: m03-l01-e3
type: solve
prompt: |
  Check your own environment and write down the result. In the terminal, run `xcodebuild -version`, `swift --version` and `xcode-select -p`. Then find the row for your Xcode version in the official **Xcode system requirements** table.

  In your notes, write: your Xcode version and build, your Swift version, the active path, the minimum macOS your Xcode needs and the range of iOS deployment targets it supports.
starter: |
  Xcode:
  Build:
  Swift:
  Active path:
  Minimum macOS (official table):
  iOS deployment targets (official table):
hints:
  - If xcodebuild fails, check the xcode-select -p path first.
  - The official table is in this lesson's resources.
rubric:
  - I copied the real output from my terminal, without rounding versions.
  - The active path points to Xcode.app; if it didn't, I fixed it with xcode-select -s.
  - I found my Xcode version in the official table and wrote down the minimum macOS and the deployment targets.
  - I compared my version with the lesson's and noted whether it's newer, the same or older.
solution: |
  There's no single right answer: it depends on your Mac. A complete answer looks like this (these are the values for Xcode 27.2 from the course research; yours may differ):

  ```plaintext
  Xcode: 27.2
  Build: 27B52
  Swift: 6.4.2
  Active path: /Applications/Xcode.app/Contents/Developer
  Minimum macOS (official table): macOS Tahoe 26.6
  iOS deployment targets (official table): iOS 15 to 27
  ```

  If your Xcode is older, all the code in the early stages will still work. If a lesson uses something from a newer version, it will flag it with an availability note. Keep these notes: when something doesn't compile the way a tutorial says it should, your version is the first thing to check.
````

````exercise
id: m03-l01-e4
type: comprehension
prompt: |
  A lesson says "written with Swift 6.4". Your `swift --version` shows a 6.3 version. Which statement is most accurate?
choices:
  - text: You won't be able to run anything in the lesson.
    correct: false
    why: Most of the language has existed since earlier versions.
  - text: You can follow it; only things specific to 6.4 will fail, and the lesson would flag those with a note.
    correct: true
    why: The version tells you what the lesson was written with, not that everything requires that version.
  - text: You need to switch the language mode to Swift 5.
    correct: false
    why: The language mode has nothing to do with the new features in 6.4.
  - text: Versions 6.3 and 6.4 are identical.
    correct: false
    why: Each version adds features; the course research lists the ones in 6.4.
solution: |
  You can follow the lesson. The version tells you what it was written and verified with, not that every line requires that version. Anything specific to one version is marked with an availability note. This course's automated tests run the early-stage examples with Swift 6.3 precisely to check that.
````

## Summary

- Xcode includes an editor, the compiler, SDKs, the simulator, a debugger and Instruments; the Command Line Tools are only part of that.
- `xcodebuild -version`, `swift --version` and `xcode-select -p` tell you exactly what's active.
- The official Xcode system requirements table is the source for minimum macOS, included Swift, SDKs and deployment targets.
- Simulator runtimes are installed separately, in *Xcode → Settings… → Components*.
- The compiler version and the language mode are different things.
