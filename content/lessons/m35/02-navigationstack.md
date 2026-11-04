---
id: m35-l02
title: NavigationStack and value-based navigation
description: "A NavigationStack is a root view plus a list of values, and each value on the list is a pushed screen. You link to values with NavigationLink(value:), map value types to screens with navigationDestination(for:), take control of the list with a path binding or a NavigationPath, push and pop from code, and see why this beats putting destination views inside links, the way UIKit and the old NavigationView did it."
module: m35
order: 2
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m35-l01, m25-l01]
objectives:
  - Build a NavigationStack whose links present values and whose destinations are declared once per type with navigationDestination(for:).
  - Bind the stack to an array of route values and push, pop, pop to root and replace the stack from code.
  - Use NavigationPath when one stack presents several unrelated types, and know what it hides.
  - Explain why value-based navigation is preferred over destination-based links, and why NavigationView and isActive links are deprecated.
  - Place navigationDestination where the stack can always see it.
terms:
  - term: NavigationStack
    definition: "A SwiftUI container (iOS 16) that shows a root view and pushes views on top of it. Its state is a collection of values, one per pushed view; the root isn't part of it and can't be removed."
  - term: Value-based link
    definition: "NavigationLink(value:) or NavigationLink(_:value:): a link that appends a value to the stack's path instead of carrying a destination view. A navigationDestination for that value's type builds the screen."
  - term: navigationDestination(for:destination:)
    definition: "A modifier inside a NavigationStack that says which view to show for values of one type. The stack matches pushed values to destinations by type."
  - term: Navigation path
    definition: "The collection of values that describes what's pushed on a stack: an array of one Hashable type, or a NavigationPath for mixed types. Reading it tells you what's on screen; writing it changes the screen."
  - term: NavigationPath
    definition: "A type-erased list of Hashable values (iOS 16) for stacks that present several types. It has count, isEmpty, append(_:) and removeLast(_:), and a codable representation when every element is Codable."
mastery:
  - Write a recipe list that pushes a detail screen through a value, with the destination declared once.
  - Write buttons that push one screen, pop one, pop to the root and replace the whole stack.
  - Model a stack as an array in plain Swift and predict what's on screen after a sequence of pushes and pops.
  - Choose between [Route] and NavigationPath for a given app.
  - Find a navigationDestination placed inside a List row and move it out.
resources: [uikit-uinavigationcontroller, swift-book-enumerations, swift-book-protocols, hig]
cards:
  - id: m35-l02-c1
    front: NavigationLink(value:) + navigationDestination(for:) in one sentence?
    back: "The link appends a value to the stack's path; the stack finds the navigationDestination registered for that value's type and shows the view it builds. Links carry data, destinations are declared once per type."
  - id: m35-l02-c2
    front: How do you push, pop and pop to root with NavigationStack(path:)?
    back: "With @State var path: [Route]: push is path.append(route), pop is path.removeLast(), pop to root is path.removeAll() (or path = []), and assigning a new array replaces the whole stack. The root view isn't in the path."
  - id: m35-l02-c3
    front: "[Route] or NavigationPath?"
    back: "An array of one Hashable enum when you own all the destinations: you can read, compare and test it. NavigationPath when a stack must present unrelated types; it's type-erased, so you only get count, isEmpty, append, removeLast and a codable representation."
  - id: m35-l02-c4
    front: Where must navigationDestination(for:) go?
    back: "Inside the NavigationStack, but not inside a lazy container like List or LazyVStack, whose rows are created only when visible. Apple: put it outside them so the stack can always see the destination. Usually on the List itself."
  - id: m35-l02-c5
    front: What happens when a link's value has no matching navigationDestination?
    back: "Apple: the link doesn't do anything (unless it's a list selection in a split view's leading column). No crash, no compile error, so check every value type you push has a destination."
---

## The idea in one sentence

A `NavigationStack` is a root view plus **a list of values**, one value per pushed screen: links append values, Back removes the last one, and your code can read or rewrite the list to navigate anywhere.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run. Navigation behavior comes from Apple's pages for `NavigationStack`, `NavigationLink`, `navigationDestination(for:destination:)`, `NavigationPath` and the article "Migrating to new navigation types", read in November 2026; it wasn't checked in a simulator. The plain-Swift models of a stack were compiled and run with Swift 6.3.

## From UINavigationController to NavigationStack

