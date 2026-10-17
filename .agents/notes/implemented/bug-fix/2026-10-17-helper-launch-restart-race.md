# Agent Note: Launch the helper without the ten-second restart race

Status: implemented

## Problem

Users reported that the notification plugin seemed to start only once a conversation began. The Host plugin and its notification capability were loaded at launch; the late arrival was the menu-bar helper, and the delay was up to ten seconds.

`ensure()` in `lib/helper-lifecycle.js` decided the helper was already running from one signal: `helper-status.json` held a valid pid and its heartbeat was newer than five seconds. It never asked whether that pid still existed. After a quick Desktop restart the previous helper's final heartbeat can still be inside the freshness window although the process has exited, so the new Host skipped the launch and waited for the 10-second watchdog.

The live timeline showed the race directly: on the 19:17 restart the helper process started twelve seconds after Desktop, while on the 19:22 restart — when the stale file had already aged out — it started two seconds after. The 19:17 helper appeared just after the user's first message, which is why it looked like a start-on-conversation behaviour. The freshness-only check dates from 0.5.0 and was not introduced by the DSH update; a faster-starting, more frequently restarted Desktop made it visible.

## Decision

Commit `222c2b5` adds a liveness probe to the existing gate and a short recovery ladder ahead of the watchdog (`lib/helper-lifecycle.js`):

- `pidAlive` probes the recorded pid with signal 0 (`lib/helper-lifecycle.js:6-11`). The helper runs as this user, so a signal is the same authority the Host already holds; any failure — `ESRCH`, or a reused pid this user cannot signal — counts as "not our helper".
- The skip condition is now freshness **and** liveness (`lib/helper-lifecycle.js:36`).
- Activation schedules recovery probes at 1 s, 2.5 s and 5 s in addition to the 10-second watchdog so a helper that exits just after activation is replaced within about a second (`lib/helper-lifecycle.js:18-19,44-47`).
- Every probe keeps the same freshness-plus-liveness gate, and `open -g -j` goes through LaunchServices, which reuses a running helper instead of starting a duplicate (`lib/helper-lifecycle.js:39-41`).
- The existing scope rules are unchanged: darwin only, only inside the official Desktop host process, never from a CLI profile (`lib/helper-lifecycle.js:25`).

Evidence: commit `222c2b5`; the helper-lifecycle regressions in the same commit, with the full plugin suite passing 115/115 against the installed 0.2.1-rc.1 runtime packages; [`CHANGELOG.md`](../../../../CHANGELOG.md) under Unreleased → Helper lifecycle.

## Alternatives considered

**Keep the freshness window as the only gate.** This was the shipped behaviour and the defect: a heartbeat written seconds before the process exits is indistinguishable from a live helper's heartbeat, so the launch is skipped exactly when it is needed. Liveness is the missing signal, and a signal-0 probe is available to the same user without any new dependency.

**Rely on the existing 10-second watchdog and add no probes.** Rejected because the watchdog *is* the observed gap: it recovers the helper, but only after the menu bar and the notification helper have been absent for up to ten seconds — the symptom users reported. The probe ladder shortens the worst case without changing what "already running" means.

**Drop the gate and launch unconditionally on activation.** Not taken: the gate is retained on every probe, including the new ones (`lib/helper-lifecycle.js:36`), because it is what leaves a healthy helper untouched. LaunchServices de-duplication is the safety net for the conservative direction of the error, not a substitute for the check.

**Prove the recorded pid is *this* helper rather than merely alive.** Rejected as unnecessary: the probe's failure direction is conservative. A pid that no longer exists, or has been reused by a process this user cannot signal, is treated as "not our helper" and the ladder simply asks LaunchServices to open the app again, which does nothing when a helper is already running. Verifying the process command line would add a second source of truth for an error that is already safe.

## Consequences

- Recovery is bounded by the probe ladder rather than the watchdog: a helper that dies immediately after activation is replaced in about a second, and the watchdog still covers later exits.
- Three extra timers are scheduled per activation; all of them are `unref`'d and cleared on disposal, so they neither hold the Host open nor survive reload (`lib/helper-lifecycle.js:45-47`).
- The activation path still fails silently by design — installation, launch and probe errors are swallowed so a broken helper never breaks DSH — which means a future regression has to be found in the helper's own log — `applet.log` inside the state directory, by default `~/.dsh/dsh-jump/applet.log` (`macos/main.swift:23`) — not in a Host error.
- The evidence is a restart timeline plus the regression suite. A helper that exits more slowly than the freshness window would still delay the first probe; that case remains unverified and would show up as a delayed `ensure()` decision in the Host log rather than as a skipped launch.

## Testing

- `tests/helper-lifecycle.test.mjs` covers a fresh-but-dead pid launching at activation, a fresh live pid being kept, the expiry path, the probe ladder and disposal cleanup (`222c2b5`).
- The behaviour is observable in production without touching the installed app: after a restart, the helper process start time should trail the DSH main process by one to two seconds, including on two quick restarts in a row.
