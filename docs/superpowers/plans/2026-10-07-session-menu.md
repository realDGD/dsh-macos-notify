# Native Session Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved native session menu to DSH Notify.app, with nested agents, prioritized states, five recent root sessions and real todo progress.

**Architecture:** A pure model builds a bounded tree from official Host facts. A lifecycle-owned collector publishes private complete snapshots and accepts a narrowly typed preference command; AppKit renders those snapshots and reuses existing authenticated Desktop navigation. Existing interaction handlers remain the decision owners.

**Tech Stack:** Node 22+ ESM and pinned Cordis; Swift/AppKit, NSStatusItem, NSPopover and native list rows; existing local Command Line Tools installer and CI.

**Spec:** [Approved design](../specs/2026-10-07-session-menu-design.md).

**Execution recommendation:** Native execution in this session, then one fresh whole-branch reviewer. These tasks share one transport contract and the existing interaction/navigation seams; per-task implementation agents would duplicate that context. Wait for the user's plan review and execution choice before product edits.

## Global Constraints

- Target 0.4.0; retain the current app/bundle identity, existing source/app backups and single active local Host/state namespace.
- History contains up to 5 eligible root sessions; pinned/activity rows do not consume those slots and children never enter history. Extreme payload limits can reduce the visible set only with an explicit omitted count.
- Title limit 200 Unicode characters, preview limit 240; previews are one line, never reasoning/tool results, and submitted/copied original text is unchanged.
- Private directory 0700, files 0600; session snapshots at most 4 MiB and 2,000 nodes, with explicit omitted count rather than silent loss.
- Display changes publish at most once per second; heartbeat every two seconds; helper poll every second; stale after six seconds.
- History discovery no more frequently than every 30 seconds; read concurrency at most 4; cache facts by supported source revision/sequence and release every observation lease.
- menuBarEnabled defaults true. Disabling removes only this status item/panel and extra history work; all notification/answer behavior stays enabled according to existing preferences.
- Pin order is official. Ancestor promotion preserves each node's actual state. Progress is completed/total of that node's current todos, never time or a sum of descendant plans.
- No model message, real approval command, writer acquisition, browser fallback, new listener, DSH Bridge delegation or official asset redistribution.
- Live Desktop reload/click acceptance requires manual Mac unlock; do not bypass lock, force quit or repeat an unanswered unlock/test request.

## Review Focus

- Fork-inherited messages and older-turn answers must not masquerade as the child's input or the current completed answer: Task 2.
- A promoted completed parent with a waiting grandchild must retain its own state and expose the real waiting descendant: Tasks 1 and 5.
- Slow cold reads, disable/re-enable and Host disposal must not publish stale rows or retain leases: Tasks 2 and 3.
- Very deep trees, wide Chinese/emoji text and hundreds of expanded children must preserve visible controls, scrolling and keyboard navigation: Task 5.
- A previous setting/jump result must not confirm a new command or close/alter an existing question draft: Tasks 4 and 6.

## File Responsibilities

| Files | Responsibility |
|---|---|
| lib/menu-model.js | Pure state mapping, previews, progress, sorting, hierarchy, history and payload limits |
| lib/menu-source.js | Official live/cold facts, projected messages/todos, revision cache and lease ownership |
| lib/menu-host.js | Collector lifecycle, coalescing, complete snapshots and enable/disable observation |
| lib/menu-control.js | Narrow private preference command validation and matching results |
| lib/interactions.js | Read-only pending-state accessor; no second middleware |
| lib/index.js, lib/settings.js, lib/client.js | Wire optional menu services, preference and existing settings UI |
| macos/SessionMenuModel.swift | Validate/decode snapshot, generation/revision and stale presentation |
| macos/SessionMenuControl.swift | Private setting command writer and identity-bound result wait |
| macos/SessionMenuView.swift | Bounded native rows, disclosure, status/progress, keyboard/accessibility |
| macos/SessionMenu.swift | Status item, popover, polling, callbacks and last action result |
| macos/main.swift | Connect existing pump/Desktop navigation; no unrelated refactor |
| tests/menu-*.test.mjs, tests/native-menu-control.swift, tests/native-session-menu.swift | Behavioral, typed transport and actual native component regressions |
| macos/build.sh, macos/test-layout.sh, scripts/release-check.mjs | Include new sources in build/package verification |

