---
id: m03-l03
title: "Swift from the terminal: single files and Swift packages"
description: You run Swift without opening Xcode, with swift file.swift and swiftc, create a Swift package with swift package init, and build, run and test it with swift build, swift run and swift test.
module: m03
order: 3
level: beginner
minutes: 45
prerequisites: [m03-l02]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Run a Swift file with swift and compile it to an executable with swiftc.
  - Create an executable Swift package with swift package init.
  - Explain what Package.swift, Sources and Tests contain.
  - Build, run and test a package with swift build, swift run and swift test.
terms:
  - term: Terminal
    definition: An app for giving the computer instructions by typing commands. On macOS it's called Terminal and lives in Applications › Utilities.
  - term: Working directory
    definition: The folder the terminal is currently "in". Commands look for files there. You change it with cd and check it with pwd.
  - term: Executable
    definition: A file that contains an already compiled program and can be run directly.
  - term: Swift package
    definition: A folder with a Package.swift file that describes one or more code modules, their dependencies and their tests. It's managed by Swift Package Manager (SwiftPM).
  - term: Manifest
    definition: The Package.swift file. It's written in Swift and declares the package's name, targets and dependencies.
  - term: Swift Package Manager
    definition: Swift's official tool for creating, building and testing packages and downloading dependencies. You use it through swift package, swift build, swift run and swift test.
mastery:
  - Run a .swift file from the terminal and explain how that differs from compiling it with swiftc.
  - Create an executable package, change its message and run it with swift run.
  - Describe, without looking at the lesson, what's in Package.swift, Sources and Tests.
  - Run swift test in a package and find in the output whether the tests passed.
resources: [swiftpm-docs, swift-cli-getting-started, swift-install]
cards:
  - id: m03-l03-c1
    front: What's the difference between `swift hello.swift` and `swiftc hello.swift -o hello`?
    back: "swift hello.swift compiles and runs in one step without leaving an executable behind. swiftc produces the executable hello, which you then run with ./hello."
  - id: m03-l03-c2
    front: Which command creates an executable package?
    back: "`swift package init --type executable`, inside an empty folder. The package is named after the folder unless you pass --name."
  - id: m03-l03-c3
    front: What are swift build, swift run and swift test for?
    back: swift build compiles the package; swift run builds if needed and runs the executable product; swift test builds and runs the tests.
  - id: m03-l03-c4
    front: What is Package.swift?
    back: The package manifest. A file written in Swift that declares the name, targets (code and tests), products and dependencies.
---

## The idea in one sentence

Xcode isn't the only way to run Swift: the terminal gives you a faster loop for practice, and it's how this course's challenges are tested.

> [!note]
> The output in this lesson was captured by running the commands with Swift 6.3.3. On macOS or with another version, the progress messages can differ in the details (step numbers, timings, paths); the files and the results are the same.

## Just enough terminal

Three commands are enough to get around:

```bash
pwd                 # shows which folder you're in
ls                  # lists what's in the folder
cd Documents        # moves into the Documents folder
```

`cd ..` moves up to the parent folder. In the terminal, anything after `#` on a line is a comment, just like `//` in Swift.

## A single file: swift and swiftc

Create a file called `hello.swift` with any text editor (or in Xcode with *File → New → File…*):

```swift
print("Hello from a file")
```

```output
Hello from a file
```

There are two ways to run it. The first compiles and runs in one step:

```bash
swift hello.swift
```

```output
Hello from a file
```

The second compiles to an executable, and then you run it:

```bash
swiftc hello.swift -o hello
./hello
```

```output
Hello from a file
```

Line by line:

1. `swiftc` is the compiler. `hello.swift` is the input, and `-o hello` sets the name of the output executable.
2. `./hello` runs the file `hello` in the current folder. The `./` is required: the terminal doesn't look for programs in the current folder unless you tell it to.

`swift hello.swift` is handy for practice. `swiftc` gives you a file you can run as many times as you like without recompiling. Either way, the code goes through the compiler before it runs, as you saw in the lesson "From source code to a running program".

## A Swift package

For anything bigger than one file, Swift has its own project format, the **Swift package**. It's the format of the challenge solutions in this course (the repository's `swift/` folder) and the format libraries are distributed in across the Swift ecosystem.

### Creating one

```bash
mkdir Greeting
cd Greeting
swift package init --type executable
```

```output
Creating executable package: Greeting
Creating Package.swift
Creating .gitignore
Creating Sources
Creating Sources/Greeting/Greeting.swift
Creating Tests/
Creating Tests/GreetingTests/
Creating Tests/GreetingTests/GreetingTests.swift
```

