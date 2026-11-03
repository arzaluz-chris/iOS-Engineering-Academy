---
id: m07-l06
title: Value semantics and nested collections
description: You see that arrays, dictionaries and sets are copied when you assign or pass them, work with grids stored as arrays of arrays, group data with Dictionary(grouping:by:), and put the whole module together in a grade book program.
module: m07
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l05]
objectives:
  - Predict that changing a copy of a collection leaves the original unchanged.
  - Pass a collection to a function and return a changed version, or change it in place with inout.
  - Read, write and loop over a grid stored as [[Int]].
  - Build a dictionary of arrays, by hand and with Dictionary(grouping:by:), and print it in a stable order.
  - Combine parsing, validation, grouping and summarizing into one program.
terms:
  - term: Value semantics
    definition: The behavior where assigning or passing a value gives the receiver its own independent copy. Swift's arrays, dictionaries, sets and strings have value semantics.
  - term: Copy-on-write
    definition: The optimization behind Swift's collections. A copy shares storage with the original until one of them is changed, and only then are the elements actually copied.
  - term: Nested collection
    definition: "A collection whose elements are themselves collections, like [[Int]] (an array of arrays) or [String: [Int]] (a dictionary of arrays)."
  - term: Grid
    definition: A two-dimensional table of values stored as an array of rows, where each row is an array. You read a cell with grid[row][column].
mastery:
  - Predict the contents of an original and a copy after changes to one of them.
  - Write a function that takes an array and returns a modified copy, without touching the caller's array.
  - Loop over every cell of a grid by row and by column, and say which indexes are valid.
  - Group values with Dictionary(grouping:by:) and print the groups in sorted order.
  - Write a small program that parses raw input, rejects invalid entries, groups what's left and prints a summary.
resources: [swift-dictionary-grouping, swift-book-collection-types, swift-book-closures, swift-book-basics]
cards:
  - id: m07-l06-c1
    front: "After var b = a; b.append(4), where a is an array, does a change?"
    back: No. Arrays are values. b is an independent copy, so changes to b never show up in a.
  - id: m07-l06-c2
    front: How do you read the cell in row 2, column 3 of a grid stored as [[Int]]?
    back: "grid[2][3]. The first subscript picks the row (an [Int]) and the second picks the element in that row. Both indexes start at 0."
  - id: m07-l06-c3
    front: "What does Dictionary(grouping: words, by: { word in word.count }) produce?"
    back: "A [Int: [String]] dictionary from each length to the words of that length, in their original order. Sort the keys before printing it."
  - id: m07-l06-c4
    front: "How do you append to an array stored in a dictionary, even if the key doesn't exist yet?"
    back: "dict[key, default: []].append(value). The default subscript starts a missing key with an empty array."
---

## The idea in one sentence

In Swift, a collection is a **value** like an `Int`: assigning it or passing it gives the receiver its own copy, so no other code can change your array behind your back.

## Copies are independent

When you write `var b = a` with integers and then change `b`, nobody expects `a` to change. Arrays work exactly the same way:

```swift
let original = [1, 2, 3]
var copy = original
copy.append(4)
copy[0] = 100
print(original)
print(copy)
```

```output
[1, 2, 3]
[100, 2, 3, 4]
```

1. `original` is a `let` array.
2. `var copy = original` makes `copy` an **independent** array with the same elements. It can be a `var` even though `original` is a `let`, because it's a separate value.
3. and 4. Changing `copy` changes only `copy`.
5. `original` is untouched.

That's **value semantics**. Dictionaries and sets behave the same way:

```swift
var prices = ["coffee": 45, "bread": 28]
var saleCopy = prices
saleCopy["coffee"] = 40
prices["juice"] = 35
print(prices["coffee", default: 0], prices.count)
print(saleCopy["coffee", default: 0], saleCopy.count)
```

```output
45 3
40 2
```

After the copy, the two dictionaries go their separate ways: the sale price only exists in `saleCopy`, and juice only in `prices`.

Not every type in Swift works like this. **Classes**, which you'll meet in Module 9, are shared: two names can refer to the same object, and a change through one is visible through the other. Many languages, including JavaScript, Python and Java, treat their arrays that way, which is a common source of bugs when a function quietly changes a list it was handed. Swift's collections don't have that problem.

