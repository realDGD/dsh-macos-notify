# DSH macOS Notify release design

User-approved scope: rename the repository/package to `dsh-macos-notify` and helper to `DSH Notify.app`, prepare a public standalone plugin, then add notification settings, task aggregation and diagnostics.

Keep the existing native question/approval forms and Host-first decision authority. Keep the historical helper bundle identifier and `dsh-jump` state namespace to preserve local notification permission and in-flight navigation compatibility. Add the new package RPC namespace with a temporary old namespace alias.

A dependency-free Host producer writes atomic completion/error records to a private notification queue. Interactions remain on the existing official approval/question protocol. Installers build locally with Command Line Tools and use the locally installed Desktop icon; do not redistribute the official icon. A LaunchAgent starts the helper on login. Upgrade preserves the previous application and settings.

Preferences live in a private local settings JSON file and are edited in a DSH settings section over authenticated Connection RPC. Per-kind switches, sound, subagent scope and optional current-session foreground suppression only affect reminders, never an explicitly opened form or Host answers. Aggregate root completion while known descendant runs are active, and cancel held completion if its root starts a new turn.

Diagnostics expose package/helper versions, permission and fresh heartbeat, Host capabilities, bounded reason counters and safe test notification; they exclude conversation text, local paths, credentials and raw logs. Browser/DSH client reports its visible selected session, but helper notification ownership remains singular.

Publish only reviewed source, tests, human documentation and CI. Private checkpoints, previous apps, runtime records and screenshots remain outside tracked Git. Validate isolated first install, upgrade backup, package contents, exact packaged Cordis lifecycle, native AppKit forms and an actual notification callback before claiming the deployed release complete.
