# DSH macOS Notify

Native interactive macOS notifications for **DeepSeek Harness Desktop**. The DSH plugin and the background **DSH Notify.app** work together; notification clicks return to the corresponding Desktop workspace and session.

原生 macOS 通知、审批与完整问答：通知点击返回 DSH Desktop 对应会话，无须浏览器或额外模型服务。

- Allow once / Deny directly from approval notifications; default click opens complete approval details, command, formatted parameters (with exact original view/copy) and related context.
- One question reminder opens a scrollable multi-question form. Every question supports its original choices and independent multiline text input; submit the full batch once.
- Soft-wrapped commands/parameters, session names, Markdown context with tables and LaTeX formulas, and Shell/JSON highlighting. Display formatting never changes submitted option labels or copied commands.
- DSH remains the decision owner. The first accepted answer wins; answered/cancelled requests are withdrawn and stale buttons cannot repeat an action. Temporary disconnection preserves open drafts.
- Optional native menu bar: prioritized active sessions, expandable subagents and the five most recent root conversations, with state labels and actual task progress.
- Standalone completion/error producer, optional child-task summaries, per-kind switches, sound and current-session foreground quiet mode.
- **DSH Settings → DSH Notify** shows connection/helper/permission/version status and a safe test-notification button. Test status distinguishes queueing, macOS acceptance, waiting for a click and confirmed Desktop session selection.

This is a community plugin, not an official DeepSeek product. Currently verified with **DSH Desktop 0.2.0-rc.2**. See [compatibility and verification](docs/compatibility.md).

## Installation

Requirements: macOS 13 or later, official DSH Desktop, Node.js 22+ and Apple's Command Line Tools. Full Xcode and a paid signing certificate are not needed for local source builds. The current local verification machine is macOS 27.0.1 / Apple Silicon; older macOS and Intel machines need additional real-device validation.

1. Clone this repository:

   ```sh
   git clone https://github.com/realDGD/dsh-macos-notify.git
   cd dsh-macos-notify
   npm ci --ignore-scripts
   ```

2. Build and install the native helper:

   ```sh
   # Run once if Command Line Tools are not installed:
   xcode-select --install
   bash macos/install.sh
   ```

   Installation creates `~/Applications/DSH Notify.app`. The Desktop plugin starts it quietly when DSH opens; it exits when DSH quits. Minimizing or closing a Desktop window keeps the helper running while Desktop remains open. No login LaunchAgent is created; upgrades retire and back up the old managed startup entry. Allow notifications for **DSH Notify** when macOS asks. If Desktop is installed at a different location, set `DSH_DESKTOP_APP` to its application path before building. Builds use the icon from your locally installed official Desktop; official binary/icon assets are not included in this repository or release.

3. In DSH Desktop, open the left sidebar’s **Plugins → Add plugin**, enter the absolute path to this cloned directory. Install and enable it, then restart Desktop once. This path is needed only during installation.

   The current `0.5.0` development version is available as `github:realDGD/dsh-macos-notify#main`. To freeze a verified revision, replace `main` with its full commit SHA and build the helper from the same revision. `v0.5.0` is not published yet. Existing JavaScript is committed; no package-install build hook runs.

4. Open **Settings → DSH Notify**. Check that the helper is running and notifications are authorized. Send the safe test notification, then actually click it. The test status becomes confirmed only after Desktop verifies the target session; queueing or macOS acceptance alone does not prove a visible banner or successful navigation.

