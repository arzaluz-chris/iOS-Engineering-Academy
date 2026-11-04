---
id: m35-l04
title: Tabs, toolbars and split views
description: "The containers that give an app its overall shape. You build a TabView twice, with the iOS 18 Tab API behind #available and with the iOS 17 tabItem form, give each tab its own NavigationStack, put buttons in the navigation bar, bottom bar and keyboard with toolbar placements, and build a NavigationSplitView that shows columns on iPad and collapses into a stack on iPhone, adapting the tab structure when the size class changes."
module: m35
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m35-l03, m25-l02]
objectives:
  - Build a TabView with programmatic selection using the iOS 18 Tab API and an iOS 17 fallback with tabItem and tag.
  - Give each tab its own NavigationStack and explain why the TabView isn't inside a stack.
  - Place toolbar items with semantic placements (primaryAction, confirmationAction, cancellationAction) and positional ones (topBarLeading, topBarTrailing, bottomBar, keyboard).
  - Build two- and three-column NavigationSplitViews driven by list selection, and predict what an iPhone shows when they collapse.
  - Adapt to iPhone and iPad with the horizontal size class, preferredCompactColumn and the sidebarAdaptable tab style.
terms:
  - term: TabView
    definition: "A container that switches between child views with a tab bar (iOS 13). From iOS 18 you declare tabs with Tab values; before that, each child gets tabItem(_:) and tag(_:)."
  - term: Tab
    definition: "An iOS 18 type that describes one tab of a TabView: title, image, selection value, optional role (such as .search) and content."
  - term: Toolbar placement
    definition: "A ToolbarItemPlacement that says where an item goes. Semantic placements (primaryAction, confirmationAction, cancellationAction) let the system choose a position per platform; positional ones (topBarLeading, topBarTrailing, bottomBar, keyboard) name it."
  - term: NavigationSplitView
    definition: "A container (iOS 16) with two or three columns where selections in leading columns control later ones. In narrow sizes, like iPhone, it collapses into a single stack."
  - term: Horizontal size class
    definition: "An environment value, compact or regular, that describes the width available. iPhone in portrait is compact; full-screen iPad is regular; iPad split screen can be either."
mastery:
  - Write a three-tab app with a badge on one tab, using Tab inside if #available(iOS 18, *) and tabItem otherwise.
  - Put Cancel and Save in a sheet's bar with cancellationAction and confirmationAction.
  - Build a categories → recipes → detail split view and describe what an iPhone user sees after selecting a category.
  - Keep a tab's selection meaningful when an iPad window becomes compact.
  - Replace navigationBarTrailing with topBarTrailing in old code.
resources: [uikit-uitabbarcontroller, uikit-uitab, uikit-adapting-trait-changes, hig]
cards:
  - id: m35-l04-c1
    front: TabView on iOS 18 vs iOS 17?
    back: "iOS 18: TabView(selection:) { Tab(\"Title\", systemImage: \"…\", value: …) { content } }, plus roles, TabSection and .sidebarAdaptable. iOS 17: children with .tabItem { Label(…) } and .tag(value). With an iOS 17 target, put the Tab version behind if #available(iOS 18, *)."
  - id: m35-l04-c2
    front: TabView inside a NavigationStack, or a NavigationStack inside each tab?
    back: "A stack inside each tab. Each tab keeps its own path and Back history, as with a UINavigationController per tab in Module 25. A stack around the TabView would push over the whole tab view and share one path."
  - id: m35-l04-c3
    front: confirmationAction, cancellationAction and primaryAction on iOS?
    back: "Apple: cancellationAction goes on the leading edge of the navigation bar; confirmationAction in the same place as primaryAction, the trailing edge. They also tell the system what the button means, so other platforms place it correctly."
  - id: m35-l04-c4
    front: What does a three-column NavigationSplitView show on iPhone?
    back: "It collapses into one stack and shows the last column with useful information: the sidebar list first, the content list after a sidebar selection, the detail after a content selection. Back clears the selection of the column it leaves."
  - id: m35-l04-c5
    front: How do you choose which column is on top when a split view collapses?
    back: "iOS 17: pass a Binding<NavigationSplitViewColumn> as preferredCompactColumn (.sidebar, .content, .detail). The split view updates it when people navigate, for example to .sidebar after Back."
---

## The idea in one sentence