In Module 25 a `UINavigationController` held an array of view controllers. You pushed a controller you had already built, and `setViewControllers(_:animated:)` replaced the stack in one step.

A `NavigationStack` keeps the same shape, but the array holds **values**, not views. Apple's overview: people "add views to the top of the stack by clicking or tapping a `NavigationLink`, and remove views using built-in, platform-appropriate controls, like a Back button or a swipe gesture. The stack always displays the most recently added view that hasn't been removed, and doesn't allow the root view to be removed."

```swift ios
import SwiftUI

struct Recipe: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let minutes: Int
}

struct RecipeListView: View {
    let recipes: [Recipe]

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                NavigationLink(recipe.title, value: recipe)
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        Text("Ready in \(recipe.minutes) minutes")
            .navigationTitle(recipe.title)
    }
}
```

Line by line:

1. **`NavigationStack { … }`** wraps the root view, here a `List`. It provides the navigation bar and the Back button.
2. **`NavigationLink(recipe.title, value: recipe)`** is a row with a disclosure indicator. It doesn't know what screen it leads to. Tapping it appends `recipe` to the stack's path; Apple's note on the `value` parameter: "When the user selects the link, SwiftUI stores a copy of the value."
3. **`.navigationDestination(for: Recipe.self) { recipe in … }`** registers a destination for every value of type `Recipe`. When a `Recipe` lands on the path, the stack calls this closure with it and pushes the view it returns.
4. **`.navigationTitle`** sets the title for whichever view it's attached to: "Recipes" for the root, the recipe's title for each detail.

The value type has to be `Hashable`. `Codable` is optional, but Apple's page for `init(value:label:)` points out that with a `Codable` value, a `NavigationPath` containing it "can produce a non-`nil` value for its `codable` property," which is what state restoration in lesson 5 needs. Making route types `Hashable` and `Codable` from the start costs one line.

### Matching by type

A stack can have several `navigationDestination(for:)` modifiers, one per type. Apple: "The stack matches navigation links with navigation destinations based on their respective data types." If a link presents a value whose type has no destination, Apple's list of outcomes ends with "In other cases, the link doesn't do anything." There's no compile error and no crash. Here's that lookup as a model in plain Swift:

```swift
/// A stack that finds a destination by the type of the value pushed.
struct Stack {
    var destinations: [ObjectIdentifier: (Any) -> String] = [:]
    var screens: [String] = ["Recipes"]

    mutating func register<T>(_ type: T.Type, _ makeScreen: @escaping (T) -> String) {
        destinations[ObjectIdentifier(type)] = { makeScreen($0 as! T) }
    }

    mutating func linkTapped<T>(_ value: T) {
        guard let makeScreen = destinations[ObjectIdentifier(T.self)] else {
            print("no destination for \(T.self): nothing happens")
            return
        }
        screens.append(makeScreen(value))
    }
}

struct Recipe {
    let title: String
}

struct Author {
    let name: String
}

var stack = Stack()
stack.register(Recipe.self) { "Recipe: \($0.title)" }
stack.register(Int.self) { "Recipe #\($0)" }

stack.linkTapped(Recipe(title: "Flan"))
stack.linkTapped(Author(name: "Ana"))
stack.linkTapped(42)
print(stack.screens.joined(separator: " > "))
```

```output
no destination for Author: nothing happens
Recipes > Recipe: Flan > Recipe #42
```

`ObjectIdentifier(T.self)` is a hashable identity for a type, so the dictionary is keyed by type, which is how the real stack matches too. The `Author` link is dead because no one registered `Author`. In an app that's a row you tap and nothing moves; the fix is a `navigationDestination(for: Author.self)` somewhere inside the stack.

> [!warning] A model
> SwiftUI's lookup also involves where the modifier sits in the view hierarchy and split-view columns (lesson 4). The model keeps only the rule that matters most: destinations are found by the value's type.

## Taking control of the path

Without a path argument, the stack keeps its state to itself. Pass a binding and you share it: "The stack adds items to the collection as it adds views to the stack and removes items when it removes views," and your code "can also modify the array to change the views on the stack."

The usual path is an array of one enum that names every screen the stack can show:

