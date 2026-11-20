# Development method and acceptance gates

Iterative task-based development: discover → define observable outcomes → implement complete journeys → test domain logic → exercise the UI → correct → release.
Sources: https://www.nngroup.com/articles/usability-101-introduction-to-usability/ and https://developer.apple.com/tutorials/develop-in-swift/testing-and-validation-conclusion

Design direction requested by the user: Material 3 Expressive adapted to desktop.
Sources: https://m3.material.io/ and https://design.google/library/expressive-material-design-google-research
Tonal surfaces, prominent timer action, pill navigation, grouped lists, large readable duration, light/dark themes, palette selection, visible keyboard focus, reduced motion. CSS transitions are an approximation, not Google's spring implementation. No Google logos or proprietary assets.

Local preview acceptance: start/stop with stable ownership; survive reload; add/edit sessions; reject backwards/future/overlapping time for same worker; delete with undo; create/archive projects; totals from historical time plus sessions; quantities grouped by work type; profiles with stable IDs; filtered history; reports; CSV and JSON export; clear Notion disconnected state.

Production gates still required: real Notion authorization, durable server idempotency/unique keys, authenticated user identity, multi-device conflict strategy, paginated reads, rate-limit retry/backoff, native builds and UI smoke tests, code signing, recovery/backup import, usability study with intended users.

Browser localStorage is a preview store, not a multi-user database. Profiles are labels with stable IDs, not security boundaries. Revision checks and storage notifications detect common multi-tab conflicts but are not transactional cross-device locking. Use one editing tab.

Notion: retain Recorded By independently from Created By. Never write rollups/formulas. Use a stable session UUID, UTC timestamps and explicit worker ID. Query-before-create alone cannot guarantee uniqueness under concurrency; a sync service with a unique session key is required. No app tokens are present in the browser or repository.

### Work type catalog in the browser preview

Project and Type support substring search. Use the arrow keys and Enter to select a match. Switch fields with Tab. To add a type, enter its full name and choose **Create type**. Units accepts a whole number from 0 to 100000.

Without integration credentials the preview uses the three types from the personal sample's `Type of Work` property and saves additions in this browser. To enable live catalog reads and additions, provide `TASK_TRACK_NOTION_SOURCE` (the personal replica's data source ID) and `TASK_TRACK_NOTION_TOKEN` to the local server process and restart `node prototype/server.cjs`. Share only the personal test database with that integration. The source check restricts the endpoint to that replica. Settings shows the catalog connection state. Session records continue to use local storage.
