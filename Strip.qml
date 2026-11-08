import QtQuick
import QtQuick.Shapes
import qs.Commons

// The progress line itself. Widget.qml reparents this onto the bar window's
// content item, which spans the screen, so it paints over the bar strip and
// the clear surface past it without being a window of its own. It takes no
// input: the bar's input mask covers only the strip, and enabled: false keeps
// this item from eating presses meant for bar widgets.
//
// Geometry is "along" the bar (the direction of travel) and "across" it.
Item {
  id: root

  property bool shown: true
  property real fraction: 0
  property color fillColor: "white"
  property real trackOpacity: 0.25
  property int lineHeight: 2
  property string pipStyle: "circle"
  property int pipSize: 9
  // A left/right bar runs the line top-to-bottom.
  property bool vertical: false
  // Travel right-to-left, or bottom-to-top.
  property bool reverse: false
  // Near side of the line across the bar, in this item's coordinates; Widget.qml
  // places it on whichever bar edge is chosen, always inside the bar strip.
  property real lineCross: 0
  // Which way a triangle hangs across the bar, away from the screen edge:
  // +1 toward larger x/y, -1 toward smaller.
  property int hang: 1
  // Rainbow sweep during a loop wrap: level fades it in and out, phase
  // scrolls the hues.
  property real rainbowLevel: 0
  property real rainbowPhase: 0

  function hue(offset) {
    var h = (offset + rainbowPhase) % 1
    return Qt.hsla(h < 0 ? h + 1 : h, 0.85, 0.62, 1)
  }
  // Gradient stops run left-to-right / top-to-bottom; the head always gets
  // hue(1) so it matches the pip.
  function stopHue(pos) { return hue(reverse ? 1 - pos : pos) }
  readonly property color pipColor: rainbowLevel > 0
    ? Qt.tint(fillColor, Qt.hsla(((rainbowPhase % 1) + 1) % 1, 0.85, 0.62, rainbowLevel))
    : fillColor

  enabled: false
  z: 10000

  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity {
    NumberAnimation { duration: Style.duration(root.shown ? 180 : 120); easing.type: Easing.OutCubic }
  }

  readonly property real length: vertical ? height : width
  readonly property real filled: Math.round(fraction * length)
  readonly property real fillStart: reverse ? length - filled : 0
  readonly property real headAlong: reverse ? length - filled : filled
  readonly property real lineMid: lineCross + lineHeight / 2

  // A span of the line from `along` for `extent`, mapped to x/y.
  component Segment: Rectangle {
    property real along: 0
    property real extent: 0
    x: root.vertical ? root.lineCross : along
    y: root.vertical ? along : root.lineCross
    width: root.vertical ? root.lineHeight : extent
    height: root.vertical ? extent : root.lineHeight
  }

  Segment {
    along: 0
    extent: root.length
    color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.trackOpacity)
  }

  Segment {
    along: root.fillStart
    extent: root.filled
    color: root.fillColor
  }

  Segment {
    visible: root.rainbowLevel > 0
    opacity: root.rainbowLevel
    along: root.fillStart
    extent: root.filled
    gradient: Gradient {
      orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
      GradientStop { position: 0.0; color: root.stopHue(0.0) }
      GradientStop { position: 0.1667; color: root.stopHue(0.1667) }
      GradientStop { position: 0.3333; color: root.stopHue(0.3333) }
      GradientStop { position: 0.5; color: root.stopHue(0.5) }
      GradientStop { position: 0.6667; color: root.stopHue(0.6667) }
      GradientStop { position: 0.8333; color: root.stopHue(0.8333) }
      GradientStop { position: 1.0; color: root.stopHue(1.0) }
    }
  }

  Item {
    id: pip
    readonly property real size: Math.max(root.pipSize, root.lineHeight + 4)
    visible: root.pipStyle !== "none"
    x: (root.vertical ? root.lineMid : root.headAlong) - size / 2
    y: (root.vertical ? root.headAlong : root.lineMid) - size / 2
    width: size
    height: size

    Rectangle {
      visible: root.pipStyle === "circle"
      anchors.fill: parent
      radius: width / 2
      color: root.pipColor
    }

    Rectangle {
      visible: root.pipStyle === "diamond"
      anchors.centerIn: parent
      width: parent.width / Math.SQRT2
      height: width
      rotation: 45
      antialiasing: true
      color: root.pipColor
    }

    // Across the line.
    Rectangle {
      visible: root.pipStyle === "tick"
      anchors.centerIn: parent
      readonly property real thin: Math.max(2, Math.round(root.lineHeight))
      width: root.vertical ? parent.width + 2 : thin
      height: root.vertical ? thin : parent.height + 2
      radius: Math.min(width, height) / 2
      color: root.pipColor
    }

    // Drawn hanging down (+y) with its apex on the pip's centre, then turned
    // about that centre to hang the way `hang` says.
    Item {
      visible: root.pipStyle === "triangle"
      anchors.fill: parent
      rotation: root.vertical ? (root.hang > 0 ? -90 : 90) : (root.hang > 0 ? 0 : 180)

      Shape {
        y: parent.height / 2
        width: parent.width
        height: parent.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: root.pipColor
          startX: pip.width / 2; startY: 0
          PathLine { x: pip.width; y: pip.height }
          PathLine { x: 0; y: pip.height }
          PathLine { x: pip.width / 2; y: 0 }
        }
      }
    }

    Shape {
      visible: root.pipStyle === "glow"
      anchors.centerIn: parent
      width: parent.width * 2.2
      height: width
      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillGradient: RadialGradient {
          centerX: pip.width * 1.1; centerY: pip.width * 1.1
          centerRadius: pip.width * 1.1
          focalX: centerX; focalY: centerY
          GradientStop { position: 0.0; color: root.pipColor }
          GradientStop { position: 0.25; color: Qt.rgba(root.pipColor.r, root.pipColor.g, root.pipColor.b, 0.8) }
          GradientStop { position: 1.0; color: Qt.rgba(root.pipColor.r, root.pipColor.g, root.pipColor.b, 0) }
        }
        PathAngleArc {
          centerX: pip.width * 1.1; centerY: pip.width * 1.1
          radiusX: pip.width * 1.1; radiusY: pip.width * 1.1
          startAngle: 0; sweepAngle: 360
        }
      }
    }
  }
}