> [!note] Copies are cheap
> You might worry that copying a million-element array on every assignment is slow. Swift doesn't actually copy the elements when you write `var copy = original`. The two share the same storage until one of them is **changed**; only then are the elements copied, just before the change. This is called **copy-on-write**. You get the behavior of a copy, and pay for one only when you need it.

## Passing collections to functions

A parameter is a constant copy of the argument (Module 6). So a function can't change the caller's array, and trying to change the parameter itself doesn't compile:

```swift no-compile cannot use mutating member on immutable value: 'scores' is a 'let' constant
func addBonus(to scores: [Int]) {
    scores.append(5)
}
```

You have two ways out. The usual one is to **return a new array**:

```swift
func addingBonus(_ bonus: Int, to scores: [Int]) -> [Int] {
    var result = scores
    for index in result.indices {
        result[index] = min(result[index] + bonus, 100)
    }
    return result
}

let midterm = [85, 98, 70]
let curved = addingBonus(5, to: midterm)
print(midterm)
print(curved)
```

```output
[85, 98, 70]
[90, 100, 75]
```

`var result = scores` makes a local copy the function is free to change. `min(a, b)` returns the smaller of two values, so no score goes over 100. The caller keeps the original and gets the new version back. This is a **pure function**, as in Module 6: same input, same output, nothing else touched. (`midterm.map { score in min(score + 5, 100) }` does the same thing in one line.)

The other way is `inout`, from Module 6, when changing the caller's variable in place really is the point:

```swift
func applyBonus(_ bonus: Int, to scores: inout [Int]) {
    for index in scores.indices {
        scores[index] = min(scores[index] + bonus, 100)
    }
}

var finalScores = [85, 98, 70]
applyBonus(5, to: &finalScores)
print(finalScores)
```

```output
[90, 100, 75]
```

The `&` at the call site makes it visible that `finalScores` will change. Prefer returning a new value; reach for `inout` when the caller clearly expects an update.

## Arrays of arrays: grids

An array's elements can be arrays. `[[Int]]` is an array whose elements are `[Int]`, which is a natural way to store a **grid**: a list of rows, each a list of cells.

```swift
let seats = [
    [1, 1, 0, 1],
    [0, 0, 1, 1],
    [1, 0, 0, 0],
]
print(seats.count)
print(seats[0].count)
print(seats[1])
print(seats[1][2])
```

```output
3
4
[0, 0, 1, 1]
1
```

1. A theater with 3 rows of 4 seats; 1 means taken. The trailing comma after the last row is allowed and makes adding a row a one-line change.
2. `seats.count` is the number of **rows**.
3. `seats[0].count` is the number of **columns**, the length of a row.
4. `seats[1]` is a whole row, an `[Int]`.
5. `seats[1][2]` picks row 1, then the element at index 2 in that row. Read it left to right: row first, then column.

Both subscripts can crash. `seats[3]` is past the last row; `seats[0][4]` is past the end of a row. Valid cells go from `seats[0][0]` to `seats[seats.count - 1][seats[0].count - 1]`.

### Looping over a grid

A nested loop (Module 5) visits every cell: the outer loop over rows, the inner loop over the cells in that row.

```swift
let seats = [
    [1, 1, 0, 1],
    [0, 0, 1, 1],
    [1, 0, 0, 0],
]
var taken = 0
for row in seats {
    for seat in row {
        taken += seat
    }
}
print("Taken: \(taken)")

for rowIndex in seats.indices {
    let free = seats[rowIndex].filter { seat in seat == 0 }.count
    print("Row \(rowIndex + 1): \(free) free")
}
```

```output
Taken: 6
Row 1: 1 free
Row 2: 2 free
Row 3: 3 free
```

The first loop doesn't need indexes. The second needs the row number for the label, so it loops over `seats.indices`. `filter` from lesson 5 works on each row, since each row is an ordinary array. (`seats.flatMap { row in row }.reduce(0, +)` would also give 6.)

### Building and changing a grid

`Array(repeating:count:)` can build a grid, with a row as the repeated value:

```swift
var board = Array(repeating: Array(repeating: ".", count: 3), count: 3)
board[0][0] = "X"
board[1][1] = "O"
board[2][0] = "X"
for row in board {
    print(row.joined(separator: " "))
}
```

```output
X . .
. O .
X . .
```

`joined(separator:)` glues an array of strings into one `String`, with the separator between each pair. It's a handy way to print a row without the brackets and quotes.

