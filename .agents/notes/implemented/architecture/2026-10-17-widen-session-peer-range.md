# Agent Note: Widen the session peer range so a newer 0.2.x harness still loads the bundle

Status: implemented

## Problem

DSH 0.2.1-rc.1 added a plugin compatibility gate: a profile bundle whose `@deepseek-ai/dsh-*` peer requirements do not match the running harness is skipped whole, and the skip is silent — the settings section, the notifications and the menu-bar helper simply never appear.

This package pinned `@deepseek-ai/dsh-session` and `@deepseek-ai/dsh-session-format-catalog` to the exact `0.2.0-rc.2`, the harness the release had been verified against. Updating Desktop to 0.2.1-rc.1 therefore dropped the bundle even though the interfaces it consumes had not changed.

## Decision

`package.json` declares both peers as `>=0.2.0-rc.2 <0.3.0-0` (commit `4968192`). The floor is the harness whose behaviour the recorded verification covers; the ceiling admits the whole 0.2 line and still blocks `0.3.0` prereleases.

The two packages are the only harness packages the plugin imports directly: `lib/menu-source.js:2-3` uses `foldSurface`/`deriveEventMessage` from `@deepseek-ai/dsh-session` and the message projections from `@deepseek-ai/dsh-session-format-catalog`. Everything else it consumes is fetched at runtime, and the range says nothing about those.

The widening rests on the umbrella's compatibility review of this plugin (`docs/reviews/2026-10-17-dsh-macos-notify-compat.md` in the umbrella checkout) and on the release commit:

- The plugin's own Node regressions pass against the installed 0.2.1-rc.1 session, session-query and format-catalog packages (113/113).
- `foldSurface` and `deriveEventMessage` are byte-identical to 0.2.0-rc.2.
- The format catalog differs only by additions, and `SESSION_FORMAT_VERSION` is still 4.
- The live Desktop resumed writing the session-menu snapshot after the range change.

Real notification delivery, menu interaction and approval/question windows on 0.2.1-rc.1 remain separate live acceptance steps; this note is not evidence for them.

## What the range does not cover

The gate reads peer declarations only, so it is narrower than the surface the plugin consumes. Everything the plugin resolves by name at runtime — host services and events, client services, the settings slot it mounts into, and the two client packages named in `dsh.client.inject` (`@deepseek-ai/dsh-client-ui-settings`, `@deepseek-ai/dsh-client-locale`) — is admitted by any range that matches; the extracted surface and the cross-plugin inventory hold that list, and this note records only the consequence.

The review recorded the client side of it as the standing exposure: no gate covers client API or slot changes, so the settings section and the session menu can break without a load error, and the check after a harness change has to exercise them rather than read a version. Widening the peer range buys a load-time refusal for two session packages; it does not buy compatibility for the rest of the surface.

## Alternatives considered

**Pin the running version exactly (`0.2.1-rc.1`).** This was the compatibility review's recommended option, on the grounds that every harness upgrade then forces a deliberate re-declaration. It lost because it reproduces the same silent skip at the next patch — `0.2.1-rc.2` would be blocked — while the verified interface pair stays unchanged inside the line; the review also recorded that an exact pin forces `devDependencies.@deepseek-ai/dsh-session-query` to move in step.

**Narrow the range to `>=0.2.1-rc.1 <0.2.2-0`** (the review's option B): admit the tested patch line only. It lost the same way — the review found `foldSurface`, `deriveEventMessage` and the format catalog unchanged between 0.2.0-rc.2 and 0.2.1-rc.1, so refusing 0.2.2 would be a version-string refusal with no interface fact behind it.

**Declare no peer range at all.** An undeclared package is neither checked nor blocked: it loads, then fails at the first call into a changed interface. For a plugin whose job is delivering notifications, a runtime failure inside the notification path is worse than a load-time skip that shows up in the profile.

**Let the profile grant an exact-version exemption and change no package** (the review's option D). The exemption binds one package version to one exact harness version, inherits across neither plugin nor harness upgrades, and changes no manifest — so this repository's own release stays unloadable on 0.2.1-rc.1 for anyone who installs it fresh. It is a local workaround, not something that travels with the package.

**Declare `engines.dsh` instead of peer dependencies.** The gate's documented behaviour is that an own `engines.dsh` range decides alone and the peers are then ignored; that would swap a statement about the two session packages the plugin imports for a statement about the whole harness build, which is not the thing that broke.

**Write the ceiling as `<0.3.0` rather than `<0.3.0-0`.** The review's range probe showed that prereleases participate in range semantics, so `<0.3.0` admits `0.3.0-alpha.1` — exactly the next breaking prerelease the ceiling exists to stop.

## Consequences

- Any 0.2.x harness loads the bundle without a declaration change, and a load-time refusal returns at the next breaking line. The cost is that a real interface break inside 0.2.x is admitted silently and surfaces at the first call rather than at load.
- The declaration tracks the two session packages, not the harness build; the rest of the consumed surface stays ungated and is verified by use after a harness change.
- `0.2.0-rc.2` stays the floor because it is the version the recorded byte-comparisons and test evidence are against. Raising the floor needs new evidence, not a new harness release.
- The default suite runs against the pinned dev packages (`@deepseek-ai/dsh-session-query` `0.2.0-rc.2`, which resolves the same session and format-catalog versions), so a green `npm test` proves the floor rather than the running harness. The 0.2.1-rc.1 evidence came from a separate run of the same suite against the installed runtime packages.