Tabs, toolbars and split views are the **frame** around your screens: a `TabView` picks a section, a `NavigationSplitView` shows a hierarchy side by side when there's room and as a stack when there isn't, and `toolbar` puts actions where each platform expects them.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target unless marked 18.0, Swift 6 mode), not run. Behavior comes from Apple's pages for `TabView`, `Tab`, `tabItem(_:)`, `toolbar(content:)`, `ToolbarItemPlacement`, `NavigationSplitView`, `NavigationSplitViewVisibility` and `NavigationSplitViewColumn`, read in November 2026. How the bars and columns look on a device wasn't checked. The models of a collapsing split view and of tab selection are plain Swift, compiled and run with Swift 6.3.

## Tabs

Module 25 built a `UITabBarController` with a `UINavigationController` in each tab. SwiftUI's `TabView` has the same structure, and since iOS 18 there are two ways to write it.

The **iOS 18 Tab API** declares each tab as a `Tab` with a title, a symbol, a selection value and its content. Apple's `TabView` page now uses this form in every example, and Apple's current documentation marks `tabItem(_:)` deprecated with "Use `Tab(title:image:value:content:)` and related initializers instead." The **iOS 17 form** attaches `.tabItem { Label(…) }` and `.tag(…)` to each child. With this course's iOS 17 deployment target you need both: the new API behind an availability check, the old one as the fallback.

```swift ios
import SwiftUI

enum AppTab: Hashable {
    case recipes, shopping, search
}

struct RootView: View {
    @State private var selection: AppTab = .recipes
    let itemsToBuy = 3

    var body: some View {
        if #available(iOS 18, *) {
            TabView(selection: $selection) {
                Tab("Recipes", systemImage: "book", value: AppTab.recipes) {
                    RecipesTab()
                }
                Tab("Shopping", systemImage: "cart", value: AppTab.shopping) {
                    ShoppingTab()
                }
                .badge(itemsToBuy)
                Tab(value: AppTab.search, role: .search) {
                    SearchTab()
                }
            }
        } else {
            TabView(selection: $selection) {
                RecipesTab()
                    .tabItem { Label("Recipes", systemImage: "book") }
                    .tag(AppTab.recipes)
                ShoppingTab()
                    .tabItem { Label("Shopping", systemImage: "cart") }
                    .tag(AppTab.shopping)
                    .badge(itemsToBuy)
                SearchTab()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(AppTab.search)
            }
        }
    }
}

struct RecipesTab: View {
    var body: some View {
        NavigationStack {
            Text("Recipes")
                .navigationTitle("Recipes")
        }
    }
}

struct ShoppingTab: View {
    var body: some View {
        NavigationStack {
            Text("Shopping list")
                .navigationTitle("Shopping")
        }
    }
}

struct SearchTab: View {
    var body: some View {
        NavigationStack {
            Text("Search")
                .navigationTitle("Search")
        }
    }
}
```

Reading it:

1. **`enum AppTab: Hashable`** names the tabs. The selection binding holds one of them; setting `selection = .shopping` from code switches tabs, which is how lesson 5's deep links will pick a tab.
2. **`if #available(iOS 18, *)`** inside `body` is allowed in a view builder. On iOS 18 and later the first branch runs; on iOS 17, the second. Both show the same three tabs.
3. **`Tab(_:systemImage:value:content:)`** (iOS 18). Apple: "Each tab should have a unique selection value and all tabs should have the same selection value type."
4. **`Tab(value:role:content:)` with `.search`** (iOS 18) creates "a new tab with a label inferred from the role": the system's search tab, with its title and symbol.
5. **`.badge(itemsToBuy)`** works on a `Tab` (iOS 18) and on a view inside a `TabView` (`View.badge`, iOS 15).
6. **`.tabItem { Label(…) }` and `.tag(AppTab.recipes)`** are the fallback. The tag is what the selection binding compares against; a tab without a tag can't be selected from code.
7. **Each tab owns a `NavigationStack`.** The tab view is the root; each section has its own stack, path and Back history.

### Tabs that become a sidebar

iOS 18 also lets a tab view turn into a sidebar on iPad. With `.tabViewStyle(.sidebarAdaptable)`, `TabSection` groups secondary tabs: Apple says that "on iPadOS, tab sections appear in both the sidebar and the tab bar," and on iPhone and compact iPad "secondary tabs appear in the tab bar," without the section header. That's iOS 18 only, so the block below is checked with an iOS 18 deployment target:

