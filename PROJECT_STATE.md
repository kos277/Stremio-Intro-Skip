# PROJECT_STATE — Stremio Intro Skip

**Status:** Functional, user-tested stable baseline. **Project reference version:** `1.0.0` (documentation label, not a formal published release). **Last confirmed:** 2026-10-07. **Target application:** official macOS **Stremio 5.1.28**. **Implementation:** Hammerspoon Lua (`~/.hammerspoon/init.lua`).

## Purpose and acceptance criteria — confirmed

Add a comfortable Netflix-inspired skip-intro experience for **any supported video** in official Stremio *without changing the native player or reducing video quality*. User-configured intros often end at different times for different runs of episodes; user must change skip endpoint quickly without editing Lua. The overlay should appear only during the intro; offer a brief opportunity to skip manually or change the time; automatically skip after a short countdown; look polished and disappear after seeking.

The user supplied their actual working Lua script. It replaces the earlier reconstructed reference and uses a **2-second** `SKIPPING...` display delay. The earlier notes described 2.5 seconds; the supplied working script is authoritative for the current baseline.

## Stable behavior — confirmed

1. Every **4 seconds**, while Stremio is foreground, an asynchronous macOS Accessibility search reads player time values. When exactly two parseable, distinct values are available, the smaller is taken as elapsed time and the larger as total duration. Basic validity guard: duration >= 180 seconds and greater than target.
2. Overlay appears when `current < target`; hides after target or when Stremio isn't active. The overlay may reappear on rewinding into an intro, including in the same episode. No dedicated episode identity detection is necessary.
3. When shown: **SKIP INTRO** (1 second) → **SKIP IN 3**, **SKIP IN 2**, **SKIP IN 1** (one second each) → automatic skip.
4. During the seek, show **SKIPPING...** for **2 seconds**. This is an aesthetic *fixed delay*, not a signal from Stremio that playback has resumed.
5. Clicking the primary button manually triggers the same seek; clicking the cog opens an editable `m:ss` / `h:mm:ss` timestamp dialog, pauses the countdown, and restores focus to Stremio afterward. Edited value persists across restarts. Keyboard shortcut can open editor even while overlay is hidden.
6. On skip, Hammerspoon moves the pointer to reveal the timeline, searches duration, computes `fraction = targetSeconds / durationSeconds`, calculates an X coordinate between saved start/end timeline positions, clicks the calibrated seek bar, and restores the original pointer location shortly afterward.
7. Pending countdown steps are cancelled on edit/hide. `skipAlreadyTriggered` prevents a second automatic skip while seeking. `skipFinishing`, a retained one-shot cleanup timer, an absolute deadline and the foreground-application check prevent `SKIPPING...` getting stuck onscreen.

## UI spec — preserve in revisions

- **Visual:** compact Netflix-style outlined black rectangle with **SKIP INTRO** centered within the main section, thin vertical divider, and **⚙** in a separate section. The user intentionally removed the extra arrow and the target-time label from the visible button; the time remains editable via cog.
- **Overall:** 195 px wide × 42 px tall; straight corners, dark fill (`white = 0`, `alpha = 0.88`), fine white stroke (`alpha = 0.90`, `strokeWidth = 1.2`).
- **Layout:** left section ~151 px for label; right section ~44 px for gear. Main text `HelveticaNeue-Bold`, 16 pt, centered, vertical frame `x=8, y=10, w=135, h=24`; gear 19 pt in `x=152, y=9, w=42, h=24`. Divider at `x=151`.
- **Hover:** translucent white highlights for main and settings hit areas, default `action="skip"`, on enter `action="fill"`.
- **Placement:** right-aligned slightly inward from calibrated seek bar: `x = seekEnd.x - 195 - 10`, `y = seekEnd.y - 42 - 35`; fallback is near bottom-right if no calibration exists. The user specifically chose the Netflix-like right-above-seek-bar position.
- **Fullscreen:** `skipUI:behavior({"canJoinAllSpaces", "transient"})`, `skipUI:clickActivating(false)`, and `skipUI:show():bringToFront(true)` when visible. These were tested successfully.

## Environment / dependencies

