---
id: p04
number: 4
title: UIKit App with a Public API
summary: A catalog app backed by a public API, with pagination, image caching, local persistence and tests for the data layer.
prerequisites: [m30, m31, m32, m33]
objectives:
  - Build an HTTP client with URLSession and async/await, kept separate from the UI.
  - Handle loading, error, empty and pagination states.
  - Test the data layer with test doubles.
requirements:
  - Pick a free public API that has no personal data (for example, a book catalog or a museum's art collection) and document its license terms.
  - A paginated list that loads more as you get near the end.
  - An in-memory image cache, with cancellation when cells are reused.
  - Local persistence of the latest results so they can be shown offline.
  - Tests for the repository using a fake network client.
acceptance:
  - Offline, the app shows the saved data and a notice with the time of the last update.
  - A decoding error shows a recoverable error state, not a crash.
  - No image shows up in the wrong cell when you scroll fast.
  - The data layer tests pass without a network connection.
milestones:
  - id: p04-h1
    title: Network client
    tasks: ["Define an HTTP client protocol and an implementation backed by URLSession.", "Model network errors, HTTP status errors and decoding errors."]
    concepts: [URLSession, Codable, Error handling]
  - id: p04-h2
    title: Repository and states
    tasks: ["Expose loading, data, empty and error states.", "Implement cursor-based or page-based pagination, depending on the API."]
    concepts: [Repository pattern, Pagination]
  - id: p04-h3
    title: Images and performance
    tasks: ["Implement an image cache and cancellation in prepareForReuse."]
    concepts: [Caching, Cell reuse]
  - id: p04-h4
    title: Persistence and offline mode
    tasks: ["Save the latest page with SwiftData or Core Data.", "Show local data first, then refresh from the network."]
    concepts: [Persistence, Offline-first]
  - id: p04-h5
    title: Tests
    tasks: ["Test the repository with a fake client: success, error, empty and pagination."]
    concepts: [Test doubles, Async tests]
---

## Choosing the API

Prefer APIs with stable documentation that need no key, or only a free one. Never put a secret key in the app's code: anyone can pull it out of the binary. If the API requires a key, document the risk and use a read-only one.