```swift ios 18.0
import SwiftUI

enum LibraryTab: Hashable {
    case home, search
    case category(String)
}

struct LibraryRoot: View {
    @State private var selection: LibraryTab = .home
    let categories = ["Desserts", "Soups", "Breads"]

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: LibraryTab.home) {
                Text("Home")
            }
            Tab(value: LibraryTab.search, role: .search) {
                Text("Search")
            }
            TabSection("Categories") {
                ForEach(categories, id: \.self) { name in
                    Tab(name, systemImage: "folder", value: LibraryTab.category(name)) {
                        Text(name)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
```

On iPhone those three category tabs would crowd the tab bar. Apple's `TabView` page has an example for that case: show a "Browse" tab in compact width that lists the categories, hide the category tabs there with `.hidden(sizeClass == .compact)`, and fix up the selection when the size class changes. The fix-up is the part worth understanding, and it's plain logic:

```swift
enum AppTab: Hashable {
    case home, search, browse
    case category(String)

    /// Tabs that only exist in regular width; in compact width they live inside Browse.
    var livesInBrowse: Bool {
        if case .category = self { return true }
        return false
    }
}

enum SizeClass {
    case compact, regular
}

struct TabState {
    var selection: AppTab
    var browsePath: [AppTab] = []

    mutating func adapt(to sizeClass: SizeClass) {
        if sizeClass == .compact && selection.livesInBrowse {
            browsePath = [selection]      // show it inside Browse
            selection = .browse
        } else if sizeClass == .regular && selection == .browse {
            selection = browsePath.last ?? .category("Desserts")
        }
    }
}

var state = TabState(selection: .category("Soups"))
state.adapt(to: .compact)
print(state.selection, "| Browse path:", state.browsePath.map { "\($0)" })
state.adapt(to: .regular)
print(state.selection)

state.selection = .home
state.adapt(to: .compact)
print(state.selection, "| Browse path:", state.browsePath.map { "\($0)" })

state.selection = .browse
state.browsePath = []
state.adapt(to: .regular)
print(state.selection)
```

```output
browse | Browse path: ["category(\"Soups\")"]
category("Soups")
home | Browse path: ["category(\"Soups\")"]
category("Desserts")
```

It's the same two branches as Apple's `onChange(of: sizeClass, initial: true)` handler, with the names changed. When an iPad window shrinks to compact while Soups is selected, the Soups tab disappears from the bar, so the user lands in Browse with Soups pushed: the same screen, reached a different way. When the window grows, the selection goes back to the category tab. Home exists in both layouts, so nothing changes for it (the leftover `browsePath` is harmless). (The path is printed through `map { "\($0)" }` because an array of enum values prints each element with its module and type name, which depends on how the program was built.)

## Toolbars

`toolbar(content:)` (iOS 14) "populates the toolbar or navigation bar with the specified items." You wrap each item in a `ToolbarItem(placement:content:)` or a group in a `ToolbarItemGroup`:

```swift ios
import SwiftUI

struct RecipeEditor: View {
    @State private var title = ""
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {}
                        .disabled(title.isEmpty)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Favorite", systemImage: isFavorite ? "star.fill" : "star") {
                        isFavorite.toggle()
                    }
                    Spacer()
                    Button("Share", systemImage: "square.and.arrow.up") {}
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {}
                }
            }
        }
    }
}
```

Two kinds of placement. **Semantic** placements say what a button means and let each platform choose where it goes. **Positional** ones say where.

| Placement | Where on iOS (Apple) |
| --- | --- |
| `.automatic` | "the trailing position of the navigation bar" (centered on iPad when the bar supports customization) |
| `.primaryAction` | "the trailing edge of the navigation bar" |
| `.confirmationAction` | "the same location as a `primaryAction` placement" |
| `.cancellationAction` | "the leading edge of the navigation bar" |
| `.topBarLeading`, `.topBarTrailing` | Leading or trailing edge of the top bar; "on watchOS, iOS, and tvOS, the top bar is the navigation bar" |
| `.bottomBar` | "the bottom toolbar" |
| `.keyboard` | Above the keyboard (iOS 15) |

