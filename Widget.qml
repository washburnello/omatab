import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "TimeModel.js" as TimeModel
import "Toml.js" as Toml

// Bar icon + settings for the time-progress line. The line (Strip.qml) is
// drawn on this bar window's own surface rather than in a window of its own:
// the bar's layer surface spans the whole screen, transparent past the strip
// it paints, so an item reparented onto its content item can sit on the
// strip's inner edge, in front of it, and park/fade with the bar for free.
Panel {
  id: root
  moduleName: "washburnello.omaprogress"
  ipcTarget: "washburnello.omaprogress"

  Commons.Translations { id: tr; directory: Qt.resolvedUrl("i18n") }

  // ------------------------------------------------------------ settings
  readonly property var cfg: TimeModel.normalize(root.settings)
  readonly property color lineColor: {
    var v = TimeModel.colorValue(cfg.color)
    return v ? v : Commons.Color.accent
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ------------------------------------------------------------- time
  property double nowMs: Date.now()
  readonly property var span: TimeModel.span(nowMs, cfg)

  // About one pixel of travel per tick.
  Timer {
    interval: Math.max(250, Math.min(60000, Math.round(root.span.durationMs / Math.max(1, strip.length || 1920))))
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  // ------------------------------------------------------------- loop wrap
  // What the line and ring draw. It follows span.fraction tick by tick, but
  // when the fraction falls back (a loop or reset) it sweeps back to the new
  // value instead of jumping, optionally in a rainbow.
  property real shownFraction: 0
  property real rainbowPhase: 0
  property real rainbowLevel: 0
  property string lastCfgKey: ""

  onSpanChanged: {
    var key = JSON.stringify(cfg)
    var f = span.fraction
    if (wrapAnim.running) {
      wrapAnim.toValue = f
    } else if (key === lastCfgKey && cfg.loopAnimation && f < shownFraction - 0.02) {
      startWrap(shownFraction, f)
    } else {
      shownFraction = f
    }
    lastCfgKey = key
  }

  function startWrap(from, to) {
    wrapAnim.stop()
    wrapAnim.fromValue = from
    wrapAnim.toValue = to
    wrapAnim.start()
  }

  function previewWrap() { startWrap(1, span.fraction) }

  SequentialAnimation {
    id: wrapAnim
    property real fromValue: 1
    property real toValue: 0
    readonly property int sweep: Style.duration(1400)

    ParallelAnimation {
      NumberAnimation {
        target: root; property: "shownFraction"
        from: wrapAnim.fromValue; to: wrapAnim.toValue
        duration: wrapAnim.sweep
        easing.type: Easing.OutCubic
      }
      // Constant hue scroll, so linear.
      NumberAnimation {
        target: root; property: "rainbowPhase"
        from: 0; to: 2
        duration: wrapAnim.sweep
      }
      NumberAnimation {
        target: root; property: "rainbowLevel"
        to: root.cfg.rainbow ? 1 : 0
        duration: Style.duration(160)
        easing.type: Easing.OutCubic
      }
    }
    NumberAnimation {
      target: root; property: "rainbowLevel"
      to: 0
      duration: Style.duration(320)
      easing.type: Easing.OutCubic
    }
    onFinished: root.shownFraction = root.span.fraction
  }

  function formatTime(ms) {
    return new Date(ms).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale), Locale.ShortFormat)
  }

  function remainingText(ms) {
    var mins = Math.ceil(ms / 60000)
    if (mins < 90) return tr.tn("remaining.minutes", mins).arg(Commons.I18n.formatNumber(mins))
    return tr.t("remaining.hours")
      .arg(Commons.I18n.formatNumber(Math.floor(mins / 60)))
      .arg(Commons.I18n.formatNumber(mins % 60))
  }

  readonly property string tooltip: {
    if (!cfg.enabled) return tr.t("tooltip.off")
    return tr.t("tooltip")
      .arg(formatTime(nowMs))
      .arg(remainingText(span.remainingMs))
      .arg(Commons.I18n.formatNumber(Math.floor(span.fraction * 100)))
  }

  // ------------------------------------------------------------ placement
  readonly property var hostWindow: root.Window.window
  readonly property Item hostItem: hostWindow ? hostWindow.contentItem : null
  readonly property string barPosition: bar ? String(bar.position || "top") : "top"
  readonly property bool barVertical: bar ? bar.vertical === true : false
  readonly property real thickness: {
    var state = bar && bar.shell ? bar.shell.bar : null
    var name = hostWindow && hostWindow.screen ? String(hostWindow.screen.name || "") : ""
    if (state && typeof state.barSizeFor === "function") return state.barSizeFor(name)
    return bar ? bar.barSize : 0
  }
  // The bar surface spanning its screen is an implementation detail of the
  // stock bar. If it ever shrinks to the strip, hide rather than draw clipped.
  readonly property real surfaceAcross: hostItem ? (barVertical ? hostItem.width : hostItem.height) : 0
  readonly property bool surfaceFits: hostItem !== null && thickness > 0
    && surfaceAcross > thickness + cfg.lineHeight + 4
  // Across the bar, the strip spans [stripStart, stripStart + thickness) on
  // the surface; a bottom or right bar sits on the far side.
  readonly property bool barOnFarSide: barPosition === "bottom" || barPosition === "right"
  readonly property real stripStart: barOnFarSide ? surfaceAcross - thickness : 0
  readonly property bool onScreenEdge: cfg.edge === "outer"
  readonly property real lineCross: {
    var atStripStart = barOnFarSide !== onScreenEdge
    return atStripStart ? stripStart : stripStart + thickness - cfg.lineHeight
  }
  readonly property bool travelReversed: barVertical ? cfg.directionV === "up" : cfg.directionH === "left"
  readonly property bool lineVisible: cfg.enabled && surfaceFits

  Strip {
    id: strip
    parent: root.hostItem
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    shown: root.lineVisible
    fraction: root.shownFraction
    rainbowLevel: root.rainbowLevel
    rainbowPhase: root.rainbowPhase
    fillColor: root.lineColor
    trackOpacity: root.cfg.trackOpacity
    lineHeight: root.cfg.lineHeight
    pipStyle: root.cfg.pipStyle
    pipSize: TimeModel.PIP_SIZES[root.cfg.pipSize]
    vertical: root.barVertical
    reverse: root.travelReversed
    lineCross: root.lineCross
    hang: root.barOnFarSide ? -1 : 1
  }

  // ------------------------------------------------------------ bar size
  // Machine-level override file shared with `omarchy display text size`;
  // only the one [bar] size line for the current orientation is touched:
  // size-horizontal is a top/bottom bar's height, size-vertical a side bar's width.
  readonly property string userTomlPath: Quickshell.env("HOME") + "/.config/omarchy/shell.toml"
  property string userTomlText: ""
  readonly property string barSizeKey: barVertical ? "size-vertical" : "size-horizontal"
  readonly property var barHeightOverride: Toml.readNumber(userTomlText, "bar", barSizeKey)
  readonly property int barHeightThemeDefault: {
    var v = Number(Commons.Color.themeShellValues ? Commons.Color.themeShellValues["bar." + barSizeKey] : NaN)
    return isFinite(v) && v > 0 ? Math.round(v) : (barVertical ? 28 : 26)
  }
  readonly property int barHeightValue: barHeightOverride !== null ? Math.round(barHeightOverride) : barHeightThemeDefault

  function setBarHeight(value) {
    var v = value === null ? null : Math.round(Math.max(16, Math.min(64, value)))
    var next = Toml.setNumber(userTomlFile.text(), "bar", root.barSizeKey, v)
    userTomlFile.setText(next)
    // A FileView's own write raises no change signal.
    root.userTomlText = next
  }

  FileView {
    id: userTomlFile
    path: root.userTomlPath
    watchChanges: true
    printErrors: false
    onLoaded: root.userTomlText = text()
    onLoadFailed: root.userTomlText = ""
    onFileChanged: reload()
  }

  // ------------------------------------------------------------ bar button
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltip
    iconComponent: Component {
      Item {
        Shape {
          id: ring
          readonly property real size: button.iconSize
          readonly property real stroke: Math.max(1.5, size * 0.16)
          readonly property real r: (size - stroke) / 2
          x: (parent.width - size) / 2
          y: (parent.height - size) / 2
          width: size
          height: size
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            strokeWidth: ring.stroke
            strokeColor: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, root.cfg.enabled ? 0.3 : 0.45)
            fillColor: "transparent"
            PathAngleArc {
              centerX: ring.size / 2; centerY: ring.size / 2
              radiusX: ring.r; radiusY: ring.r
              startAngle: 0; sweepAngle: 360
            }
          }

          ShapePath {
            strokeWidth: ring.stroke
            strokeColor: root.cfg.enabled ? root.lineColor : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
              centerX: ring.size / 2; centerY: ring.size / 2
              radiusX: ring.r; radiusY: ring.r
              startAngle: -90
              sweepAngle: 360 * root.shownFraction
            }
          }
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.persistSettings({ enabled: !root.cfg.enabled })
      else root.toggle()
    }
  }

  // ------------------------------------------------------------ panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(900))

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: settingsPanel.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsPanel.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        SettingsPanel {
          id: settingsPanel
          width: panelFlick.width - Style.space(10)
          controller: root
          strings: tr
        }
      }
    }
  }

  IpcHandler {
    target: "washburnello.omaprogress.ctl"

    function toggleLine(): string { root.persistSettings({ enabled: !root.cfg.enabled }); return "ok" }
    function previewLoop(): string { root.previewWrap(); return "ok" }
    // 0 goes back to the theme default.
    function barHeight(value: int): string { root.setBarHeight(value > 0 ? value : null); return "ok" }
    function status(): string {
      return JSON.stringify({
        cfg: root.cfg, fraction: root.span.fraction, remainingMs: root.span.remainingMs,
        thickness: root.thickness, surfaceFits: root.surfaceFits, lineVisible: root.lineVisible,
        surfaceAcross: root.surfaceAcross, lineCross: root.lineCross, vertical: root.barVertical, reversed: root.travelReversed, barHeight: root.barHeightValue
      })
    }
  }
}
