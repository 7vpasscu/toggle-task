# Task Track

Cross-platform time tracking for macOS and Windows, with a shared project/session model and a Notion synchronization boundary.

- macOS: SwiftUI + AppKit (`macos/ToggleTask`)
- Windows: WPF + .NET 8 (`windows/ToggleTask`)
- Browser prototype for testing the macOS flow without a Mac (`prototype`)
- GitHub Actions for macOS build, tests and app artifact

Product name: **Task Track**. Existing repository, source module names and the preview storage key are retained for compatibility.

Preview: `node prototype/server.cjs`, then open http://127.0.0.1:4173. `Ctrl+D` (or `Cmd+D`) switches manual/timer mode. Use the top-right menu for projects, reports, local profiles and theme settings. Click a session to edit its duration and dates.

Checks: `node --test prototype/core.test.cjs`; `npm ci --prefix prototype`, then in `prototype`, `npx playwright test --config playwright.config.cjs`. On Windows the browser tests use installed Edge; elsewhere install Chromium with `npx playwright install chromium`.

Native builds/tests run in GitHub Actions. Artifacts: `TaskTrack-macos` and `TaskTrack-windows`. In the native app, enable activity tracking, use another application for at least 15 seconds and return to review a suggestion. Recording is off on launch.

See [reference analysis and current limitations](docs/TOGGL_REFERENCE.md). Notion authentication is not configured; local profiles are not authenticated accounts.