In a sheet like `RecipeEditor`, use `.cancellationAction` and `.confirmationAction`: they put Cancel and Save where people expect them and mark which is which. In a pushed or root screen, `.primaryAction` or `.topBarTrailing` for the main action. Apple also notes that the system "uses the space available to the toolbar when determining how many items to render," moving extras into an overflow menu. `ToolbarItemGroup` keeps related controls together; Apple: grouping "provides a one-to-one mapping between controls and toolbar items which results in the correct layout and spacing on each platform."

> [!warning] navigationBarLeading and navigationBarTrailing
> Older code uses `.navigationBarTrailing`. Apple's current documentation marks it deprecated with "use topBarTrailing instead." `topBarLeading` and `topBarTrailing` are back-deployed (`@backDeployed(before: iOS 17.0)`), so they work with any deployment target this course uses. The same goes for `navigationBarItems(…)` and `navigationBarTitle(_:)`, replaced by `toolbar` and `navigationTitle`.

## Split views

On iPad there's room for a list and its detail side by side. `NavigationSplitView` (iOS 16) "presents views in two or three columns, where selections in leading columns control presentations in subsequent columns":

```swift ios
import SwiftUI

struct Recipe: Identifiable, Hashable {
    let id: Int
    let title: String
    let category: String
}

struct CookbookSplitView: View {
    let categories = ["Desserts", "Soups"]
    let recipes = [
        Recipe(id: 1, title: "Flan", category: "Desserts"),
        Recipe(id: 2, title: "Brownies", category: "Desserts"),
        Recipe(id: 3, title: "Gazpacho", category: "Soups"),
    ]
    @State private var category: String?
    @State private var recipeID: Recipe.ID?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(categories, id: \.self, selection: $category) { name in
                Text(name)
            }
            .navigationTitle("Cookbook")
        } content: {
            if let category {
                List(recipes.filter { $0.category == category }, selection: $recipeID) { recipe in
                    Text(recipe.title)
                }
                .navigationTitle(category)
            } else {
                Text("Select a category")
            }
        } detail: {
            if let recipe = recipes.first(where: { $0.id == recipeID }) {
                Text(recipe.title)
                    .font(.largeTitle)
            } else {
                Text("Select a recipe")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

- **Selection drives the columns.** The sidebar `List` writes the chosen category into `category`; the content column reads it and lists that category's recipes, writing into `recipeID`; the detail column shows that recipe. Apple: "Programmatic changes that you make to the selection property also affect both the list appearance and the presented detail view."
- **Placeholders** ("Select a category") are what an iPad shows in a column that has nothing selected.
- **`columnVisibility`** controls which leading columns show in regular width: `.automatic`, `.all`, `.doubleColumn` (hides the sidebar of a three-column view) or `.detailOnly`. Apple: "The split view ignores the visibility control when it collapses its columns into a stack."
- **`.navigationSplitViewStyle(.balanced)`** shrinks the detail to make room for leading columns; `.prominentDetail` tries to keep the detail's size.

### What an iPhone shows

On a narrow screen the same code becomes a stack. Apple: "with narrow sizes like on iPhone or on iPad in Slide Over, the navigation split view collapses all of its columns into a stack, and shows the last column that displays useful information," and for the three-column example it "shows the list of departments to start, the employees in the department after someone selects a department, and the employee details when someone selects an employee." In plain Swift:

```swift
struct Selection {
    var category: String?
    var recipe: String?
}

/// Regular width: three columns side by side, with placeholders.
func expanded(_ selection: Selection) -> String {
    let content = selection.category ?? "Select a category"
    let detail = selection.category != nil ? (selection.recipe ?? "Select a recipe") : "Select a recipe"
    return "Cookbook | \(content) | \(detail)"
}

/// Compact width: one stack, ending at the last column with something useful.
func collapsed(_ selection: Selection) -> String {
    var stack = ["Cookbook"]
    if let category = selection.category {
        stack.append(category)
        if let recipe = selection.recipe {
            stack.append(recipe)
        }
    }
    return stack.joined(separator: " > ")
}

let states = [
    Selection(),
    Selection(category: "Desserts"),
    Selection(category: "Desserts", recipe: "Flan"),
]
for state in states {
    print(expanded(state))
    print("  iPhone:", collapsed(state))
}
```

```output
Cookbook | Select a category | Select a recipe
  iPhone: Cookbook
