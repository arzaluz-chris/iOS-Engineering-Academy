---
id: m10-l02
title: Inheritance, overriding and polymorphism
description: You build a subclass that inherits from a base class, replace behavior with override, reuse the original with super, lock things down with final, write designated and convenience initializers that follow two-phase initialization, and see how one call on a base-class reference runs the right subclass method.
module: m10
order: 2
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m10-l01]
objectives:
  - Declare a subclass and use the properties and methods it inherits.
  - Override a method or computed property with override, and call the superclass version with super.
  - Use final to prevent overriding or subclassing, and say what it allows the compiler to do.
  - Write a subclass designated initializer in the right order, and a convenience initializer that delegates to it.
  - Call methods through a base-class reference and predict which implementation runs.
  - Check and convert an instance's real type with is and as?.
terms:
  - term: Subclass
    definition: "A class that inherits the properties and methods of another class, its superclass, and can add to them or replace them. Written class Dog: Animal."
  - term: override
    definition: "The keyword that marks a subclass member replacing one it inherited. Required, so you can't replace something by accident or claim to replace something that doesn't exist."
  - term: super
    definition: "Inside a subclass, a way to reach the superclass's version of a method, property or initializer: super.describe(), super.init(…)."
  - term: final
    definition: "Marks a class that can't be subclassed, or a member that can't be overridden. It also lets the compiler call that code directly instead of looking it up at run time."
  - term: Designated initializer
    definition: "A class's main initializer. It sets every stored property the class introduces and then calls a designated initializer of its superclass."
  - term: Convenience initializer
    definition: "A secondary initializer, marked convenience, that must call another initializer of the same class (self.init) instead of setting properties itself."
  - term: Two-phase initialization
    definition: "Swift's rule for class initializers. Phase 1: every stored property, from the subclass up to the base class, gets a value. Phase 2: only then can the initializer use self, call methods, or change inherited properties."
  - term: Polymorphism
    definition: "Using values of different types through one common type. A variable of type Shape can hold a Circle or a Square, and shape.area() runs the version that belongs to the actual instance."
  - term: Dynamic dispatch
    definition: "Choosing which implementation of a method to run at run time, based on the actual type of the instance. Non-final class methods are dispatched this way, through a table of method entries (a vtable)."
mastery:
  - Write a subclass that adds a stored property and overrides one method, calling super inside it.
  - Fix "property not initialized at super.init call" by reordering an initializer.
  - Add a convenience initializer that supplies a default and delegates with self.init.
  - Predict the output of a loop over [BaseClass] that calls an overridden method.
  - Explain why final can make calls cheaper, without overstating it.
  - Use as? to reach a subclass-only member from a base-class reference.
resources: [swift-book-inheritance, swift-book-initialization, swift-book-methods, swift-book-structures-classes]
cards:
  - id: m10-l02-c1
    front: What do override and super do?
    back: "override marks a subclass member that replaces an inherited one; the compiler requires it. super.name(…) calls the superclass's version from inside the subclass."
  - id: m10-l02-c2
    front: "In a subclass designated init, what's the order?"
    back: "1) Set every stored property the subclass adds. 2) Call super.init(…). 3) Only now use self: call methods, change inherited properties."
  - id: m10-l02-c3
    front: What must a convenience initializer do?
    back: "Call another initializer of the same class with self.init(…), which eventually reaches a designated one. It can't set stored properties before that."
  - id: m10-l02-c4
    front: "let shape: Shape = Circle(radius: 1). Which area() runs for shape.area()?"
    back: "Circle's, if Circle overrides it. Non-final class methods use dynamic dispatch: the actual instance decides, not the declared type."
  - id: m10-l02-c5
    front: What does final do?
    back: "final class can't be subclassed; a final method or property can't be overridden. Because nothing can replace it, the compiler can call it directly (static dispatch) instead of looking it up at run time."
---

## The idea in one sentence

A subclass starts with everything its superclass has, can add more, and can replace methods with `override`, and when you call a method through a superclass-typed reference, **the actual instance decides which version runs**.

## Subclassing

Structs can't inherit from anything. Classes can inherit from one other class:

