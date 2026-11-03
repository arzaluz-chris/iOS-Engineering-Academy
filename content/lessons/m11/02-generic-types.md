---
id: m11-l02
title: Generic types
description: You build a generic Stack<Element>, create instances with inferred and explicit type arguments, extend a generic type, write generic enums and methods with their own type parameters, and recognize Array, Dictionary, Optional and Set as generic types you've used since Module 7.
module: m11
order: 2
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m11-l01]
objectives:
  - Declare a generic struct and a generic enum with type parameters.
  - Create instances with an inferred type argument and with an explicit one, and explain when Swift needs the explicit one.
  - Explain why Stack<Int> and Stack<String> are different, unrelated types.
  - Extend a generic type and use its type parameter in the extension without redeclaring it.
  - Write a method with its own type parameter inside a generic type.
  - "Read [Int], [String: Int] and Int? as Array<Int>, Dictionary<String, Int> and Optional<Int>."
terms:
  - term: Generic type
    definition: "A struct, enum or class with type parameters, like struct Stack<Element>. Its stored properties and methods can use Element as a type."
  - term: Type argument
    definition: "The concrete type that fills a type parameter, like Int in Stack<Int>. It's written explicitly or inferred from an initializer's arguments."
  - term: Specialization (of a generic type)
    definition: "A generic type with its parameters filled in, like Stack<Int>. Different specializations are different types: a Stack<Int> can't be assigned to a Stack<String>."
  - term: Type sugar
    definition: "A shorter spelling for a generic type: [T] for Array<T>, [K: V] for Dictionary<K, V>, T? for Optional<T>."
mastery:
  - Write a generic Stack<Element> with push, pop and a computed top, and use it with two element types.
  - "Fix \"generic parameter 'Element' could not be inferred\" by writing Stack<Int>() or annotating the variable."
  - Add a computed property to a generic type in an extension that uses Element.
  - Write a generic enum with an associated value of the type parameter.
  - Translate between the sugared and the full spelling of Array, Dictionary and Optional.
resources: [swift-book-generics, swift-book-collection-types, swift-book-extensions]
cards:
  - id: m11-l02-c1
    front: "How do you create an empty Stack<Element> of Ints?"
    back: "Stack<Int>() or var stack: Stack<Int> = Stack(). Stack() alone fails with \"generic parameter 'Element' could not be inferred\"."
  - id: m11-l02-c2
    front: "Can you assign a Stack<String> to a variable of type Stack<Int>?"
    back: "No. Each specialization is its own type, as unrelated as Int and String."
  - id: m11-l02-c3
    front: "In extension Stack { … }, how do you refer to the element type?"
    back: "Element, the name from the original declaration. Don't redeclare it: extension Stack<T> fails with \"cannot find type 'T' in scope\"."
  - id: m11-l02-c4
    front: "What are [Int], [String: Int] and Int? really?"
    back: "Array<Int>, Dictionary<String, Int> and Optional<Int>: generic types from the standard library, written with sugar."
---

## The idea in one sentence

A **generic type** is a struct, enum or class with a type parameter, like `Stack<Element>`, so one definition gives you a stack of `Int`s, a stack of `String`s and a stack of your own screens, each fully type-checked.

## A stack, first for Int

A stack is last in, first out: you push onto the top and pop from the top, like a pile of plates. Navigation in an iOS app works this way: each screen you open is pushed, and Back pops it.

```swift
struct IntStack {
    private(set) var items: [Int] = []

    mutating func push(_ item: Int) {
        items.append(item)
    }

    mutating func pop() -> Int? {
        items.popLast()
    }
}

var numbers = IntStack()
numbers.push(1)
numbers.push(2)
print(numbers.pop() ?? -1)
print(numbers.items)
```

```output
2
[1]
```

`popLast()` removes and returns the last element, or `nil` when the array is empty, which is exactly what `pop` needs. Now you need a stack of screen names. Copying `IntStack` into `StringStack` is the same duplication problem from lesson 1, only bigger, because now it's a whole type.

## Stack<Element>

```swift
struct Stack<Element> {
    private(set) var items: [Element] = []

    var isEmpty: Bool {
        items.isEmpty
    }

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element? {
        items.popLast()
    }
}

var screens = Stack<String>()
screens.push("Home")
screens.push("Settings")
screens.push("Privacy")
print(screens.pop() ?? "none")
print(screens.items)

var undo = Stack(items: [10, 20])
undo.push(30)
print(undo.items, undo.isEmpty)
```

