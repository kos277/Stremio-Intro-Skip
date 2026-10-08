# Stremio Intro Skip

Automatically skip to your chosen intro endpoint in **Stremio on macOS**. A small **SKIP INTRO | ⚙** button lets you skip immediately or change the time.

**New Mac?** Follow steps 1–3. **New screen or resolution?** Repeat step 2.

## 1. Install

1. Install [Stremio for macOS](https://www.stremio.com/downloads) and [Hammerspoon](https://www.hammerspoon.org/).
2. Open Hammerspoon. Allow it under **System Settings → Privacy & Security → Accessibility**. Quit and reopen Hammerspoon if prompted.
3. Open [init.lua](init.lua) here on GitHub and copy all the code using the **Copy raw file** button.
4. Click Hammerspoon’s icon in the **top menu bar** → **Open Config**. Paste the code into the editor and press **Command + S** to save. If there’s existing code, save a backup first; keep any other Hammerspoon tools you use.
5. Click the same Hammerspoon menu → **Reload Config**. Keep Hammerspoon running.

## 2. Set up your screen

Do this once for each new Mac, screen, resolution, or display layout. You’ll mark both ends of Stremio’s playback bar so the script knows where to click.

1. Click Hammerspoon’s menu bar icon → **Open Config**. Paste the block below at the **bottom** of the existing code, press **Command + S**, then choose **Reload Config** from the same menu.

```lua
-- Screen setup shortcuts
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "1", function()
    hs.settings.set("onepace_seek_start", hs.mouse.absolutePosition())
    hs.alert.show("Seek bar START saved")
end)

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "2", function()
    hs.settings.set("onepace_seek_end", hs.mouse.absolutePosition())
    hs.alert.show("Seek bar END saved")
end)
```

2. Play a video in **fullscreen Stremio on the screen you’ll use**. Seek well past the intro so the skip button disappears. Move the mouse to show the playback bar.
3. Point at the **far-left end of the playback bar** without clicking. Press **Control + Option + Command + 1**.
4. Point at the **far-right end of the same bar** without clicking. Press **Control + Option + Command + 2**.
5. Choose **Reload Config** again.

Use the long **video progress bar**, not the volume slider. You can leave the setup shortcuts in the file; next time you change screens, repeat steps 2–5. Don’t paste the block twice.

## 3. Choose the skip time

1. With Stremio open, press **Control + Option + Command + E**.
2. Enter the time where the intro ends, such as **1:42**, and click **Save**. This time is remembered and applies to all videos until you change it.

Click **SKIP INTRO** to skip immediately, or **⚙** to change the time.

To start Hammerspoon automatically after restarting your Mac, enable **Launch at Login** in its preferences.

## If something doesn’t work

| Problem | What to do |
| --- | --- |
| It clicks the wrong place or skips to the wrong time | Repeat **step 2** on your current screen, then check your saved time with **Control + Option + Command + E**. |
| No skip button | Keep Hammerspoon running, check its Accessibility permission, and choose **Reload Config**. Play a video longer than three minutes from the beginning with Stremio in front. |
| An error appears when reloading | Open Hammerspoon’s **Console** and copy the error when asking for help. |

User-reported working setup: **Stremio 5.1.28 · Hammerspoon 1.1.1 (6936) · macOS Tahoe 26.7**. Other versions may need adjustments.

For technical details and maintenance, see [PROJECT_STATE.md](PROJECT_STATE.md).