```swift
class Vehicle {
    let wheels: Int
    var speed = 0

    init(wheels: Int) {
        self.wheels = wheels
    }

    func describe() -> String {
        "\(wheels) wheels at \(speed) km/h"
    }
}

class Bicycle: Vehicle {
    var hasBell = true

    init() {
        super.init(wheels: 2)
    }

    func ring() -> String {
        hasBell ? "Ring ring" : "..."
    }
}

let bike = Bicycle()
bike.speed = 18
print(bike.describe())
print(bike.ring())
```

```output
2 wheels at 18 km/h
Ring ring
```

1. `class Bicycle: Vehicle` makes `Bicycle` a **subclass** of `Vehicle`, its **superclass**. The colon reads "inherits from".
2. A `Bicycle` has everything a `Vehicle` has: `wheels`, `speed` and `describe()`. It adds `hasBell` and `ring()`.
3. `Bicycle`'s `init()` hands the superclass its part of the work with `super.init(wheels: 2)`. More on initializer order below.
4. `bike.describe()` runs the method `Bicycle` inherited, unchanged.

A class that doesn't inherit from anything is a **base class**. Unlike some languages, Swift has no universal root class every class inherits from.

## override and super

To replace an inherited method, write it again with `override`:

```swift
class Vehicle {
    var speed = 0

    func describe() -> String {
        "Moving at \(speed) km/h"
    }
}

class Bus: Vehicle {
    var passengers = 0

    override func describe() -> String {
        super.describe() + " with \(passengers) passengers"
    }
}

let bus = Bus()
bus.speed = 50
bus.passengers = 31
print(bus.describe())
```

```output
Moving at 50 km/h with 31 passengers
```

`override` tells the compiler "I mean to replace an inherited member". `super.describe()` calls the `Vehicle` version, so `Bus` extends the original text instead of rewriting it. You'll use `super` this way often: keep what the superclass does, then add to it.

The keyword is checked in both directions:

```swift no-compile overriding declaration requires an 'override' keyword
class Vehicle {
    func describe() -> String { "Vehicle" }
}

class Bus: Vehicle {
    func describe() -> String { "Bus" }
}
```

```swift no-compile method does not override any method from its superclass
class Vehicle {
    func describe() -> String { "Vehicle" }
}

class Bus: Vehicle {
    override func descripton() -> String { "Bus" }
}
```

The first is "you replaced something without saying so". The second catches a typo: `descripton` doesn't exist in `Vehicle`, so there's nothing to override. Without this check, the typo would silently add a new method and the old one would keep running.

You can override computed properties too. A stored property in the superclass can be overridden with a computed one, or given property observers (Module 9):

```swift
class Room {
    var name: String { "Room" }
    var temperature = 20
}

class ServerRoom: Room {
    override var name: String { "Server room" }
    override var temperature: Int {
        didSet {
            if temperature > 25 {
                print("\(name) too hot: \(temperature)")
            }
        }
    }
}

let room = ServerRoom()
room.temperature = 24
room.temperature = 27
```

```output
Server room too hot: 27
```

## final

`final` closes a door:

- `final class` means nobody can subclass it.
- `final func` (or `final var`) on a member means subclasses can't override that member.

```swift no-compile inheritance from a final class 'Receipt'
final class Receipt {
    let total = 0
}

class GiftReceipt: Receipt {}
```

```swift no-compile instance method overrides a 'final' instance method
class Account {
    final func audit() -> String { "Audited" }
}

class SavingsAccount: Account {
    override func audit() -> String { "Skipped" }
}
```

Two reasons to use it. First, design: a class that wasn't built to be subclassed, or a method whose behavior other code relies on, shouldn't be replaceable. Second, dispatch, which the next section explains. A good default for your own classes is `final class`, opened up only when you actually design for subclassing.

## Polymorphism and dynamic dispatch

A variable or array of the superclass type can hold instances of any subclass. Call a method on it, and each instance runs **its own** version:

```swift
class Shape {
    func area() -> Double {
        0
    }

    func name() -> String {
        "shape"
    }
}

class Rectangle: Shape {
    let width: Double
    let height: Double

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    override func area() -> Double {
        width * height
    }

    override func name() -> String {
        "rectangle"
    }
}

class Circle: Shape {
    let radius: Double

    init(radius: Double) {
        self.radius = radius
    }

    override func area() -> Double {
        3.14 * radius * radius
    }

    override func name() -> String {
        "circle"
    }
}

let shapes: [Shape] = [Rectangle(width: 3, height: 4), Circle(radius: 1), Shape()]
var total = 0.0
for shape in shapes {
    print("\(shape.name()): \(shape.area())")
    total += shape.area()
}
print("Total: \(total)")
```

```output
rectangle: 12.0
circle: 3.14
shape: 0.0
Total: 15.14
```

The array's type is `[Shape]`, and inside the loop `shape` has the type `Shape`. The compiler doesn't know which subclass each element is. Still, the rectangle runs `Rectangle.area()` and the circle runs `Circle.area()`. That's **polymorphism**: one piece of code, `shape.area()`, working with many types.

How does that work? Each class has a table of its overridable methods, the **vtable**. A `Circle` instance knows it's a `Circle`, and `Circle`'s table points `area` at `Circle`'s implementation. At run time, `shape.area()` looks up `area` in the table of the instance's actual class and jumps there. This is **dynamic dispatch**, and it's the default for methods and properties of a class that aren't `final`.

The cost is small but real: an indirect jump, and the compiler usually can't inline the method body into the caller, since it doesn't know which body will run. When a method is `final`, or the class is `final`, or the member is `private` (so no subclass elsewhere can see it), the compiler knows there's exactly one implementation and can call it directly: **static dispatch**. With whole-module optimization it can sometimes prove the same thing for an internal class that simply has no subclasses. A method called directly on a struct or enum value is statically dispatched too, because those types can't be subclassed. (Calls through a protocol are a different story, covered in lessons 3 and 4.)

Don't sprinkle `final` around for speed in code you haven't measured. Do use it for design, and know that the speed comes along.

> [!note] The declared type decides what you may call
> Dynamic dispatch picks *which version* of `area()` runs. The declared type decides *which members you can call at all*. Through a `Shape` reference you can't call `radius`, even when the instance is a `Circle`, because `Shape` has no `radius`.

### Checking the real type: is and as?

Sometimes you have a superclass reference and need something only a subclass has. `is` checks the type; `as?` tries to convert and gives back an optional (Module 8):

```swift
class Shape {}

class Circle: Shape {
    let radius: Double
    init(radius: Double) {
        self.radius = radius
    }
}

class Square: Shape {
    let side: Double
    init(side: Double) {
        self.side = side
    }
}

let shapes: [Shape] = [Circle(radius: 2), Square(side: 3), Circle(radius: 5)]

var circleCount = 0
for shape in shapes where shape is Circle {
    circleCount += 1
}
print("Circles: \(circleCount)")

for shape in shapes {
    if let circle = shape as? Circle {
        print("Circle with radius \(circle.radius)")
    } else if let square = shape as? Square {
        print("Square with side \(square.side)")
    }
}
```

```output
Circles: 2
Circle with radius 2.0
Square with side 3.0
Circle with radius 5.0
```

`shape as? Circle` produces a `Circle?`: the circle if the instance really is one, `nil` otherwise. Pair it with `if let`. There's also `as!`, which crashes when the cast fails, with the same warnings as force unwrapping in Module 8.

Use casts sparingly. A chain of `if let x = shape as? …` that grows every time someone adds a subclass is a sign the behavior belongs in an overridden method instead.

## Initializers in subclasses

Class initializers have stricter rules than struct ones, because a subclass instance is built in layers: the subclass's own properties and everything inherited.

### Designated initializers and two-phase initialization

Every class has at least one **designated initializer**, the main kind you've been writing. Swift's rule, called **two-phase initialization**:

- **Phase 1.** Each class sets its own stored properties, then hands off to its superclass with `super.init(…)`, which does the same, up to the base class. When the base class finishes, every stored property in the whole instance has a value.
- **Phase 2.** Back down the chain, each initializer can now use `self` freely: call methods, read properties, change inherited ones.