Cookbook | Desserts | Select a recipe
  iPhone: Cookbook > Desserts
Cookbook | Desserts | Flan
  iPhone: Cookbook > Desserts > Flan
```

The placeholders never appear on iPhone: a column with nothing selected isn't pushed. Tapping Back from Flan pops to the Desserts list; in the real split view that clears the recipe selection, since the selection is what put the screen there. This is why a split view is often the right root even for an iPhone-first app: you get the iPad layout for free, and on iPhone it behaves like a `NavigationStack` driven by selection.

> [!warning] A model
> The model follows Apple's description of the three-column example. Which column SwiftUI shows on top when the app launches collapsed with a selection already set can be overridden, next.

### Adapting to iPhone and iPad

Three tools, from least to most manual:

- **Let the split view collapse.** Most of the adaptation is done for you.
- **`preferredCompactColumn`** (iOS 17) says which column should be on top when collapsed. Apple's example: with `.detail`, an iPhone starts on the detail; "when the person using the app taps the back button, they'll see the yellow view. The value of `preferredCompactColumn` will change from `.detail` to `.sidebar`."
- **`@Environment(\.horizontalSizeClass)`** for anything else: a different arrangement of a header, a different set of tabs (as in Apple's Browse example). It's `.compact` or `.regular`, or `nil` when unknown.

```swift ios
import SwiftUI

struct ReaderSplitView: View {
    @State private var preferredColumn = NavigationSplitViewColumn.detail

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            List {
                Text("Today's recipe")
                Text("Archive")
            }
            .navigationTitle("Reader")
        } detail: {
            RecipeHeader()
        }
    }
}

struct RecipeHeader: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 24) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 64))
                Text("Gazpacho")
                    .font(.largeTitle)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.largeTitle)
                Text("Gazpacho")
                    .font(.title)
            }
        }
    }
}
```

A detail column that needs to push further (recipe → step → timer) gets its own `NavigationStack` inside the `detail:` closure. Apple: "If you need navigation within a column, embed a navigation stack in that column."

## Common mistakes

> [!error] A TabView inside a NavigationStack
> The tab view becomes the root of one stack, so a push from any tab covers the whole tab view, tab bar included, and all tabs share one path. Put a `NavigationStack` inside each tab.

> [!error] Using Tab with an iOS 17 deployment target
> `Tab`, `TabSection`, `.sidebarAdaptable` and `Tab`'s `badge` are iOS 18. Without `if #available(iOS 18, *)` (or a higher deployment target) the code doesn't compile. Keep the `tabItem` fallback until the app's minimum is iOS 18.

> [!error] Tabs without tags in the iOS 17 form
> With `TabView(selection:)` and `tabItem`, each child needs `.tag(value)` of the selection's type. Without it, setting the selection from code doesn't switch to that tab.

> [!error] Positional placements in sheets
> `Button("Save")` at `.topBarTrailing` in a sheet looks right on iPhone, but it says nothing about meaning. `.confirmationAction` and `.cancellationAction` put the buttons in the platform's place and tell the system which is which.

> [!error] Checking the device instead of the size class
> "If iPad" is the wrong question: an iPad app in Split View or Slide Over can be compact. Ask the horizontal size class, or let `NavigationSplitView` collapse on its own.

## Exercises

````exercise
id: m35-l04-e1
type: prediction
prompt: "A two-column split view for a mail app, modeled like the lesson's. What does this print?"
code: |
  struct Selection {
      var mailbox: String?
      var message: String?
  }

  func collapsed(_ selection: Selection) -> String {
      var stack = ["Mailboxes"]
      if let mailbox = selection.mailbox {
          stack.append(mailbox)
          if let message = selection.message {
              stack.append(message)
          }
      }
      return stack.joined(separator: " > ")
  }

  var selection = Selection(mailbox: "Inbox", message: "Lunch?")
  print(collapsed(selection))
  selection.message = nil          // Back from the message
  print(collapsed(selection))
  selection.message = "Invoice"    // a message picked while no mailbox is selected
  selection.mailbox = nil
  print(collapsed(selection))
output: |
  Mailboxes > Inbox > Lunch?
  Mailboxes > Inbox
  Mailboxes
hints:
  - "Back clears the selection of the column it leaves."
  - "The message is only pushed if a mailbox is pushed first."
