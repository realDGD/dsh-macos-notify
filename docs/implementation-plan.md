# Standalone release implementation plan

> Implement inline with superpowers:executing-plans. The user explicitly requested execution of the previously discussed scope.

Goal: publish a standalone macOS interactive notification plugin under the chosen names.
Architecture: existing authenticated Host/client navigation and native AppKit interaction transport; private local settings and queue; no new network listener or model calls.
Tech stack: dependency-free Node ESM, Swift AppKit/UserNotifications, shell/Node installation tools, GitHub Actions.
Spec: docs/design.md

## Global constraints
- Package/repository `dsh-macos-notify`; app `DSH Notify.app`.
- Preserve prior source/apps/history and official Desktop conversations.
- Preserve first-wins, multi-question custom input, context and exact command handling.
- Do not publish local runtime records or official binary/icon assets.

## Review focus
- A root completion held for children must not survive a newer root turn.
- Disabling reminders must never suppress an explicitly opened native form.
- Upgrade must not leave old/new helpers concurrently reading the queue.
- Cold start must not replay stale events or overwrite unknown LaunchAgents.
- Diagnostic/export paths must never leak local conversation content.

## Task 1: Rename and standalone notification producer
Files: package.json, cordis.patch.yml, lib/index.js, lib/client.js, lib/notifications.js, tests/notifications.test.mjs, macos/main.swift.
- [x] Add failing tests for official completion/error inputs, duplicate delivery, aborted turns, stale/new-turn aggregation and private queue files.
- [x] Implement the producer and rename package/client while retaining old RPC aliases and state namespace.
- [x] Run Node suite with exact Cordis runtime and compile native helper.

## Task 2: Installation and public package
Files: macos/build.sh, macos/install.sh, macos/uninstall.sh, scripts/install.mjs, scripts/release-check.mjs, tests/install.test.mjs, README.md, LICENSE, docs/compatibility.md, .github/workflows/ci.yml.
- [x] Test isolated installation, backup-preserving upgrade and ownership-safe removal.
- [x] Package all required sources/scripts, add explicit compatibility and privacy checks.
- [x] Validate package in an isolated profile and install helper using standalone CLT.

## Task 3: Settings, aggregation and diagnostics
Files: lib/settings.js, lib/notifications.js, lib/index.js, macos/main.swift, macos/Interactions.swift, tests/settings.test.mjs.
- [x] Add failing tests for validated preferences, authenticated status/save/test RPC and reminder suppression without loss of forms.
- [x] Add DSH settings section, sound/type/scope controls and helper/Host diagnostic projections.
- [x] Exercise the rendered settings in official Desktop and safe synthetic notifications.

## Task 4: Review, deployment and publication
- [x] Run complete Node/native/package/privacy checks and one independent final review.
- [x] Deploy without losing the prior app/profile.
- [ ] Verify the new safe notification callback and selected session ack.
- [ ] Create public GitHub repository with `dsh-plugin` topic, push reviewed commits, attach source release and verify CI.
