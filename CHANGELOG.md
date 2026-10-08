# Changelog

## 0.5.0 (unreleased)

- Produce a plugin installation package and a separate complete source archive with exact-commit manifest and SHA-256 checksums. Normalize archive ownership/timestamps and audit all reachable Git history plus the actual archive contents before distribution.
- Document independent source installation, safe upgrades/uninstall and the distinction between automated evidence and pending live menu acceptance. Do not advertise an unpublished stable tag.

- Size short approval command/argument previews to their text and group related controls more tightly, keeping the context disclosure visible at the default window height. Long previews and narrow windows remain scrollable.
- Normalize bundled context-document URLs before navigation checks so expanded question/approval Markdown loads from the installed app instead of leaving a blank pane. Run the WebKit regression from a real application bundle.
- Reserve approval-control space in both text constraints and immediate row layout, including older macOS control metrics.
- Add the white fish.circle menu symbol with an independently colored ring, rotating fish and one-second pause. Track concurrent run batches before snapshot coalescing; acknowledge alerts on panel opening and ignore user cancellations.
- Stack green Allow once and red Deny buttons vertically. Keep approval context in the notification's details entry and remove the redundant menu-row details button.
- Pace the 0.26-second expansion with the display refresh rate and preserve transitions across unchanged Host heartbeats.

- Follow DSH Desktop startup and exit instead of login startup. Retire and back up the old managed LaunchAgent; the Desktop plugin recovers a missing helper without creating duplicates or affecting CLI profiles.
- Resize the popover before its content view so AppKit cannot restore the old outer size and clip expanded rows.
- Animate section height with a short synchronized transition instead of the whole popover effect. Respect Reduce Motion, retain unchanged rows and sticky roots, and replace interrupted transitions from their current size.
- Share four compact rows between activity and recent history: split evenly when both overflow and lend unused slots to the longer section. Show each section's disclosure only when more rows remain.
- Avoid rebuilding session rows while the menu is closed or a request submenu is tracking. Multiple approvals include the command and numbered request labels.

- Add per-session menu-bar Allow once, Deny and complete question-form actions. Multiple requests use explicitly bound entries; stale, submitting and already accepted requests cannot be submitted again.
- Scope activity to runs observed or started during the current Host connection; retain their terminal results without importing old errors or dormant pins.
- Distinguish official user/parent/hook/environment cancellation causes from failures, crash recovery and unknown legacy stops. Use 未分组 for sessions outside registered workspaces.
- Show all connection-local activity without read acknowledgments or filters; ignore old private read marks.
- Separate activity and recent-history viewports, put connection status alongside the heading, keep expanded roots reachable and enlarge disclosure controls.
- Remove unused disclosure spacing from root conversations without subagents while preserving nested tree alignment.
- Use fixed viewports with expand/collapse arrows, complete-row heights and explicit up/down controls for screen-bounded trees. Disable wheel scrolling and omit controls for fitting/empty sections.
- Center status dots in their left gutter and across the full row; omit the redundant navigation hint and its reserved space.
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