Because arrays are values, each of the three rows is an independent copy of the repeated row. Writing `board[0][0]` changes only row 0. In languages where arrays are shared, the same one-liner creates three references to **one** row, and setting one cell changes the whole column. In Swift, it just works.

## Dictionaries of arrays

A dictionary's values can be arrays too. `[String: [Int]]` maps each name to a list of numbers. Build one with the default subscript, starting each new key with an empty array:

```swift
let entries = [("Ana", 91), ("Luis", 78), ("Ana", 85), ("Luis", 88), ("Marta", 70)]
var scoresByStudent: [String: [Int]] = [:]
for (name, score) in entries {
    scoresByStudent[name, default: []].append(score)
}
for name in scoresByStudent.keys.sorted() {
    print(name, scoresByStudent[name, default: []])
}
```

```output
Ana [91, 85]
Luis [78, 88]
Marta [70]
```

`scoresByStudent[name, default: []].append(score)` reads "the list for this name, or an empty list if there isn't one yet, with this score appended", and stores the result back under `name`. It's the frequency-count pattern from lesson 3, with `append` instead of `+= 1`. And as always with a dictionary, the keys are sorted before printing.

### Dictionary(grouping:by:)

Grouping is common enough that Swift does it in one call. `Dictionary(grouping:by:)` takes a collection and a closure that computes each element's **group key**, and returns a dictionary from each key to the elements in that group:

```swift
let words = ["apple", "fig", "kiwi", "pear", "plum", "banana", "grape"]
let byLength = Dictionary(grouping: words, by: { word in word.count })
for length in byLength.keys.sorted() {
    print(length, byLength[length, default: []])
}
```

```output
3 ["fig"]
4 ["kiwi", "pear", "plum"]
5 ["apple", "grape"]
6 ["banana"]
```

The closure returns each word's `count`, so the keys are `Int`s and the result is `[Int: [String]]`. Within each group the words keep their original order: `"kiwi"`, `"pear"`, `"plum"`. Only the dictionary's own order is unstable, which is why the keys are sorted.

## A practical example: a grade book

This program ties the module together. It gets raw entries the way a form or file would deliver them, as strings that may be invalid, and prints a report.

```swift
func letterGrade(for score: Int) -> String {
    switch score {
    case 90...100: return "A"
    case 80..<90: return "B"
    case 70..<80: return "C"
    case 60..<70: return "D"
    default: return "F"
    }
}

func parse(_ raw: [(String, String)]) -> (valid: [(name: String, score: Int)], rejected: [String]) {
    var valid: [(name: String, score: Int)] = []
    var rejected: [String] = []
    for (name, text) in raw {
        let score = Int(text) ?? -1
        if score >= 0 && score <= 100 {
            valid.append((name: name, score: score))
        } else {
            rejected.append("\(name) \"\(text)\"")
        }
    }
    return (valid, rejected)
}

let rawEntries = [
    ("Ana", "91"), ("Luis", "78"), ("Ana", "85"), ("Marta", "abc"),
    ("Luis", "105"), ("Marta", "88"), ("Sofía", "64"), ("Sofía", "70"),
    ("Diego", "55"),
]

let parsed = parse(rawEntries)

var scoresByStudent: [String: [Int]] = [:]
for entry in parsed.valid {
    scoresByStudent[entry.name, default: []].append(entry.score)
}

var averages: [String: Int] = [:]
print("Averages")
for name in scoresByStudent.keys.sorted() {
    let scores = scoresByStudent[name, default: []]
    let average = scores.reduce(0, +) / scores.count
    averages[name] = average
    print("  \(name): \(average) \(letterGrade(for: average))")
}

let namesByGrade = Dictionary(grouping: averages.keys.sorted(), by: { name in
    letterGrade(for: averages[name, default: 0])
})
print("By grade")
for grade in namesByGrade.keys.sorted() {
    print("  \(grade): \(namesByGrade[grade, default: []].joined(separator: ", "))")
}

print("Rejected \(parsed.rejected.count): \(parsed.rejected.joined(separator: ", "))")
```


```output
Averages
  Ana: 88 B
  Diego: 55 F
  Luis: 78 C
  Marta: 88 B
  Sofía: 67 D
By grade
  B: Ana, Marta
  C: Luis
  D: Sofía
  F: Diego
Rejected 2: Marta "abc", Luis "105"
```

Step by step:

