# Task Track — macOS MVP

Native SwiftUI + AppKit time tracker.

## Included

- Start/stop timer with an activity description and project picker.
- Personal session history and calendar.
- Menu bar status item and popover.
- Stable session and worker IDs independent of Notion `Created By`.
- Manual mode with ⌘D and a session editor.
- Optional foreground-app activity suggestions.
- Automatic local CSV persistence, legacy migration and running-timer recovery.
- `TimeTrackingSyncClient` boundary prepared for Notion.

## Run on macOS

```bash
cd macos/ToggleTask
swift run
```

AppKit requires Xcode/macOS. GitHub Actions builds and tests it on a macOS runner.

## GitHub Actions

`.github/workflows/macos.yml` builds the package on `macos-latest` for every push to `main`/`master` and every pull request, then uploads a runnable app bundle.
