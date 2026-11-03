---
id: p06
number: 6
title: Hybrid UIKit and SwiftUI App
summary: An existing UIKit app that adds SwiftUI screens, and a SwiftUI screen that needs a UIKit component. This is the most common setup at companies with legacy code.
prerequisites: [m40]
objectives:
  - Bring SwiftUI into UIKit navigation with UIHostingController.
  - Wrap a UIKit component with UIViewRepresentable and its coordinator.
  - Share state between the two worlds without duplicating it.
requirements:
  - Start from project 3 or 4 and add a new screen in SwiftUI.
  - Put a UIKit component inside SwiftUI (for example, a UITextView with formatting, or a map).
  - One observable model shared by the UIKit screen and the SwiftUI screen.
acceptance:
  - Navigation works in both directions without duplicated screens.
  - The wrapped component reports changes to SwiftUI through its coordinator.
  - There are no memory leaks when you go in and out of the hybrid screens.
milestones:
  - id: p06-h1
    title: SwiftUI inside UIKit
    tasks: ["Present a SwiftUI view with UIHostingController from the existing coordinator."]
    concepts: [UIHostingController]
  - id: p06-h2
    title: UIKit inside SwiftUI
    tasks: ["Wrap a component with UIViewRepresentable and handle its events with a coordinator."]
    concepts: [UIViewRepresentable, Coordinators]
  - id: p06-h3
    title: Shared state
    tasks: ["Share an observable model between both screens and check that changes show up in each."]
    concepts: [Observation, Hybrid life cycles]
---

## When it makes sense

Interoperability makes architectural sense when you're migrating incrementally, or when a mature UIKit component has no SwiftUI equivalent. Write down why you chose each integration.