So in a subclass designated initializer, the order is: **your properties, then `super.init`, then anything else**.

```swift
class Employee {
    let name: String
    var salary: Int

    init(name: String, salary: Int) {
        self.name = name
        self.salary = salary
    }

    func summary() -> String {
        "\(name) earns \(salary)"
    }
}

class Manager: Employee {
    let teamSize: Int

    init(name: String, salary: Int, teamSize: Int) {
        self.teamSize = teamSize
        super.init(name: name, salary: salary)
        self.salary += teamSize * 100
        print("Created: \(summary())")
    }

    override func summary() -> String {
        super.summary() + " and leads \(teamSize)"
    }
}

let lead = Manager(name: "Ana", salary: 5000, teamSize: 4)
```

```output
Created: Ana earns 5400 and leads 4
```

1. Phase 1: `self.teamSize = teamSize` sets the property `Manager` adds.
2. `super.init(name:salary:)` lets `Employee` set its properties. Now the instance is complete.
3. Phase 2: changing the inherited `salary` and calling `summary()` are allowed.

Why the strictness? Look at `summary()`: `Manager`'s override reads `teamSize`. If `Employee.init` called `summary()` before `Manager` had set `teamSize`, dynamic dispatch would run `Manager`'s version and read a property with no value. Phase 1 makes that impossible.

Get the order wrong and the compiler tells you exactly what's missing:

```swift no-compile property 'self.teamSize' not initialized at super.init call
class Employee {
    let name: String
    init(name: String) {
        self.name = name
    }
}

class Manager: Employee {
    let teamSize: Int

    init(name: String, teamSize: Int) {
        super.init(name: name)
        self.teamSize = teamSize
    }
}
```

```swift no-compile 'self' used in method call 'describe' before 'super.init' call
class Employee {
    let name: String
    init(name: String) {
        self.name = name
    }
    func describe() -> String { name }
}

class Manager: Employee {
    let teamSize: Int

    init(name: String, teamSize: Int) {
        self.teamSize = teamSize
        print(describe())
        super.init(name: name)
    }
}
```

### Convenience initializers

A **convenience initializer** is a shortcut that fills in some arguments and passes the work to another initializer of the **same** class with `self.init(…)`:

```swift
class Employee {
    let name: String
    var salary: Int

    init(name: String, salary: Int) {
        self.name = name
        self.salary = salary
    }

    convenience init(intern name: String) {
        self.init(name: name, salary: 1500)
    }
}

let intern = Employee(intern: "Leo")
print(intern.name, intern.salary)
```

```output
Leo 1500
```

The two delegation rules, in short:

- A **designated** initializer delegates **up**: it calls `super.init`.
- A **convenience** initializer delegates **across**: it calls `self.init`, and the chain must end at a designated initializer of the same class.

A convenience initializer can't set stored properties itself before `self.init`: Swift 6.3 rejects that with "'let' property 'name' may not be initialized directly; use "self.init(...)" or "self = ..." instead".

Structs don't need the `convenience` keyword; any struct initializer can call `self.init`. It exists for classes because of the inheritance rules.

> [!note] Inherited initializers
> A subclass doesn't automatically get its superclass's initializers, because they wouldn't set the subclass's new properties. There's one simple case where it does: if the subclass adds no designated initializers of its own and gives every new stored property a default value, it inherits all of the superclass's designated initializers (and with them the convenience ones). The full rules are in the Swift book's Initialization chapter, linked below.

## The cost of inheritance

Inheritance ties a subclass tightly to its superclass. The subclass depends on the superclass's stored properties, its initializer order, and on which of its methods call which others. Change the superclass and every subclass may break, sometimes silently. And a class can have only one superclass, so a type that needs behavior from two places has nowhere to go.

UIKit uses inheritance heavily (`UIViewController`, `UIView`), and you'll subclass those all the time. For your own types, Swift leans on structs, protocols and composition, which the rest of this module covers. Lesson 6 comes back to this trade-off.

## Common mistakes

> [!error] error: overriding declaration requires an 'override' keyword
> You redeclared an inherited method. If you meant to replace it, add `override`. If you didn't, rename yours.

