---
id: m03-l02
title: "Your first Xcode project: the window, building, running and the simulator"
description: You create a command-line project and an iOS app project, walk through the areas of the Xcode window, build, run, read the console and open the simulator.
module: m03
order: 2
level: beginner
minutes: 45
prerequisites: [m03-l01]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Create an Xcode project from a template, both for the terminal and for iOS.
  - Identify the navigator, the editor, the inspectors, the debug area and the toolbar.
  - Tell apart a project, a target, a scheme and a run destination.
  - Build and run a program, and find its output in the console.
  - Run an app in the iOS simulator.
terms:
  - term: Project
    definition: The .xcodeproj file that groups source files, resources and build settings.
  - term: Target
    definition: A product the project builds, such as an app or a command-line tool, with its own list of files and settings.
  - term: Scheme
    definition: Configuration that says which target to build and how to run, test or analyze it. You pick it in the toolbar.
  - term: Run destination
    definition: Where the program runs, for example "My Mac", an iPhone simulator or a connected iPhone.
  - term: Bundle identifier
    definition: An app's unique identifier on the system, usually in reverse-domain form, such as com.yourname.MyApp. Xcode builds it from the organization identifier and the product name.
  - term: Console
    definition: The part of the debug area where you see what the program prints with print, along with runtime error messages.
mastery:
  - Create a Command Line Tool project from scratch, run it and point to its output in the console.
  - Create an iOS app project and run it on a simulator picked in the run destination.
  - Name out loud the five areas of the Xcode window and what each one is for.
  - Explain what a target is and why a project can have several.
resources: [xcode-create-project, xcode-components, xcode-overview]
cards:
  - id: m03-l02-c1
    front: Which shortcuts build, run and stop a program in Xcode?
    back: "⌘B builds, ⌘R builds and runs, ⌘. (Command-period) stops the run."
  - id: m03-l02-c2
    front: Where does `print` output show up in Xcode?
    back: "In the console, inside the debug area at the bottom. ⇧⌘Y shows or hides it."
  - id: m03-l02-c3
    front: What's the difference between a project and a target?
    back: The project groups files and settings. A target is one specific product built from it; a project can have several, for example the app and its tests.
  - id: m03-l02-c4
    front: What is the run destination?
    back: Where whatever you build runs, for example "My Mac", an iPhone simulator or a physical device. You pick it in the toolbar, next to the scheme.
---

## The idea in one sentence

An Xcode project is an organized folder of code and settings; Xcode builds it for a destination and shows you what happens in the console.

> [!version]
> The menus in this lesson follow Apple's documentation for recent Xcode versions. Some names differ in older versions; if something isn't where the lesson says, check the documentation for your version.

## First project: a command-line tool

In the core Swift modules, most programs print to the console. The simplest template for that is **Command Line Tool**, a macOS program with no graphical interface.

1. From the Xcode welcome window, or from *File → New → Project…*, choose to create a project from a template (*Choose Template*).
2. Select the **macOS** platform and the **Command Line Tool** template.
3. Enter a product name, for example `Practice`. For **Organization Identifier**, enter something in reverse-domain form, like `com.yourname`. The language is **Swift**.
4. Pick a folder and create the project.

Xcode generates a `main.swift` file with a sample program similar to this one. The comment header, with your name and the date, will vary:

```swift
//
//  main.swift
//  Practice
//

import Foundation

print("Hello, World!")
```

```output
Hello, World!
```

Line by line:

1. Lines starting with `//` are comments. Xcode fills in the file and project names; the compiler ignores them.
2. `import Foundation` makes the Foundation framework available, with utilities for dates, text and files. This program doesn't need it, but the template includes it.
3. `print("Hello, World!")` is the only statement that does anything visible.

In a command-line project, code you write directly in `main.swift`, outside any function, runs from top to bottom when the program starts.

Press **⌘R** or the run button (▶) in the toolbar. Xcode builds, runs and shows `Hello, World!` in the **console** at the bottom of the window.

## The areas of the window