```output
Privacy
["Home", "Settings"]
[10, 20, 30] false
```

Line by line:

1. `struct Stack<Element>` declares a type parameter after the type's name, just like a generic function declares one after its name.
2. Inside the type, `Element` is used like any type: the array is `[Element]`, `push` takes an `Element`, `pop` returns `Element?`.
3. `Stack<String>()` creates a stack and states the **type argument** explicitly. For this instance, every `Element` means `String`.
4. `Stack(items: [10, 20])` uses the memberwise initializer. Swift sees an `[Int]` and infers `Element` as `Int`, so `undo` is a `Stack<Int>`.

`Element` is the name the standard library uses for "the thing a collection holds", so it's a good choice here. A single `T` would work, but `Stack<Element>` tells the reader what the parameter is for.

### When Swift can't infer the type argument

An empty stack gives Swift nothing to go on:

```swift no-compile generic parameter 'Element' could not be inferred
struct Stack<Element> {
    var items: [Element] = []
}

let stack = Stack()
```

Swift 6.3: `error: generic parameter 'Element' could not be inferred`, with a note: "explicitly specify the generic arguments to fix this issue". Either way works:

```swift
struct Stack<Element> {
    var items: [Element] = []
}

let first = Stack<Double>()
let second: Stack<Bool> = Stack()
print(first)
print(second)
```

```output
Stack<Double>(items: [])
Stack<Bool>(items: [])
```

Unlike a generic function, a generic type **can** be written with explicit angle brackets: `Stack<Double>()` is how you name a specialization.

### Stack<Int> and Stack<String> are different types

Once the type argument is fixed, it's part of the type. A `Stack<Int>` variable can never hold a `Stack<String>`:

```swift no-compile cannot assign value of type 'Stack<String>' to type 'Stack<Int>'
struct Stack<Element> {
    var items: [Element] = []
}

var stack = Stack<Int>()
stack = Stack<String>()
```

That's the same rule you already know from arrays: `[Int]` and `[String]` are different types, and you can't assign one to the other.

## Extending a generic type

An extension of a generic type can use its type parameter by the original name. You don't redeclare it:

```swift
struct Stack<Element> {
    private(set) var items: [Element] = []

    mutating func push(_ item: Element) {
        items.append(item)
    }
}

extension Stack {
    var top: Element? {
        items.last
    }

    var count: Int {
        items.count
    }
}

var history = Stack<String>()
history.push("swift.org")
history.push("developer.apple.com")
print(history.top ?? "empty")
print(history.count)
print(Stack<Int>().top ?? -1)
```

```output
developer.apple.com
2
-1
```

`top` returns `Element?`, which is `String?` for `history` and `Int?` for the empty `Stack<Int>`. If you try to rename the parameter in the extension, as `extension Stack<T>`, Swift 6.3 says `error: cannot find type 'T' in scope`: inside the angle brackets of an extension, Swift expects a real type, not a new name.

That real-type form does exist. `extension Stack<Int> { … }` (Swift 5.7, SE-0361) adds members only to stacks of `Int`. Lesson 3 covers that and the more general `where` form.

## Methods with their own type parameters

A method inside a generic type can declare an extra type parameter of its own. Here's `map` for the stack: it turns a `Stack<Element>` into a stack of something else.

```swift
struct Stack<Element> {
    private(set) var items: [Element] = []

    mutating func push(_ item: Element) {
        items.append(item)
    }

    func map<NewElement>(_ transform: (Element) -> NewElement) -> Stack<NewElement> {
        var result = Stack<NewElement>()
        for item in items {
            result.push(transform(item))
        }
        return result
    }
}

var prices = Stack<Int>()
prices.push(250)
prices.push(1200)

let dollars = prices.map { cents in Double(cents) / 100 }
let labels = prices.map { cents in "\(cents) cents" }
print(dollars.items)
print(labels.items)
print(type(of: dollars), type(of: labels))
```

```output
[2.5, 12.0]
["250 cents", "1200 cents"]
Stack<Double> Stack<String>
```

