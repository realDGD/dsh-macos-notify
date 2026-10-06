# Changelog

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
