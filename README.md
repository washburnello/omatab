# OmaProgress

A time-awareness plugin for the Omarchy shell. A thin progress line runs the full
length of the screen along an edge of the bar (top, bottom, left or right), drawn in front of the bar. It
fills as the hour (or day, or a custom block) passes, with a pip marking now.

- **Spans:** the clock hour (default), the day, or a custom start time and length
  that loops or holds.
- **Look:** any color from the current theme, or a preset; track opacity; line
  thickness 1–8 px; inner or screen edge; direction of travel; circle, triangle, diamond, tick, glow
  or no pip, in three sizes.
- **Loop sweep:** when a span loops, the marker sweeps back to zero instead of
  jumping, optionally in a rainbow and raining sparks.
- **Bar size:** set the bar's height (or width, on a side) from the same panel;
  writes `[bar] size-horizontal`/`size-vertical` to `~/.config/omarchy/shell.toml`.
- **Bar icon:** a ring showing progress. Click for settings, right-click to toggle
  the line, hover for the time left.

## Install

```bash
git clone git@github.com:washburnello/omaprogress.git \
  ~/.config/omarchy/plugins/washburnello.omaprogress
omarchy bar put washburnello.omaprogress --after omarchy.tray
```

See [design.md](design.md) for how it works.