1. **`letterGrade(for:)`** is a pure function with a `switch` over ranges (Module 5).
2. **`parse`** converts and validates. `Int(text) ?? -1` turns anything that isn't a number into -1, and the range check rejects it along with out-of-range numbers like 105. It returns a tuple with two arrays (Module 6), so the caller gets both the good entries and a record of the bad ones. Nothing is silently dropped. Each valid entry is a tuple with labels, `(name: String, score: Int)`, so later code can write `entry.name` instead of `entry.0`.
3. **Grouping by student** uses the default-subscript pattern to build `[String: [Int]]`.
4. **Averages** loop over the sorted names. Every name in `scoresByStudent` has at least one score, because it only got there by appending one, so `scores.count` is never 0. The division is integer division: Sofía's (64 + 70) / 2 is exactly 67, but a 67.5 would also print as 67.
5. **Grouping by grade** uses `Dictionary(grouping:by:)` on the sorted names, so the names inside each group come out alphabetical. There's no `A:` line: `Dictionary(grouping:by:)` only creates a group for a key that at least one element produced, and nobody averaged 90.
6. **Rejected** entries are reported with `joined(separator:)`, in the order they appeared.

Every dictionary in the program is printed through sorted keys, so the report is identical on every run. And no function touches a global variable: data goes in through parameters and comes out through return values, which keeps the program legal in Swift 6 and easy to test piece by piece.

## Common mistakes

> [!error] error: cannot use mutating member on immutable value: 'scores' is a 'let' constant
> You tried to change an array parameter inside a function. Parameters are constants. Copy it into a local `var` and return the result, or declare the parameter `inout` and call with `&`.

> [!error] Expecting a change to a copy to show up in the original
> `var working = scores; working.append(100)` doesn't add anything to `scores`. If the original should change, change the original, or assign the copy back: `scores = working`.

> [!error] Fatal error: Index out of range in a grid
> `grid[row][column]` has two indexes, and each can be out of range. Swapping them (`grid[column][row]`) on a grid that isn't square is a classic way to get there. Swift 6.3, reading row 0, column 3 of a 3 × 2 grid:

```swift runtime-error Index out of range
let grid = [
    [1, 2, 3],
    [4, 5, 6],
]
print(grid[1][2])
print(grid[0][3])
```

```output
6
```

> [!error] Printing a grouped dictionary directly
> `print(Dictionary(grouping: …))` shows the groups in an order that changes between runs. Loop over `keys.sorted()`.

> [!error] Expecting empty groups
> `Dictionary(grouping:by:)` has no key for a group with no elements. If the report must show every grade, loop over a fixed list like `["A", "B", "C", "D", "F"]` and use `groups[grade, default: []]`.

````exercise
id: m07-l06-e1
type: comprehension
prompt: |
  What does this program print?
  ```swift
  var team = ["Ana", "Luis"]
  var backup = team
  backup.append("Marta")
  team[0] = "Sofía"
  print(team.count, backup[0])
  ```
choices:
  - text: "`2 Sofía`"
    correct: false
    why: backup was copied before team[0] changed, so it still has Ana.
  - text: "`2 Ana`"
    correct: true
    why: team and backup are independent after the copy.
  - text: "`3 Sofía`"
    correct: false
    why: That would be true if both names referred to the same array, which isn't how Swift arrays work.
  - text: "`3 Ana`"
    correct: false
    why: Appending to backup doesn't change team's count.
solution: |
  **`2 Ana`.** `var backup = team` gives `backup` its own copy of `["Ana", "Luis"]`. After that, the two arrays are unrelated: appending Marta to `backup` leaves `team` with 2 elements, and changing `team[0]` leaves `backup[0]` as Ana. In a language where arrays are shared references, the answer would be `3 Sofía`; that's exactly the kind of surprise value semantics prevents.
````

````exercise
id: m07-l06-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  func doubled(_ values: [Int]) -> [Int] {
      var result = values
      for i in result.indices {
          result[i] *= 2
      }
      return result
  }
  var grid = [[1, 2], [3, 4], [5, 6]]
  let row = grid[1]
  grid[1][0] = 30
  print(row)
  print(grid[1])
  print(doubled(grid[2]), grid[2])
  print(grid.count, grid[0].count)
output: |
  [3, 4]
  [30, 4]
  [10, 12] [5, 6]
  3 2