> [!error] error: method does not override any method from its superclass
> Usually a typo in the name, or a different parameter label or type. Overriding needs the exact same signature.

> [!error] error: property 'self.teamSize' not initialized at super.init call
> Set the subclass's own stored properties first, then call `super.init`.

> [!error] error: 'self' used in method call 'describe' before 'super.init' call
> You called a method in phase 1. Move the call after `super.init`.

> [!error] Forgetting super in an override
> An override replaces the whole method. If the superclass version did something you still need, such as setup or validation, call `super.method()` yourself.

> [!error] Casting instead of overriding
> A growing `if let … as? Circle … else if let … as? Square` chain means the base class is missing a method. Put the behavior in the class and let dynamic dispatch choose.

````exercise
id: m10-l02-e1
type: comprehension
prompt: |
  `let item: Shape = Circle(radius: 2)`, where `Circle` overrides `area()`. Which statement is true?
choices:
  - text: "item.area() runs Shape's version, because item is declared as Shape."
    correct: false
    why: "That's what happens with static dispatch. Non-final class methods are dispatched dynamically: the instance's real class decides."
  - text: "item.area() runs Circle's version, and item.radius doesn't compile."
    correct: true
    why: "Dynamic dispatch picks Circle.area(). But the declared type Shape decides which members you can name, and Shape has no radius."
  - text: "item.area() and item.radius both work, because the instance is a Circle."
    correct: false
    why: "To reach radius you need a Circle-typed reference: if let circle = item as? Circle."
  - text: It doesn't compile; a Circle can't be stored in a Shape variable.
    correct: false
    why: A subclass instance can always be used where its superclass is expected.
solution: |
  **item.area() runs Circle's version, and item.radius doesn't compile.** Two different questions with two different answers: *which members can I call?* is decided at compile time by the declared type, `Shape`. *Which implementation runs?* is decided at run time by the instance, a `Circle`.
````

````exercise
id: m10-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  class Animal {
      func sound() -> String {
          "..."
      }
      func speak() -> String {
          "The animal says " + sound()
      }
  }

  class Dog: Animal {
      override func sound() -> String {
          "Woof"
      }
  }

  class Puppy: Dog {
      override func sound() -> String {
          super.sound() + " (squeaky)"
      }
  }

  let animals: [Animal] = [Animal(), Dog(), Puppy()]
  for animal in animals {
      print(animal.speak())
  }
output: |
  The animal says ...
  The animal says Woof
  The animal says Woof (squeaky)
hints:
  - "speak() is only written in Animal, but it calls sound()."
  - "Which sound() runs depends on the instance, even when the call is made from inside Animal's code."
solution: |
  ```output
  The animal says ...
  The animal says Woof
  The animal says Woof (squeaky)
  ```

  `speak()` exists only in `Animal`, so every instance runs that one. Inside it, `sound()` is a call on `self`, and `self` is the real instance, so dynamic dispatch picks the most specific override. For the puppy, `Puppy.sound()` calls `super.sound()`, which is `Dog`'s version, and adds to it. This pattern, a base-class method calling an overridable method, is how many frameworks let subclasses customize one step of a larger process.
````

````exercise
id: m10-l02-e3
type: fill-in
prompt: |
  Complete the subclass so the program prints `Lisbon trip, 3 nights, 360`.
code: |
  class Booking {
      let city: String
      init(city: String) {
          self.city = city
      }
      func price() -> Int {
          0
      }
      func label() -> String {
          "\(city) trip"
      }
  }

  class HotelBooking: Booking {
      let nights: Int
      init(city: String, nights: Int) {
          self.nights = nights
          [[1]].init(city: city)
      }
      [[2]] func price() -> Int {
          nights * 120
      }
      override func label() -> String {
          super.[[3]]() + ", \(nights) nights, \(price())"
      }
  }

  print(HotelBooking(city: "Lisbon", nights: 3).label())
blanks:
  - id: "1"
    answers: ["super"]
  - id: "2"
    answers: ["override"]
  - id: "3"
    answers: ["label"]
