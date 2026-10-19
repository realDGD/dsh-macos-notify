# plugins/dsh-macos-notify/AGENTS.md

DSH Notify is a community macOS plugin for DSH Desktop: a DSH bundle (host half plus a client half) and a compiled menu-bar helper app that owns notifications, native approval/question windows and the session panel. No browser, relay, network listener or extra model service is involved.

Repository-wide rules are in [`../../AGENTS.md`](../../AGENTS.md) and the plugin-unit layout is in [`../AGENTS.md`](../AGENTS.md); this file adds only what is specific to this plugin. The package contract is [`README.md`](README.md); the standing references stay in [`docs/install.md`](docs/install.md), [`docs/release.md`](docs/release.md), [`docs/compatibility.md`](docs/compatibility.md) and [`docs/images/README.md`](docs/images/README.md); decisions live in [`.agents/notes/`](.agents/notes/README.md).

## The two planes

| Plane | Source | Runs as | How an edit takes effect |
|---|---|---|---|
| JS bundle | `lib/`, `cordis.patch.yml`, `package.json` | Host and client modules inside the DSH process | next plugin reload, when the profile resolves this directory as a `link:` |
| Native helper | `macos/*.swift`, `macos/assets/`, `macos/Info.plist` | `/Applications/DSH Notify.app`, a copy compiled and signed by the installer | only after the helper is rebuilt and installed; reloading JS does nothing |

The JS half owns the semantics: it observes official events, owns settings and the private state directory, publishes the bounded `session-menu.json` snapshot and reads the helper's `open-session.json` request. The helper owns everything the user sees and touches. Either half tolerates the other being absent — the helper renders the last valid snapshot, and the host catches every helper failure so a broken helper never breaks DSH.

The helper is started only inside the official Desktop host process on darwin (`lib/helper-lifecycle.js:21-25`); a CLI profile must never launch the GUI helper.

## Swift edits need an explicit reinstall

`npm install` and `dsh plugin add` run the `postinstall` script `node scripts/install.mjs --automatic --defer-start`, which compiles a staging app, verifies its signature, retires the running helper, backs up the previous app and replaces it atomically; `--defer-start` leaves LaunchServices registration and startup to Desktop. Rebuild and install on demand with that same command.

That command replaces a working, code-signed app and stops the running helper, so treat it as a user-visible action: an open question/approval window, or a hidden unsent draft, makes the installer refuse the upgrade ([`docs/install.md`](docs/install.md)). Never swap the contents of the installed `.app` by hand while the helper runs.

The helper is always code-signed, and the installer checks it: the staged bundle is verified with `codesign --verify --deep --strict` before anything is replaced (`scripts/install.mjs:105,116`). A local build is ad-hoc signed — that is not Apple notarisation and does not bypass package-manager script approval or Gatekeeper, so a prebuilt helper is never distributed; the release ships Swift sources and builds them on the machine.

The helper's bundle identifier `com.dgd.dsh-jump-notifier` and the `dsh-jump` state namespace are compatibility surface, not cosmetic names: macOS attaches the granted notification permission to the bundle identity, and the helper finds the host's state directory through the namespace. Changing either is a permission and navigation migration.

## The compatibility gate

`package.json` declares peers on the two session packages the plugin imports directly — `@deepseek-ai/dsh-session` and `@deepseek-ai/dsh-session-format-catalog` — as `>=0.2.0-rc.2 <0.3.0-0`. A bundle whose peers do not match the running harness is skipped whole by the loader, which is why the range is bounded rather than pinned, and why it is widened only after the consumed interfaces have been re-verified. Rationale, evidence and the alternatives that lost: [widen the session peer range](.agents/notes/implemented/architecture/2026-10-17-widen-session-peer-range.md).

The range covers those two imports only. Everything else the plugin consumes — the harness services and events it resolves by name at runtime, and the client services, slots and `dsh.client.inject` packages — is ungated, so a harness change is verified by use rather than by a version check; the extracted surface and the cross-plugin inventory hold the exact list, and [`../../.agents/skills/dsh-plugin-upgrade-check/SKILL.md`](../../.agents/skills/dsh-plugin-upgrade-check/SKILL.md) owns that procedure. What this plugin adds is the consequence: a client-side change (settings section slot, locale, workspace/session services) shows up as a broken settings panel or a menu that stops updating, not as a load failure.

## Testing

| Command | What it establishes | What it does not |
|---|---|---|
| `npm test` (`node --test tests/*.test.mjs`) | host/client behaviour: reminder lifecycle, ownership leases, settings validation, snapshot bounds, menu model, routing | anything the native helper does |
| `npm run test:native` (`bash macos/test-layout.sh`) | real AppKit/WebKit components and layouts, compiled from `macos/` | notification delivery or a live Desktop click |
| `npm run check:release` | package contents, lockfile and version agreement, privacy patterns | runtime behaviour |
| `npm run test:release` | the release tools' own boundaries | the plugin running |
| `npm run audit:privacy`, `npm run package:release` | the archives' contents and history audit | a working install |

The suites need `npm ci --ignore-scripts` first, which is also what CI does; `--ignore-scripts` is what keeps a test run from invoking the native installer. A Swift change that only affects layout or the launch path can be checked without touching the installed app: `npm run test:native` compiles the fixtures against the same sources the app is built from, and the helper's launch and click paths accept `--simulate-no-desktop` / `--simulate-click <url>` against a temporary `--state-dir` for an isolated staging run.

## Boundaries

- Do not reinstall the helper to test a change; reinstall only when the compiled app itself must change, and expect the user's live notifications to be disturbed.
- `dist/` is released output, not source; the private state directory (`$DSH_HOME/dsh-jump`, directory `0700`, files `0600`) holds runtime records that are never committed or packaged.
- Notification, menu and settings flows reuse the authenticated connection; the plugin adds no listener, sends no model request and answers no approval on its own.
- Diagnostic surfaces stay limited to versions, coarse states and timestamps; conversation content, local paths, credentials and raw logs are not exposed, and the same exclusion applies to what is published.
