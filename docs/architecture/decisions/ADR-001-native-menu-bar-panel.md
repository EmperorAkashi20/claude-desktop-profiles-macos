# ADR-001: Native menu-bar panel

Status: Accepted

## Context

The original NSMenu combines account labels, percentages, reset times and freshness in wide multiline items. Long names make switching difficult to scan. The fork is limited to presentation and existing local labels; the CLI and account/session mechanisms must remain unchanged.

## Decision

Host a SwiftUI panel in an AppKit NSPopover attached to the existing NSStatusItem. Use only system frameworks supported by macOS 13. Keep views and the AppDelegate in `menubar/main.swift`, and pure presentation helpers in `menubar/Usage.swift`, so the installer remains unchanged.

Present cached remaining usage as horizontal bars with explicit unknown states and separate model-specific caps. Edit names through the CLI's existing label command and configuration format. Keep the original CLI process invocation, switch wait and refresh interval.

## Consequences

The panel supports system appearance, native controls, keyboard shortcuts and accessibility without a new application, dependency or persistence layer. More profiles require scrolling. Switching still relaunches Claude; cached usage cannot support reliable live-limit automation. The upstream installer, CLI, authentication, synchronization and uninstall behavior remain compatible.
