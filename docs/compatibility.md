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

The current helper coordinates one local active DSH profile/state namespace. Multiple simultaneous Hosts sharing it require separate state directories/helpers and are not certified here. Aggregation can only track descendant runs observed while the plugin is loaded. Result-unknown submissions never auto-retry. Notification previews and action availability depend on macOS settings and available banner space; default approval click always opens details.

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
