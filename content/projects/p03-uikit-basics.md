---
id: p03
number: 3
title: First UIKit App - Reading List
summary: A multi-screen app for keeping track of books you want to read. Navigation, forms, lists, validation, an empty state and error handling in UIKit, with the UI built in code.
prerequisites: [m22, m23, m24, m25]
objectives:
  - Build UIKit screens in code with Auto Layout.
  - Pass data between screens and send results back.
  - Design empty and error states.
requirements:
  - A book list built with UICollectionView, a diffable data source and a list layout.
  - A screen for adding a book, with validation that the title is required.
  - A detail screen with an option to mark the book as read.
  - An empty state with a clear instruction for adding the first book.
  - Dynamic Type and VoiceOver support on every screen.
acceptance:
  - The app adopts the scene-based life cycle.
  - Saving without a title shows an error next to the field, not a generic alert.
  - At the largest text size, no text gets cut off.
  - After you close the detail screen, no view controller stays in memory (checked with the Memory Graph).
milestones:
  - id: p03-h1
    title: Project and scene
    tasks: ["Create the project with the scene-based life cycle and no main Storyboard.", "Set up the window with a UINavigationController."]
    concepts: [UIWindowScene, UIWindow]
  - id: p03-h2
    title: List with a diffable data source
    tasks: ["Show sample books in a UICollectionView in list mode.", "Add the empty state."]
    concepts: [Diffable data sources, Compositional layout]
  - id: p03-h3
    title: Form and validation
    tasks: ["Present the form modally.", "Send the new book back with a delegate or a closure."]
    concepts: [Returning results, Validation]
  - id: p03-h4
    title: Detail and accessibility
    tasks: ["Show the detail screen with a push.", "Check VoiceOver and Dynamic Type with Accessibility Inspector."]
    concepts: [Accessibility, Dynamic Type]
---

## Scope

No networking or persistence yet: the data lives in memory. Persistence comes in project 4. Focus on clean navigation and accessible interfaces.