For CLI installations the equivalent plugin step is `dsh plugin --profile <your-profile> add <path-to-checkout>`. Desktop users do not need to install another npm DSH executable. The plugin `.tgz` contains runtime/helper sources and install scripts; the separate `-source.tar.gz` contains the complete tracked repository, tests and CI. See [installation, upgrade and recovery](docs/install.md) and [release artifacts and verification](docs/release.md). Published versions are listed in [GitHub Releases](https://github.com/realDGD/dsh-macos-notify/releases); the current development version should not be mistaken for an accepted stable release.

## Upgrade

Update the checkout to the matching release, run `npm ci --ignore-scripts`, close any native question/approval windows, then run `bash macos/install.sh` again. The installer retains previous helper applications under the private state directory, preserves preferences and verifies that the previous helper exited before replacing it.

Reinstall the plugin from the new release using DSH's plugin manager if necessary, and restart Desktop to load the new Host/client modules. Check the actual plugin and helper versions in **DSH Notify**. Do not judge success from the source version alone.

For existing `dsh-notify-web` / `DSH Jump.app` users: the helper installation moves the known old app into a backup. Remove the old plugin and its old native completion/error relay from the active DSH bundle list before enabling this standalone package, to avoid duplicate notifications. Other plugins and conversation history are unaffected. The historical helper bundle ID and local state namespace are intentionally preserved so local notification permission and navigation compatibility can survive migration.

## Uninstall

Remove `dsh-macos-notify` in DSH's plugin manager, then run:

```sh
bash macos/uninstall.sh
```

The installer removes only its owned helper and startup file. It retains preferences and application backups. Restart Desktop to unload the Host plugin. Unknown applications/startup entries are never overwritten or removed.

## Session menu bar

Click the DSH Notify menu-bar icon to open the native session panel. Each row shows `workspace · session name`, one line of the latest human input while active, or the latest formal answer from the completed turn. A subagent without human input uses its own task text. Normal user forks remain independent conversations.

Official Pins come first, followed by requests waiting for input/approval and failures or involuntary interruption, then running sessions. The history section contains up to five recent eligible root conversations; subagents and pinned/activity rows do not consume those slots. Expand the disclosure arrow to inspect nested subagents. A waiting or pinned descendant promotes its ancestor branch while preserving the ancestor’s own state. Colors always have text labels. A ring counts completed/current task items for that row only; no plan means no ring.

A row click closes the popover and uses verified Desktop session selection. Navigation failure is shown when you reopen the panel. Existing question-window drafts remain intact. Keyboard arrows navigate and expand/collapse; Return opens a session and Escape closes the panel. The panel adapts to available screen space and ignores mouse-wheel/trackpad scrolling.

Pending approvals offer a vertical pair of green **允许本次** and red **拒绝** buttons within their session row. Questions offer **打开完整问答**, reusing the complete multi-question panel and any existing draft. Multiple requests in one session use a **处理请求** menu with a separate entry for each request; narrow rows use the same menu. Actions always resolve the latest exact request, share notification submission guards and await the Host result. Disconnected or submitting approvals cannot be clicked; accepted or expired requests disappear. A request inherited from a child belongs to that child's row, so approving a parent cannot accidentally answer its subagent.

Activity starts with sessions running or awaiting input when the Host connects, then follows turns actually started during that connection. It retains their completions and failures; older failures and dormant pins belong to recent history. Unregistered working directories are labeled **未分组**, matching DSH's grouping. Official cancellation causes distinguish user stops, parent stops, hook cancellations and environment shutdown from actual failures or crash recovery; unknown legacy causes stay explicit.

The header puts connection status beside the app name. Activity and the five recent root sessions have separate fixed viewports, sharing four compact rows. Both start with two slots and lend unused slots to the longer section. A downward arrow appears only when more rows remain; it expands that section, then points upward to collapse it. A display-paced 0.26-second height transition respects macOS Reduce Motion and survives unchanged Host heartbeats (screen-rate timer fallback on macOS 13). If an expanded section exceeds screen height, separate up/down arrows reveal the remaining rows while keeping its root's collapse control reachable. Fitting and empty sections have no expansion controls or scrollbars. Activity shows all connection-local statuses in Host order; old private read marks are ignored. Status dots are centered in a dedicated left gutter and vertically centered on their row. Task fractions sit inside the ring; a complete todo list shows a green check.

The menu-bar symbol is a white **fish.circle**. Only its fish rotates while the current batch has running turns, with a one-second pause between rotations. Concurrent runs share a batch; a run started after the batch stops begins a fresh batch, so retained old activity cannot color it. The ring uses orange (`#F78318`) for questions/approvals, then red (`#FF5356`) for abnormal stops, then green (`#62BA46`) for completion. When no turns remain running, an alert becomes **fish.circle.fill**; opening the panel acknowledges it and restores the white outline. User, parent and rule cancellations do not create alerts. A newer result may alert again; disconnected data stops the animation without inventing completion.

Enable or disable it in **DSH Settings → DSH Notify → 菜单栏会话面板**. The panel’s gear can also disable it through the same validated setting. Notifications and question/approval windows keep working. To re-enable, use the existing DSH settings section. Initial discovery shows loading; a missing service shows unavailable, and an absent Host heartbeat marks retained data stale after six seconds. Snapshots are private, capped at 4 MiB/2,000 nodes, with an explicit omitted count when limited. History refreshes no more frequently than every 30 seconds. One active local Host/state namespace is supported.

## Privacy and behavior

No additional network listener, webhook, cloud service or model session is used. The official authenticated DSH Connection carries navigation and settings RPC. Same-user Host/helper records are exchanged atomically in a private directory (`0700`, files `0600`). Local question/approval content is needed for the native form; it is not exported by diagnostics. macOS notification previews can expose displayed text on the lock screen; use macOS preview settings according to your preference.

Quiet mode suppresses reminders only. Explicitly opened forms stay available, and it never approves/rejects or answers a request automatically. Turning off a notification type does not disable that underlying DSH interaction.

Task aggregation waits for descendant runs observed by the active plugin. A newly started root turn cancels its old held completion. Aborted/interrupted/blocked turns are silent. Cold installation does not replay old idle sessions. Older turn events cannot end a newer child run, and background windows cannot clear another window’s foreground quiet state.

## Development

```sh
npm ci --ignore-scripts
npm test
npm run test:native     # macOS only; real AppKit components
npm run check:release
npm pack --dry-run
# Maintainers only; Python 3.9+ (standard library):
npm run test:release
npm run audit:privacy
npm run package:release -- --output dist/release
```

Node tests use the pinned DSH Cordis dependency and do not silently skip lifecycle tests. Use a clone or the full source archive to run the complete test suite. Python is used only by maintainers' release tooling, not by the plugin or helper. To verify against a particular installed Desktop artifact, set `DSH_CORDIS_MODULE` to that artifact's Cordis module. Public CI checks Node versions, native compilation/layout and package/privacy completeness. Real macOS notification acceptance and Desktop session selection remain separate live checks.

Question/choice labels use native Markdown text formatting. The expanded context pane uses bundled, offline Markdown and KaTeX rendering for headings, lists, quotes, tables, code and formulas (`$…$`, `$$…$$`, `\(...\)`, `\[…\]`). Long context stays fully scrollable; long table cells wrap. A wide formula has its own scroll area so it remains readable. Shell/JSON have semantic colors; other code blocks remain monospaced. Remote images are shown as text placeholders, raw HTML is inert, and only explicitly clicked HTTP(S) links open externally.

Approval parameters are indented without re-encoding JSON keys, numeric values or escapes. **查看原文** switches the display; **复制原始参数** copies the exact original. Both parameters and commands soft-wrap without horizontal scrollbars. These changes affect display only, never the underlying tool request.

## License

MIT, see [LICENSE](LICENSE). The DSH name and locally sourced official icon identify integration with Desktop; this repository does not grant rights to third-party branding. Existing local notification permission uses a historical bundle identifier that is not a credential.