```swift ios
import SwiftUI

enum Route: Hashable, Codable {
    case category(String)
    case recipe(id: Int)
    case author(name: String)
}

struct CookbookView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink("Desserts", value: Route.category("Desserts"))
                NavigationLink("Soups", value: Route.category("Soups"))
                Button("Today's pick") {
                    path = [.category("Desserts"), .recipe(id: 42)]   // replace the whole stack
                }
            }
            .navigationTitle("Cookbook")
            .navigationDestination(for: Route.self) { route in
                screen(for: route)
            }
        }
    }

    @ViewBuilder
    private func screen(for route: Route) -> some View {
        switch route {
        case .category(let name):
            List {
                NavigationLink("Flan", value: Route.recipe(id: 42))
                NavigationLink("Brownies", value: Route.recipe(id: 7))
            }
            .navigationTitle(name)
        case .recipe(let id):
            VStack(spacing: 16) {
                Text("Recipe \(id)")
                NavigationLink("About the author", value: Route.author(name: "Ana"))
                Button("Back") { path.removeLast() }                  // pop one
                Button("All recipes") { path.removeAll() }            // pop to root
            }
            .navigationTitle("Recipe")
        case .author(let name):
            Text(name)
                .navigationTitle("Author")
        }
    }
}
```

- **Push**: a link appends, or your code calls `path.append(.recipe(id: 7))`.
- **Pop one**: `path.removeLast()`. The system Back button does the same to your array.
- **Pop to root**: `path.removeAll()`. The root (the `List`) isn't in the path, so an empty path means "show the root."
- **Replace**: assign a new array. Apple's example `showParks()` sets two values and the stack "replaces the stack's display with a view that shows details for Sequoia, the last item," with Yosemite underneath it for Back. It's `setViewControllers(_:animated:)` from Module 25, written as an assignment.

One `switch` decides what every route looks like, and the compiler checks that it handles every case. Lesson 5 moves the path out of the view into a model so that deep links and saved state can write to it.

### The path as a plain value

Because the path is just an array of values, the navigation logic can be written and tested without SwiftUI:

```swift
enum Route: Hashable {
    case category(String)
    case recipe(id: Int)
    case author(name: String)
}

struct NavigationModel {
    private(set) var path: [Route] = []

    mutating func push(_ route: Route) {
        path.append(route)
    }

    mutating func pop() {
        guard !path.isEmpty else { return }   // the root can't be popped
        path.removeLast()
    }

    mutating func popToRoot() {
        path.removeAll()
    }

    mutating func replace(with routes: [Route]) {
        path = routes
    }

    /// What the user sees, root first; the last one is on screen.
    var screens: String {
        (["Cookbook"] + path.map { "\($0)" }).joined(separator: " > ")
    }
}

var navigation = NavigationModel()
navigation.push(.category("Desserts"))
navigation.push(.recipe(id: 42))
print(navigation.screens)

navigation.push(.author(name: "Ana"))
navigation.pop()
print(navigation.screens)

navigation.replace(with: [.category("Soups"), .recipe(id: 7)])
print(navigation.screens)
print(navigation.path == [.category("Soups"), .recipe(id: 7)])

navigation.popToRoot()
navigation.pop()
print(navigation.screens, navigation.path.count)
```

```output
Cookbook > category("Desserts") > recipe(id: 42)
Cookbook > category("Desserts") > recipe(id: 42)
Cookbook > category("Soups") > recipe(id: 7)
true
Cookbook 0
```

Two details matter. The model's `pop()` guards against an empty path: `Array.removeLast()` on an empty array stops the program, and the same goes for a `Button("Back") { path.removeLast() }` that can run when nothing is pushed:

```swift runtime-error Can't remove last element from an empty collection
var path: [String] = []
path.removeLast()
```

And `==` on the path works because `Route` is `Hashable` (which includes `Equatable`): a test can say "after this link, the stack is exactly these screens," something you can't easily check with a stack of view controllers.

## NavigationPath for mixed types

When one stack must present unrelated types and you don't want a single enum around them (a shared component pushes its own type, say), use `NavigationPath`, "a type-erased list of data representing the content of a navigation stack":

```swift ios
import SwiftUI

struct Author: Hashable, Codable {
    let name: String
}

struct MixedStackView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 12) {
                Button("Recipe 42") { path.append(42) }
                Button("Ana") { path.append(Author(name: "Ana")) }
                Button("Back to start") { path.removeLast(path.count) }
                Text("\(path.count) screens pushed")
            }
            .navigationDestination(for: Int.self) { id in
                Text("Recipe \(id)")
            }
            .navigationDestination(for: Author.self) { author in
                Text(author.name)
            }
        }
    }
}
```