solution: |
  ```output
  Mailboxes > Inbox > Lunch?
  Mailboxes > Inbox
  Mailboxes
  ```

  The collapsed stack is built from leading columns to trailing ones, and stops at the first column with nothing selected. In the third state a message is selected but the mailbox isn't, so the stack stops at the mailbox list and the message selection is unreachable. In a real app that's a sign of inconsistent state: when you clear a leading selection, clear the trailing ones too.
````

````exercise
id: m35-l04-e2
type: prediction
prompt: "The tab adaptation model from the lesson, run through a few size-class changes. What does it print?"
code: |
  enum AppTab: Hashable {
      case home, search, browse
      case category(String)

      var livesInBrowse: Bool {
          if case .category = self { return true }
          return false
      }
  }

  enum SizeClass {
      case compact, regular
  }

  struct TabState {
      var selection: AppTab
      var browsePath: [AppTab] = []

      mutating func adapt(to sizeClass: SizeClass) {
          if sizeClass == .compact && selection.livesInBrowse {
              browsePath = [selection]
              selection = .browse
          } else if sizeClass == .regular && selection == .browse {
              selection = browsePath.last ?? .category("Desserts")
          }
      }
  }

  var state = TabState(selection: .category("Breads"))
  state.adapt(to: .regular)
  print(state.selection)
  state.adapt(to: .compact)
  state.browsePath.append(.category("Soups"))   // the user opens Soups inside Browse
  state.adapt(to: .regular)
  print(state.selection)
  state.adapt(to: .compact)
  print(state.selection, state.browsePath.count)
output: |
  category("Breads")
  category("Soups")
  browse 1
hints:
  - "Regular with a category selected: neither branch applies."
  - "Going back to regular picks the last item of the browse path."
solution: |
  ```output
  category("Breads")
  category("Soups")
  browse 1
  ```

  Already regular with a category selected, the first `adapt` does nothing. Compact moves Breads into Browse (`browsePath = [Breads]`), and the user then opens Soups, so the path is `[Breads, Soups]`. Back to regular, the selection becomes the last thing they were looking at, Soups, not Breads. Compact again replaces the browse path with just `[Soups]`, so the count is 1: the Breads level is lost, which is a choice Apple's example makes too (it assigns `browseTabPath = [selection]`).
````

````exercise
id: m35-l04-e3
type: comprehension
prompt: "A sheet for adding an event has Cancel and Add buttons. Which toolbar code fits best?"
choices:
  - text: "ToolbarItem(placement: .cancellationAction) for Cancel and ToolbarItem(placement: .confirmationAction) for Add."
    correct: true
    why: "Apple places cancellation on the leading edge and confirmation on the trailing edge on iOS, and the placements describe what the buttons do on every platform."
  - text: "ToolbarItem(placement: .navigationBarLeading) and ToolbarItem(placement: .navigationBarTrailing)."
    correct: false
    why: "Apple's current documentation marks navigationBarTrailing deprecated in favor of topBarTrailing, and neither says what the button means."
  - text: "Both in a ToolbarItemGroup(placement: .bottomBar)."
    correct: false
    why: "Apple's example uses confirmationAction for an Add button in a modal; a sheet's primary decision belongs in the top bar."
  - text: "Put them in the Form as the last row."
    correct: false
    why: "It works, but scrolls away with the content and doesn't follow the platform's convention."
solution: |
  **`.cancellationAction` and `.confirmationAction`.** Apple's description of `confirmationAction` uses this exact case: "An example of a confirmation action would be an action with the label 'Add' to add a new event to the calendar." On iOS cancellation goes "on the leading edge of the navigation bar" and confirmation where `primaryAction` goes, the trailing edge. On macOS the same code puts them at the bottom right of the sheet, which is why semantic placements are worth using even in an iPhone-only app.
````

````exercise
id: m35-l04-e4
type: fill-in
prompt: "Complete the iOS 17 fallback branch so the tab view can be switched from code and the Inbox tab shows an unread count."
code: |
  TabView(selection: $selection) {
      InboxView()
          .[[1]] { Label("Inbox", systemImage: "tray") }
          .[[2]](MailTab.inbox)
          .[[3]](unreadCount)
      SettingsView()
          .tabItem { Label("Settings", systemImage: "gear") }
          .tag(MailTab.settings)
  }