| Area | Where | What it's for |
| --- | --- | --- |
| Toolbar | Top | Run (▶) and stop (■), pick the scheme and destination, see build status |
| Navigator | Left | Browse project files, issues, breakpoints and search results |
| Editor | Center | Write code |
| Inspectors | Right | Properties of the selected file or item, plus Quick Help |
| Debug area | Bottom | Variables and the console while the program runs |

Shortcuts worth memorizing from day one:

| Shortcut | Action |
| --- | --- |
| ⌘R | Build and run |
| ⌘B | Build only |
| ⌘. | Stop the run |
| ⇧⌘K | Clean the build folder (*Clean Build Folder*) |
| ⇧⌘Y | Show or hide the debug area |
| ⌘0 | Show or hide the navigator |
| ⇧⌘O | *Open Quickly*: find a file or symbol by name |

If the console doesn't appear after running, press ⇧⌘Y.

## Project, target, scheme and destination

Four words you'll see in every project:

- **Project** (`Practice.xcodeproj`): groups files and settings.
- **Target**: a product that gets built. Your project has one target, the `Practice` tool. A real app usually has several: the app, its unit tests, its UI tests, maybe a widget.
- **Scheme**: which target gets built and how it runs. You pick it in the toolbar.
- **Run destination**: where it runs, next to the scheme. For a macOS tool it's *My Mac*; for an iOS app, a simulator or an iPhone.

Building (⌘B) only translates and checks. Running (⌘R) builds if needed and then starts the program on the chosen destination.

## Second project: an iOS app in the simulator

1. Create a new project with the **App** template for **iOS**. The default interface is SwiftUI, which gets its own stage later; for now, leave the code alone.
2. In the run destination, pick a simulated iPhone. If none appear, Xcode shows a *Get* button to download the simulator runtime (previous lesson).
3. Press ⌘R. The simulator takes a while to boot the first time.

Among other things, the template creates a file with the app's entry point, a file with the first view and an asset catalog (`Assets`) for icons, colors and images. You'll see the app in a window that looks like an iPhone.

The simulator runs your app compiled for your Mac, not for a real iPhone. It's fast and convenient, but it doesn't reproduce everything: performance, the camera, some sensors and certain system features behave differently. You have to test on a device before you ship an app.

## Practical example: your practice file

Replace the contents of `main.swift` in the `Practice` project with:

```swift
print("Practice project")
print("Minutes in a day:")
print(24 * 60)
```

```output
Practice project
Minutes in a day:
1440
```

Run it with ⌘R and compare the console with the output above. You'll use this project for the exercises in the next lessons: each time, replace the contents of `main.swift`, run it and compare.

## Common mistakes

> [!error] The console is empty
> It might be hidden (⇧⌘Y), or the program may never have run because the build failed. Check the status in the toolbar and the Issue navigator.

> [!error] Running the wrong scheme
> If you have several projects or targets, the ▶ button runs the scheme selected in the toolbar. Make sure it's the one you're editing.

> [!error] No simulators in the run destination
> The iOS runtime is missing. Install it in *Xcode → Settings… → Components* or with the *Get* button next to the destination.

> [!error] Deleting main.swift or removing it from the target
> If a file doesn't belong to the target, Xcode doesn't compile it. In the File inspector, the *Target Membership* section shows which targets it belongs to.

````exercise
id: m03-l02-e1
type: comprehension
prompt: You're in Xcode with your command-line project open. What does ⌘B do?
choices:
  - text: Builds the project without running it.
    correct: true
    why: B for build. It translates and checks, but doesn't start the program.
  - text: Builds and runs the program.
    correct: false
    why: That's ⌘R.
  - text: Stops the running program.
    correct: false
    why: That's ⌘. (Command-period).
  - text: Shows or hides the console.
    correct: false
    why: That's ⇧⌘Y.
solution: |
  **⌘B builds** without running. It's a quick way to check that there are no compile errors. ⌘R builds if needed and also runs; ⌘. stops; ⇧⌘Y shows or hides the debug area, where the console is.
