# omaprogress — design

An Omarchy shell plugin that shows time passing as a thin, YouTube-style progress
line on an edge of the top bar, with a bar icon for toggling and settings.

- Plugin id: `washburnello.omaprogress`, kind `bar-widget` (icon in `bar.layout.right`)
- Location: `~/.config/omarchy/plugins/washburnello.omaprogress/`
- Tracking: private GitHub repo `washburnello/omaprogress`, Kaneo project
  `omaprogress` (workspace `w4sh`), `MAJOR.MINOR` versions via `version-track`

## Goal

A glanceable "where am I in the hour / day / work block" indicator: a full-width
line with a subdued empty track, a filled part for elapsed time, and a pip marking
now. By default it covers one clock hour: empty at :00, full at :59:59, then it
starts over.

## Rendering: drawn on the bar's own surface

Findings from the stock bar (`shell/plugins/bar/Bar.qml`, `BarPanel`):

- The bar's `PanelWindow` covers its **whole screen** (`implicitHeight: screen.height`,
  `color: "transparent"`). Only `barStrip` (the top `thickness` px) is painted.
- Input is masked to the strip (`mask: stripInputRegion`), so anything drawn on
  the clear area lets clicks through.
- When the bar hides, it moves (parks) its whole surface off-screen rather than
  unmapping it.

The widget reparents one `Item` (`Strip.qml`) onto its own window's
`Window.window.contentItem` (the same move `Ui/MultiSelect.qml` makes) with a high
`z`. No extra layer surface. The line is in front of the bar strip, moves off-screen
and fades with the bar because it is part of the same surface, and every screen's
bar gets its own line because the widget exists once per screen.

### Geometry
- `thickness = bar.shell.bar.barSizeFor(screen.name)` (the plugin bar-state API;
  includes notch floors).
- **Edge** setting:
  - `inner` (default): the line overlaps the bar's inner edge, i.e. the bottom
    `lineHeight` px of a top bar.
  - `outer`: it sits on the screen edge, i.e. the top `lineHeight` px.
- In both cases the line stays inside the bar strip and gets thicker inward from
  the edge it sits on.
- Width: the full screen width. The pip is centered on the line at
  `x = fraction × width`. Wherever it pokes past the strip it is on the clear,
  click-through part of the surface.
- Bottom bar: mirrored. Vertical bar: the line is hidden.
- **Safety guard:** the line hides if the surface is not taller than the strip
  plus the line. That would mean a future Omarchy update stopped making the bar
  surface span its screen.

### Update cadence
The timer interval is `durationMs / screenWidth`, clamped to 250 ms … 60 s. That
is about one pixel of travel per tick (≈1.3 s for 1h at 2752 logical px).

## Time spans (`TimeModel.js`)

| Mode | Start | Duration | At the end |
|------|-------|----------|------------|
| `hour` (default) | top of the current hour | 60 min | starts over |
| `day` | local midnight | 24 h | starts over |
| `custom` | `startTime` (HH:MM) | `durationMin` | `loop` (default) or `hold` |

- **loop:** cycles are anchored to today's `startTime` and repeat every `durationMin`.
- **hold:** empty before the start and full after the end. A block that started
  yesterday and runs past midnight is still found.
- Presets: 15m, 30m, 1h, 2h, 4h, and 8h (which also sets the start to 08:00).
- Span boundaries come from local `Date` fields, so DST stretches or shrinks the
  hour or day it lands in instead of shifting it.

`span(nowMs, cfg) → { start, end, durationMs, fraction, remainingMs }`

## Settings

Inline on the widget's `shell.json` layout entry, written through
`bar.shell.updateEntryInline`. Every value is validated when read (`normalize`).

```json
{
  "id": "washburnello.omaprogress",
  "enabled": true,
  "mode": "hour",
  "startTime": "08:00",
  "durationMin": 480,
  "endBehavior": "loop",
  "color": "theme",
  "trackOpacity": 0.25,
  "edge": "inner",
  "lineHeight": 2,
  "pipStyle": "circle",
  "pipSize": "medium"
}
```

- **color:** `theme` (the theme accent, follows theme switches), `red`, `orange`,
  `yellow`, `green`, `cyan`, `blue`, `purple`, `pink`, `white`.
- **trackOpacity:** the empty part is the same color at this opacity.
- **lineHeight:** 1–8 px.
- **pipStyle:** `circle`, `triangle` (apex on the line, hanging away from the
  screen edge), `diamond`, `tick`, `glow`, `none`. **pipSize:** small / medium / large.

### Top bar height
The bar's own height is the `[bar] size-horizontal` token. The plugin writes it
to the machine-level `~/.config/omarchy/shell.toml`, the same file
`omarchy display text size` uses for `[font]`. The shell watches that file and
lets it override the theme, so the change applies live and survives theme
switches.

`Toml.js` edits only that one line and leaves other sections and comments as they
are. "Use theme default" removes the key, and removes the `[bar]` section too if
nothing else is in it. The value is the raw token; with `scale-with-font` the
drawn height scales with `[font] base-size`.

## Bar icon and panel (`Widget.qml`, `SettingsPanel.qml`)

- **Icon:** a ring that fills to the current fraction in the line color, dimmed
  when the line is off.
- **Tooltip:** `2:54 PM · 6 min left · 90%`.
- **Left-click:** opens the settings panel (`KeyboardPanel`). **Right-click:**
  turns the line on or off.
- **Panel sections:** title with enable switch; current range and time left;
  Time span; Color (swatches and track slider); Line (edge, thickness); Marker;
  Top bar (height slider and reset).

### IPC
- `omarchy-shell washburnello.omaprogress open|close|toggle`: the panel.
- `omarchy-shell washburnello.omaprogress.ctl status`: JSON diagnostics.
- `... .ctl toggleLine`: turns the line on or off.
- `... .ctl barHeight <n>`: sets the bar height (`0` = theme default).

## Shell conventions followed

- Plain-text `Text` everywhere.
- `Style.duration()` for the 180/120 ms fade, eased out.
- Strings through `Commons.Translations` (`i18n/en.json`), numbers through
  `Commons.I18n.formatNumber`, times through `Qt.locale(Commons.I18n.formatLocale)`.
- No network, no subprocesses. Never edits `/usr/share/omarchy/`.

## Known limits

- Quickshell caches plugin file contents. Edits to the plugin's QML sometimes
  need `omarchy restart shell` before they show up, even though the shell logs a
  reload.
- The surface-reparenting approach depends on how the stock bar is built
  internally (see the safety guard). A replacement `kind: "bar"` plugin may not
  provide a full-screen surface, in which case the line stays hidden.

## Ideas

- A soft tick at the halfway mark.
- A notification when a span ends.
- A hover readout that grows the line.
