# Agent Note: Keep expanded subagent trees reachable within section height limits

Status: implemented

## Problem

The native panel's compact quota counted the flattened rows, so expanding a parent consumed the same slots as its root peers. A valid five-row tree could remain in a two-row viewport until the user separately expanded the section. On a short panel, a section could have only one row of space while its pinned parent occupied that entire row, hiding every child even when paging.

The 24-point subagent overflow controls also break the alignment assumed by paging in multiples of a 64-point session row. Rows after an intervening control can remain partially clipped on every page. Treating controls as unselectable leaves their hidden children unreachable through the table's direction-key navigation.

## Decision

The activity and recent sections allocate their compact quotas by root count. The height for each allocated root includes its currently expanded descendants. This preserves the shared default root quota while allowing a subtree to grow without a second section-expansion action (`macos/MenuSessionList.swift`, `macos/SessionMenuView.swift`).

Height limits still apply. Paging is available immediately for expanded descendants and whenever the viewport cannot fit its allocated roots. The separate section-expansion control appears only when additional roots exceed the compact quota. Parent pinning requires room for at least two rows; a single-row viewport uses paging without a pinned overlay.

Each parent initially reveals two children and a separate control for any remaining children. Paging targets the next hidden row using actual table rectangles and the pinned overlay's covered area, rather than assuming uniform row heights. The keyboard includes overflow controls in table selection; selection is retained by session identity or the control's parent identity because expanding children changes row indices. Activating an overflow control focuses the first newly revealed child, while collapsing it keeps focus on the surviving control.

This refines the bounded native panel described in [the session-menu decision](../feature/2026-10-07-native-session-menu.md); Host snapshot bounds and transport are unaffected.

## Alternatives considered

**Keep flattened-row quotas and require a second section expansion.** This makes a parent's disclosure appear incomplete and couples child visibility to an unrelated section control. Root quotas keep the default peer-session allocation without charging descendants against it.

**Always pin the expanded parent.** A pinned parent uses the entire single-row viewport, so paging changes the hidden child rather than making it visible. Disabling that overlay at one row preserves navigation to both parent and children.

**Keep paging in 64-point multiples.** Adding a 24-point control shifts later session rows away from those offsets. Snapping to the actual hidden row keeps both control and session rows wholly accessible across tree boundaries.

## Consequences

Expanded subtrees can make the default panel taller. The menu remains bounded, so large trees still require explicit paging and the parent is not continuously visible in a single-row viewport. Native tests cover activity and recent trees, nested descendants, 400 children, mixed-height multi-root paging in both directions, keyboard activation and focus across refreshes, selection visibility and both single-row and larger viewports; they establish component behavior without reinstalling the helper or exercising live Desktop navigation.
