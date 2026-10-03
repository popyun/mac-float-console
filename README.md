# Mac Float Console

**A small, always-available macOS panel for system health and Codex quota.**

[简体中文](README.zh-CN.md) · English

Mac Float Console lives in the menu bar and opens a movable, pin-able floating panel. It shows system-wide CPU and memory usage alongside the remaining Codex 5-hour and weekly quotas. Collapse the demo system switches or shrink the whole panel when you need more screen space.

![Default panel with illustrative values](docs/images/dashboard.png)

<sub>Product preview with illustrative values. The running app reads live metrics and the signed-in Codex account.</sub>

## What works today

| Area | Behavior | Update |
| --- | --- | --- |
| CPU | System-wide busy time across all logical processors; click for top CPU processes | Every 2 seconds |
| Memory | Active, wired, and physically compressed RAM as a share of installed RAM; click for page categories and top resident processes | Every 2 seconds |
| Codex | Remaining percentage and local reset time for available 5-hour and weekly windows | At launch, every 5 minutes, or manually |
| Floating window | Drag, pin, lock, collapse switches, shrink/expand, hide/reopen from menu bar | Immediate |
| System switches | Prevent sleep, Do Not Disturb, show hidden files, auto-hide Dock | **UI demo only** |

The compact panel stays 180 points wide, includes both Codex percentages, omits reset times, and uses 75% opacity:

![Compact panel with illustrative values](docs/images/compact.png)

The default panel is 280 × 242 points. Expanding the switch section makes it 280 × 366; compact mode is 180 × 106. Click either metric bar to open its on-demand detail. Click the same bar or the detail's close button to collapse it. A metric click in compact mode opens the full detail.

![CPU process detail with illustrative values](docs/images/cpu-detail.png)
![Memory page and process detail with illustrative values](docs/images/memory-detail.png)

## Run locally

Requires macOS 14 or newer and Xcode Command Line Tools with Swift. Build the source on your Mac:

~~~sh
zsh scripts/build-app.sh
open dist/系统控制台.app
~~~

The build creates a locally signed app and a zip in the ignored dist directory. The repository does not contain a prebuilt or notarized release. CPU and memory work without a login. To display live Codex quota, install and sign in to the Codex CLI with a ChatGPT account.

Drag the title area in the normal panel, or drag the Codex data area in compact mode; the CPU and memory bars remain clickable. The blue button expands the compact panel. The pin button toggles always-on-top; the lock button prevents dragging in either mode. Closing the panel leaves its menu-bar icon available for reopening or quitting.

## Data and privacy

CPU comes from consecutive macOS processor-time samples, so the first percentage appears after roughly two seconds. Memory uses macOS virtual-memory counters; its definition is close to, but may differ slightly from, Activity Monitor's Memory Used. Whole-number percentages may stay unchanged when utilization is steady.

Process details use the local `ps` command and are sampled only while a detail is open. Per-process CPU treats one core as 100% and may exceed 100%, so it is not directly comparable with the 0–100% system-wide bar. Per-process memory is resident set size (RSS); shared pages can be counted in several processes, so the rows cannot be summed into system memory used. Inactive pages are shown for context but excluded from the memory bar. Process lists are neither uploaded nor saved.

Codex quota is read through the locally installed Codex CLI app-server, using its read-only rate-limits request. The app does not read or save authentication tokens, create model turns, or consume quota-reset credits. If the CLI is unavailable or signed out, the UI shows an unavailable state; a failed refresh preserves the last successful reading. No analytics, telemetry, or app-level preference storage is implemented.

The four colored switches change only their on-screen state. They do not change macOS settings and reset when the app exits. The Edit shortcut entry is deliberately disabled.

## Project docs and development

- [Product requirements / PRD (English)](docs/PRD.en.md)
- [产品需求文档 / PRD（简体中文）](docs/PRD.zh-CN.md)
- [中文使用说明](README.zh-CN.md)

~~~sh
zsh scripts/check-system-metrics.sh
zsh scripts/check-quota.sh
zsh scripts/export-previews.sh --demo
~~~

The preview command renders the SwiftUI interface using synthetic CPU, memory, and Codex values. Its images go to the ignored artifacts directory. The checked-in images above are synthetic previews, never captures of a personal Codex account.

The next product milestone is to make system switches real with explicit permission, state reconciliation, and local persistence. Shortcut editing and distribution packaging follow that work.
