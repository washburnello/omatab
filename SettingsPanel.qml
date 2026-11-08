import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "TimeModel.js" as TimeModel

// Every control writes straight through controller.persistSettings(), which
// lands in shell.json and hot-reloads; the bar size goes to the user
// shell.toml instead. Each group's header carries a reset-to-defaults icon.
Column {
  id: panelRoot

  property var controller: null
  property var strings: null

  readonly property var cfg: controller ? controller.cfg : TimeModel.DEFAULTS
  readonly property color fg: controller ? controller.barForeground : Commons.Color.foreground
  readonly property color accentColor: controller ? controller.lineColor : Commons.Color.accent
  readonly property string ff: Style.font.family
  readonly property bool vertical: controller ? controller.barVertical : false

  function t(key) { return strings ? strings.t(key) : key }
  function set(values) { if (controller) controller.persistSettings(values) }
  function reset(group) { if (controller) controller.resetGroup(group) }
  function isDefault(group) { return TimeModel.groupIsDefault(cfg, group) }

  spacing: Style.space(10)

  component Label: Text {
    textFormat: Text.PlainText
    color: panelRoot.fg
    font.family: panelRoot.ff
    font.pixelSize: Style.font.body
    verticalAlignment: Text.AlignVCenter
  }

  // Group title with an icon-only reset button, dimmed when the group is
  // already at its defaults. Extra controls (Preview) go in `trailing`.
  component GroupHeader: Item {
    id: gh
    property string text: ""
    property bool atDefault: true
    property alias trailing: trailingRow.data
    signal resetRequested()
    width: parent.width
    height: Math.max(ghText.implicitHeight, resetIcon.height, trailingRow.height)

    PanelSectionHeader {
      id: ghText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: gh.text
      foreground: panelRoot.fg
      fontFamily: panelRoot.ff
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Row {
        id: trailingRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)
      }

      PanelActionButton {
        id: resetIcon
        anchors.verticalCenter: parent.verticalCenter
        iconText: ""
        fontSize: Style.font.body
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
        tooltipText: panelRoot.t("reset")
        opacity: gh.atDefault ? 0.3 : 1
        enabled: !gh.atDefault
        onClicked: gh.resetRequested()
      }
    }
  }

  // PanelSlider plus a small pip under the track marking the default value.
  component DefaultSlider: Item {
    id: ds
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    property int tickCount: 0
    property real defaultValue: 0
    signal released(real value)
    width: parent.width
    height: slider.implicitHeight + Style.space(6)

    PanelSlider {
      id: slider
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      bar: controller ? controller.bar : null
      value: ds.value
      minimum: ds.minimum; maximum: ds.maximum; step: ds.step
      integer: ds.integer
      tickCount: ds.tickCount
      onReleased: function(v) { ds.released(v) }
    }

    Rectangle {
      readonly property real fraction: Math.max(0, Math.min(1, (ds.defaultValue - ds.minimum) / Math.max(0.0001, ds.maximum - ds.minimum)))
      width: Style.space(6)
      height: width
      radius: width / 2
      color: panelRoot.accentColor
      x: slider.trackX(fraction) - width / 2
      y: slider.height / 2 + slider.trackHeight / 2 + Style.space(3)
    }
  }

  component Swatch: Rectangle {
    id: swatch
    required property var modelData
    readonly property bool selected: panelRoot.cfg.color === modelData.id
    width: swatches.size
    height: width
    radius: width / 2
    color: modelData.value
    border.width: selected ? 2 : (swatchHover.hovered ? 1 : 0)
    border.color: panelRoot.fg

    HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: panelRoot.set({ color: swatch.modelData.id }) }

    PanelToolTip {
      visible: swatchHover.hovered
      text: swatch.modelData.label
    }
  }

  // ---------------------------------------------------------- title + switch
  Item {
    width: parent.width
    height: Math.max(titleText.implicitHeight, enableSwitch.implicitHeight)

    Label {
      id: titleText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: panelRoot.t("title")
      font.pixelSize: Style.font.title
      font.bold: true
    }

    ToggleSwitch {
      id: enableSwitch
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: panelRoot.cfg.enabled
      accent: panelRoot.accentColor
      onToggled: panelRoot.set({ enabled: !panelRoot.cfg.enabled })
    }
  }

  Label {
    width: parent.width
    opacity: 0.7
    font.pixelSize: Style.font.caption
    text: controller && strings ? strings.t("span.range").arg(controller.formatTime(controller.span.start)).arg(controller.formatTime(controller.span.end))
      + "  ·  " + controller.remainingText(controller.span.remainingMs) : ""
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- span
  GroupHeader {
    text: panelRoot.t("section.span")
    atDefault: panelRoot.isDefault("span")
    onResetRequested: panelRoot.reset("span")
  }

  ButtonGroup {
    foreground: panelRoot.fg
    fontFamily: panelRoot.ff
    value: panelRoot.cfg.mode
    options: [
      { value: "hour", label: panelRoot.t("mode.hour") },
      { value: "day", label: panelRoot.t("mode.day") },
      { value: "custom", label: panelRoot.t("mode.custom") }
    ]
    onChanged: function(v) { panelRoot.set({ mode: v }) }
  }

  Column {
    id: customColumn
    width: parent.width
    spacing: Style.space(8)
    visible: panelRoot.cfg.mode === "custom"

    readonly property int startMin: TimeModel.parseClock(panelRoot.cfg.startTime)

    Row {
      spacing: Style.space(10)

      Label { text: panelRoot.t("custom.start"); height: startHour.height }

      NumberField {
        id: startHour
        label: panelRoot.t("custom.hour")
        from: 0; to: 23
        value: Math.floor(customColumn.startMin / 60)
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
        onModified: function(v) {
          panelRoot.set({ startTime: TimeModel.formatClock(v * 60 + customColumn.startMin % 60) })
        }
      }

      NumberField {
        label: panelRoot.t("custom.minute")
        from: 0; to: 59; stepSize: 5
        value: customColumn.startMin % 60
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
        onModified: function(v) {
          panelRoot.set({ startTime: TimeModel.formatClock(Math.floor(customColumn.startMin / 60) * 60 + v) })
        }
      }
    }

    NumberField {
      label: panelRoot.t("custom.duration")
      from: 1; to: 1440; stepSize: 5
      value: panelRoot.cfg.durationMin
      foreground: panelRoot.fg
      fontFamily: panelRoot.ff
      onModified: function(v) { panelRoot.set({ durationMin: v }) }
    }

    ButtonGroup {
      foreground: panelRoot.fg
      fontFamily: panelRoot.ff
      value: String(panelRoot.cfg.durationMin)
      options: [
        { value: "15", label: "15m" },
        { value: "30", label: "30m" },
        { value: "60", label: "1h" },
        { value: "120", label: "2h" },
        { value: "240", label: "4h" },
        { value: "480", label: "8h" }
      ]
      onChanged: function(v) {
        var values = { durationMin: parseInt(v, 10) }
        // The 8h preset is a workday: start it at 08:00.
        if (v === "480") values.startTime = "08:00"
        panelRoot.set(values)
      }
    }

    ButtonGroup {
      foreground: panelRoot.fg
      fontFamily: panelRoot.ff
      value: panelRoot.cfg.endBehavior
      options: [
        { value: "loop", label: panelRoot.t("end.loop") },
        { value: "hold", label: panelRoot.t("end.hold") }
      ]
      onChanged: function(v) { panelRoot.set({ endBehavior: v }) }
    }
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- color
  GroupHeader {
    text: panelRoot.t("section.color")
    atDefault: panelRoot.isDefault("color")
    onResetRequested: panelRoot.reset("color")
  }

  // Row 1: the theme's whole palette (accent first, as "theme", so it keeps
  // following the accent). Row 2: the fixed presets. Both rows share one
  // swatch size, sized so the longer row fits on a single line.
  Item {
    id: swatches
    width: parent.width
    height: themeRow.height + Style.space(6) + presetRow.height

    readonly property var themeModel: {
      var out = [{ id: "theme", value: Commons.Color.accent, label: "accent" }]
      var list = controller ? controller.themeColors : []
      for (var i = 0; i < list.length; i++) {
        if (list[i].key === "accent") continue
        out.push({ id: "theme:" + list[i].key, value: list[i].value, label: list[i].key.replace(/_/g, " ") })
      }
      return out
    }
    readonly property var presetModel: {
      var out = []
      for (var i = 0; i < TimeModel.COLORS.length; i++)
        if (TimeModel.COLORS[i].value) out.push({ id: TimeModel.COLORS[i].id, value: TimeModel.COLORS[i].value, label: panelRoot.t("color." + TimeModel.COLORS[i].id) })
      return out
    }
    readonly property real gap: Style.space(3)
    readonly property real size: {
      var n = Math.max(themeModel.length, presetModel.length, 1)
      return Math.max(10, Math.min(Style.space(26), Math.floor((width - gap * (n - 1)) / n)))
    }

    Row {
      id: themeRow
      spacing: swatches.gap
      Repeater { model: swatches.themeModel; Swatch { } }
    }

    Row {
      id: presetRow
      y: themeRow.height + Style.space(6)
      spacing: swatches.gap
      Repeater { model: swatches.presetModel; Swatch { } }
    }
  }

  Label { text: strings ? strings.t("line.track").arg(Commons.I18n.formatNumber(Math.round(panelRoot.cfg.trackOpacity * 100))) : "" }

  DefaultSlider {
    minimum: 0; maximum: 1; step: 0.05
    value: panelRoot.cfg.trackOpacity
    defaultValue: TimeModel.DEFAULTS.trackOpacity
    onReleased: function(v) { panelRoot.set({ trackOpacity: Math.round(v * 100) / 100 }) }
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- direction
  // Each orientation keeps its own direction, so moving the bar between top
  // and side doesn't flip it.
  GroupHeader {
    text: panelRoot.t("section.direction")
    atDefault: panelRoot.isDefault("direction")
    onResetRequested: panelRoot.reset("direction")
  }

  ButtonGroup {
    foreground: panelRoot.fg
    fontFamily: panelRoot.ff
    value: panelRoot.vertical ? panelRoot.cfg.directionV : panelRoot.cfg.directionH
    options: panelRoot.vertical
      ? [{ value: "up", label: panelRoot.t("direction.up") }, { value: "down", label: panelRoot.t("direction.down") }]
      : [{ value: "left", label: panelRoot.t("direction.left") }, { value: "right", label: panelRoot.t("direction.right") }]
    onChanged: function(v) { panelRoot.set(panelRoot.vertical ? { directionV: v } : { directionH: v }) }
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- edge
  GroupHeader {
    text: panelRoot.t("section.edge")
    atDefault: panelRoot.isDefault("edge")
    onResetRequested: panelRoot.reset("edge")
  }

  ButtonGroup {
    foreground: panelRoot.fg
    fontFamily: panelRoot.ff
    value: panelRoot.cfg.edge
    options: [
      { value: "inner", label: panelRoot.t("edge.inner") },
      { value: "outer", label: panelRoot.t("edge.outer") }
    ]
    onChanged: function(v) { panelRoot.set({ edge: v }) }
  }

  Label { text: strings ? strings.t("line.thickness").arg(Commons.I18n.formatNumber(panelRoot.cfg.lineHeight)) : "" }

  DefaultSlider {
    minimum: 1; maximum: 8; step: 1; integer: true
    tickCount: 8
    value: panelRoot.cfg.lineHeight
    defaultValue: TimeModel.DEFAULTS.lineHeight
    onReleased: function(v) { panelRoot.set({ lineHeight: Math.round(v) }) }
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- marker
  GroupHeader {
    text: panelRoot.t("section.marker")
    atDefault: panelRoot.isDefault("marker")
    onResetRequested: panelRoot.reset("marker")
  }

  // All six styles on one line: equal-width chips that share the row.
  Row {
    id: markerRow
    width: parent.width
    spacing: Style.space(4)

    Repeater {
      model: TimeModel.PIP_STYLES

      Button {
        required property string modelData
        width: (markerRow.width - markerRow.spacing * (TimeModel.PIP_STYLES.length - 1)) / TimeModel.PIP_STYLES.length
        text: panelRoot.t("pip." + modelData)
        bordered: true
        selected: panelRoot.cfg.pipStyle === modelData
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
        fontSize: Style.font.bodySmall
        horizontalPadding: Style.space(2)
        onClicked: panelRoot.set({ pipStyle: modelData })
      }
    }
  }

  ButtonGroup {
    foreground: panelRoot.fg
    fontFamily: panelRoot.ff
    value: panelRoot.cfg.pipSize
    options: [
      { value: "small", label: panelRoot.t("size.small") },
      { value: "medium", label: panelRoot.t("size.medium") },
      { value: "large", label: panelRoot.t("size.large") }
    ]
    onChanged: function(v) { panelRoot.set({ pipSize: v }) }
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- loop
  GroupHeader {
    text: panelRoot.t("section.loop")
    atDefault: panelRoot.isDefault("loop")
    onResetRequested: panelRoot.reset("loop")
    trailing: Button {
      text: panelRoot.t("loop.preview")
      bordered: true
      foreground: panelRoot.fg
      fontFamily: panelRoot.ff
      fontSize: Style.font.bodySmall
      onClicked: if (controller) controller.previewWrap()
    }
  }

  component SwitchRow: Item {
    id: switchRow
    property string label: ""
    property bool checked: false
    signal toggled()
    width: parent.width
    height: Math.max(rowLabel.implicitHeight, rowSwitch.implicitHeight)

    Label {
      id: rowLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: switchRow.label
    }

    ToggleSwitch {
      id: rowSwitch
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: switchRow.checked
      accent: panelRoot.accentColor
      onToggled: switchRow.toggled()
    }
  }

  SwitchRow {
    label: panelRoot.t("loop.animate")
    checked: panelRoot.cfg.loopAnimation
    onToggled: panelRoot.set({ loopAnimation: !panelRoot.cfg.loopAnimation })
  }

  SwitchRow {
    label: panelRoot.t("loop.rainbow")
    checked: panelRoot.cfg.rainbow
    onToggled: panelRoot.set({ rainbow: !panelRoot.cfg.rainbow })
  }

  SwitchRow {
    label: panelRoot.t("loop.sparks")
    checked: panelRoot.cfg.sparks
    onToggled: panelRoot.set({ sparks: !panelRoot.cfg.sparks })
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- bar size
  GroupHeader {
    text: panelRoot.t("section.bar")
    atDefault: !controller || controller.barHeightOverride === null
    onResetRequested: if (controller) controller.setBarHeight(null)
  }

  Label {
    text: !controller || !strings ? ""
      : (controller.barHeightOverride === null
        ? strings.t(panelRoot.vertical ? "bar.widthDefault" : "bar.heightDefault").arg(Commons.I18n.formatNumber(controller.barHeightValue))
        : strings.t(panelRoot.vertical ? "bar.width" : "bar.height").arg(Commons.I18n.formatNumber(controller.barHeightValue)))
  }

  DefaultSlider {
    minimum: 18; maximum: 48; step: 1; integer: true
    value: controller ? controller.barHeightValue : 26
    defaultValue: controller ? controller.barHeightThemeDefault : 26
    onReleased: function(v) { if (controller) controller.setBarHeight(Math.round(v)) }
  }
}