hints:
  - "let row = grid[1] copies the row at that moment."
  - doubled works on its own copy.
solution: |
  ```output
  [3, 4]
  [30, 4]
  [10, 12] [5, 6]
  3 2
  ```

  - `row` is a copy of `grid[1]` taken before the change, so it's still `[3, 4]`.
  - `grid[1][0] = 30` changes the grid's own row: `[30, 4]`.
  - `doubled` copies its parameter into `result` and returns the doubled copy. `grid[2]` is unchanged.
  - The grid has 3 rows of 2 columns.
````

````exercise
id: m07-l06-e3
type: fill-in
prompt: |
  Complete the program so it groups the cities by their first letter and prints exactly:

  ```output
  B ["Bogotá", "Buenos Aires"]
  L ["Lima", "La Paz"]
  Q ["Quito"]
  ```
code: |
  let cities = ["Lima", "Bogotá", "Quito", "La Paz", "Buenos Aires"]
  let groups = Dictionary([[1]]: cities, by: { city in city.first ?? " " })
  for letter in groups.keys.[[2]]() {
      print(letter, groups[letter, [[3]]: []])
  }
blanks:
  - id: "1"
    answers: ["grouping"]
  - id: "2"
    answers: ["sorted"]
  - id: "3"
    answers: ["default"]
solution: |
  ```swift
  let cities = ["Lima", "Bogotá", "Quito", "La Paz", "Buenos Aires"]
  let groups = Dictionary(grouping: cities, by: { city in city.first ?? " " })
  for letter in groups.keys.sorted() {
      print(letter, groups[letter, default: []])
  }
  ```

  ```output
  B ["Bogotá", "Buenos Aires"]
  L ["Lima", "La Paz"]
  Q ["Quito"]
  ```

  `city.first` is the first `Character` of the string, an optional because a string can be empty, so `?? " "` supplies a fallback. The keys are `Character`s; sorting them gives B, L, Q. Inside each group the cities keep the order they had in `cities`: Lima before La Paz.
````

````exercise
id: m07-l06-e4
type: find-errors
prompt: This function is supposed to return a copy of a grid with every negative number replaced by 0, without changing the caller's grid. Pick out the real problems.
code: |
  func clampNegatives(_ grid: [[Int]]) -> [[Int]] {
      for row in grid.indices {
          for column in grid.indices {
              if grid[row][column] < 0 {
                  grid[row][column] = 0
              }
          }
      }
      return grid
  }
choices:
  - text: "grid is a parameter, so it can't be assigned to. It needs a local var copy."
    correct: true
    why: "Parameters are constants: cannot assign through subscript: 'grid' is a 'let' constant."
  - text: "The inner loop uses grid.indices, the row indexes, instead of grid[row].indices."
    correct: true
    why: "On a grid that isn't square, that either skips columns or reads past the end of a row."
  - text: "Returning grid would change the caller's array."
    correct: false
    why: Returning gives the caller a new value. Value semantics means the caller's grid is never touched by the function.
  - text: "You can't compare grid[row][column] with 0."
    correct: false
    why: It's an Int, so < 0 is fine.
rubric:
  - I copied the parameter into a local var and returned that.
  - The inner loop goes over the columns of the current row.
  - I tested with a grid that isn't square.
solution: |
  ```swift
  func clampNegatives(_ grid: [[Int]]) -> [[Int]] {
      var result = grid
      for row in result.indices {
          for column in result[row].indices {
              if result[row][column] < 0 {
                  result[row][column] = 0
              }
          }
      }
      return result
  }

  let readings = [[3, -1, 4], [-5, 9, -2]]
  print(clampNegatives(readings))
  print(readings)
  ```

  ```output
  [[3, 0, 4], [0, 9, 0]]
  [[3, -1, 4], [-5, 9, -2]]
  ```

  The first problem stops it from compiling. The second is a logic error that a square test grid would hide: with 2 rows of 3 columns, `grid.indices` is `0..<2`, so column 2 would never be checked. Testing with a non-square grid catches it. Printing `readings` afterward shows the caller's grid is unchanged. A shorter version: `grid.map { row in row.map { value in max(value, 0) } }`.
````

````exercise
id: m07-l06-e5
type: solve
prompt: |
  Write `func columnTotals(of grid: [[Int]]) -> [Int]` that returns the sum of each column of a rectangular grid (every row has the same length). An empty grid returns `[]`. Then print:

  ```output
  [12, 15, 18]
  [10]
  []
  ```

  for `[[1, 2, 3], [4, 5, 6], [7, 8, 9]]`, `[[4], [6]]` and `[]`.