- User-reported environment: **macOS Tahoe 26.7**, **Hammerspoon 1.1.1 (6936)**, and official **Stremio 5.1.28**. Future Stremio versions **not verified**.
- [Hammerspoon](https://www.hammerspoon.org/), running with macOS **Accessibility permission**; `hs.canvas`, `hs.axuielement`, `hs.timer`, `hs.settings`, `hs.mouse`, `hs.eventtap`, `hs.application`, and `hs.dialog`.
- Does **not** modify Stremio, its addons, the video file, streaming quality, or install an alternative Stremio fork.
- Assumes one relevant fullscreen player on the calibrated display; seek-bar coordinates are absolute and may change with display or layout.

## File layout / ownership

| File / key | Responsibility |
| --- | --- |
| `~/.hammerspoon/init.lua` | **Actual live script on the user's Mac. Source of truth.** |
| `init.lua` (this package) | Working script supplied by the user, with project naming updated, built-in screen calibration shortcuts, and `SKIP_DISPLAY_DELAY = 2`. Compare with any newer local edits before restoring. |
| `README.md` | Installation, calibration, backup, usage, shortcuts |
| `PROJECT_STATE.md` | Current state, design rationale, regressions, upgrade guidance |
| `hs.settings` `onepace_skip_seconds` | User-selected target in seconds; fallback `102` = `1:42` only when setting missing |
| `hs.settings` `onepace_seek_start` | Absolute `{x, y}` timeline start calibration |
| `hs.settings` `onepace_seek_end` | Absolute `{x, y}` timeline end calibration |

These settings **are not backed up by copying the script alone**. The legacy `onepace_` key prefix is retained for compatibility with saved timestamps and calibration; it has no effect on content support.

## Timing parameters (confirmed final)

```lua
local AUTO_SKIP_DELAY = 3
local INITIAL_DISPLAY_DELAY = 1
local CHECK_INTERVAL = 4
local SKIP_DISPLAY_DELAY = 2
```

The 1 + 3 second display cycle starts **when the accessibility monitor detects the intro**, potentially up to roughly four seconds into the episode. `SKIPPING...` lasts another 2 seconds after skip is initiated; actual seek completion is **not** polled or confirmed by the overlay.

## Implementation architecture

- **Parsing (`parseTime`)**: accepts `m:ss` or `h:mm:ss`; rejects non-time strings and invalid minute/second fields.
- **Playback read**: `hs.axuielement.applicationElement("Stremio"):elementSearch(...)` identifies accessibility elements whose `AXValue` parses as time; asynchronous callback extracts exactly two unique timestamps, validates them, and calls visibility function.
- **Overlay**: `hs.canvas` with 8 ordered layers: border/background, two hover shapes, label, divider, cog, two hitboxes. `mouseCallback` routes `id == "skip"` to `executeSkip()` and `id == "edit"` to `editTimestamp()`.
- **Countdown**: `startCountdown()` schedules one-shot text changes and an execution timer. `countdownGeneration` guards against stale callbacks. `cancelCountdown()` stops timers and restores default text.
- **Seek (`skipIntro`)**: holds original mouse position, retrieves saved calibration, exposes timeline by moving cursor, queries duration, clicks `start.x + (end.x - start.x) * target/duration` at calibrated Y, then restores pointer.
- **Transition**: `executeSkip()` cancels countdown, locks duplicate seeks, shows `SKIPPING...`, schedules retained `skipHideTimer`, then calls `skipIntro()`. `finishSkipTransition()` always hides the overlay and resets text. A monitor-time deadline fallback is present, and leaving Stremio must always hide the overlay.
- **Edit**: `hs.dialog.textPrompt`, saves `hs.settings.set("onepace_skip_seconds", seconds)`; returns focus via `hs.application.get("Stremio"):activate()`; resumes playback visibility check afterward.
- **Shortcuts**: Ctrl+Option+Command+1 / 2 save seek-bar start / end at the pointer position; reload config afterward to reposition the overlay. P shows currently exposed timestamps; E edits; 0 temporarily toggles overlay.

## Constraints and design decisions

**Confirmed/current:**

- **Official Stremio only.** User explicitly rejected switching to alternative desktop clients/ports after Stremio Enhanced looked noticeably more washed out/compressed than native playback when compared on the exact same frame.
- **Hammerspoon overlay, not a Stremio addon.** Fullscreen overlay and calibrated click seeking were empirically tested; they work on the user's setup.
- **Content-independent operation**: No show-specific logic, addon integration, or external timestamp database. A manually adjustable global endpoint drives automatic skipping; intro boundaries are not detected automatically.
- **Minimal monitoring**: 4-second Accessibility scan; one-shot UI/countdown/cleanup timers; no image recognition, video processing, background server, or episode metadata database.
- **No episode title/ID detection**: A previous attempt over-engineered this, broke automatic skipping, and was explicitly rejected. The stable solution uses existing `current < target` visibility behavior.
- **Fixed 2-second visual transition**: User preferred longer persistence of the `SKIPPING...` state because Stremio needs a moment to seek and resume.

**Rejected or superseded:**

- Unofficial Stremio Enhanced and Community ports; native picture quality takes priority.
- Simple seek keybinding / repeated relative arrows; user required absolute time jump with a clickable editable button.
- Absolute timeline coordinate guesses; previously caused volume muting instead of seeking. Saved **manual calibration** fixed it.
- Instant disappearance upon triggering seek; jarring relative to Stremio's actual playback resume.
- Countdown beginning immediately without first showing `SKIP INTRO`; user wanted a one-second lead-in.
- `SKIP IN 3 → 2 → 1 → SKIP INTRO` post-countdown flash; replaced by the `SKIPPING...` transition.
- `skipFinishing` guard that could prevent hiding outside Stremio; now has explicit cleanup, foreground override, and fail-safe deadline.

**Unresolved / expected limitations:**

- New macOS/Stremio versions might change Accessibility tree, native timeline layout, or focus behavior; future compatibility unknown.
- Because the automation relies on two strings parsed as timestamps, extra timestamp-like Accessibility values can suppress the button as a precaution.
- The absolute seek click requires recalibration on changed monitor/layout/fullscreen geometry.
- Rewinding below target may re-trigger automatic skip. This is a deliberate consequence of the minimal design, not an episode-specific guard.
- `SKIPPING...` visibility uses a fixed timer, not an actual playback-resumed event. No requirement to implement costly state detection.
- The repository now contains the user-supplied working script; runtime behavior has not been independently verified in the Linux cloud environment.

## Regression tests (after any edits or Stremio updates)

1. **Startup and fullscreen**: Hammerspoon config reloads without Lua errors; overlay appears on a playing intro, correctly positioned above the right end of timeline.
2. **Countdown**: Show `SKIP INTRO` ~1 second → `SKIP IN 3` / `2` / `1` → automatic seek → `SKIPPING...` ~2 seconds → hides.
3. **Seek accuracy**: On the currently configured episode, actual playback lands near the saved target; no mistaken volume clicks or loss of subtitles/video quality.
4. **Mouse restoration**: After skip, mouse returns to its original location.
5. **Edit**: Cog opens dialog during intro; countdown stops; save a different target; dialog closes; button remains as appropriate and new countdown uses the new target. Test cancel too.
6. **Persistence**: Reload Hammerspoon; target and calibrated seek positions are retained.
7. **Visibility**: Button remains hidden after intro; switching away from Stremio always hides it; no lingering `SKIPPING...` overlay.
8. **Rewind / next stream**: Rewinding into intro and starting another episode each show button again; test actual auto-skip, not just visibility.
9. **Manual click**: Main button seeks immediately; it does not execute a second timer-driven skip.
10. **Failure safety**: In a non-playing Stremio screen or if Accessibility timestamps are absent, no spurious seek occurs; check Hammerspoon Console if behavior changes.

## Maintenance workflow for a future developer / ChatGPT conversation

1. Read **this file and `README.md`** and the repository’s `init.lua`. Before modifying an existing installation, check whether the user has made newer local edits to `~/.hammerspoon/init.lua`.
2. Ask for the symptom, Stremio version, Hammerspoon Console errors, what Ctrl+Option+Command+P displays, and whether fullscreen seek-bar coordinates changed. Prefer focused diagnostics over rewriting the entire script.
3. Preserve proven design/behavior; modify **only the relevant block**. Avoid speculative episode detection, external video players, and changing multiple mechanisms simultaneously.
4. Keep the stable baseline backed up before edits; after each change, run the regression checklist.
5. Update this project's status/version, new dependencies, tested environment, decisions, and any new failure modes whenever a revision is confirmed working.

## Revision record (functional milestones; not formal releases)

- Established native Stremio 5.1.28 + Hammerspoon fullscreen overlay and clickable hitboxes.
- Verified Accessibility timestamp read with playback controls hidden and calibrated seek to a target time.
- Added editable persistent target, pointer restoration, auto show/hide before target, polished Netflix-like compact UI.
- Added automatic 1 + 3-second countdown using the existing detection/seek pipeline; removed unsuccessful episode-detection experiment.
- Added `SKIPPING...` state and fixed stale/stuck overlay behavior by retained hide timer, deadline fallback and foreground override.
- **Current stable baseline:** user-supplied working `init.lua`, with `SKIP_DISPLAY_DELAY = 2`, replaces the reconstructed reference.

- Included screen calibration shortcuts in `init.lua` so setup requires only one code paste. Existing saved-setting keys and playback behavior are preserved.
