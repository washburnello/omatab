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
    interval: Math.max(250, Math.min(60000, Math.round(root.span.durationMs / Math.max(1, strip.width || 1920))))
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
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
  readonly property bool surfaceFits: hostItem !== null && thickness > 0
    && hostItem.height > thickness + cfg.lineHeight + 4
  // The bar strip spans [stripTop, stripTop + thickness) on the surface.
  readonly property real stripTop: barPosition === "bottom" && hostItem ? hostItem.height - thickness : 0
  readonly property bool onScreenEdge: cfg.edge === "outer"
  readonly property real lineY: {
    var atStripTop = (barPosition === "bottom") !== onScreenEdge
    return atStripTop ? stripTop : stripTop + thickness - cfg.lineHeight
  }
  readonly property bool lineVisible: cfg.enabled && !barVertical && surfaceFits

  Strip {
    id: strip
    parent: root.hostItem
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    shown: root.lineVisible
    fraction: root.span.fraction
    fillColor: root.lineColor
    trackOpacity: root.cfg.trackOpacity
    lineHeight: root.cfg.lineHeight
    pipStyle: root.cfg.pipStyle
    pipSize: TimeModel.PIP_SIZES[root.cfg.pipSize]
    lineY: root.lineY
    hangDown: root.barPosition !== "bottom"
  }

  // ------------------------------------------------------------ top bar height
  // Machine-level override file shared with `omarchy display text size`;
  // only the [bar] size-horizontal line is ever touched.
  readonly property string userTomlPath: Quickshell.env("HOME") + "/.config/omarchy/shell.toml"
  property string userTomlText: ""
  readonly property var barHeightOverride: Toml.readNumber(userTomlText, "bar", "size-horizontal")
  readonly property int barHeightThemeDefault: {
    var v = Number(Commons.Color.themeShellValues ? Commons.Color.themeShellValues["bar.size-horizontal"] : NaN)
    return isFinite(v) && v > 0 ? Math.round(v) : 26
  }
  readonly property int barHeightValue: barHeightOverride !== null ? Math.round(barHeightOverride) : barHeightThemeDefault

  function setBarHeight(value) {
    var v = value === null ? null : Math.round(Math.max(16, Math.min(64, value)))
    var next = Toml.setNumber(userTomlFile.text(), "bar", "size-horizontal", v)
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
              sweepAngle: 360 * root.span.fraction
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
    // 0 goes back to the theme default.
    function barHeight(value: int): string { root.setBarHeight(value > 0 ? value : null); return "ok" }
    function status(): string {
      return JSON.stringify({
        cfg: root.cfg, fraction: root.span.fraction, remainingMs: root.span.remainingMs,
        thickness: root.thickness, surfaceFits: root.surfaceFits, lineVisible: root.lineVisible,
        hostHeight: root.hostItem ? root.hostItem.height : -1, barHeight: root.barHeightValue
      })
    }
  }
}