- `Element` comes from the type; it's already fixed to `Int` for `prices`.
- `NewElement` belongs to the method. Each call infers it from what the closure returns: `Double` in the first call, `String` in the second.
- The result is a new `Stack` with a different type argument. `prices` is untouched.

This is the shape of `Array`'s own `map`. Its real declaration adds error handling you'll meet in Module 12: `func map<T, E>(_ transform: (Element) throws(E) -> T) throws(E) -> [T] where E : Error`. Strip the `throws` parts and it's the method above.

## Generic enums

Enums take type parameters too. In Module 9 you modeled a screen's loading state. Every screen loads something different: a profile, a list of orders, an image. A generic enum covers them all:

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)
}

struct Profile {
    let name: String
}

func describe<Value>(_ state: LoadState<Value>) -> String {
    switch state {
    case .idle:
        return "Not started"
    case .loading:
        return "Loading…"
    case .loaded(let value):
        return "Loaded: \(value)"
    case .failed(let message):
        return "Error: \(message)"
    }
}

let profile: LoadState<Profile> = .loaded(Profile(name: "Ana"))
let orders: LoadState<[Int]> = .loaded([1042, 1043])
let image: LoadState<String> = .failed(message: "timeout")
print(describe(profile))
print(describe(orders))
print(describe(image))
print(describe(LoadState<Int>.loading))
```

```output
Loaded: Profile(name: "Ana")
Loaded: [1042, 1043]
Error: timeout
Loading…
```

`describe` is a generic function that takes a generic type: whatever `Value` the state carries, the function handles it. Classes work the same way (`final class Cache<Value>`); the syntax is identical.

## You've been using generic types since Module 7

`Array`, `Dictionary`, `Set` and `Optional` are generic types from the standard library. The short spellings you've been writing are **sugar** for them:

| You write | It means | Declared as (simplified) |
| --- | --- | --- |
| `[Int]` | `Array<Int>` | `struct Array<Element>` |
| `[String: Int]` | `Dictionary<String, Int>` | `struct Dictionary<Key, Value> where Key: Hashable` |
| `Set<Int>` | `Set<Int>` (no sugar) | `struct Set<Element> where Element: Hashable` |
| `Int?` | `Optional<Int>` | `enum Optional<Wrapped>` |

```swift
let scores: Array<Int> = [90, 85]
let ages: Dictionary<String, Int> = ["Ana": 31]
let nickname: Optional<String> = .none
let lucky: Int? = Optional.some(7)

print(type(of: [1, 2]), type(of: ["a": 1]), type(of: lucky))
print(scores.count, ages["Ana"] ?? 0, nickname ?? "none", lucky ?? 0)
```

```output
Array<Int> Dictionary<String, Int> Optional<Int>
2 31 none 7
```

This explains things you've accepted on faith:

- `Optional` is an enum with cases `.some(Wrapped)` and `.none` (Module 8). Now you can read `Wrapped` as its type parameter.
- `Dictionary` has two type parameters, and the `where Key: Hashable` part is why dictionary keys must be hashable. That's a **constraint**, the subject of the next lesson.
- `first`, `last` and `popLast()` all return `Element?`, which is why their type changes with the array's.

The declarations in the table are simplified. The real `Optional`, for example, also says how it works with values that can't be copied, a feature you won't need in this course.

## A practical example: a recent-items list

Search screens keep the last few things you looked up, newest first, without duplicates. The logic is the same for search strings, product IDs or whole structs, as long as you can tell two items apart. For now, the caller passes that test as a closure:

```swift
struct RecentItems<Item> {
    let capacity: Int
    private(set) var items: [Item] = []

    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func add(_ item: Item, sameAs isSame: (Item, Item) -> Bool) {
        items.removeAll { existing in isSame(existing, item) }
        items.insert(item, at: 0)
        if items.count > capacity {
            items.removeLast()
        }
    }
}

var searches = RecentItems<String>(capacity: 3)
for term in ["swift", "generics", "closures", "swift", "enums"] {
    searches.add(term) { a, b in a == b }
}
print(searches.items)

struct Product {
    let id: Int
    let name: String
}

