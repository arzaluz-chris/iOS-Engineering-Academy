# Phase 1. Repository audit

Date: November 3, 2026.

## Findings

| Aspect | State found |
| --- | --- |
| Repository | `arzaluz-chris/iOS-Engineering-Academy`, newly created |
| Commits | None (empty `main` branch) |
| Existing stack | None |
| Dependencies, scripts, tests, configuration | None |
| Prior conventions or design system | None |
| Visibility | Private at first; changed to **public** during the session (verified with the GitHub API) |
| GitHub Pages | Source set to **GitHub Actions** by the owner |

Conclusion: there was nothing to keep or migrate. The stack was chosen from scratch (see `04-technical-design.md`).

## Constraints identified in this phase

- **Publishing on GitHub Pages:** a static site with no server and no route rewriting; the site lives under the `/iOS-Engineering-Academy/` subpath.
- **CI cost:** while the repository was private, macOS runners used minutes at roughly a 10x multiplier compared with Linux. According to GitHub's billing documentation, standard runners are free in public repositories. Once it went public, a macOS job for `swift test` was enabled at no cost.
- **Build environment:** no Swift toolchain and no network access to developer.apple.com or swift.org. As a result, Swift tests are delegated to CI on macOS and link checking to a workflow.
- **Request added during the session:** a secure coding module, because of its weight in banking interviews. It was added as Module 42 and as the "Security" category of the interview bank.
