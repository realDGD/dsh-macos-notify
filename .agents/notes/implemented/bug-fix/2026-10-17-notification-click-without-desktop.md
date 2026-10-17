# Agent Note: Hand a notification click to Desktop when Desktop is closed

Status: implemented

## Problem

The helper follows Desktop: when DSH quits, the menu-bar helper exits with it (`macos/DesktopLifecycle.swift`, and `onStopped` terminating the app at `macos/main.swift:90`). But a notification that was already delivered stays in Notification Center, and clicking it makes macOS start the helper again just to deliver the click response.

`applicationDidFinishLaunching` checked the Desktop lifecycle first and returned when Desktop was not running, before wiring `UNUserNotificationCenter`'s delegate or registering the interaction handler. The launch whose only purpose was to deliver that response therefore dropped it: clicking an old notification did nothing at all, and DSH was not started either. This was not a failed navigation — the click was never received.

## Decision

Commit `1719a09` reorders the launch path and gives the no-Desktop launch a purpose (`macos/main.swift`):

- `UILocalization.poll`, `installEditMenu`, `center.delegate = self`, `NotificationInteractions.shared.register()` and the `openSession` closure all run before the Desktop lifecycle gate (`macos/main.swift:76-88`), so a launch response is always received.
- When Desktop is absent the helper sets `awaitingNotificationLaunch`, logs `started without desktop; awaiting notification response`, keeps the run loop alive for six seconds, and terminates if nothing arrives (`macos/main.swift:94-100`).
- A click takes the same `handleClick` path as a normal click: `jump(to:)` writes the pending session request and opens DSH through LaunchServices, then the helper exits 1.5 seconds after the hand-off rather than lingering as a helper with no Desktop state (`macos/main.swift:331-336`). The freshly started Desktop boots its own helper once its profile is up.
- An interaction-class click (approval or question) arriving without Desktop is logged as `interaction-click-without-desktop` and opens nothing (`macos/main.swift:302-305`), because an interaction window needs live Host state to be meaningful.
- Two hidden presentation hooks make the path verifiable in isolation: `--simulate-no-desktop` and `--simulate-click <url>`, alongside the existing `--question-panel` hook (`macos/main.swift:91-93,101-107`).

The JS half already supported the hand-off and did not change: it accepts a pending request for 120 seconds (`lib/index.js:54`), and the client polls for it every second (`lib/client.js:252`), so a normal Desktop cold start fits inside the window.

Evidence: commit `1719a09`; [`CHANGELOG.md`](../../../../CHANGELOG.md) under Unreleased → Helper lifecycle.

## Alternatives considered

**Keep the lifecycle check first and accept the dropped click.** This was the shipped behaviour: the notification stays in Notification Center, macOS starts the helper to deliver the response, and the helper exits without listening. It fails silently, which is the worst outcome for a notification plugin, so the ordering had to change.

**Make the helper a resident process that keeps running after Desktop exits.** Rejected: it reintroduces the second owner of the helper lifecycle that the Desktop-owned design removed. A resident helper would sit without Desktop state, keep its status heartbeat alive, and race the helper the next Desktop launch starts; exiting after the hand-off leaves exactly one helper owner. For the same reason the earlier login `LaunchAgent` design was not revived.

**Open the interaction window anyway when Desktop is absent.** Rejected: an approval or question window with no live Host cannot be answered and would show stale content — worse than doing nothing. Logging the click keeps the path observable without pretending to serve it.

**Wait longer than six seconds for the launch response.** Not chosen: macOS delivers the response right after launch, so the window only needs to cover a delivery that is already in flight; a longer wait keeps a helper with no Desktop state alive and competes with the Desktop that the click is starting. The 1.5-second exit delay after a successful hand-off serves the opposite need — letting the write and the `open` call finish.

## Consequences

- Clicking a delivered notification after quitting DSH now starts Desktop and navigates to the session, provided the notification has not been cleared from Notification Center.
- The helper still follows Desktop start and exit, so the menu-bar icon is absent while DSH is closed; that is the design, not a regression.
- End-to-end latency for a cold-start jump is DSH's own start time plus the client poll (at most about a second) and the navigation wait — typically ten to twenty seconds, during which the DSH window appears and then switches to the target session.
- The validation was an isolated staging build with `--simulate-no-desktop --simulate-click` against a temporary state directory: request file written, Desktop opened through LaunchServices, helper exited about 2.5 seconds after the click. The real operating-system path — quit DSH, click an old notification in Notification Center — was not exercised in that session and remains a manual acceptance step.

## Testing

- The isolated run used a staging build (`--simulate-no-desktop --simulate-click "<url>" --state-dir <temp>`), which leaves the installed helper untouched; the helper log shows `started without desktop; awaiting notification response`, then the request, the Desktop open and the exit.
- Live acceptance is a deliberate manual step: quit DSH, click a notification that is still in Notification Center, and confirm Desktop opens on the session, with `open-session.json` written in the state directory and the helper gone afterwards.