solution: |
  ```swift
  class Booking {
      let city: String
      init(city: String) {
          self.city = city
      }
      func price() -> Int {
          0
      }
      func label() -> String {
          "\(city) trip"
      }
  }

  class HotelBooking: Booking {
      let nights: Int
      init(city: String, nights: Int) {
          self.nights = nights
          super.init(city: city)
      }
      override func price() -> Int {
          nights * 120
      }
      override func label() -> String {
          super.label() + ", \(nights) nights, \(price())"
      }
  }

  print(HotelBooking(city: "Lisbon", nights: 3).label())
  ```

  ```output
  Lisbon trip, 3 nights, 360
  ```

  The initializer sets `nights` first and then calls `super.init`, in two-phase order. `price()` replaces an inherited method, so it needs `override`. `super.label()` reuses the base text instead of repeating `"\(city) trip"`.
````

````exercise
id: m10-l02-e4
type: find-errors
prompt: This code doesn't compile. Pick out the real problems.
code: |
  class Course {
      let title: String
      var students: Int
      init(title: String, students: Int) {
          self.title = title
          self.students = students
      }
      convenience init(title: String) {
          self.title = title
          self.students = 0
      }
  }

  final class OnlineCourse: Course {
      let url: String
      init(title: String, url: String) {
          super.init(title: title, students: 0)
          self.url = url
      }
  }

  class RecordedCourse: OnlineCourse {}
choices:
  - text: The convenience init sets stored properties instead of calling self.init.
    correct: true
    why: "A convenience initializer must delegate across with self.init(title: title, students: 0)."
  - text: OnlineCourse calls super.init before setting url.
    correct: true
    why: "Phase 1 requires the subclass's own properties first: property 'self.url' not initialized at super.init call."
  - text: RecordedCourse inherits from a final class.
    correct: true
    why: "final class OnlineCourse can't be subclassed: inheritance from a final class 'OnlineCourse'."
  - text: OnlineCourse needs override on its init.
    correct: false
    why: "init(title:url:) has a different signature from anything in Course, so it doesn't override anything."
rubric:
  - The convenience init calls self.init.
  - url is set before super.init.
  - RecordedCourse is removed or OnlineCourse is no longer final.
solution: |
  ```swift
  class Course {
      let title: String
      var students: Int
      init(title: String, students: Int) {
          self.title = title
          self.students = students
      }
      convenience init(title: String) {
          self.init(title: title, students: 0)
      }
  }

  final class OnlineCourse: Course {
      let url: String
      init(title: String, url: String) {
          self.url = url
          super.init(title: title, students: 0)
      }
  }

  let course = OnlineCourse(title: "Swift", url: "example.com/swift")
  print(course.title, course.students, course.url)
  ```

  ```output
  Swift 0 example.com/swift
  ```

  Three real errors. The convenience initializer delegates across with `self.init`. The subclass sets `url` before handing off to `super.init`. And since nothing in the design needs `RecordedCourse`, the simplest fix is to drop it and keep `OnlineCourse` final. If you did need it, you'd remove `final` from `OnlineCourse`.
````

````exercise
id: m10-l02-e5
type: solve
prompt: |
  Payroll. Write:

  - a class `Employee` with `let name: String`, a designated `init(name:)`, and `func monthlyPay() -> Int` that returns 3000,
  - a subclass `Contractor` with `let hours: Int` and `let rate: Int`, whose `monthlyPay()` returns `hours * rate`,
  - a subclass `Manager` with `let bonus: Int`, whose `monthlyPay()` returns the employee pay plus the bonus, using `super`.

  Then compute the total over an `[Employee]` array so this prints the output below:

  ```swift
  let staff: [Employee] = [
      Employee(name: "Ana"),
      Contractor(name: "Leo", hours: 80, rate: 40),
      Manager(name: "Sofia", bonus: 1200),
  ]
  for person in staff {
      print("\(person.name): \(person.monthlyPay())")
  }
  ```

  ```output
  Ana: 3000
  Leo: 3200
  Sofia: 4200
  Total: 10400
  ```
starter: |
  class Employee {
      // your code
  }
