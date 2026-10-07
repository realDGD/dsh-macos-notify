# Changelog

## 0.5.0

- Scope activity to runs observed or started during the current Host connection; retain their terminal results without importing old errors or dormant pins.
- Distinguish official user/parent/hook/environment cancellation causes from failures, crash recovery and unknown legacy stops. Use 未分组 for sessions outside registered workspaces.
- Add activity filters and reversible bulk read acknowledgment; keep live sessions and required input visible, preserve private read marks across helper restarts and reveal new turns.
- Separate activity and recent-history viewports, put connection status alongside the heading, keep expanded roots reachable and enlarge disclosure controls.
- Remove unused disclosure spacing from root conversations without subagents while preserving nested tree alignment.
- Put completed/total inside todo rings and use a green check when all todos finish. Preserve notification navigation, questions and approval behavior.

## 0.4.1

- Blend the session table and scrolling viewport into the native popover material instead of showing a separate opaque dark rectangle.

## 0.4.0

- Add an optional native menu-bar popover for active conversations, expandable nested subagents and five recent root conversations.
- Use official workspace/session names and Pin order; prioritize pending input/approval, failures and runs. Preserve ancestor state when an active descendant promotes its branch.
- Show one-line human input/current-turn formal answer, accessible state labels/colors and completed/total rings from actual todos. Ordinary user forks remain roots.
- Reuse authenticated, acknowledged Desktop navigation, including official child-session addresses; closing the popover preserves independent question drafts.
- Add a validated enable/disable setting, private bounded snapshots, loading/unavailable/stale indicators and lifecycle-owned discovery/refresh.
- Include all Host/native sources in the source distribution; retain existing notification behavior, app identity and local icon handling.

## 0.3.1

- Keep foreground quiet state per client window, expire inactive leases and ignore out-of-order presence packets. Focus changes and disposal release only that window’s lease.
- Ignore stale child-turn ends, starts and errors so older events cannot flush or cancel a newer task summary.
- Show safe test progress from queueing through macOS acceptance and actual matching Desktop session confirmation. Queue failure, rejection and timeout no longer imply success; old or unrelated receipts cannot confirm a new test.
- Report plugin/helper version mismatch explicitly and keep diagnostic status limited to validated versions, coarse states and timestamps. Private receipt history is bounded.

## 0.3.0

- Approval arguments default to indented JSON, with exact original view and copy controls. Formatting preserves key order, numbers and string escapes.
- Long commands and parameters soft-wrap at the current window width without horizontal scrollbars.
- Expanded question/approval context renders Markdown tables, lists, quotes, code and LaTeX formulas using bundled offline components. Long content remains scrollable and table cells wrap.
- Context is loaded only when expanded; rendering failure retains original text. The context view has no approval/answer capability and does not fetch remote images or execute supplied HTML.

## 0.2.0

- Rename the plugin/repository to `dsh-macos-notify` and the helper to **DSH Notify.app**.
- Produce completion/error reminders directly from official DSH events, without the old browser relay.
- Add per-kind notification settings, sound, child-task scope/aggregation, foreground quiet mode, version/permission diagnostics and a safe test button.
- Preserve interactive Allow/Deny, full approval context/commands, multi-question options plus individual text input, Markdown/highlighting, verified Desktop navigation and first-wins handling.
- Ship helper source, Command Line Tools build/install/upgrade/uninstall scripts, backup protection, MIT license, package/privacy checks and Node/native CI.

Current scope: DSH Desktop 0.2.0-rc.2, one active local Host/state namespace. Native source builds target macOS 13+ on the build machine's architecture; older OS and Intel device acceptance need separate validation. No downloaded prebuilt helper or official icon asset is distributed.
