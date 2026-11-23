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

### Local CSV database

Task Track loads and saves `task-track.csv` automatically, including while Notion is offline. Each client keeps a separate file under the current OS account. The first launch with no CSV migrates that client's existing history and active timer. Original legacy files and browser storage are preserved. Use the same browser profile for the first preview launch.

| Client | Default file |
| --- | --- |
| macOS | `~/Library/Application Support/TaskTrack/task-track.csv` |
| Windows | `%LOCALAPPDATA%\TaskTrack\task-track.csv` |
| Browser preview | `TaskTrack/Preview/task-track.csv` under the user data directory. Settings → Local database shows its absolute path. |

Project and session rows use the personal sample database's column names. `Parent item` and `Sub-items` reference stable local IDs. `Worker ID` identifies the worker independently of `Created By`. Times are ISO 8601 UTC. Durations and totals are numeric minutes. Rollups are calculated at save time. Lists and per-type quantities use JSON within a cell. A settings row preserves the preview profiles, catalog and preferences. Properties without a local value stay empty.

Close Task Track before editing the CSV externally. For a backup of all local profiles, copy the file. The existing CSV export in Settings is a filtered report for one profile. Notion catalog access and local time storage are independent. Session upload and automatic reconciliation with Notion are still pending.

