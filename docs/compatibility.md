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

Prior implementation was verified on official Desktop 0.2.0-rc.2, macOS 27.0.1 / Apple Silicon. The new release's live deployment checks are recorded only once performed; no blanket support is claimed for older Desktop versions.

## Operational limits

The current helper coordinates one local active DSH profile/state namespace. Multiple simultaneous Hosts sharing it require separate state directories/helpers and are not certified here. Aggregation can only track descendant runs observed while the plugin is loaded. Result-unknown submissions never auto-retry. Notification previews and action availability depend on macOS settings and available banner space; default approval click always opens details.
