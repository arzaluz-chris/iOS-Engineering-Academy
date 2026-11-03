---
id: p07
number: 7
title: Production-Quality App
summary: A personal finance app with a defined architecture, strict concurrency, persistence, security, accessibility, logging and CI.
prerequisites: [m41, m42, m43]
objectives:
  - Apply a documented architecture with justified decisions.
  - Build in Swift 6 mode with no concurrency warnings.
  - Protect sensitive data according to MASVS.
  - Automate checks in CI.
requirements:
  - A documented architecture (for example, layers with repositories, and use cases only where they add something).
  - Per-environment configuration (development and production) with no secrets in the repository.
  - Sensitive data in the Keychain, and a local database protected with Data Protection.
  - Logging with os.Logger and no personal data.
  - Unit tests for the domain and data layers, and at least one UI test for the main flow.
  - A CI workflow that builds and runs the tests.
acceptance:
  - Builds in the Swift 6 language mode with no warnings.
  - Inspecting a device backup reveals no amounts or tokens.
  - The main flow is usable with VoiceOver from start to finish.
  - CI fails if a test fails.
milestones:
  - id: p07-h1
    title: Architecture and decisions
    tasks: ["Write an architecture decision record that includes the alternatives you rejected."]
    concepts: [Architecture, Trade-offs]
  - id: p07-h2
    title: Domain, data and concurrency
    tasks: ["Implement the domain and persistence with correct actor isolation."]
    concepts: [Swift Concurrency, Persistence]
  - id: p07-h3
    title: Security
    tasks: ["Work through the checklist from the secure development module."]
    concepts: [Keychain, Data Protection, Secure logging]
  - id: p07-h4
    title: Accessibility and performance
    tasks: ["Audit with Accessibility Inspector and profile app launch with Instruments."]
    concepts: [Accessibility, Instruments]
  - id: p07-h5
    title: CI
    tasks: ["Set up the build and test workflow."]
    concepts: [GitHub Actions]
---

## The bar

This project is judged the way a pull request would be reviewed on a banking team: you have to be able to defend every decision. Use the quality checklist from stage 12.