## Shared Contract

Define and export JSDoc types in lib/menu-model.js; mirror the wire contract in SessionMenuModel.swift:

- MenuFact: id, parentId (nullable), origin (nullable), workspaceTitle, sessionTitle, pinIndex (nullable), archived, blank, running, turn (nullable), terminal (nullable {turn, kind, cause, time}), userText, taskText, answerText, answerTurn (nullable), todos (nullable array), waiting ({questions, approval}), updatedAt.
- MenuNode: id, parentId, workspaceTitle, sessionTitle, state, preview, previewKind, pinned, pinIndex, progress (nullable {completed,total}), childIds, descendantBadge (nullable), updatedAt.
- State enum: waiting-questions, waiting-approval, error, interrupted, max-tokens, running, completed, stopped, paused, unknown. Labels/colors are the approved spec's table, not supplied HTML or arbitrary error text.
- MenuRows: nodes, activeIds, orphanIds, historyIds, omittedCount (number of excluded session nodes, not branches). Flat nodes have unique valid session IDs; child IDs reference included nodes and retain ancestor closure.
- MenuSnapshot: version=1, generation (UUID), revision (safe non-negative integer), updatedAt, enabled, availability (ready/loading/unavailable), and MenuRows. Loading marks incomplete initial history discovery, never a claim that absent roots completed.
- Menu preference command: version=1, commandId (UUID matching filename), createdAt, kind=set-menu-enabled, enabled (boolean). Result: commandId, kind, enabled, status (accepted/invalid/failed/stale), completedAt. It accepts no session/approval answer or arbitrary method.

### Task 1: Pure Session Model

**Files:** Create lib/menu-model.js and tests/menu-model.test.mjs.
**Interfaces:** buildMenuRows(facts: MenuFact[], {maxNodes=2000,maxBytes=4194304}={}) -> MenuRows; singleLinePreview(text, limit=240) -> string; todoProgress(todos) -> {completed,total}|null. MenuRows is consumed by Tasks 3 and 5.

- [ ] **Step 1:** Add failing tests named priority_and_history, promote_waiting_grandchild, orphan_and_cycle, real_progress, current_turn_preview, unicode_and_budget and markdown_plain_preview. Assertions: official pinned order first; wait/error before running; latest terminal times sort history; a pinned completed root is absent from five history IDs; children never count; archived/blank roots are excluded; a completed parent stays completed while its waiting grandchild promotes the branch; invalid/cyclic references terminate; 3 completed of 5 gives {completed:3,total:5}; absent/empty lists give null; old answers do not become current completion; combined display title is <=200 Unicode characters and single-line preview <=240; Markdown formatting becomes safe text, image-only input has a truthful placeholder; 2,001 nodes or oversized UTF-8 text yield explicit omittedCount and a serializable bounded result.

  Golden assertions for real_progress and unicode_and_budget:
  ```js
  assert.deepEqual(todoProgress([{status:'completed'}, {status:'completed'}, {status:'completed'}, {status:'in_progress'}, {status:'pending'}]), {completed:3,total:5})
  assert.equal(todoProgress([]), null)
  assert.ok([...singleLinePreview('题目🙂'.repeat(300))].length <= 240)
  assert.equal(buildMenuRows([]).historyIds.length, 0)
  ```
