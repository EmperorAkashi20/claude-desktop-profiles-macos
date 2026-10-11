# Menu-bar panel

The UI fork uses a native AppKit popover with SwiftUI content. It keeps the original application identity, menu-bar placement and launch-at-login item.

## Accounts and controls

- Select an account row to invoke the existing switch command. The active row has a checkmark and an **Active** label. Selecting it again does nothing.
- The menu bar shows a compact account name and the lowest known general allowance. Model-specific limits appear separately inside the panel.
- Choose **Profile options → Rename profile**, or right-click a row, to edit its local name. Save invokes the existing `claude-profiles label` command. Empty names cannot be saved.
- **Next**, **Add profile**, **Refresh** and **Quit Profiles for Claude** retain their existing purpose. Adding a profile opens Claude's official sign-in flow.
- With the panel open, use ⌘1 through ⌘9, ⌘N for Next, ⌘R for Refresh, or Escape to dismiss. The name editor supports standard copy, paste and select-all shortcuts.

## Usage

Bars show the remaining percentage, not consumed usage. A low allowance also has a numeric label, so color is not the only signal. Model-specific weekly caps are identified by model and are excluded from the menu bar's general allowance.

**Unknown** means no percentage is available. Its neutral track is not a zero-percent reading. Unconfirmed, estimated and expired reset times stay hidden.

Every row displays its cache age. Refresh rereads the existing local usage files and cannot obtain a live server reading. Claude's Usage card remains the authority. Existing `usage-record` functionality is unchanged.

## Switching safely

Switching still uses the original CLI and relaunches Claude. Finish running responses first. The panel disables additional switch and rename actions while its existing switch wait is pending.

The UI does not force-quit Claude, rotate accounts on a limit, submit continuation prompts, change authentication, modify session data, or alter working directories. A refused or timed-out graceful quit remains governed by the unchanged CLI. The panel is not a guarantee that a task can run unattended.

## Native behavior and validation

System typography and semantic surfaces adapt to light and dark appearance. The panel is scrollable when profiles or usage windows exceed the available screen height. Controls expose accessibility labels, usage values and keyboard shortcuts. Popover animation follows macOS Reduce Motion.

Build with the unchanged installer, or compile without installation:

```bash
swiftc -O -target arm64-apple-macosx13.0 -o /tmp/ProfilesForClaude menubar/Usage.swift menubar/main.swift
swiftc -o /tmp/test-menu menubar/Usage.swift tests/menu/main.swift
/tmp/test-menu
```

Run the original sandbox suites before release. For manual acceptance, check all rows and bars, unknown data, model-only quotas, a long name, rename Save/Cancel and empty-name validation, shortcuts, dismissal, and an idle account switch followed by reopening an existing Code session. Test failure/empty states in a disposable environment rather than editing real profile data.

## Roll back the UI

Quit **Profiles for Claude** using its options menu. Reinstall a previously reviewed upstream revision, or replace `/Applications/Profiles for Claude.app` with a saved copy. This replaces only the menu-bar application; retain the current Claude data, shared workspaces and local profile configuration.

Names use the existing `~/.config/claude-profiles/config.json` labels and remain compatible with the upstream app. Rename them with `claude-profiles label` if desired. Do not restore an old Claude data directory over a newer coding session merely to undo this UI.
