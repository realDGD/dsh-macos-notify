# Compatibility and evidence

## Supported scope

- Target: official DSH Desktop 0.2.0-rc.2; community plugin and local macOS helper.
- Node: 22+. DSH itself supplies its Host/client services.
- Native deployment target: macOS 13+. Build is for the local architecture; this is not a certified universal binary.
- Host native transport is private same-user files; navigation/settings use existing authenticated Connection Fetch routes.
- Default state namespace and helper bundle identity retain historical compatibility; they are not an additional model bridge or a secret.

## Evidence levels

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| Node tests with pinned Cordis | Request lifecycle, first-wins, event aggregation, settings validation and routing contracts | Actual notification delivery or exact Desktop UI rendering |
| Tests with installed Desktop Cordis artifact | Plugin API registration/disposal on that exact runtime | All future DSH releases |
| Real AppKit native regression | Question layout, scrolling, original choice labels, command/context display and matching navigation ack behavior | Notification-center actions by themselves |
| Local source build and signature check | Current architecture can compile with CLT; bundle integrity verifies | Gatekeeper acceptance of downloaded prebuilt apps or Intel/older OS device verification |
| Safe live notification click | Real callback and exact Desktop session ack on the test machine | Execution of real commands or new model messages |

Prior implementation was verified on official Desktop 0.2.0-rc.2, macOS 27.0.1 / Apple Silicon. For v0.2.0, the official package installer loaded the source tarball in a fresh isolated profile. The production Desktop loaded the renamed plugin, rendered the settings section, persisted a toggle through authenticated RPC, and reported matching plugin/helper versions plus authorized notification permission. The helper consumed and posted the safe test queue entry; the corresponding notification-click acceptance check is recorded separately. No blanket support is claimed for older Desktop versions.

## Operational limits

The current helper coordinates one local active DSH profile/state namespace. Multiple simultaneous Hosts sharing it require separate state directories/helpers and are not certified here. The official Desktop Host starts the helper through LaunchServices; CLI profiles do not start it automatically. The helper follows the Desktop bundle's running processes, so minimizing/closing a window does not stop it, but quitting Desktop does. Installation retires the old managed login LaunchAgent and keeps a backup. Aggregation can only track descendant runs observed while the plugin is loaded. Foreground leases expire after five seconds and retain sequence history for at most 128 client views; delayed packets from an evicted identity are outside that retained history. Result-unknown submissions never auto-retry. Notification previews and action availability depend on macOS settings and available banner space; default approval click always opens details.

## v0.2.0 distribution checks

- Public GitHub installation `github:realDGD/dsh-macos-notify#v0.2.0` succeeded through the official package manager in a second isolated profile; no model or command was run.
- Downloaded the published release tarball and SHA256SUMS; its checksum matched. Archive ownership headers are normalized, and local state, session identifiers, machine paths and official binary/icon assets are excluded.
- [Release-tag CI](https://github.com/realDGD/dsh-macos-notify/actions/runs/37544661825) passed Node 22, Node 24 and the hosted macOS native regression/build/signature jobs. These hosted checks do not certify actual notification behavior on every OS/architecture.
- The renamed production helper posted the new safe test notification. The new user-click acceptance is still pending; prior real Allow/Deny/question callbacks and verified session navigation belong to the earlier native implementation.

## v0.3.0 rendering checks

- Node renderer regressions verify table/list/code rendering, four math delimiters, exact TeX in blockquotes/nested lists, inert HTML, blocked image loading, invalid-formula fallback and all vendored file/font hashes and notices.
- Real native AppKit checks cover parameter formatting/original view/copy, large numbers/escapes/duplicate keys/leading combining characters, narrow-window command/parameter wrapping and existing question/navigation regressions.
- Actual WebKit in the native question disclosure loads local fonts, renders tables and formulas, wraps long table cells, keeps a bounded scrollable context pane and blocks programmatic external navigation. The context renderer loads only when expanded.
- This is component/layout evidence. Live visible-window and notification-click acceptance remain separate checks; older macOS/Intel real-device validation is still required.

## v0.3.1 reminder and diagnostic checks

- Regression tests cover concurrent client leases, out-of-order and expired presence, disposal, stale child generations, queue failure and exact test/session/request/timestamp-bound confirmation.
- The native safe-test payload retains its identity through the notification callback. Delivery receipts contain only a validated test ID, coarse acceptance state and timestamp, use private permissions and retain at most 32 records.
- A macOS accepted receipt means the system accepted the notification request. Actual display depends on system settings. Only a matching authenticated Desktop selection acknowledgement reports a confirmed test jump.
- Live Desktop reload and notification-click acceptance remain separate from these source/component checks.

## v0.4.0 session-menu checks

- Node regressions cover official names/Pins, normal forks versus subagents, current-turn and inherited-message boundaries, actual todos, waiting-state ownership, bounded graph snapshots, cold-read cancellation/disposal and stale-result rejection.
- Real native component tests cover 400 expanded children, deep/narrow trees, Unicode titles, one-line previews, scroll bounds, keyboard/accessibility, loading/stale recovery and menu-only disable/re-enable. A real independent question window retains its draft during menu navigation/close.
- Cold child navigation uses the official SubagentAddress derived from a fresh private Host snapshot. Unknown/stale lineage produces a visible failure instead of guessing a workspace. No browser fallback is used by menu clicks.
- These checks establish source/component contracts. Current Desktop reload, visible menu interaction and real notification/session-selection acknowledgement remain separate live acceptance steps. macOS 13/Intel device acceptance is still unverified.

The menu uses the official 0.2.0-rc.2 session and format-catalog peer packages to fold the same retained observation; `sessionPersistence.stat` supplies lightweight revision tokens. Cache identity includes the persistence instance and session revision. Unchanged histories do not exceed the SDK’s prepared-cache capacity with repeated full reads, and no second uncancellable surface read is held across disposal. Local source installs must run `npm ci --ignore-scripts`; DSH package installs resolve the declared peer packages.

## v0.5.0 activity semantics

Activity is connection-local. Existing running/waiting sessions are captured at connection; official live turn/start events capture even runs ending between refresh ticks. Historical errors and idle pins are not activity. Pin order applies within tracked activity. Recent history keeps five roots after excluding tracked activity; child sessions never occupy a root-history slot. Read/filter controls are removed, and legacy private read marks are retained but ignored. Cancellation causes remain separate from actual interrupted/error/max-tokens results, including unknown legacy causes. The one-local-Host boundary and existing size/refresh bounds still apply.


The fish icon tracks the current concurrent run batch before snapshot writes are coalesced. Waiting approval/question turns remain unfinished; a new turn after the batch ends does not inherit its old terminal colors. Opening the panel acknowledges the current icon alert without changing a turn or official answer. User cancellations create no alert. Retina raster tests assert 44×44 pixels for a 22-point symbol at scale 2. Display-paced sizing uses the macOS 14+ display link and a macOS 13 screen-rate timer; compilation targets macOS 13, but real macOS 13 device acceptance remains unverified.