What you give up is visibility. `NavigationPath` has `count`, `isEmpty`, `append(_:)` and `removeLast(_:)`, plus `codable` for saving; you can't loop over its elements or ask what's on top. `removeLast(_:)` has a precondition: `k` "must be less than or equal to the number of elements in the path," which is why the button removes exactly `path.count`. For an app's own screens, an enum and an array are easier to reason about and to test; reach for `NavigationPath` when the types genuinely don't belong together.

## Why value-based beats destination-based

`NavigationLink` also has a destination form, `NavigationLink("Work Folder") { FolderDetail(id: workFolder.id) }`, where the link carries the view it pushes. It isn't deprecated, and for a static settings screen with three rows it's fine. The forms that *are* deprecated are the ones that tried to make destination links programmable: `NavigationLink(destination:isActive:label:)` is marked deprecated since iOS 16 with the message "use NavigationLink(value:label:), or navigationDestination(isPresented:destination:), inside a NavigationStack or NavigationSplitView," and `NavigationView` itself is deprecated in favor of `NavigationStack` and `NavigationSplitView`.

Apple's migration article gives the reason in one sentence: `navigationDestination(for:destination:)` "detach[es] the presented data from the corresponding view. That makes it possible for the `path` array to represent every view on the stack." The consequences:

| | Destination in the link | Value in the link |
| --- | --- | --- |
| What's on screen | Hidden inside SwiftUI | Your `path`, readable and comparable |
| Programmatic push or pop | One `Bool` per link (`isActive`), now deprecated | Append to or remove from an array |
| Deep link to three levels | Set three `Bool`s, one per level, in order | Assign a three-element array |
| Saving and restoring | Not possible from outside | Encode the path (lesson 5) |
| Where a screen is defined | In every link that leads to it | Once per type |
| When the destination value is created | When the link is created (the closure runs to build it) | Only when the value is pushed |

The first four rows are the reason teams move to value-based links. A path you own is the SwiftUI version of Module 25's coordinator: navigation decisions live in one place, as data.

### One-off pushes

Two other modifiers push without a link, both for a single destination:

- `navigationDestination(isPresented:destination:)` (iOS 16) pushes a view while a `Bool` is true. Apple: "In general, favor binding a path to a navigation stack for programmatic navigation," and use this for "components that can push an associated view."
- `navigationDestination(item:destination:)` (iOS 17) pushes while an optional value is non-`nil`, and setting it back to `nil` pops.

From inside a pushed view, `@Environment(\.dismiss)` pops it: Apple lists "Pop the current view from a `NavigationStack`" among the things the dismiss action does. Lesson 3 covers `dismiss` for sheets.

## Common mistakes

> [!error] navigationDestination inside a List row
> Apple, on every `navigationDestination` page: "Do not put a navigation destination modifier inside a 'lazy' container, like `List` or `LazyVStack`. These containers create child views only when needed to render on screen." A destination attached to a row inside `ForEach` may not exist when a link or your code pushes a value. Attach it to the `List` (or anything outside the lazy container) inside the stack.

> [!error] A NavigationStack inside a pushed view
> Each pushed screen is already inside the stack. Wrapping a destination's content in another `NavigationStack` nests a second stack with its own path, which the outer path (and your router in lesson 5) can't see. One stack per column of navigation; destinations are plain views.

> [!error] A link that does nothing
> A value whose type has no `navigationDestination` in that stack is ignored. Check that every type you push, including types pushed from code, has a destination.

> [!error] error: type 'Route' does not conform to protocol 'Hashable'
> Route values must be `Hashable`, and Swift only synthesizes that when every associated value is `Hashable`. A closure can't be. Swift 6.3 reports it for `Hashable` and again for `Equatable`. Keep routes to plain data (ids, names); put behavior in the views and models the destination builds.

```swift no-compile type 'Route' does not conform to protocol 'Hashable'
enum Route: Hashable {
    case recipe(id: Int)
    case confirm(onDone: () -> Void)
}
```

> [!error] Whole model objects in the path
> SwiftUI "stores a copy of the value" you push. Push a recipe struct and later edit the recipe, and the pushed screen still shows the old copy. Push an id (`.recipe(id: 42)`) and let the destination look up the current data.

## Exercises

