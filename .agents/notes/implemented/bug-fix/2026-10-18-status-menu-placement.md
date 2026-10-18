# Agent Note: Let the native status item place its context menu

Status: implemented

## Problem

The right-click menu could initially cover the menu bar, hide its first action behind a scroll-up affordance, and move downward when the pointer moved. It used `NSMenu.popUp(positioning:at:in:)` with `button.bounds.minY`. An AppKit probe establishes that `NSStatusBarButton.isFlipped` is true: this coordinate names the button's top edge, rather than its lower edge. A manually positioned menu therefore starts from the wrong menu-bar boundary.

## Decision

`SessionMenuController.showStatusMenu()` temporarily assigns the generated menu to `NSStatusItem.menu` and invokes the status button's native click path. AppKit owns menu placement instead of receiving a hand-computed point. A `defer` removes the menu when tracking returns, preserving the ordinary left-click session panel after cancellation or selection (`macos/SessionMenu.swift`).

The popover closes and removes its outside-click monitors before context-menu tracking starts. Menu actions and their existing task-exit confirmation remain unchanged. This refines [the status-action decision](../feature/2026-10-18-status-menu-actions.md).

## Alternatives considered

**Correct the manually supplied lower-edge coordinate.** Using the flipped button's other edge would correct that point, but still leaves the helper responsible for placement at the display boundary. The status item already supplies the native pull-down menu path, so it owns the geometry directly.

**Keep the menu permanently attached.** A non-nil status-item menu takes over its normal click behavior. Temporary attachment allows right-click menu tracking while retaining the approved left-click session panel.

## Consequences

The regression fixture observes real AppKit menu tracking, checks that it uses the status item's attached menu and that the first action fits vertically within a screen's usable area before any pointer movement, then cancels tracking and verifies that the menu detaches and the session panel can open again (`tests/native-menu-actions.swift`). This establishes native component behavior; it does not independently reproduce the user's physical pointer movement or certify every display and menu-bar configuration.