The package takes the folder's name. With Swift 6.3.3, the generated structure is:

```plaintext
Greeting/
├── Package.swift
├── Sources/
│   └── Greeting/
│       └── Greeting.swift
└── Tests/
    └── GreetingTests/
        └── GreetingTests.swift
```

> [!version]
> The `swift package init` template has changed between versions: some generate `main.swift` instead of `Greeting.swift`, and not all of them create the `Tests` folder. If your structure is slightly different, that's not an error.

### Package.swift, the manifest

```swift illustrative
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Greeting",
    targets: [
        .executableTarget(
            name: "Greeting"
        ),
        .testTarget(
            name: "GreetingTests",
            dependencies: ["Greeting"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Line by line (this version leaves out the comments the template adds):

1. `// swift-tools-version: 6.3` looks like a comment, but SwiftPM reads it: it's the minimum tools version this package needs. It has to be the first line.
2. `import PackageDescription` brings in the definitions used to describe packages.
3. `Package(name: …)` declares the package.
4. `.executableTarget(name: "Greeting")` declares a module that produces an executable. Its code lives in `Sources/Greeting`.
5. `.testTarget(…)` declares the tests, in `Tests/GreetingTests`, which depend on the `Greeting` module.
6. `swiftLanguageModes: [.v6]` asks for Swift 6 language mode.

You don't need to understand every word of this syntax yet; you'll learn it in the Swift modules. What matters is the relationship: **each target in the manifest corresponds to a folder**.

### The executable's code

`Sources/Greeting/Greeting.swift` contains a sample program:

```swift illustrative
@main
struct Greeting {
    static func main() {
        print("Hello, world!")
    }
}
```

`@main` marks where the program starts. For now, think of it this way: everything you put inside `main()` runs from top to bottom. In a single file or in `main.swift` you can write statements directly, as in the previous lesson.

### Building, running and testing

```bash
swift build
```

This compiles the package. The output ends with a line like `Build complete! (3.42s)`. The compiled files go in the hidden `.build` folder, which the template keeps out of git with `.gitignore`.

```bash
swift run
```

```output
Building for debugging...
[0/2] Write swift-version-24593BA9C3E375BF.txt
Build of product 'Greeting' complete! (0.13s)
Hello, world!
```

`swift run` compiles whatever changed and runs the product. The first three lines come from the build; the last one is your program's output.

```bash
swift test
```

This builds and runs the tests. With the Swift 6.3.3 template, the output ends with lines like these:

```output
✔ Test example() passed after 0.001 seconds.
✔ Test run with 1 test in 0 suites passed after 0.001 seconds.
```

✔ marks passing tests; a failing one is marked with ✘. You'll write your own tests with Swift Testing in the testing module; until then, you'll use `swift test` to check your challenge solutions.

## Practical example: testing the course challenges

This academy's repository has a package in `swift/` with the solution and tests for each challenge. From the repository folder:

```bash
cd swift
swift test --filter FizzBuzzTests
```

`--filter` runs only the tests whose name matches. To practice a challenge, write your own solution on a separate branch and run its tests; if they all pass, your solution does what the tests check.

## Common mistakes

> [!error] error: error opening input file 'hello.swift' (No such file or directory)
> The terminal isn't in the file's folder, or the name is misspelled. Use `pwd` to see where you are, `ls` to see what's there and `cd` to get to the right folder.

> [!error] zsh: command not found: hello
> To run a program in the current folder you have to type `./hello`, not `hello`.

> [!error] error: Could not find Package.swift in this directory or any of its parent directories.
> You ran `swift build`, `swift run` or `swift test` outside the package folder. `cd` into the folder that contains `Package.swift`.

> [!error] Editing files inside .build
> `.build` holds build output that gets regenerated. If you change anything there, your changes will be lost. Only edit `Sources`, `Tests` and `Package.swift`.

````exercise
id: m03-l03-e1
type: comprehension
prompt: You're in a Swift package folder and want to check that the tests pass. Which command do you use?
choices:
  - text: "`swift build`"
    correct: false
    why: It only compiles; it doesn't run the tests.
  - text: "`swift run`"
    correct: false
    why: It runs the executable product, not the tests.
  - text: "`swift test`"
    correct: true
    why: It builds and runs the package's tests.
  - text: "`swiftc Package.swift`"
    correct: false
    why: Package.swift is a manifest that SwiftPM reads; you don't compile it that way.
solution: |
  **`swift test`** builds the package and its test targets and runs the tests. At the end it tells you how many passed; failing ones are marked with ✘ and show what the test expected and what it got.
````