blanks:
  - id: "1"
    answers: ["tabItem"]
  - id: "2"
    answers: ["tag"]
  - id: "3"
    answers: ["badge"]
hints:
  - "The pre-iOS 18 modifier that sets a tab's label."
  - "The selection binding is compared against this value."
solution: |
  ```swift ios
  import SwiftUI

  enum MailTab: Hashable {
      case inbox, settings
  }

  struct InboxView: View {
      var body: some View { Text("Inbox") }
  }

  struct SettingsView: View {
      var body: some View { Text("Settings") }
  }

  struct MailRoot: View {
      @State private var selection = MailTab.inbox
      let unreadCount = 4

      var body: some View {
          TabView(selection: $selection) {
              InboxView()
                  .tabItem { Label("Inbox", systemImage: "tray") }
                  .tag(MailTab.inbox)
                  .badge(unreadCount)
              SettingsView()
                  .tabItem { Label("Settings", systemImage: "gear") }
                  .tag(MailTab.settings)
          }
      }
  }
  ```

  `tabItem` sets the label, `tag` gives the tab the value the selection binding compares against, and `badge` (iOS 15 on views) shows the count. On iOS 18 the same tab would be `Tab("Inbox", systemImage: "tray", value: MailTab.inbox) { InboxView() }.badge(unreadCount)`.
````

````exercise
id: m35-l04-e5
type: find-errors
prompt: "This root view is for an app with an iOS 17 deployment target that runs on iPhone and iPad. Which of these are real problems?"
code: |
  struct AppRoot: View {
      @State private var selection = 0

      var body: some View {
          NavigationStack {
              TabView(selection: $selection) {
                  FeedView()
                      .tabItem { Label("Feed", systemImage: "newspaper") }
                  ProfileView()
                      .tabItem { Label("Profile", systemImage: "person") }
              }
              .toolbar {
                  ToolbarItem(placement: .navigationBarTrailing) {
                      Button("Compose") {}
                  }
              }
          }
      }
  }
choices:
  - text: "The TabView is inside one NavigationStack, so pushes cover the tab bar and all tabs share one path."
    correct: true
    why: "Each tab should have its own NavigationStack inside it."
  - text: "The tabs have no tag, so selection can't switch them from code."
    correct: true
    why: "Add .tag(0) and .tag(1), or better, an enum of tabs."
  - text: "navigationBarTrailing is marked deprecated; use topBarTrailing (or primaryAction)."
    correct: true
    why: "Apple's current documentation says \"use topBarTrailing instead.\""
  - text: "tabItem doesn't compile with an iOS 17 deployment target."
    correct: false
    why: "tabItem is iOS 13. It's the Tab API that needs iOS 18."
  - text: "A TabView can't have more than one tab on iPad."
    correct: false
    why: "Tab views work on iPad; from iOS 18 they can also become a sidebar."
rubric:
  - Flags the stack around the TabView.
  - Flags the missing tags.
  - Flags the deprecated placement.
  - Doesn't claim tabItem is unavailable on iOS 17.
solution: |
  ```swift ios
  import SwiftUI

  enum RootTab: Hashable {
      case feed, profile
  }

  struct FeedView: View {
      var body: some View {
          NavigationStack {
              Text("Feed")
                  .navigationTitle("Feed")
                  .toolbar {
                      ToolbarItem(placement: .primaryAction) {
                          Button("Compose", systemImage: "square.and.pencil") {}
                      }
                  }
          }
      }
  }

  struct ProfileView: View {
      var body: some View {
          NavigationStack {
              Text("Profile")
                  .navigationTitle("Profile")
          }
      }
  }

  struct AppRoot: View {
      @State private var selection = RootTab.feed

      var body: some View {
          TabView(selection: $selection) {
              FeedView()
                  .tabItem { Label("Feed", systemImage: "newspaper") }
                  .tag(RootTab.feed)
              ProfileView()
                  .tabItem { Label("Profile", systemImage: "person") }
                  .tag(RootTab.profile)
          }
      }
  }
  ```

  Each tab owns its stack and its toolbar, so Compose only appears in the Feed tab, where it belongs. The tags make `selection` work, and an enum instead of `0` and `1` lets deep links (lesson 5) name tabs.
````

