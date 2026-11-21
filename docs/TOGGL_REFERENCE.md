# Task Track: interface references and scope

Reference reviewed: official `toggl-open-source/toggldesktop`, commit `013038304ee8e9154db4a45fb642716956cf153b`. Downloaded into ignored `research/vendor/toggldesktop`, sparse checkout of `src/ui/osx`. The repository is archived and its README says the native clients were rewritten. It is historical source, not evidence of the current application's internals.

Files inspected under `src/ui/osx/TogglDesktop/Features`:

| Source | Observation | Task Track adaptation |
| --- | --- | --- |
| `Timeline/MainDashboardViewController.swift` | Persistent timer header above List/Timeline tabs; date navigation | Shared composer above Lista/Calendario |
| `TimeEntryList/TimeEntryDatasource.swift` | Day sections; 64-point cells and 36-point headers in this version | Personal sessions grouped by day, duration aligned right |
| `Timeline/TimelineFlowLayout.swift` | Time labels, positioned blocks, current-time line, zoom and overlap layout | Daily timeline, clipped day intervals; advanced dragging/zoom still pending |
| `MainWindow/MainWindowController.xib` | Compact, resizable window | Compact desktop window, no permanent sidebar |

Visual evidence: the user's light/dark List, Calendar and Details screenshots. Approximate window scale: 420 logical pixels. Later explicit direction: preserve Toggl's organization with Material 3 Expressive's visual language. This supersedes pixel-for-pixel duplication. Material roles, tonal containers, rounded groups, prominent primary action and reduced-motion support are custom implementations; no Toggl/Google logos, assets or source files are incorporated into the product.

Official installer downloaded without executing: `research/downloads/Toggl-arm64.dmg` (138857205 bytes), from https://toggl.com/toggl/desktop/downloads/Toggl-arm64.dmg via https://toggl.com/apps/desktop/mac. SHA-256 `7367c8955101f599b9a6e349a4ea73d49b728a259814cf9abe5d4a485a7b94aa`. This is the file served by the current site, not a verified binary match to the archived source or supplied screenshots. Windows cannot execute it.

References:
- https://github.com/toggl-open-source/toggldesktop (BSD-3-Clause; retained in the ignored research checkout)
- https://support.toggl.com/en-us/article/toggl-track-desktop-app-for-macos-1669b8x/
- https://design.google/library/expressive-material-design-google-research
- https://m3.material.io/styles/color/roles

## Identity and activity recording

List, Calendar, CSV and preview JSON exports use stable worker IDs; missing owners are excluded. Display names and Notion Created By never establish ownership. Native suggestions are also worker-scoped. The browser profiles and native local identity are **not authenticated accounts**. Production requires a server to derive the worker from the authenticated session and enforce workspace/project membership on every read and write, with per-user cache isolation and logout cleanup. UI filtering alone is not authorization. Notion authentication and the sync service remain unconfigured; no personal or team Notion workspace was modified.

Native activity capture is opt-in on each launch. It samples only the foreground application name/identifier every 2 seconds. No window titles, URLs, screenshots, keystrokes or document contents. Pauses after 2 minutes idle; OS sleep/session notifications stop the interval, and polling gaps over 10 seconds never count as work. Intervals shorter than 15 seconds are discarded. Activity is stored locally, retained up to 7 days (pruned when sampled), with a clear action. Suggestions are reviewed against a chosen project and may overlap existing time. A stable activity-derived session ID prevents duplicate conversion. Notion receives nothing while disconnected.

macOS: NSWorkspace frontmostApplication and CoreGraphics idle time. Windows: GetForegroundWindow/GetWindowThreadProcessId and GetLastInputInfo, with session/power events. Browser: reports the native-only limitation, does not simulate observation of other apps.

Primary API references:
- https://developer.apple.com/documentation/appkit/nsworkspace
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid

## Remaining parity work

Native UI is an initial adaptation, not yet visually verified on macOS. Browser has more complete work-type/units editing and project reports than the native clients. Windows currently uses the dark tonal palette. Calendar dragging/resizing, automatic project rules, Pomodoro, third-party calendar imports, full multi-account login and production synchronization remain open. Native foreground capture needs real-device testing, especially sleep/lock, permission behavior and retention. Build/test success is not a substitute for those checks.
