# Agent Note: Keep status actions on the existing Desktop connection

Status: implemented

## Problem

The status icon has no contextual application actions, and the panel gear exposes menu-only controls instead of the plugin's settings page. The accessory helper's transient popover also needs explicit outside-click handling. Adding application exit creates a risk of interrupting active work when the bounded menu snapshot cannot establish that tasks are idle.

## Decision

The icon's native context menu owns Open DSH, Open DSH Notify Settings, Hide Menu Bar and Quit DSH. The gear shares the Notify settings action. Hiding persists the existing menu preference; quitting requests normal termination of Desktop and lets the existing helper lifecycle follow it. Active or pending tasks require a confirmation with Cancel as the default. Unknown, stale, invalid, unavailable or incomplete task state also requires confirmation.

Context-menu placement and restoration of left-click behavior are owned by [the native status-menu placement decision](../bug-fix/2026-10-18-status-menu-placement.md).

Settings navigation adds the fixed `open-notify-settings` kind to the existing private `open-session.json` / `jump-result.json` channel and authenticated pending/ack RPC. A settings request cannot be acknowledged as a session selection or name an arbitrary settings section. The client waits for the registered Notify section and the existing `sidebar.settings` shell, calls its shared store's `openSection`, checks the resulting open/active section state, then acknowledges. Lost receipts are retried without reopening a dialog the user has already closed.

The settings shell store is an ungated client interface inspected in Desktop 0.2.1-rc.2, not a new stable service promised by DSH. The registry exposes it as `entry.store`, separately from `entry.options`; registration input shape is not the shape returned by `slots.entries`. An isolated probe of the installed frontend registry verifies that distinction. If its shape or slot changes, the request times out visibly instead of pretending the settings page opened. Popover event monitors exist only while it is open, distinguish its own content and status button from other windows, and pass local clicks through unchanged. Closing the popover does not close independent question or approval windows.

## Alternatives considered

**Invent a settings URL or select it as a session.** The verified Desktop URL only focuses the application, while session routing validates real session identities. A typed fixed destination preserves both boundaries and reuses the authenticated carrier without adding a listener.

**Treat missing task data as idle, or force the application to exit.** Bounded and stale snapshots cannot prove that no work exists. Confirmation preserves the user's decision in that case, and normal termination keeps Desktop's own shutdown behavior.

**Rely exclusively on transient-popover dismissal.** That is already configured but does not cover the reported accessory-app interaction. Scoped local/global mouse monitors and deactivation handling make the intended dismissal explicit without consuming another application's click.

## Consequences

Settings navigation needs the updated Host/client and helper together; restarting Desktop loads the linked JS changes. Native fixtures exercise menu actions, quit decisions, private typed receipts and outside-click handling, and Node tests cover settings dispatch and acknowledgement. These component checks do not establish physical mouse behavior or a live Desktop settings navigation.