var viewed = RecentItems<Product>(capacity: 2)
viewed.add(Product(id: 1, name: "Mug")) { a, b in a.id == b.id }
viewed.add(Product(id: 2, name: "Lamp")) { a, b in a.id == b.id }
viewed.add(Product(id: 1, name: "Mug")) { a, b in a.id == b.id }
print(viewed.items.map { product in product.name })
```

```output
["enums", "swift", "closures"]
["Mug", "Lamp"]
```

- `removeAll(where:)` removes every element the closure says yes to. Here it drops any existing copy, so a repeated search moves to the front instead of appearing twice.
- `insert(item, at: 0)` puts the newest first; `removeLast()` trims past the capacity.
- Passing `sameAs` on every call is clumsy. Both types here could just use `==`, and lesson 3 will let you require that with `Item: Equatable` and delete the closure.

## Common mistakes

> [!error] error: generic parameter 'Element' could not be inferred
> You created an instance without anything that tells Swift the type argument, usually an empty initializer. Write `Stack<Int>()` or annotate: `let stack: Stack<Int> = Stack()`.

> [!error] error: cannot assign value of type 'Stack<String>' to type 'Stack<Int>'
> Two specializations of a generic type are different types. Pick the right one when you declare the variable.

> [!error] error: cannot find type 'T' in scope
> You wrote `extension Stack<T>` to "get" the type parameter in an extension. It's already there under its original name: write `extension Stack` and use `Element`.

> [!error] Writing a type parameter where a concrete type belongs
> `var history: Stack<Element>` outside of any generic context doesn't compile ("cannot find type 'Element' in scope"). Outside the type, you always name a concrete specialization: `Stack<String>`.

````exercise
id: m11-l02-e1
type: comprehension
prompt: "What's the full, unsugared type of `let lookup: [String: [Int]]?`"
choices:
  - text: "Optional<Dictionary<String, Array<Int>>>"
    correct: true
    why: "The ? applies to the whole dictionary type, [K: V] is Dictionary<K, V>, and [Int] is Array<Int>."
  - text: "Dictionary<String, Optional<Array<Int>>>"
    correct: false
    why: "That would be [String: [Int]?]. Here the ? comes after the closing bracket, so the whole dictionary is optional."
  - text: "Dictionary<Optional<String>, Array<Int>>"
    correct: false
    why: "Nothing makes the key optional."
  - text: "Array<Dictionary<String, Int>>?"
    correct: false
    why: "That's [[String: Int]]?, an optional array of dictionaries."
solution: |
  **`Optional<Dictionary<String, Array<Int>>>`.** Read the sugar from the outside in: `…?` is `Optional<…>`, `[String: …]` is `Dictionary<String, …>`, and `[Int]` is `Array<Int>`. The sugared spelling is what you should write; the full spelling is what the compiler means, and it's what shows up in some error messages.
````

````exercise
id: m11-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Stack<Element> {
      private(set) var items: [Element] = []

      mutating func push(_ item: Element) {
          items.append(item)
      }

      mutating func pop() -> Element? {
          items.popLast()
      }
  }

  extension Stack {
      var top: Element? {
          items.last
      }
  }

  var plates = Stack<Int>()
  plates.push(1)
  plates.push(2)
  let copy = plates
  plates.push(3)
  print(plates.pop() ?? 0, plates.pop() ?? 0)
  print(copy.top ?? 0, copy.items.count)

  var words = Stack(items: ["a"])
  _ = words.pop()
  print(words.pop() ?? "empty", words.top ?? "none")
output: |
  3 2
  2 2
  empty none
hints:
  - "Stack is a struct. What happens to copy when plates changes?"
  - "pop() on an empty stack returns nil, and so does top."
solution: |
  ```output
  3 2
  2 2
  empty none
  ```

  1. `plates` gets 1 and 2. `let copy = plates` copies the struct, array included, because `Stack` is a value type (Module 9). Pushing 3 only changes `plates`.
  2. Two pops return 3, then 2.
  3. `copy` still holds `[1, 2]`: its top is 2 and it has two items.
  4. `words` starts as `["a"]` (Swift infers `Element` as `String`). The first pop removes `"a"`; the second returns `nil`, and so does `top`.

  Making a type generic doesn't change whether it's a value or a reference. A generic struct is still copied on assignment.
````

````exercise
id: m11-l02-e3
type: fill-in
prompt: |
  Complete the extension so every `Stack` gets a `peek(depth:)` method that returns the element `depth` places below the top (0 is the top itself), or `nil` if the stack isn't that deep.
code: |
  struct Stack<Element> {
      var items: [Element] = []
  }

  extension [[1]] {
      func peek(depth: Int) -> [[2]] {
          let index = items.count - 1 - depth
          guard index >= 0 else {
              return nil
          }
          return items[index]
      }
  }

  let stack = Stack(items: ["a", "b", "c"])
  print(stack.peek(depth: 0) ?? "-", stack.peek(depth: 2) ?? "-", stack.peek(depth: 3) ?? "-")
blanks:
  - id: "1"
    answers: ["Stack"]
  - id: "2"
    answers: ["Element?", "Optional<Element>"]
solution: |
  ```swift
  struct Stack<Element> {
      var items: [Element] = []
  }

  extension Stack {
      func peek(depth: Int) -> Element? {
          let index = items.count - 1 - depth
          guard index >= 0 else {
              return nil
          }
          return items[index]
      }
  }

  let stack = Stack(items: ["a", "b", "c"])
  print(stack.peek(depth: 0) ?? "-", stack.peek(depth: 2) ?? "-", stack.peek(depth: 3) ?? "-")
  ```

  ```output
  c a -
  ```

  The extension names the type without angle brackets, and `Element` is available inside it with the meaning it has in the original declaration. The return type is `Element?` because asking for a depth the stack doesn't have isn't an error, just "no answer". For depth 3 on a three-item stack, the index is -1 and the guard returns `nil`. (The method doesn't check for a negative depth; `peek(depth: -1)` would read past the end and crash.)
````

````exercise
id: m11-l02-e4
type: find-errors
prompt: Pick out the real problems in this code.
code: |
  struct Box<Content> {
      var content: Content
  }

  extension Box<Content> {
      var description: String {
          "Box with \(content)"
      }
  }

  var box = Box(content: 5)
  box = Box(content: "five")

  let empty = Box()
  var label: Box<Element> = Box(content: "x")
choices:
  - text: "extension Box<Content> tries to redeclare the type parameter."
    correct: true
    why: "Inside an extension's angle brackets Swift expects a real type, so Content isn't found. Write extension Box."
  - text: "box is a Box<Int>, so it can't be assigned a Box<String>."
    correct: true
    why: "Each specialization is its own type."
  - text: "Box() has no content to infer Content from, and no initializer without arguments exists."
    correct: true
    why: "The memberwise initializer needs content. There's nothing to create or infer from."
  - text: "Box<Element> uses a type parameter name outside any generic context."
    correct: true
    why: "Outside the type, write a concrete type argument: Box<String>."
  - text: "Box(content: 5) needs to be written Box<Int>(content: 5)."
    correct: false
    why: "Swift infers Content as Int from the argument. The explicit form is allowed but not required."
rubric:
  - Flags the extension's redeclared parameter.
  - Flags the Box<Int> to Box<String> assignment.
  - Flags Box() and Box<Element>.
  - "Doesn't flag Box(content: 5)."
solution: |
  Four problems, one distractor.

  ```swift
  struct Box<Content> {
      var content: Content
  }

  extension Box {
      var description: String {
          "Box with \(content)"
      }
  }

  var box = Box(content: 5)
  box = Box(content: 6)

  var label: Box<String> = Box(content: "x")
  label.content += "!"
  print(box.description)
  print(label.description)
  ```

  ```output
  Box with 6
  Box with x!
  ```

  The pattern behind all four: **inside** the generic type and its extensions, use the parameter name (`Content`). **Outside**, name a concrete specialization (`Box<Int>`, `Box<String>`) or let Swift infer one from real arguments.
````

````exercise
id: m11-l02-e5
type: solve
prompt: |
  Write a generic `struct Queue<Element>`: first in, first out, like a line at a coffee shop. It needs:

  - `mutating func enqueue(_ element: Element)` that adds at the back,
  - `mutating func dequeue() -> Element?` that removes from the front, or returns `nil` when empty,
  - a computed `var count: Int`.

  Then make this print the output below:

  ```swift
  var orders = Queue<String>()
  orders.enqueue("latte")
  orders.enqueue("mocha")
  orders.enqueue("tea")
  print(orders.dequeue() ?? "none", orders.count)

  var tickets = Queue<Int>()
  print(tickets.dequeue() ?? -1)
  tickets.enqueue(42)
  print(tickets.dequeue() ?? -1, tickets.count)
  ```

  ```output
  latte 2
  -1
  42 0
  ```
starter: |
  struct Queue<Element> {
      // your code
  }
hints:
  - "Store the elements in a private(set) var items: [Element]."
  - "dequeue: guard the array isn't empty, then return items.removeFirst()."
rubric:
  - Queue is generic over Element and used with String and Int.
  - dequeue returns Element? and doesn't crash when empty.
  - enqueue and dequeue are mutating.
  - The output matches exactly.
solution: |
  ```swift
  struct Queue<Element> {
      private(set) var items: [Element] = []

      var count: Int {
          items.count
      }

      mutating func enqueue(_ element: Element) {
          items.append(element)
      }

      mutating func dequeue() -> Element? {
          guard !items.isEmpty else {
              return nil
          }
          return items.removeFirst()
      }
  }

  var orders = Queue<String>()
  orders.enqueue("latte")
  orders.enqueue("mocha")
  orders.enqueue("tea")
  print(orders.dequeue() ?? "none", orders.count)

  var tickets = Queue<Int>()
  print(tickets.dequeue() ?? -1)
  tickets.enqueue(42)
  print(tickets.dequeue() ?? -1, tickets.count)
  ```

  ```output
  latte 2
  -1
  42 0
  ```

  `removeFirst()` crashes on an empty array, so the `guard` turns that case into `nil`. `Queue<Int>()` names the type argument because an empty queue gives Swift nothing to infer from.

  One honest caveat: `removeFirst()` shifts every remaining element left, so `dequeue` gets slower as the queue grows. For a few dozen orders it doesn't matter. A queue that holds thousands of items would keep a "head" index instead and move it forward; you'll measure costs like this in Module 15 (Algorithmic Complexity).
````

````exercise
id: m11-l02-e6
type: design
prompt: |
  For each type, say whether it should be generic, and if so, what its type parameter(s) would be called and stand for:

  1. `Temperature`, which stores degrees in Celsius and converts to Fahrenheit.
  2. `Paginated`, which an API client returns for any list endpoint: the items on this page, the page number and whether there's a next page.
  3. `Cache`, which stores values by key and evicts old entries.
  4. `Result` of a form validation: either a valid value of the form's type or a list of error messages.
rubric:
  - "1: not generic; it always holds a Double of degrees."
  - "2: generic over the item type, e.g. Paginated<Item>."
  - "3: generic over key and value, with the key hashable."
  - "4: generic over the valid value's type, e.g. an enum with valid(Value) and invalid([String])."
solution: |
  1. **Not generic.** A temperature is always a number of degrees. Making it `Temperature<T>` would add a parameter that no caller ever varies. Generics answer "the logic is the same for different types"; if there's only one type, skip them.
  2. **`Paginated<Item>`**, with `let items: [Item]`, `let page: Int`, `let hasNext: Bool`. The page metadata is the same for users, orders or photos; only the item type changes.
  3. **`Cache<Key, Value>`**, two independent parameters, like `Dictionary`. The key has to be `Hashable` if you store entries in a dictionary, which is the constraint from the next lesson.
  4. **`enum Validation<Value> { case valid(Value); case invalid([String]) }`.** One type parameter for the success value. The error side is always messages, so it stays concrete. (The standard library has a `Result<Success, Failure>` type with two parameters; you'll use it in Module 12.)

  The test: what part of the type's data varies **by use site** while the logic stays the same? That part becomes the type parameter.
````

## Summary

- A generic type declares type parameters after its name: `struct Stack<Element>`. Inside it, `Element` is used like any type.
- Create instances with an explicit type argument (`Stack<Int>()`) or let Swift infer it from initializer arguments. Empty initializers usually need the explicit form.
- Each specialization is its own type: `Stack<Int>` and `Stack<String>` are unrelated.
- Extensions use the original parameter name (`extension Stack { … Element … }`) without redeclaring it.
- Methods can add their own type parameters, like `map<NewElement>`.
- Enums and classes can be generic too: `enum LoadState<Value>`.
- `[T]`, `[K: V]` and `T?` are sugar for `Array<T>`, `Dictionary<K, V>` and `Optional<T>`, generic types from the standard library.