````exercise
id: m03-l03-e2
type: prediction
prompt: You save this program as `table.swift` and run `swift table.swift`. Write exactly what appears in the terminal.
code: |
  print("9 times table")
  print(9 * 1)
  print(9 * 2)
  print(9 * 3)
  print("9 * 4")
output: |
  9 times table
  9
  18
  27
  9 * 4
hints:
  - The last line is in quotes.
solution: |
  ```output
  9 times table
  9
  18
  27
  9 * 4
  ```

  The three multiplications are calculated. The last line is text in quotes and is printed as is: `9 * 4`, not 36. With `swiftc table.swift -o table` and `./table` the output would be identical: what changes is how the program is compiled, not what it does.
````

````exercise
id: m03-l03-e3
type: fill-in
prompt: |
  Complete the sequence of commands to create an executable package called `Notes`, run it and run its tests.
code: |
  mkdir Notes
  [[1]] Notes
  swift package init --type [[2]]
  swift [[3]]
  swift [[4]]
blanks:
  - id: "1"
    answers: ["cd"]
  - id: "2"
    answers: ["executable"]
  - id: "3"
    answers: ["run"]
  - id: "4"
    answers: ["test"]
solution: |
  ```bash
  mkdir Notes
  cd Notes
  swift package init --type executable
  swift run
  swift test
  ```

  `cd` moves into the new folder; the package takes its name. `--type executable` creates a package with an executable product. `swift run` builds and runs; `swift test` builds and runs the tests.
````

````exercise
id: m03-l03-e4
type: solve
prompt: |
  Create an executable package called `Greeting` with `swift package init --type executable`. Change the program so it prints these two lines instead of `Hello, world!`:

  ```output
  Hi, I'm your first package
  2 + 2 = 4
  ```

  The 4 has to be calculated. Run it with `swift run` and then run `swift test`.
starter: |
  // Sources/Greeting/Greeting.swift
  @main
  struct Greeting {
      static func main() {
          print("Hello, world!")
      }
  }
hints:
  - "You only change what's inside main(): the print lines."
  - "print with two values separates them with a space: print(\"2 + 2 =\", 2 + 2)."
rubric:
  - I created the package with swift package init inside a folder called Greeting.
  - I edited the file in Sources, not anything in .build.
  - swift run shows the two requested lines after the build messages.
  - The 4 is calculated with an expression.
  - swift test finishes with no failing tests.
solution: |
  ```swift illustrative
  @main
  struct Greeting {
      static func main() {
          print("Hi, I'm your first package")
          print("2 + 2 =", 2 + 2)
      }
  }
  ```

  `print("2 + 2 =", 2 + 2)` prints the text, a space and the result of the addition. If your template generated `main.swift` instead of `Greeting.swift`, write just the two `print` lines in that file, without `@main` or `struct`.

  The template's test doesn't check anything yet, so `swift test` passes. In the testing module you'll write tests that actually check your code.
````

````exercise
id: m03-l03-e5
type: explain
prompt: Explain what each part of this structure is for and what would happen if you deleted the `.build` folder.
code: |
  Greeting/
  ├── .build/
  ├── Package.swift
  ├── Sources/
  │   └── Greeting/
  │       └── Greeting.swift
  └── Tests/
      └── GreetingTests/
          └── GreetingTests.swift
rubric:
  - I explained that Package.swift is the manifest and declares the targets.
  - I connected Sources/Greeting and Tests/GreetingTests to the targets in the manifest.
  - I explained that .build holds build output.
  - I said deleting .build doesn't lose any code; the next build regenerates it, just more slowly.
solution: |
  - `Package.swift` is the **manifest**: it declares the package name and its targets.
  - `Sources/Greeting` holds the code for the executable target `Greeting`.
  - `Tests/GreetingTests` holds the tests for the `GreetingTests` target, which depends on `Greeting`.
  - `.build` holds build output and anything SwiftPM downloads.

  If you delete `.build` you don't lose any code: the next time you run `swift build`, `swift run` or `swift test`, SwiftPM regenerates it. That first build will be slower because it starts from scratch. Deleting it is actually a common fix when a build starts acting strangely.
````

## Summary

- `swift file.swift` compiles and runs in one step; `swiftc file.swift -o name` produces an executable you run with `./name`.
- `swift package init --type executable` creates a package with `Package.swift`, `Sources` and, in recent versions, `Tests`.
- Each target in the manifest corresponds to a folder.
- `swift build` compiles, `swift run` runs, `swift test` tests; run them inside the package folder.
- `.build` gets regenerated; your code lives in `Sources` and `Tests`.