````exercise
id: m35-l02-e1
type: prediction
prompt: "The navigation model from the lesson. What does it print?"
code: |
  enum Route: Hashable {
      case category(String)
      case recipe(id: Int)
      case author(name: String)
  }

  struct NavigationModel {
      private(set) var path: [Route] = []

      mutating func push(_ route: Route) { path.append(route) }

      mutating func pop() {
          guard !path.isEmpty else { return }
          path.removeLast()
      }

      mutating func popToRoot() { path.removeAll() }

      mutating func replace(with routes: [Route]) { path = routes }

      var onScreen: String {
          path.last.map { "\($0)" } ?? "root"
      }
  }

  var navigation = NavigationModel()
  navigation.replace(with: [.category("Soups"), .recipe(id: 3)])
  navigation.push(.author(name: "Lee"))
  navigation.pop()
  navigation.pop()
  print(navigation.onScreen, navigation.path.count)
  navigation.push(.recipe(id: 9))
  navigation.push(.recipe(id: 9))
  print(navigation.onScreen, navigation.path.count)
  navigation.popToRoot()
  navigation.pop()
  print(navigation.onScreen, navigation.path.isEmpty)
output: |
  category("Soups") 1
  recipe(id: 9) 3
  root true
hints:
  - "replace sets two values; the push adds a third; two pops remove two."
  - "Nothing stops the same value being pushed twice."
  - "pop() on an empty path does nothing."
solution: |
  ```output
  category("Soups") 1
  recipe(id: 9) 3
  root true
  ```

  After `replace` the path has two values; pushing the author makes three, and two pops leave only the category. Pushing recipe 9 twice gives three values: nothing in an array stops duplicates, and a real stack would show the same recipe twice with Back between them, which is usually a bug in whatever pushed it. `popToRoot()` empties the path, and the guarded `pop()` then does nothing instead of crashing.
````

````exercise
id: m35-l02-e2
type: prediction
prompt: "The type-matching model from the lesson, with three registered types and four taps. What does it print?"
code: |
  struct Stack {
      var destinations: [ObjectIdentifier: (Any) -> String] = [:]
      var screens: [String] = ["Home"]

      mutating func register<T>(_ type: T.Type, _ makeScreen: @escaping (T) -> String) {
          destinations[ObjectIdentifier(type)] = { makeScreen($0 as! T) }
      }

      mutating func linkTapped<T>(_ value: T) {
          guard let makeScreen = destinations[ObjectIdentifier(T.self)] else {
              print("ignored:", value)
              return
          }
          screens.append(makeScreen(value))
      }
  }

  struct Tag {
      let name: String
  }

  var stack = Stack()
  stack.register(String.self) { "Search \"\($0)\"" }
  stack.register(Int.self) { "Item \($0)" }
  stack.register(Tag.self) { "Tag #\($0.name)" }

  stack.linkTapped("milk")
  stack.linkTapped(7)
  stack.linkTapped(2.5)
  stack.linkTapped(Tag(name: "quick"))
  print(stack.screens.count)
  print(stack.screens.last ?? "none")
output: |
  ignored: 2.5
  4
  Tag #quick
hints:
  - "2.5 is a Double. Is Double registered?"
  - "The stack starts with one screen, Home."
solution: |
  ```output
  ignored: 2.5
  4
  Tag #quick
  ```

  `"milk"`, `7` and the `Tag` each find their type's destination and push a screen: Home plus three is four. `2.5` is a `Double`, and only `Int` was registered, so the tap is ignored. That's the silent dead link Apple describes ("the link doesn't do anything"); `Int` and `Double` are different types even though both are numbers.
````

````exercise
id: m35-l02-e3
type: comprehension
prompt: "A support link must open Settings > Account > Devices from a push notification. Why is a NavigationStack with a [Route] path the better fit than destination-based NavigationLinks?"
choices:
  - text: "Because the whole stack is one array, the notification handler can assign [.settings, .account, .devices] and the stack shows all three with working Back buttons."
    correct: true
    why: "Assigning the path replaces the stack in one step, like setViewControllers in UIKit."
  - text: "Because destination-based links don't compile on iOS 17."
    correct: false
    why: "NavigationLink(destination:label:) compiles and isn't deprecated; only the isActive and selection forms are."
  - text: "Because NavigationStack animates faster than NavigationView."
    correct: false
    why: "Speed isn't the point; control of the stack's state is."
  - text: "Because value-based links don't need a navigationDestination."
    correct: false
    why: "They do: the destination for each value type is what turns the value into a screen."