````

````exercise
id: m03-l02-e2
type: prediction
prompt: You replace `main.swift` with this code and press ⌘R. What appears in the console?
code: |
  print("Seconds in an hour:")
  print(60 * 60)
  print("Hours in a week:")
  print(24 * 7)
output: |
  Seconds in an hour:
  3600
  Hours in a week:
  168
hints:
  - Lines run from top to bottom.
solution: |
  ```output
  Seconds in an hour:
  3600
  Hours in a week:
  168
  ```

  Each `print` writes one line. Text in quotes is printed as is; multiplications without quotes are calculated: 60 × 60 = 3600 and 24 × 7 = 168.
````

````exercise
id: m03-l02-e3
type: comprehension
multiple: true
prompt: An iOS app project contains the app, its unit tests and a widget. Which of these statements are true? Select all that apply.
choices:
  - text: The project has three targets.
    correct: true
    why: Every product that gets built is a target.
  - text: A .swift file can belong to more than one target.
    correct: true
    why: That's controlled with Target Membership; for example, a model shared between the app and the widget.
  - text: A single scheme runs all three at once.
    correct: false
    why: A scheme picks what to build and how to run it; usually each runnable product has its own.
  - text: The run destination decides which device or simulator the thing you run runs on.
    correct: true
    why: You pick it next to the scheme in the toolbar.
solution: |
  The project has **three targets** (the app, the tests and the widget). A file can belong to several targets through *Target Membership*. The **run destination** decides where things run. A scheme doesn't run all three products at once: it picks one target to run and defines how to test and analyze it.
````

````exercise
id: m03-l02-e4
type: solve
prompt: |
  Create the `Practice` project with the Command Line Tool template and write a program in `main.swift` that prints exactly these lines, calculating the numbers with multiplication:

  ```output
  Days in 3 weeks:
  21
  Minutes in 2 hours:
  120
  ```

  Run it with ⌘R and compare the console with the expected output.
starter: |
  print("Days in 3 weeks:")
hints:
  - "A week has 7 days: 3 * 7."
  - "An hour has 60 minutes: 2 * 60."
rubric:
  - I created the project with the Command Line Tool template for macOS.
  - The program prints exactly the four lines asked for.
  - The numbers are calculated with multiplication, not typed in by hand.
  - I found the output in the console in the debug area.
solution: |
  ```swift
  print("Days in 3 weeks:")
  print(3 * 7)
  print("Minutes in 2 hours:")
  print(2 * 60)
  ```

  If the console doesn't appear, press ⇧⌘Y. If you get an error instead of output, the next lesson in this module teaches you how to read it; check your quotes and parentheses first.
````

````exercise
id: m03-l02-e5
type: explain
prompt: |
  A teammate says: "The simulator is the same as an iPhone, so if my app works in the simulator it's ready for the App Store." Explain what's true about that and what isn't.
rubric:
  - I explained that the simulator runs the app compiled for the Mac, not for an iPhone.
  - I mentioned at least two differences, such as performance, the camera or sensors.
  - I said the simulator is useful for developing quickly.
  - I concluded that you have to test on a real device before shipping.
code: |
  Simulator = iPhone
solution: |
  What's true is that the simulator is an excellent development tool: it boots quickly, lets you try several iOS models and versions, and shows the interface almost exactly as an iPhone would.

  It's not true that it's the same. The simulator runs the app compiled **for the Mac**, with the Mac's processor, memory and network. Performance isn't representative, and the camera, some sensors and certain system features don't behave like they do on a device. Before shipping, the app has to be tested on at least one real iPhone.
````

## Summary

- Command Line Tool is the simplest template for practicing Swift in the console; App is the template for an iOS app.
- The Xcode window: toolbar, navigator, editor, inspectors and the debug area with the console.
- The project groups things; a target is a product; a scheme says what to build and how; the destination says where to run.
- ⌘B builds, ⌘R runs, ⌘. stops, ⇧⌘Y shows the console.
- The simulator is for development; final testing happens on a device.
