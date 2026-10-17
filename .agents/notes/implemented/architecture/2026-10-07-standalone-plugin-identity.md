# Agent Note: Ship a standalone plugin under a new name, keeping the helper's identity

Status: implemented

## Problem

The plugin began as an internal part of a personal notification setup, next to a browser-relay companion and an older helper app, and it carried those names. Publishing it as a standalone community plugin meant a new package name, a new helper name and a publishable source tree — while the macOS side of the system could not simply start over.

macOS ties a notification permission to the application's bundle identity, and the plugin and helper had already exchanged navigation requests through a state directory named after the old helper. Renaming the bundle or the namespace would have thrown away the granted notification permission and any request already in flight, and a first release that asks users to re-grant permission and loses in-flight navigation is not a rename, it is a migration.

## Decision

The package and repository are `dsh-macos-notify` and the helper application is **DSH Notify.app**, while two identifiers are deliberately frozen:

- The helper keeps the bundle identifier `com.dgd.dsh-jump-notifier` (`macos/Info.plist:8-9`), so an upgraded install keeps its existing macOS notification permission.
- The plugin keeps the state namespace `dsh-jump` under `DSH_HOME` (`lib/index.js:23`), so settings, the private queue and an in-flight navigation request survive the rename.

The rest of the shipped shape follows from the same release scope:

- Reminders are produced in the Host from official DSH events, written as atomic records into a private queue, with no browser relay and no dependency beyond Node (`lib/notifications.js:49`).
- Interactions stay on the official approval/question protocol: the helper presents forms and offers choices, and DSH remains the authority on whether a request is still valid, so the first accepted answer wins and stale buttons cannot repeat an action.
- Preferences live in a private local settings file with a closed boolean set (`lib/settings.js:3-4`) and are edited through the authenticated connection; the helper never rewrites the settings file.
- Reminder preferences — per-kind switches, sound, subagent scope, waiting for descendants, and quieting the current session — affect reminders only. They never suppress an explicitly opened form, an approval, or an answer the Host is waiting for.
- A root completion is held while known descendants are still running, and a held completion is dropped if the root starts a new turn (`lib/notifications.js:72-83`).
- The installer builds the helper locally with Command Line Tools, copies the locally installed Desktop icon, and never redistributes a prebuilt app or official assets (`macos/build.sh`, `docs/install.md`).
- Only reviewed source, tests, documentation and CI are published: private checkpoints, previous helper apps, runtime records and screenshots stay out of tracked Git and out of both archives (`scripts/release.py` privacy allowlist, [`docs/release.md`](../../../../docs/release.md)).

One part of the original scope was later reversed and the note records the current state: the helper is **not** started by a login `LaunchAgent`. Commit `05d6507` moved the helper to the Desktop-owned lifecycle — it starts and stops with Desktop, the retired managed LaunchAgent is backed up, and a CLI profile never starts the GUI helper (`lib/helper-lifecycle.js:21-25`).

Evidence: commit `4759ffb` (the standalone release), `05d6507` (Desktop-owned helper lifecycle), [`CHANGELOG.md`](../../../../CHANGELOG.md) under 0.2.0 and 0.5.0, and [`docs/compatibility.md`](../../../../docs/compatibility.md).

## Alternatives considered

**Keep the old package and helper names.** The user-approved scope was a public standalone plugin under the new names; keeping `dsh-notify-web` / `DSH Jump.app` would have published a package named after a retired browser relay. The rename lost the old identity only for the names — the bundle identifier and state namespace were kept precisely because they are what the operating system and the in-flight requests hold on to. The residual cost is visible to users of the old setup: the old plugin and its completion/error relay have to be removed, or reminders arrive twice (`docs/install.md`).

**Keep producing reminders through the browser relay.** Rejected: reminders that depend on a browser tab disappear with the tab, and the plugin's reason to exist is delivering a reminder when DSH is not the frontmost window. Consuming official Host events directly removed that dependency and the relay with it.

**Start the helper from a login `LaunchAgent`, as the original scope specified.** This shipped and was then reversed (`05d6507`). A login item starts a helper when there is no Desktop to serve, needs its own retirement logic on upgrade, and duplicates the ownership question the Desktop process already answers. Following Desktop gives exactly one lifecycle owner and no helper without Desktop state — at the cost that a notification clicked while DSH is closed has to be handed back to a helper macOS launches on demand.

**Distribute a prebuilt, notarised helper and the official Desktop icon.** Rejected: the helper is built locally from the shipped Swift sources so the release needs no notarisation, and the official icon is copied from the local Desktop installation rather than redistributed. This keeps signing materials and official assets out of the repository, and leaves the release with an ad-hoc signature that is not Apple notarisation.

**Publish the working material along with the source.** Rejected: the release publishes reviewed source, tests, human documentation and CI only, while private checkpoints, previous helper apps, local runtime records and screenshots stay outside Git. The archive audit enforces the exclusion — local paths, session identifiers, key material and personal commit addresses abort packaging — and the source archive is the exact commit's files rather than a copy of the working directory.

## Consequences

- Users upgrading from the old names keep their notification permission and their settings; users running the old plugin and relay alongside this one get duplicate reminders until they remove them.
- The frozen bundle identifier and namespace are compatibility surface: changing either is a permission and navigation migration, not a rename.
- The unverified platform scope is unchanged by the rename: macOS 13+ is the build target and older systems plus Intel machines still need real-device acceptance, as recorded in [`docs/compatibility.md`](../../../../docs/compatibility.md).
- Reminders work without a browser and without a model call; the diagnostic surface that reports on them excludes conversation content, local paths, credentials and raw logs by design.

## Related

- [Add a native menu-bar session panel to the existing helper](../feature/2026-10-07-native-session-menu.md) reuses this identity, the private state directory and the authenticated navigation path.