solution: |
  **The path is the stack.** With destination links, each level is created by the previous screen's link, so reaching the third level from outside means activating links one after another, which is what the deprecated `isActive` bindings tried to do. With a path, the notification handler writes three values and SwiftUI builds the three screens, exactly the "Use a path to support deep links, state restoration, or other kinds of programmatic navigation" case in Apple's `NavigationStack` overview. Lesson 5 builds that handler.
````

````exercise
id: m35-l02-e4
type: fill-in
prompt: "Complete the stack: bind it to path, register the destination for Route values, and make the Home button return to the root."
code: |
  struct NotesView: View {
      @State private var path: [Route] = []

      var body: some View {
          NavigationStack([[1]]: $path) {
              List {
                  NavigationLink("Work", value: Route.folder("Work"))
              }
              .[[2]](for: Route.self) { route in
                  RouteScreen(route: route, onHome: { path.[[3]]() })
              }
          }
      }
  }
blanks:
  - id: "1"
    answers: ["path"]
  - id: "2"
    answers: ["navigationDestination"]
  - id: "3"
    answers: ["removeAll"]
hints:
  - "The initializer that shares the stack's state takes a binding labeled like the property."
  - "An empty path means the root is on screen."
solution: |
  ```swift ios
  import SwiftUI

  enum Route: Hashable, Codable {
      case folder(String)
      case note(id: Int)
  }

  struct RouteScreen: View {
      let route: Route
      let onHome: () -> Void

      var body: some View {
          VStack {
              Text(String(describing: route))
              Button("Home", action: onHome)
          }
      }
  }

  struct NotesView: View {
      @State private var path: [Route] = []

      var body: some View {
          NavigationStack(path: $path) {
              List {
                  NavigationLink("Work", value: Route.folder("Work"))
              }
              .navigationDestination(for: Route.self) { route in
                  RouteScreen(route: route, onHome: { path.removeAll() })
              }
          }
      }
  }
  ```

  `NavigationStack(path:root:)` shares the stack's state through the binding. The destination is attached to the `List`, outside the lazy rows, inside the stack. `removeAll()` empties the path, which pops to the root. The pushed screen gets a closure instead of the whole path: it only needs to say "go home," not know how the stack works.
````

````exercise
id: m35-l02-e5
type: find-errors
prompt: "This screen was ported from an iOS 15 app. Which of these are real problems?"
code: |
  struct LibraryView: View {
      let books: [Book]
      @State private var showsFirst = false

      var body: some View {
          NavigationView {
              List(books) { book in
                  NavigationLink(book.title, value: book)
                      .navigationDestination(for: Book.self) { book in
                          NavigationStack {
                              BookDetail(book: book)
                          }
                      }
              }
          }
      }
  }
choices:
  - text: "NavigationView is deprecated; this should be a NavigationStack."
    correct: true
    why: "Apple's migration article: with iOS 16 or later as the minimum, transition away from NavigationView. Value links and navigationDestination are designed for NavigationStack and NavigationSplitView."
  - text: "The navigationDestination is inside the List's rows, a lazy container."
    correct: true
    why: "Apple says to put it outside lazy containers so the stack can always see it. Attach it to the List."
  - text: "The destination wraps BookDetail in a second NavigationStack."
    correct: true
    why: "The pushed view is already in the stack; nesting adds a second stack with its own path that the outer one can't see."
  - text: "showsFirst is unused state."
    correct: false
    why: "It's dead code worth deleting, but it doesn't break navigation. (It hints that someone planned an isActive link.)"
  - text: "Book must be a class for value-based links."
    correct: false
    why: "It must be Hashable. A struct is the normal choice."
rubric:
  - Flags NavigationView.
  - Flags the destination inside the List rows.
  - Flags the nested NavigationStack.
  - Doesn't treat the unused state or Book being a struct as navigation bugs.
solution: |
  ```swift ios
  import SwiftUI

  struct Book: Identifiable, Hashable, Codable {
      let id: Int
      let title: String
  }

  struct BookDetail: View {
      let book: Book
      var body: some View {
          Text(book.title).navigationTitle(book.title)
      }
  }

  struct LibraryView: View {
      let books: [Book]

      var body: some View {
          NavigationStack {
              List(books) { book in
                  NavigationLink(book.title, value: book)
              }
              .navigationDestination(for: Book.self) { book in
                  BookDetail(book: book)
              }
          }
      }
  }
  ```

  One stack, one destination per type attached outside the lazy rows, and destination views that are just views. The unused `showsFirst` goes too; if the old app needed "open the first book on launch," the new version would set a path to `[books[0]]`.