starter: |
  func columnTotals(of grid: [[Int]]) -> [Int] {
      // Your code
      return []
  }
hints:
  - "Start with an array of zeros, one per column: Array(repeating: 0, count: …)."
  - The number of columns is the length of the first row, but only if there is a first row.
  - "For each row, add row[column] to totals[column]."
rubric:
  - The function handles the empty grid without crashing.
  - The totals array has one entry per column.
  - The loops use indices, not hard-coded sizes.
  - The output matches exactly.
solution: |
  ```swift
  func columnTotals(of grid: [[Int]]) -> [Int] {
      let columnCount = grid.isEmpty ? 0 : grid[0].count
      var totals = Array(repeating: 0, count: columnCount)
      for row in grid {
          for column in row.indices {
              totals[column] += row[column]
          }
      }
      return totals
  }

  print(columnTotals(of: [[1, 2, 3], [4, 5, 6], [7, 8, 9]]))
  print(columnTotals(of: [[4], [6]]))
  print(columnTotals(of: []))
  ```

  ```output
  [12, 15, 18]
  [10]
  []
  ```

  The column count is the length of the first row, and the ternary only reads `grid[0]` when there is a row 0. For the empty grid, `totals` starts empty and the loop never runs. (Module 8 shows a shorter way to write this line, `grid.first?.count ?? 0`, with optional chaining.)

  Each row adds its values into the matching column total. For the 3 × 3 grid: column 0 is 1 + 4 + 7 = 12, column 1 is 2 + 5 + 8 = 15, column 2 is 3 + 6 + 9 = 18. The function trusts the "rectangular" promise: a row longer than the first would crash on `totals[column]`.
````

````exercise
id: m07-l06-e6
type: solve
prompt: |
  Given a list of expenses as `(category, amount)` tuples, print the total per category in alphabetical order, then the category with the highest total. Use a dictionary to accumulate. Break a tie for the highest total alphabetically.

  ```output
  food: 230
  rent: 900
  transport: 85
  Biggest: rent
  ```
starter: |
  let expenses = [("food", 120), ("transport", 40), ("rent", 900), ("food", 110), ("transport", 45)]
hints:
  - "totals[category, default: 0] += amount"
  - Loop over the sorted keys for both the printing and the search for the biggest, so ties are broken alphabetically.
rubric:
  - "I accumulated totals in a [String: Int] dictionary."
  - The categories print in alphabetical order.
  - The biggest category is found with a stable tie-breaker.
  - The output matches exactly.
solution: |
  ```swift
  let expenses = [("food", 120), ("transport", 40), ("rent", 900), ("food", 110), ("transport", 45)]

  var totals: [String: Int] = [:]
  for (category, amount) in expenses {
      totals[category, default: 0] += amount
  }

  var biggest = ""
  var biggestTotal = 0
  for category in totals.keys.sorted() {
      let total = totals[category, default: 0]
      print("\(category): \(total)")
      if total > biggestTotal {
          biggest = category
          biggestTotal = total
      }
  }
  print("Biggest: \(biggest)")
  ```

  ```output
  food: 230
  rent: 900
  transport: 85
  Biggest: rent
  ```

  The first loop is the frequency-count pattern, adding the amount instead of 1. The second loop does two jobs in one pass, printing and tracking the maximum, which is a case where a loop is clearer than separate chains. Because the keys are visited alphabetically and the comparison is strict, an equal total later in the alphabet never replaces an earlier one: that's the tie-breaker.
````

## Summary

- Arrays, dictionaries and sets are values. `var copy = original` gives an independent copy; changing one never changes the other. Copy-on-write keeps this cheap.
- A function gets a constant copy of a collection argument. Return a changed copy, or use `inout` and `&` when the caller expects an in-place update.
- A grid is `[[T]]`: `grid[row][column]`, `grid.count` rows, `grid[0].count` columns. Each index can be out of range.
- Build a dictionary of arrays with `dict[key, default: []].append(value)`, or all at once with `Dictionary(grouping:by:)`. Groups keep their elements' order; the dictionary doesn't, so sort the keys.
- A real program parses, validates, groups and summarizes, with pure functions in between and sorted output at the end.
