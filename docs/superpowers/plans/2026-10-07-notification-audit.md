# Four notification priorities audit implementation plan

> Implement inline with superpowers:executing-plans. Existing four-priority scope is user approved; preserve all native interaction behavior.

**Goal:** Complete the four accepted borrowing priorities by repairing observed-window reminder suppression, stale child events and visible test-navigation diagnostics.
**Architecture:** Keep singular Host event ownership, authenticated Connection RPC and private same-user transport. Add bounded per-client foreground leases and identity-bound safe-test delivery/navigation receipts. No new listener, model request or automatic decision.
**Tech Stack:** Node ESM, Swift AppKit/UserNotifications, existing CI and CLT installer.
**Spec:** docs/design.md and the accepted four-priority comparison (standalone installation; settings; aggregation; visible runtime/test status).

## Global constraints
- Original answers, commands, session routing and native Markdown remain unchanged.
- Persist only bounded diagnostic identities/timestamps locally; expose no session IDs, paths, command/error text through status.
- Never claim a queued notification was displayed; only a matching authenticated session acknowledgement confirms navigation.
- Preserve app/profile backups and conversation history. No real model/approval commands for tests.

## Review focus
- A background client cannot override the actual foreground client; old presence packets cannot resurrect stale focus while their bounded client history is retained.
- A duplicate end from an earlier child turn cannot mark its newer turn idle or flush root completion early.
- An old/different test receipt or session acknowledgement cannot confirm the current safe test.
- Failed queue writes must not report success; helper delivery acceptance does not prove a visible banner.
- Plugin/helper version mismatch and unknown legacy diagnostic state remain explicit.

## Task 1: Reminder ownership boundaries
Files: lib/foreground.js, lib/index.js, lib/client.js, lib/notifications.js; Node tests.
- [x] Reproduce multi-client quiet override and old-child end with failing tests.
- [x] Add bounded expiring client leases with packet order and generation-aware child completion.
- [x] Verify native forms remain available when reminders are quiet/disabled.

## Task 2: Safe test and visible status
Files: lib/diagnostics.js, lib/index.js, lib/notifications.js, lib/client.js; macos/NotificationPayload.swift, macos/Diagnostics.swift, macos/main.swift; tests and build/package checks.
- [x] Reproduce queue-failure success and missing current-test confirmation with failing tests.
- [x] Carry safe-test ID from queue through notification click and authenticated ack, retain private bounded receipts.
- [x] Render explicit queued/system-accepted/click-pending/opening/confirmed/failure/timeout state plus version mismatch.
- [x] Test receipt identity, stale/malformed files, privacy, bounds and native payload compatibility without real notifications.

## Task 3: Publish and deploy
- [x] Run full Node/native/package checks and fresh independent review.
- [ ] Build/install with backup; verify actual helper version/signature.
- [ ] Push reviewed changes, verify CI, publish matching source release/checksum.
- [ ] When Mac is unlocked, restart Desktop normally and verify live settings/click state; never bypass lock or repeat pending prompts.