- [ ] **Step 2:** Run `node --test tests/menu-model.test.mjs`; expect failures for missing model exports/behavior.
- [ ] **Step 3:** Implement the declared functions. Use iterative graph traversal and stable sorting; retain ancestors of selected descendants. Strip Markdown to plain one-line previews without image/HTML/link execution; title fallback is 未命名会话, never an ID. State comes from current authoritative waiting/running/terminal facts; idle alone is unknown. If a byte budget forces omissions, drop the lowest-priority complete branches and count their nodes, retaining known ancestry for every surviving row. Task 3 supplies the rows budget after reserving the actual serialized envelope size and checks the entire final file.
- [ ] **Step 4:** Rerun the same command; expect all assertions pass, including deep-tree input without recursion overflow.
- [ ] **Step 5:** Commit the pure model and its tests as `feat: model prioritized session menu rows`.

### Task 2: Official Read-Only Session Facts

**Files:** Create lib/menu-source.js and tests/menu-source.test.mjs; modify lib/interactions.js and tests/interactions.test.mjs.
**Interfaces:** createMenuSource(ctx, {now=Date.now,maxReadConcurrency=4}={}) -> {liveFacts(): MenuFact[], discover(signal): Promise<MenuFact[]>, invalidate(sessionId):void, dispose():void}; installInteractions now returns {pendingStates(): Map<string,{questions:boolean,approval:boolean}>}. Existing callers may ignore this return value.

- [ ] **Step 1:** Add failing tests for live_titles_pins_todos, lease_cleanup, fork_and_turn_boundaries, human_vs_task_preview, cold_failures_and_revision_cache and pending_accessor_first_wins. Assert workspaceRegistry pin order, parent/cwd mapping, current todos, numeric terminal turn/time and labels; excluded inherited assistant messages; the new turn has no previous answer or plan; child task input is used only without human input; each observation uses `[Symbol.dispose]()` once on success/failure/cancellation; unchanged revision/cursor avoids refolding; at most four concurrent reads; continued unanswered requests remain pending and an accepted/cancelled request disappears without duplicate callbacks.

  Build the scripted official-service test double in this test file; its observations record lease disposals and peak concurrent reads. Golden assertions after discovery and a new-turn event:
  ```js
  assert.equal(metrics.disposals, metrics.observations)
  assert.ok(metrics.peakReads <= 4)
  assert.equal(newTurnFact.answerTurn, null)
  assert.equal(newTurnFact.todos, null)
  assert.equal(accessor.pendingStates().get('session-test').questions, true)
  ```
- [ ] **Step 2:** Run `node --test tests/menu-source.test.mjs tests/interactions.test.mjs`; confirm the new interface cases fail while existing interaction tests retain their expectations.
- [ ] **Step 3:** Implement official workspaceRegistry/sessions/agents/sessionTitle/sessionProjections and sessionQuery adapters. Read cold observations with `{signal,projectionMode:'all'}`; dispose in finally. Build previews from official message surface only, using current turn and inheritedEventCount boundaries; inherited parent user/assistant text is not the child's direct input or answer. Read event.time and typed aborted reasons; distinguish user/parent cancellation, current running retries, true failure and synthetic interrupted facts. Keep a bounded fact/revision cache, not full logs. Expose cloned pending booleans from the existing active/continued lifecycle, including transitions until withdrawal; Task 3 merges this accessor into live/cold facts by ID. Do not install another handler.
- [ ] **Step 4:** Rerun the command, expecting no leaked leases, writes, Agent activation or altered original answers. Add an explicit delayed-read test proving a newer live cursor wins over an older cold observation.
- [ ] **Step 5:** Commit as `feat: collect read-only session menu facts`.

### Task 3: Host Snapshot Lifecycle and Settings

**Files:** Create lib/menu-host.js and tests/menu-host.test.mjs; modify lib/index.js, lib/settings.js, lib/client.js, tests/settings.test.mjs and tests/desktop-host.test.mjs.
**Interfaces:** installSessionMenu(ctx, {stateDir,settings,pendingStates,now=Date.now}) -> {refresh():void}; ctx.effect owns disposal. Consumes Tasks 1/2. Settings adds menuBarEnabled=true; the existing RPC names and old navigation aliases stay unchanged.

