# Agent Note: Add a native menu-bar session panel to the existing helper

Status: implemented

## Problem

The plugin could tell a user that a session needed attention, but not what was running across sessions or what had just finished: the menu bar had a notification entry point and no view of session state, so seeing that state meant switching DSH windows one by one.

A session view also has to be built without becoming a second source of truth. The Host already owns workspaces, pin order, session titles, turn state, todos and pending approvals/questions; a panel that derived its own versions of those facts would disagree with DSH and with the notification path that shares the same state directory.

## Decision

`DSH Notify.app` gains an `NSStatusItem` + `NSPopover` panel, rendered by the helper that already exists. No second application, browser window or web service is added, and the panel reuses the helper's private same-user file transport plus the plugin's authenticated Desktop navigation.

The panel shows connection-local activity (pending input or approval, failures, running sessions, nested subagents included) and the five most recent root sessions, each with a one-line preview of the current turn and a completed/total ring from the official todo projection. `menuBarEnabled` (default `true`) is a validated boolean in the existing private settings file; turning it off removes the status item and stops the extra history reads while notifications, approvals and question forms keep working.

Facts come from official Host services only: workspace names and membership with the official pin order, live session/agent/turn state, official titles, the todo projection, the existing interaction state for pending requests, and cancelling read-only queries for cold sessions (`lib/menu-source.js`). The panel consumes those facts; it never owns them, and it installs no second request handler.

## Wire contract

The Host publishes one complete `session-menu.json` snapshot per revision into the private state directory: `version: 1`, a `generation` per activation, a monotone `revision`, `updatedAt`, `enabled`, `availability` (ready/loading/unavailable) and rows whose flat node list has unique session IDs and retains ancestor closure, with an explicit `omittedCount` (`lib/menu-host.js:49-58`, `lib/menu-model.js:96-98`). The helper validates a snapshot before rendering it and keeps the last valid view when a new one is malformed (`macos/SessionMenuModel.swift`).

The bounds are part of the contract, not tuning constants: at most 4 MiB for the whole envelope and 2,000 nodes (`lib/menu-host.js:50,55`, `lib/menu-model.js:29`, `macos/SessionMenuModel.swift:55,74`), directory `0700` and file `0600` (`lib/menu-host.js:56-58`), display changes coalesced to at most 1 Hz with a 2-second heartbeat (`lib/menu-host.js:53`), cold history discovery no more frequent than every 30 seconds with at most 4 concurrent read-only observations (`lib/menu-host.js:33`, `lib/menu-source.js:9,126`), and a snapshot older than 6 seconds presented as stale rather than as session facts (`macos/SessionMenuModel.swift:64`, `lib/index.js:60-62`). Titles are clipped so the displayed `workspace · session` line stays within 200 Unicode characters and previews to 240 on one line (`lib/menu-model.js:6,34-35`). A budget overrun drops the lowest-priority complete branches and reports how many nodes were omitted instead of truncating silently.

## Alternatives considered

**Put the session list in a browser window or a small web service.** Rejected in the approved design: it would add a second rendering stack, a second place where session facts are shown, and a live connection to maintain, for a view whose value is being one click away in the menu bar. The panel reuses the helper the user already runs.

**Add a second read/clear-error action set to the panel.** Rejected: DSH owns read state, and a parallel model would drift from the official one and add a second way to dismiss an error. The panel shows status and priorities and owns no acknowledgement; the private read marks earlier builds wrote are retained but ignored.

**Aggregate several Hosts or remote sessions.** Rejected for this capability: a multi-Host merge needs a state-namespace and identity model the plugin does not have, and navigation is bound to one authenticated Desktop connection. The supported scope stays one active local Host/state namespace.

**Refactor the notification producer so the panel and notifications share one model.** Rejected: the notification path is the plugin's load-bearing behaviour and was already verified. The panel takes a narrow interface — titles, pending state, a bounded snapshot — instead of reshaping that path.

**Keep the scrollable panel the design first described.** The approved design allowed a scrollable content area; the shipped panel uses fixed viewports with explicit expand/collapse arrows and up/down controls, no wheel scrolling and no scrollbars, and keeps expanded rows reachable (`CHANGELOG.md`, 0.5.0). Long trees are still reachable, so the earlier scrolling model lost to a predictable set of rows on screen.

The root-quota and single-row pinning rules are refined in [the subtree-visibility decision](../bug-fix/2026-10-18-menu-subtree-visibility.md).

Application actions, settings navigation and popover dismissal are refined in [the status-action decision](2026-10-18-status-menu-actions.md).

**Compute a session's progress from descendant todos or from elapsed time.** Rejected: the ring is completed/total of that node's current todo list only. A parent's ring never sums its children's plans, and the ring is not an estimate of how far the model run has progressed.

## Consequences

- The menu costs the Host a bounded set of reads: a 250 ms refresh tick, coalesced 1 Hz writes, a 30-second discovery cycle and a small per-session fact/revision cache rather than full log reads. Disposal cancels the reads, clears leases and blocks later writes (`lib/menu-host.js:63-73`).
- Session facts are connection-local: activity means runs observed or started during the current connection, so a session that ended while the plugin was not loaded appears as history or as unknown rather than as a failure. The icon tracks the current run batch and does not alert for user cancellations.
- Panel rows reuse the authenticated Desktop navigation and are confirmed only by a matching acknowledgement; there is no browser fallback, and a session whose lineage is unknown fails visibly instead of guessing a workspace.
- The five-root history window, the exclusion of subagents, empty sessions and sessions already shown in the activity area, and the omission count are visible behaviour rather than tuning constants.

## Testing

- `tests/menu-model.test.mjs`, `tests/menu-source.test.mjs`, `tests/menu-host.test.mjs`, `tests/menu-cohort.test.mjs` and `tests/menu-control.test.mjs` cover priority and history ordering, ancestor promotion, cycle and orphan handling, real todo progress, bounds and omission, lifecycle/disposal, stale-result rejection and the private preference command.
- `npm run test:native` compiles `tests/native-session-menu.swift` and `tests/native-menu-control.swift` against the real Swift sources: snapshot decode and revision rules, layout bounds, deep trees, one-line previews, ring counts, keyboard/accessibility and disable/re-enable.
- These establish source and component behaviour only. Visible live Desktop acceptance is recorded separately in [`docs/compatibility.md`](../../../../docs/compatibility.md).