````exercise
id: m35-l04-e6
type: solve
prompt: |
  A photo app's iPad layout has tabs Library, Albums, Search and one tab per album (`album(String)`), which only exist in regular width. In compact width the albums live inside the Albums tab, which has a path of album values.

  Write `mutating func adapt(to sizeClass: SizeClass)` on `PhotoTabs`:

  - Compact with an album tab selected: the albums path becomes that album, and the selection becomes `.albums`.
  - Regular with `.albums` selected: the selection becomes the last album in the path; if the path is empty, it stays `.albums` (in regular width, Albums still exists as an overview tab).
  - Anything else: no change.

  Then run the sequence in the starter and print the selection after each step.
starter: |
  enum PhotoTab: Hashable {
      case library, albums, search
      case album(String)
  }

  enum SizeClass {
      case compact, regular
  }

  struct PhotoTabs {
      var selection: PhotoTab
      var albumsPath: [String] = []

      mutating func adapt(to sizeClass: SizeClass) {
          // your code
      }
  }

  var tabs = PhotoTabs(selection: .album("Trips"))
  tabs.adapt(to: .compact)
  print(tabs.selection, tabs.albumsPath)
  tabs.adapt(to: .regular)
  print(tabs.selection)
  tabs.selection = .albums
  tabs.albumsPath = []
  tabs.adapt(to: .regular)
  print(tabs.selection)
  tabs.selection = .search
  tabs.adapt(to: .compact)
  print(tabs.selection)
hints:
  - "if case .album(let name) = selection { … } extracts the album name."
  - "albumsPath.last.map { .album($0) } ?? .albums"
rubric:
  - Moves an album selection into the Albums tab's path in compact width.
  - Restores the last album in regular width, or keeps .albums when the path is empty.
  - Leaves other tabs alone.
  - Prints the four expected lines.
solution: |
  ```swift
  enum PhotoTab: Hashable {
      case library, albums, search
      case album(String)
  }

  enum SizeClass {
      case compact, regular
  }

  struct PhotoTabs {
      var selection: PhotoTab
      var albumsPath: [String] = []

      mutating func adapt(to sizeClass: SizeClass) {
          switch sizeClass {
          case .compact:
              if case .album(let name) = selection {
                  albumsPath = [name]
                  selection = .albums
              }
          case .regular:
              if selection == .albums, let last = albumsPath.last {
                  selection = .album(last)
              }
          }
      }
  }

  var tabs = PhotoTabs(selection: .album("Trips"))
  tabs.adapt(to: .compact)
  print(tabs.selection, tabs.albumsPath)
  tabs.adapt(to: .regular)
  print(tabs.selection)
  tabs.selection = .albums
  tabs.albumsPath = []
  tabs.adapt(to: .regular)
  print(tabs.selection)
  tabs.selection = .search
  tabs.adapt(to: .compact)
  print(tabs.selection)
  ```

  ```output
  albums ["Trips"]
  album("Trips")
  albums
  search
  ```

  `if case .album(let name) = selection` matches only album tabs and binds the name. In regular width, `.albums` with an empty path stays as is, because unlike the lesson's Browse tab, Albums exists in both layouts. Search is in both layouts, so neither branch touches it. In SwiftUI, this method would run from `.onChange(of: horizontalSizeClass, initial: true)`, as in Apple's example.
````

## Summary

- `TabView(selection:)` switches sections. On iOS 18 declare `Tab(title, systemImage:, value:)` (with roles, `TabSection` and `.sidebarAdaptable`); on iOS 17 use `.tabItem` and `.tag`. With an iOS 17 target, wrap the new form in `if #available(iOS 18, *)`.
- Put a `NavigationStack` inside each tab, never a stack around the tab view.
- `toolbar` with `ToolbarItem(placement:)`: semantic placements (`primaryAction`, `confirmationAction`, `cancellationAction`) for meaning, positional ones (`topBarLeading`, `topBarTrailing`, `bottomBar`, `keyboard`) for position. `navigationBarTrailing` is marked deprecated.
- `NavigationSplitView` shows two or three columns driven by `List` selection. In compact width it collapses into a stack ending at the last column with something selected.
- Adapt with the split view's own collapsing, `preferredCompactColumn` (iOS 17), and `horizontalSizeClass` for everything else. When the set of tabs differs by size class, move the selection between layouts so the user stays on the same content.