- [ ] **Step 1:** Write failing tests for baseline_loading_to_ready, lifecycle_and_coalescing, disable_reenable, late_read_after_dispose, service_absence and private_snapshot. Assert one complete version1 snapshot; distinct generation per activation; monotone revision; update cadence <=1Hz and heartbeat2s; cold discovery >=30s apart; disable empties menu data and stops extra reads while interaction handling still accepts exactly one original answer; re-enable creates fresh data; dispose cancels work and prevents late writes; missing optional services do not prevent navigation/routes from loading; file modes700/600 and <=4MiB/2,000 nodes.

  Use temporary files and a controlled clock with real Cordis disposal. Golden private_snapshot assertions:
  ```js
  assert.ok(Buffer.byteLength(readFileSync(snapshotPath)) <= 4 * 1024 * 1024)
  assert.ok(snapshot.nodes.length <= 2000)
  assert.equal(statSync(stateDir).mode & 0o777, 0o700)
  assert.equal(statSync(snapshotPath).mode & 0o777, 0o600)
  ```
- [ ] **Step 2:** Run `node --test tests/menu-host.test.mjs tests/settings.test.mjs tests/desktop-host.test.mjs`; confirm new behavior fails before implementation.
- [ ] **Step 3:** Wire menu capability with Cordis optional injection for workspaceRegistry, sessions, agents, sessionTitle, sessionProjections and sessionQuery; preserve hard injection of connection only. Merge current pendingStates() by ID after collecting facts. Own discovery/coalescing/heartbeat timers and cancellation. Use a single complete atomic session-menu.json snapshot; bound the entire UTF-8 envelope to 4MiB, not only its rows; no writes after disposed or obsolete refresh generation. Preserve prior settings on migration, expose the menu checkbox in the existing settings section, and publish capability-unavailable/loading explicitly without private data in status RPC. Preference observation remains alive when disabled so the existing settings RPC can re-enable collection.
- [ ] **Step 4:** Rerun the targeted tests with real Cordis activation/disposal. Verify the existing route count/namespace, settings validation and notification defaults except the new approved boolean.
- [ ] **Step 5:** Commit as `feat: publish bounded session menu snapshots`.

### Task 4: Narrow Menu Setting Transport

**Files:** Create lib/menu-control.js, macos/SessionMenuControl.swift, tests/menu-control.test.mjs and tests/native-menu-control.swift; modify lib/index.js and macos/test-layout.sh.
**Interfaces:** installMenuControl(ctx,{stateDir,settings,now=Date.now}) -> void, owns effect/timer and is installed in index.js even when menuBarEnabled=false; Swift SessionMenuControl(directory:) with setEnabled(_: Bool, completion: @escaping (String?)->Void) and poll(). Completion receives nil only for accepted matching results, otherwise a user-facing failure string. Consumes Task 3's settings. Use menu-commands/ and menu-results/, independent of approval commands/results.

- [ ] **Step 1:** Test boolean-only commands, UUID/filename/time binding, malformed/oversized/unknown-kind rejection, old results, duplicate commands and private permissions. Assert commands older than120s or >10s future are stale; files >4KiB are rejected; only settings.save({menuBarEnabled:bool}) occurs; prior command/result cannot satisfy a new wait; unknown owned-file names are preserved. Native wait times out after15s and reports unconfirmed rather than success.

  Golden assertions using the command processor's scripted settings spy and clock:
  ```js
  assert.deepEqual(savedPreferences, [{menuBarEnabled:false}])
  assert.equal(result.commandId, command.commandId)
  assert.equal(result.status, 'accepted')
  assert.equal(staleResult.status, 'stale')
  ```
- [ ] **Step 2:** Run `node --test tests/menu-control.test.mjs`; compile `swiftc -o "$TMPDIR/NativeMenuControlTests" tests/native-menu-control.swift macos/SessionMenuControl.swift` and run that fixture; confirm new cases fail.
- [ ] **Step 3:** Implement and wire the typed Host processor and Swift writer/waiter, with control transport kept active independently of menu display. Include the control fixture in test-layout.sh. Cap results at128 and keep at most10minutes of own recognized results; cleanup does not remove unrelated files. The helper never overwrites settings.json; accepted results include the canonical enabled value. Use generic user-facing failure text without raw secrets/paths.
- [ ] **Step 4:** Rerun the same tests; all identity/timeout/permissions cases must pass without real notifications or answers.
- [ ] **Step 5:** Commit as `feat: add validated menu preference controls`.

