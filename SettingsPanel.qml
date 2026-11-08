import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "TimeModel.js" as TimeModel

// Every control writes straight through controller.persistSettings(), which
// lands in shell.json and hot-reloads; the top-bar height goes to the user
// shell.toml instead.
Column {
  id: panelRoot

  property var controller: null
  property var strings: null

  readonly property var cfg: controller ? controller.cfg : TimeModel.DEFAULTS
  readonly property color fg: controller ? controller.barForeground : Commons.Color.foreground
  readonly property string ff: Style.font.family

  function t(key) { return strings ? strings.t(key) : key }
  function set(values) { if (controller) controller.persistSettings(values) }

  spacing: Style.space(10)

  component Label: Text {
    textFormat: Text.PlainText
    color: panelRoot.fg
    font.family: panelRoot.ff
    font.pixelSize: Style.font.body
    verticalAlignment: Text.AlignVCenter
  }

  component Header: PanelSectionHeader {
    foreground: panelRoot.fg
    fontFamily: panelRoot.ff
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
      accent: controller ? controller.lineColor : Commons.Color.accent
      onToggled: panelRoot.set({ enabled: !panelRoot.cfg.enabled })
    }
  }

  Label {
    width: parent.width
    opacity: 0.7
    font.pixelSize: Style.font.caption
    text: controller ? strings.t("span.range").arg(controller.formatTime(controller.span.start)).arg(controller.formatTime(controller.span.end))
      + "  ·  " + controller.remainingText(controller.span.remainingMs) : ""
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- span
  Header { text: panelRoot.t("section.span") }

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
        value: Math.floor(parent.parent.startMin / 60)
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
        onModified: function(v) {
          panelRoot.set({ startTime: TimeModel.formatClock(v * 60 + parent.parent.startMin % 60) })
        }
      }

      NumberField {
        label: panelRoot.t("custom.minute")
        from: 0; to: 59; stepSize: 5
        value: parent.parent.startMin % 60
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
        onModified: function(v) {
          panelRoot.set({ startTime: TimeModel.formatClock(Math.floor(parent.parent.startMin / 60) * 60 + v) })
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
  Header { text: panelRoot.t("section.color") }

  Flow {
    width: parent.width
    spacing: Style.space(8)

    Repeater {
      model: TimeModel.COLORS

      Rectangle {
        id: swatch
        required property var modelData
        readonly property bool selected: panelRoot.cfg.color === modelData.id
        readonly property color swatchColor: modelData.value ? modelData.value : Commons.Color.accent

        width: Style.space(26)
        height: width
        radius: width / 2
        color: swatchColor
        border.width: selected ? 2 : (swatchHover.hovered ? 1 : 0)
        border.color: panelRoot.fg

        // The theme swatch is marked so it reads as "follow the theme", not as
        // whatever colour the current accent happens to be.
        Text {
          visible: swatch.modelData.id === "theme"
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "T"
          font.family: panelRoot.ff
          font.pixelSize: Style.font.caption
          font.bold: true
          color: (0.299 * swatch.swatchColor.r + 0.587 * swatch.swatchColor.g + 0.114 * swatch.swatchColor.b) > 0.55 ? "#1a1b20" : "#f2f3f5"
        }

        HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: panelRoot.set({ color: swatch.modelData.id }) }

        PanelToolTip {
          visible: swatchHover.hovered
          text: panelRoot.t("color." + swatch.modelData.id)
        }
      }
    }
  }

  Label { text: strings ? strings.t("line.track").arg(Commons.I18n.formatNumber(Math.round(panelRoot.cfg.trackOpacity * 100))) : "" }

  PanelSlider {
    width: parent.width
    bar: controller ? controller.bar : null
    minimum: 0; maximum: 1; step: 0.05
    value: panelRoot.cfg.trackOpacity
    onReleased: function(v) { panelRoot.set({ trackOpacity: Math.round(v * 100) / 100 }) }
  }

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- line + marker
  Header { text: panelRoot.t("section.line") }

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

  // Each orientation keeps its own direction, so moving the bar between top
  // and side doesn't flip it.
  ButtonGroup {
    readonly property bool vertical: controller ? controller.barVertical : false
    foreground: panelRoot.fg
    fontFamily: panelRoot.ff
    value: vertical ? panelRoot.cfg.directionV : panelRoot.cfg.directionH
    options: vertical
      ? [{ value: "down", label: panelRoot.t("direction.down") }, { value: "up", label: panelRoot.t("direction.up") }]
      : [{ value: "right", label: panelRoot.t("direction.right") }, { value: "left", label: panelRoot.t("direction.left") }]
    onChanged: function(v) { panelRoot.set(vertical ? { directionV: v } : { directionH: v }) }
  }

  Label { text: strings ? strings.t("line.thickness").arg(Commons.I18n.formatNumber(panelRoot.cfg.lineHeight)) : "" }

  PanelSlider {
    width: parent.width
    bar: controller ? controller.bar : null
    minimum: 1; maximum: 8; step: 1; integer: true
    tickCount: 8
    value: panelRoot.cfg.lineHeight
    onReleased: function(v) { panelRoot.set({ lineHeight: Math.round(v) }) }
  }

  Header { text: panelRoot.t("section.marker") }

  // Six styles don't fit one ButtonGroup row, so these wrap.
  Flow {
    width: parent.width
    spacing: Style.space(6)

    Repeater {
      model: TimeModel.PIP_STYLES

      Button {
        required property string modelData
        text: panelRoot.t("pip." + modelData)
        bordered: true
        selected: panelRoot.cfg.pipStyle === modelData
        foreground: panelRoot.fg
        fontFamily: panelRoot.ff
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
  Item {
    width: parent.width
    height: Math.max(loopHeader.implicitHeight, previewButton.implicitHeight)

    Header {
      id: loopHeader
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: panelRoot.t("section.loop")
    }

    Button {
      id: previewButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: panelRoot.t("loop.preview")
      bordered: true
      foreground: panelRoot.fg
      fontFamily: panelRoot.ff
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
      accent: controller ? controller.lineColor : Commons.Color.accent
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

  PanelSeparator { width: parent.width; foreground: panelRoot.fg }

  // ---------------------------------------------------------- top bar
  Header { text: panelRoot.t("section.bar") }

  Item {
    width: parent.width
    height: Math.max(barHeightLabel.implicitHeight, resetButton.implicitHeight)

    Label {
      id: barHeightLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: !controller || !strings ? ""
        : (controller.barHeightOverride === null
          ? strings.t(controller.barVertical ? "bar.widthDefault" : "bar.heightDefault").arg(Commons.I18n.formatNumber(controller.barHeightValue))
          : strings.t(controller.barVertical ? "bar.width" : "bar.height").arg(Commons.I18n.formatNumber(controller.barHeightValue)))
    }

    Button {
      id: resetButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: controller !== null && controller.barHeightOverride !== null
      text: panelRoot.t("bar.reset")
      foreground: panelRoot.fg
      onClicked: if (controller) controller.setBarHeight(null)
    }
  }

  PanelSlider {
    width: parent.width
    bar: controller ? controller.bar : null
    minimum: 18; maximum: 48; step: 1; integer: true
    value: controller ? controller.barHeightValue : 26
    onReleased: function(v) { if (controller) controller.setBarHeight(Math.round(v)) }
  }
}
