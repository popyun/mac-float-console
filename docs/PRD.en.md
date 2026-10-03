# Mac Float Console — Product Requirements

[简体中文](PRD.zh-CN.md) · English · [Project overview](../README.md)

- **Status:** Working MVP / interface prototype
- **Platform:** macOS 14+
- **Current scope:** Live system metrics and Codex quota; preview-only system switches

## 1. Product brief

Mac Float Console is a menu-bar utility with a small floating panel. It brings system-wide CPU and memory usage together with the signed-in user's Codex quota, so a Mac user can check both without opening Activity Monitor or a separate account page. The panel can remain on top, be locked against accidental movement, or shrink to a translucent status strip.

The visual system-switch section demonstrates the intended control surface. It is deliberately separated from the live metrics and **does not change macOS settings in this version**.

## 2. Users and jobs

| User | Job to be done |
| --- | --- |
| Mac user | Notice a change in CPU or RAM use while working in another app. |
| Codex user | Check remaining short and weekly quota, and know when each window resets. |
| Small-screen user | Keep only essential percentages visible without covering the workspace. |

## 3. Goals and boundaries

The MVP should make live data glanceable, stay unobtrusive, and clearly distinguish real readings from demo controls. It should use the existing local Codex login, without introducing a second sign-in or copying credentials.

This release does not execute the four system switches, save UI preferences, edit shortcuts, show historical charts, manage Codex accounts, or provide a notarized downloadable binary.

## 4. Experience specification

| Mode | Size | Visible content | Window behavior |
| --- | --- | --- | --- |
| Default | 280 × 242 pt | Header, CPU, memory, Codex quota and reset times, collapsed system-setting section | 100% opacity; pin on by default |
| Settings expanded | 280 × 366 pt | Default content plus four demo switches | Same position anchor, 100% opacity |
| Compact | 180 × 106 pt | CPU, memory, Codex 5-hour and weekly remaining percentages; expand button | 75% opacity; reset times hidden |
| Metric detail | Adds 188 pt (CPU) or 246 pt (memory) to the full panel | Five processes; memory also shows active, wired, compressed and inactive pages | Opens on demand; updates every 2 seconds |

- Click a CPU or memory bar to open its detail. Click it again or use the detail close button to collapse it. A metric click in compact mode opens that detail in full mode.
- Drag the header in full mode or the Codex data area in compact mode; metric bars remain clickable. Position lock disables dragging in either mode.
- The expand button remains clickable in compact mode. The context menu can also restore full mode.
- Closing hides the panel; the menu-bar icon reopens it and offers compact, lock and quit actions.
- Switches use green for on and red for off. They retain their demo state only until the app quits.
- The UI currently uses Chinese labels. This document and the README are available in Chinese and English; UI localization is future work.

## 5. Functional requirements and acceptance

| ID | Requirement | Acceptance |
| --- | --- | --- |
| FR-01 | Show system-wide CPU use. | Use the busy-time delta between successive processor samples; update every 2 seconds. Show an unavailable mark until the second sample. |
| FR-02 | Show physical memory use. | Display a whole-number percent and used/total amount from active, wired and compressor pages; update every 2 seconds. Do not label cached file pages as used. |
| FR-03 | Show Codex quota. | Read the current local CLI account at launch and every 5 minutes. Show remaining percent and local reset time for the available short and weekly windows. The refresh button requests an immediate read. |
| FR-04 | Handle unavailable quota honestly. | Missing fields show unavailable, never zero by assumption. If a later refresh fails, retain the last successful reading and mark it as older data. |
| FR-05 | Keep compact mode useful. | Show CPU, memory, and both Codex percentages; omit reset times. Apply 75% opacity to the whole window. A visible button restores full mode. |
| FR-06 | Control window placement. | Pin toggles floating level; lock blocks dragging. The panel stays reachable through the menu bar after closing. |
| FR-07 | Demonstrate switches safely. | All four switches respond visually and update the enabled count, but do not read or modify system settings or persist their state. Shortcut editing stays disabled. |
| FR-08 | Inspect metric detail on demand. | CPU shows five high-usage processes. Memory shows active, wired, compressed and inactive pages plus five processes ranked by RSS. Refresh while open every 2 seconds, stop reading processes when closed, and explain the difference from system-wide metrics. |

## 6. Data, states and constraints

**CPU:** macOS processor-time counters are sampled twice. Busy ticks across logical processors are divided by total tick growth. The percentage is a system-wide 0–100% reading rather than an individual process's multi-core percentage.

**Memory:** macOS virtual-memory counters provide active, wired and physically compressed pages. Their total is divided by installed physical RAM. This approximates Activity Monitor's “Memory Used”; exact numbers can differ because the underlying categories and rounding differ.

**Processes:** Opening a detail reads CPU percentage and resident set size (RSS) from the local `ps` command. Process CPU uses one core as 100% and may exceed 100%; it cannot be directly compared with the system-wide bar. RSS can count shared pages in multiple processes, so process rows cannot be summed into system memory used. Inactive pages appear as context but are excluded from the memory percentage. Process data stays on the Mac and is neither stored nor uploaded.

**Codex:** The installed CLI's local app-server handles authentication. The app sends a read-only rate-limit request, prefers the Codex entry in the multi-bucket response, and falls back to the legacy bucket. Remaining percentage is 100 minus used percentage, clamped to 0–100. Reset timestamps are displayed in the Mac's local time zone. A query has a 20-second timeout. The app neither reads authentication files directly nor creates model turns or consumes reset credits.

All UI state stays in memory for this MVP. The app implements no analytics or telemetry. The CLI may need network access to fetch quota. If a system metric cannot be sampled, its numeric value is unavailable rather than a fabricated percentage.

## 7. Quality bar

- The default and compact panels must not clip labels, percentages or controls.
- CPU and memory detail must not clip page categories, process rows or measurement notes; clicking a metric opens and closes its detail.
- Sampling continues while the panel is compact or the settings section is collapsed.
- Moving between modes retains the top-right position where screen bounds allow.
- Refreshing quota must not block the interface, start a Codex turn, or consume a reset credit.
- Preview images committed to the public repository must use synthetic data, not a personal quota capture.
- Validate the release build, app signature and plist; run CPU-delta/rollover, process parsing and quota-response checks; inspect rendered default, compact and metric-detail states.

## 8. Follow-on decisions

1. Define the exact OS effect, required permissions, state reconciliation and persistence for each switch before making any of them real.
2. Design the shortcut editor and choose a local preference format.
3. Localize the in-app UI and prepare a notarized distribution channel if a downloadable release is desired.

The PRD describes the implemented MVP as well as the deliberate boundaries above. The future items are proposals, not functionality claimed by the current app.