### Task 5: Native Menu Data and Popover

**Files:** Create macos/SessionMenuModel.swift, macos/SessionMenuView.swift, macos/SessionMenu.swift and tests/native-session-menu.swift; modify macos/build.sh and macos/test-layout.sh.
**Interfaces:** SessionMenuStore accepts validated MenuSnapshot bytes and current time and exposes presentation state; SessionMenuController(directory:openSession:openDesktop:) has poll(); openSession is `(String,@escaping(String?)->Void)->Void`, openDesktop is `()->Bool`. Controller uses Task 4's waiter. View callbacks separate disclosure, row selection and settings.

- [ ] **Step 1:** Create failing native tests for snapshot_decode_and_stale, bounds_and_long_text, fold_and_deep_tree, status_and_progress, keyboard_and_accessibility, enabled_lifecycle and setting_result_match. Assert valid snapshots update; lower same-generation revisions are ignored; corrupt/oversized/duplicate-ID data cannot replace a valid view; at6s+ it is visibly stale without changing underlying session facts; width420/maxheight600 responds to available screen width; previews stay one line; 3/5 ring/accessibility count is correct; scrolling keeps controls usable with hundreds of children; invalid IDs cannot trigger callbacks; disabling removes only the status item/popover.

  Golden native layout assertions, with fixture content/controller retained for the run:
  ```swift
  precondition(content.view.frame.width <= 420)
  precondition(content.view.frame.height <= 600)
  precondition(row.preview.maximumNumberOfLines == 1)
  precondition(progress.completed == 3 && progress.total == 5)
  ```
- [ ] **Step 2:** Compile `tests/native-session-menu.swift` with the four new menu Swift files and run the fixture; expect missing classes/behavior initially. Add this fixture to test-layout.sh.
- [ ] **Step 3:** Implement bounded Codable validation and AppKit rows. Use a native table with flattened visible tree rows and explicit disclosure controls; cap visual indentation at8levels with a depth label for deeper rows, retain actual ancestry and keyboard parent/child navigation. Start children collapsed; preserve expanded IDs in memory. Draw native state shapes plus fixed labels and a completed/total ring. Use a monochrome template status icon with tooltip DSH Notify, a transient NSPopover and status item; settings menu offers typed disable, openDesktop and the documented DSH settings path. Missing initial data shows unavailable/loading, never a false completed list; malformed data retains the last validated view with an unavailable indicator.
- [ ] **Step 4:** Run `npm run test:native`; require all new and existing AppKit/WebKit fixtures pass. Verify actual layout at narrow widths, long Chinese/emoji input, deep trees, scroll ends, collapse/expand and stale/recovery transitions. These are component tests, not claims of visible live acceptance.
- [ ] **Step 5:** Commit as `feat: render native session menu popover`.

### Task 6: Existing Desktop Navigation Integration

**Files:** Modify macos/main.swift and lib/client.js; extend tests/native-session-menu.swift, tests/native-question-layout.swift and tests/deeplink.test.mjs.
**Interfaces:** Main creates one SessionMenuController and polls it in the existing pump. Its openSession callback reuses openInDesktop(url,completion:); missing Desktop yields a failure string. Menu navigation carries a fresh requestId/sessionId/createdAt and existing client ack; no new session selection API.

- [ ] **Step 1:** Add tests named row_vs_disclosure, jump_ack_is_current, old_ack_and_timeout, child_workspace_route and menu_close_preserves_draft. Assert row click calls the selected ID once; disclosure never opens; only matching current ack confirms; cross-workspace selection connects workspace first; child target follows known ancestry/workspace; no Desktop produces error without Chrome calls; popover closes but an open question's draft and answer handler stay intact.

  Golden assertions from navigation/disclosure spies and the existing draft fixture:
  ```swift
  precondition(openedSessionIDs == ["session-test"])
  precondition(browserFallbackCalls == 0)
  precondition(questionDraftAfterMenuClose == questionDraftBeforeMenuClose)
  ```