hints:
  - "Each subclass init sets its own property first, then calls super.init(name: name)."
  - "Manager: super.monthlyPay() + bonus."
  - "The total is a loop with a var total = 0, or staff.reduce(0) { $0 + $1.monthlyPay() } from Module 7."
rubric:
  - Both subclasses use override, and Manager calls super.monthlyPay().
  - Both subclass initializers follow two-phase order.
  - The loop works through Employee references and never casts.
  - The output matches exactly.
solution: |
  ```swift
  class Employee {
      let name: String

      init(name: String) {
          self.name = name
      }

      func monthlyPay() -> Int {
          3000
      }
  }

  final class Contractor: Employee {
      let hours: Int
      let rate: Int

      init(name: String, hours: Int, rate: Int) {
          self.hours = hours
          self.rate = rate
          super.init(name: name)
      }

      override func monthlyPay() -> Int {
          hours * rate
      }
  }

  final class Manager: Employee {
      let bonus: Int

      init(name: String, bonus: Int) {
          self.bonus = bonus
          super.init(name: name)
      }

      override func monthlyPay() -> Int {
          super.monthlyPay() + bonus
      }
  }

  let staff: [Employee] = [
      Employee(name: "Ana"),
      Contractor(name: "Leo", hours: 80, rate: 40),
      Manager(name: "Sofia", bonus: 1200),
  ]

  var total = 0
  for person in staff {
      let pay = person.monthlyPay()
      print("\(person.name): \(pay)")
      total += pay
  }
  print("Total: \(total)")
  ```

  ```output
  Ana: 3000
  Leo: 3200
  Sofia: 4200
  Total: 10400
  ```

  The loop never asks what kind of employee it has; dynamic dispatch picks the right `monthlyPay()`. Adding a fourth kind of employee means writing one more subclass, with no change to the loop. The subclasses are `final` because nothing inherits from them. `Employee` can't be, since it has subclasses.
````

````exercise
id: m10-l02-e6
type: explain
prompt: |
  A teammate marked every class in the project `final` "for performance". Another says that's pointless. Explain what `final` changes for the compiler, what it changes for the design, and when you'd leave it off.
code: |
  final class ImageCache {
      func image(named name: String) -> String? {
          nil
      }
  }
rubric:
  - "Says final prevents subclassing (and overriding), so the compiler knows there's one implementation."
  - Says that allows static dispatch and inlining instead of a vtable lookup, and that the gain is usually small and should be measured.
  - Mentions that private members and whole-module optimization can give the compiler the same knowledge.
  - Names the design benefit, saying "this wasn't built to be subclassed", and leaves final off only for classes designed as base classes.
solution: |
  `final` means no subclass can exist, so no override of `image(named:)` can exist. The compiler can then call the one implementation directly and even inline it, instead of looking it up in the vtable at run time. That's real, but the cost of one indirect call is tiny; it matters in hot loops, not in most app code, and you'd measure before claiming a win. The compiler can sometimes reach the same conclusion without `final`: `private` members can't be overridden from elsewhere, and whole-module optimization can see that an internal class has no subclasses.

  The better argument is design. `final class` documents "this type wasn't built for inheritance": nobody can subclass it and accidentally break assumptions its methods make about each other. So both teammates are half right. Making classes `final` by default is a good habit, mostly for design. Leave it off for a class you actually design as a base class, with overridable methods you've thought about.
````

## Summary

- `class Sub: Super` inherits everything from `Super`. A class has at most one superclass; structs and enums can't inherit.
- `override` is required to replace an inherited member, and it catches typos. `super.member` reaches the superclass's version.
- `final` stops subclassing or overriding, and lets the compiler dispatch statically.
- Non-final class methods are dispatched dynamically through a vtable: the instance's real class decides which version runs, even when you call through a superclass reference. That's polymorphism.
- `is` checks an instance's type and `as?` converts to a subclass, giving an optional. Prefer overriding to long cast chains.
- Two-phase initialization: set your own stored properties, call `super.init`, then use `self`. A convenience init delegates across with `self.init`.
- Inheritance couples classes tightly. Use it when a framework asks for it or the hierarchy is genuinely simple; the rest of the module shows the alternatives.
