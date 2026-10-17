# Agent Note: Reject stale reminder ownership and unconfirmed safe tests

Status: implemented

## Problem

Two assumptions in the reminder path were wrong, and both produced user-visible misbehaviour.

Quiet-mode ownership was Host-global. A background client window could therefore claim the foreground and silence reminders that belonged to the window the user was actually looking at, and an old presence packet could bring back a focus state after it had stopped being true.

Safe-test status treated macOS accepting a notification request as success. A failed queue write, a rejected request and a notification nobody clicked all reported the same outcome, so the diagnostic could claim a delivery that never happened. An older receipt, or a session acknowledgement belonging to a different test, could also confirm the current one; and a duplicate `turn/end` from an earlier child turn could close a newer turn's summary.

## Decision

Foreground ownership is per client window. `lib/foreground.js:1-2` keeps bounded, expiring leases (five-second TTL, at most 128 client views) keyed by client identity; `lib/foreground.js:11` ignores a packet whose sequence is not newer than the one already recorded, so an out-of-order packet cannot override a later state, and a focus change or disposal releases only that window's lease. Reminder suppression stays a preference: disabling or quieting reminders never suppresses an explicitly opened form, an approval or a question answer.

Turn boundaries are generation-aware. `lib/notifications.js:73,79,94-95` drop an event whose turn is older than the latest observed turn for that session, so a duplicate end from an earlier child turn cannot mark a newer turn idle or flush the parent's completion early.

The safe test carries its identity end to end. A validated test ID (`lib/diagnostics.js:3`) travels from the queue entry through the notification click into the authenticated session acknowledgement; `lib/index.js:105` accepts an acknowledgement only when the test ID, session ID and creation time all match. `lib/diagnostics.js:7-29` reports distinct states instead of one success: `queue-failed`, `waiting-for-helper`, `waiting-for-click`, `opening`, `confirmed`, `timed-out`, `system-rejected`, `expired`. A queue-write failure reports failure, and an accepted receipt reports acceptance, never display. A plugin/helper version mismatch is reported explicitly instead of assumed.

Evidence: commit `e45f9b9` (merged by `ba5f106`), [`CHANGELOG.md`](../../../../CHANGELOG.md) under 0.3.1, and the v0.3.1 section of [`docs/compatibility.md`](../../../../docs/compatibility.md).

## Alternatives considered

**Keep one foreground state for the whole Host.** This was the shipped behaviour and the reason the bug existed: it cannot distinguish two windows of the same client, so whichever wrote last won, including a background one. Bounded per-client leases cost a TTL, a history cap and sequence handling, and bought an ownership rule that matches what the user sees.

**Treat a macOS acceptance receipt as the test result.** Rejected: acceptance means the system took the request, while whether a banner appears depends on system settings, focus modes and screen state. Reporting acceptance as success is exactly the unverifiable claim the diagnostic exists to avoid, so the accepted state is its own visible step and only a matching session acknowledgement confirms the jump.

**Confirm a test from any receipt or session acknowledgement.** Rejected: without a binding to the test's identity and time window, an earlier test's receipt or another session's acknowledgement confirms the current test. The shipped check binds test ID, session ID, request ID and timestamps.

**Retry an unconfirmed submission automatically.** Rejected: an automatic retry would re-post or re-submit after an unknown outcome, and the correct information in that state is that the result is unknown — not a second attempt.

**Expose session IDs, paths, or command and error text in the diagnostic status** so a failure is easier to explain. Rejected: the status stays limited to validated versions, coarse states and timestamps, and the diagnostic surface excludes conversation content, local paths, credentials and raw logs.

## Consequences

- Quiet mode now has retention limits of its own: leases expire after five seconds and the client history keeps at most 128 views, so a delayed packet from an evicted identity is outside the retained history.
- The safe-test result is deliberately weaker but honest — several states now describe partial progress, and none of them claims a visible banner.
- The diagnostic cannot explain a failure beyond versions and coarse states by design; explaining one requires the helper's own record, not the status payload.
- The refreshed status is only as good as the helper's delivery receipt: the plugin side verifies identity and timing of what the helper writes, it does not observe the notification centre.

## Testing

- `tests/foreground.test.mjs` covers concurrent client leases, out-of-order and expired presence, and disposal; `tests/notifications.test.mjs` covers stale child generations and reminder ownership; `tests/diagnostics.test.mjs` covers queue failure, receipt identity, stale/malformed files and bounds.
- `tests/native-notification-diagnostics.swift` compiles the helper's payload and diagnostics sources and checks the identity carried through the native side.
- These are source and component checks. Live Desktop reload and a real notification-click acceptance remain separate steps, as recorded in [`docs/compatibility.md`](../../../../docs/compatibility.md).