- [ ] **Step 2:** Run `node --test tests/deeplink.test.mjs` and `npm run test:native`; observe the new integration failures first.
- [ ] **Step 3:** Attach controller lifetime to Notifier, use the existing Desktop-only path and completion waiter, and retain the latest menu jump failure for next opening. If a child is not in root workspace membership, client routing follows the known parent chain to its workspace and then confirms the actual selected child ID. Do not alter notification browser compatibility or existing question close-after-ack behavior.
- [ ] **Step 4:** Rerun those tests and full `npm test`; require first-wins, retained drafts, old/foreign ack rejection, original options/parameters and existing Markdown regressions remain passing.
- [ ] **Step 5:** Commit as `feat: connect session menu to verified Desktop navigation`.

### Task 7: Review, Release and Live Acceptance

**Files:** Modify package.json, package-lock.json, macos/Info.plist, scripts/release-check.mjs, README.md, CHANGELOG.md and docs/compatibility.md; keep local evidence/checkpoints ignored.
**Interfaces:** Version0.4.0 and complete source package; owned installer/LaunchAgent, authenticated settings and existing public repository remain the integration points.

- [ ] **Step 1:** Extend release checks to require all new Host/Swift sources, matching package/native version and no private menu fixtures/state, personal paths/session IDs, app/icon assets or credentials. Document the menu, native toggle, priority/history rules, actual todo meaning, loading/stale states and known one-Host scope.
- [ ] **Step 2:** Run `npm test`, `npm run test:native`, `npm run check:release`, `git diff --check`; build into a fresh staging app and verify signature. Request one fresh independent whole-branch review; fix Important findings with reproducing tests and rerun affected checks.
- [ ] **Step 3:** Build a normalized-owner install-source archive and SHA256SUMS, inspect contents, then compile/install from an extracted fresh home. Confirm the packed Host imports all menu modules; verify upgrade retains old app/settings and protects open question drafts. Use separate paths for failed artifacts rather than overwriting them.
- [ ] **Step 4:** After review, integrate with normal Git history, push and verify exact-head Node22/24/macOS CI. Publish the matching tag/source/checksum, download and check it. Install the verified helper with backup, compare actual binary/icon/vendor hashes and fresh version/permission; verify the production plugin resolves to the exact updated source.
- [ ] **Step 5:** When the Mac is manually unlocked, restart Desktop normally while preserving the current conversation. Use short-lived no-op synthetic facts to visibly verify menu open/close, nested expansion, Pin/attention/run/history order, one-line previews, ring counts, disable/re-enable and exact session jump ack. Verify original safe notification click and draft preservation. Clear only test-owned fixtures and restore the original view. Until this passes, report source/component/deployment evidence separately from live acceptance.
- [ ] **Step 6:** Record final evidence and remaining blockers in existing private checkpoints. Check5h quota throughout; if remaining<=5%, update the same dsh-desktop heartbeat to latest reset+1minute with the exact unfinished task, then use remaining quota. Stop the heartbeat only when required implementation and acceptance are actually complete.

## Plan Self-Review

Coverage: model/state/history/progress=Task1; official facts/readonly/pending=Task2; cadence/settings/disposal=Task3; narrow preference transport=Task4; native layout/tree/accessibility=Task5; safe navigation/draft regression=Task6; packaging/review/live evidence/quota=Task7. All five Review Focus cases have named tests. Node/Swift wire names and limits agree. Initial loading is explicit; no step starts an Agent or invents a success state. Inline review repaired final-envelope byte bounds, inherited parent input exclusion, pending-state merge ownership, disabled re-enable observation and control wiring, and separated the Task4 native fixture from Task5's view fixture. No product edits have begun; user plan review/execution choice is the next gate.
