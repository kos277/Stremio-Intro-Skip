# One Pace Skip Intro — macOS / official Stremio

A small **Hammerspoon** utility that adds a Netflix-inspired **SKIP INTRO | ⚙** overlay to the **official Stremio 5 desktop app on macOS**. It automatically appears during the beginning of a video, counts down, and seeks to a user-configured time using Stremio's existing timeline. The official Stremio player is unchanged.

**Documented stable baseline:** 1.0.0 (project documentation label), verified by the user on **Stremio 5.1.28**, October 2026. User-reported environment: **Hammerspoon 1.1.1 (6936)** and **macOS Tahoe 26.7**. See [PROJECT_STATE.md](PROJECT_STATE.md) for design decisions, architecture, limitations, and troubleshooting.

> **Keep your own working `~/.hammerspoon/init.lua` as the primary source of truth.** The `init.lua` in this archive is a *reference reconstruction* from the latest shared code plus the confirmed final 2.5-second hide delay, not a byte-for-byte export from your Mac. Before replacing an already-working installation, back up and compare the local file.

## How to install or restore

1. Install the **official Stremio desktop app** for macOS and [Hammerspoon](https://www.hammerspoon.org/). This was tested with **Stremio 5.1.28**; newer Stremio versions may need adjustment.
2. Open Hammerspoon once. Under **System Settings → Privacy & Security → Accessibility**, allow Hammerspoon to control your Mac; macOS may require you to quit and reopen it. Keep Hammerspoon running in the menu bar.
3. In Finder, choose **Go → Go to Folder…**, enter `~/.hammerspoon`, and open `init.lua`. If it doesn't exist, create a plain-text file with that exact name.
4. **Back up any existing `init.lua` first.** Copy the project's `init.lua` into `~/.hammerspoon/init.lua`. If you already use other Hammerspoon automation, do not overwrite it blindly—merge the code and check for shortcut conflicts.
5. From Hammerspoon's menu bar icon, select **Reload Config**. Check the Hammerspoon Console if it reports a Lua error.
6. If your old Hammerspoon preferences survived, the saved skip timestamp and seek-bar calibration may still work. **On a fresh installation or a different screen, calibrate the seek bar below.**
7. Play an episode in **fullscreen official Stremio**. The overlay should appear before your saved intro endpoint, then automatically skip after its countdown.

### First-time seek-bar calibration

The script clicks a calculated point on Stremio's native timeline; it needs the actual screen coordinates of the **beginning** and **end** of the seek bar. They are stored by Hammerspoon, not in `init.lua`.

For a first-time setup, temporarily append this helper to the **bottom of `~/.hammerspoon/init.lua`** and reload:

```lua
-- TEMPORARY SEEK BAR CALIBRATION (remove after setup)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "1", function()
    hs.settings.set("onepace_seek_start", hs.mouse.absolutePosition())
    hs.alert.show("Seek bar START saved")
end)

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "2", function()
    hs.settings.set("onepace_seek_end", hs.mouse.absolutePosition())
    hs.alert.show("Seek bar END saved")
end)
```

1. Play an episode fullscreen and seek **past the intro** first, so the overlay is hidden and cannot cover the bar.
2. Move the pointer to the **very beginning of the seek bar** without clicking; press **Control + Option + Command + 1**.
3. Move it to the **very end of the seek bar** without clicking; press **Control + Option + Command + 2**.
4. Remove the temporary calibration helper (optional, but recommended), **save and reload** Hammerspoon so the overlay can reposition using the stored coordinates.
5. Rewind the episode to the beginning and test a manual or automatic skip. If it clicks the wrong location, recalibrate and reload again.

The start position should be to the left of the end position. Recalibrate after changing display, resolution, scaling, or Stremio window geometry if seeking becomes inaccurate.

## Everyday use

- At the start of a video, the button appears when playback is **before your configured intro endpoint**. Detection occurs on a **4-second interval**.
- It displays **SKIP INTRO** for ~1 second, then **SKIP IN 3 → 2 → 1** for one second each; clicking the main area skips immediately.
- At the end of the countdown, it seeks automatically and displays **SKIPPING...** for **2.5 seconds** before hiding. The 2.5 seconds is a fixed visual delay, *not* playback-completion detection.
- Click the **⚙ cog** to edit the target (e.g. `1:42`, `2:30`, `3:15`). The countdown is suspended during editing and restarts after returning to Stremio.
- The target is remembered across restarts. The current target **might not** be `1:42`; that is only the *initial fallback* when no value has been saved.
- The overlay hides when the intro is over or Stremio isn't the foreground application. Rewinding into the intro can trigger the auto-skip sequence again; the code does **not** identify episodes by title.

### Shortcuts

| Shortcut | Action |
| --- | --- |
| **Ctrl + Option + Command + E** | Edit the skip timestamp, including when the overlay is hidden |
| **Ctrl + Option + Command + P** | Debug: show timestamps exposed by Stremio Accessibility |
| **Ctrl + Option + Command + 0** | Manually toggle overlay visibility (auto-monitor may override this on a later scan) |
| **Ctrl + Option + Command + 1 / 2** | Only if the **temporary calibration helper** has been added: capture seek-bar start / end |

## Change the timings

At the top of `init.lua`, these controls are independent:

```lua
local INITIAL_DISPLAY_DELAY = 1  -- Initial SKIP INTRO label
local AUTO_SKIP_DELAY = 3       -- Three-second countdown
local CHECK_INTERVAL = 4        -- Accessibility scan interval
local SKIP_DISPLAY_DELAY = 2.5  -- SKIPPING... visual duration
```

Change one value, save, then choose **Reload Config**. The last number (`SKIP_DISPLAY_DELAY`) is the confirmed final preference; `1.2` seconds was judged too short.

## Back up or move to another Mac

Store **both** these project documents and your actual working script somewhere backed up (e.g. `iCloud Drive/Projects/OnePaceSkipIntro/`). The Mac reads only `~/.hammerspoon/init.lua`; the iCloud copy is a backup, not the runtime file.

The target and seek-bar coordinates live separately under these `hs.settings` keys:

- `onepace_skip_seconds`
- `onepace_seek_start`
- `onepace_seek_end`

If you need to inspect them, open the **Hammerspoon Console** and run each expression below to see the current values:

```lua
print(hs.inspect({
    seconds = hs.settings.get("onepace_skip_seconds"),
    start = hs.settings.get("onepace_seek_start"),
    finish = hs.settings.get("onepace_seek_end")
}))
```

You can save the printed values privately alongside the backup, but **seek coordinates should normally be recalibrated on a different Mac or display**. Enable Hammerspoon's **Launch at Login** preference if you'd like the utility available automatically after a restart.

## If an update breaks it

Consult [PROJECT_STATE.md](PROJECT_STATE.md), especially **Architecture**, **Invariants**, and **Regression tests**. The key questions are whether Stremio still exposes current/duration values to Accessibility and whether clicking the calibrated native timeline still seeks. Don't replace the official player or add episode-identification logic unless a new requirement actually needs it.