````

````exercise
id: m35-l02-e6
type: solve
prompt: |
  Add `mutating func pop(to route: Route)` to the navigation model: it removes every screen above the **last** occurrence of `route`, so that `route` is on screen. If `route` isn't in the path, it does nothing. (UIKit's equivalent is `popToViewController(_:animated:)`.)

  Then run:

  ```swift
  var navigation = NavigationModel()
  navigation.replace(with: [.category("Desserts"), .recipe(id: 42), .author(name: "Ana"), .recipe(id: 7)])
  navigation.pop(to: .recipe(id: 42))
  print(navigation.screens)
  navigation.pop(to: .category("Soups"))
  print(navigation.screens)
  navigation.replace(with: [.recipe(id: 1), .author(name: "Lee"), .recipe(id: 1), .author(name: "Lee")])
  navigation.pop(to: .recipe(id: 1))
  print(navigation.screens)
  ```
starter: |
  enum Route: Hashable {
      case category(String)
      case recipe(id: Int)
      case author(name: String)
  }

  struct NavigationModel {
      private(set) var path: [Route] = []

      mutating func replace(with routes: [Route]) { path = routes }

      mutating func pop(to route: Route) {
          // your code
      }

      var screens: String {
          (["Cookbook"] + path.map { "\($0)" }).joined(separator: " > ")
      }
  }
hints:
  - "lastIndex(of:) works on arrays of Equatable elements and returns an optional index."
  - "Keep the elements up to and including that index: path = Array(path[...index])."
rubric:
  - Finds the last occurrence, not the first.
  - Leaves the path untouched when the route isn't there.
  - Keeps the target route on screen (doesn't remove it).
  - Prints the three expected lines.
solution: |
  ```swift
  enum Route: Hashable {
      case category(String)
      case recipe(id: Int)
      case author(name: String)
  }

  struct NavigationModel {
      private(set) var path: [Route] = []

      mutating func replace(with routes: [Route]) { path = routes }

      mutating func pop(to route: Route) {
          guard let index = path.lastIndex(of: route) else { return }
          path = Array(path[...index])
      }

      var screens: String {
          (["Cookbook"] + path.map { "\($0)" }).joined(separator: " > ")
      }
  }

  var navigation = NavigationModel()
  navigation.replace(with: [.category("Desserts"), .recipe(id: 42), .author(name: "Ana"), .recipe(id: 7)])
  navigation.pop(to: .recipe(id: 42))
  print(navigation.screens)
  navigation.pop(to: .category("Soups"))
  print(navigation.screens)
  navigation.replace(with: [.recipe(id: 1), .author(name: "Lee"), .recipe(id: 1), .author(name: "Lee")])
  navigation.pop(to: .recipe(id: 1))
  print(navigation.screens)
  ```

  ```output
  Cookbook > category("Desserts") > recipe(id: 42)
  Cookbook > category("Desserts") > recipe(id: 42)
  Cookbook > recipe(id: 1) > author(name: "Lee") > recipe(id: 1)
  ```

  `lastIndex(of:)` is available because `Route` is `Equatable` (through `Hashable`). `path[...index]` is a slice up to and including the target, wrapped in `Array` because `path` is an array. Soups isn't in the path, so the second call changes nothing. When a route appears twice, popping to the last one removes only what's above it, which matches what the user sees: the nearest earlier copy. In SwiftUI the same function, called on the model that owns the path, pops several screens in one animated step.
````

## Summary

- A `NavigationStack` shows a root view and pushes one view per value in its path. The root can't be popped.
- `NavigationLink(value:)` appends a value; `navigationDestination(for:)` builds the screen for values of a type. Matching is by type, and a value with no destination does nothing.
- Bind the stack to `@State var path: [Route]` to push (`append`), pop (`removeLast`), pop to root (`removeAll`) and replace (assign) from code. Guard pops; `removeLast()` on an empty array stops the program.
- `NavigationPath` holds mixed types but hides them: count, append, removeLast and a codable form. Prefer one enum and an array for your own screens.
- Value-based links make navigation state data you own: readable, testable, settable for deep links and saveable. `NavigationView` and `isActive` links are deprecated.
- Put `navigationDestination` inside the stack but outside lazy containers, don't nest stacks in destinations, and push ids rather than model copies.
