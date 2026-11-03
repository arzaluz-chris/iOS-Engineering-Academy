---
id: p05
number: 5
title: The Same App in SwiftUI
summary: Rebuild the catalog from project 4 with SwiftUI and Observation, reusing the data layer. Figure out what changes and which principles carry over.
prerequisites: [m36, m37]
objectives:
  - Reuse the domain and data layers unchanged when you switch UI frameworks.
  - Put state in the right owner with Observation.
  - Navigate by value with NavigationStack.
requirements:
  - The same features as project 4.
  - Models with @Observable and local state with @State.
  - Navigation with NavigationStack and NavigationPath.
  - A short write-up comparing the two implementations.
acceptance:
  - The data layer from project 4 is used without modifications.
  - The write-up explains at least three differences and three principles that carry over.
  - Views don't make network calls directly.
milestones:
  - id: p05-h1
    title: Reuse the data layer
    tasks: ["Extract the domain and data layers from project 4 into a local Swift package."]
    concepts: [Modularization]
  - id: p05-h2
    title: List and detail
    tasks: ["Build the list with List or LazyVStack, plus value-based navigation."]
    concepts: [NavigationStack, Observation]
  - id: p05-h3
    title: States and pagination
    tasks: ["Implement loading, error, empty and pagination with task and refreshable."]
    concepts: [task, refreshable]
  - id: p05-h4
    title: Comparison
    tasks: ["Write the comparison."]
    concepts: [Architecture]
---

## What to watch for

The data layer shouldn't change at all. If you have to modify it for SwiftUI, there were UIKit dependencies where they didn't belong. That's the most useful lesson in this project.
