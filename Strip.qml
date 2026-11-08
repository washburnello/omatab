import QtQuick
import QtQuick.Shapes
import qs.Commons

// The progress line itself. Widget.qml reparents this onto the bar window's
// content item, which spans the screen, so it paints over the bar strip and
// the clear surface below it without being a window of its own. It takes no
// input: the bar's input mask covers only the strip, and enabled: false keeps
// this item from eating presses meant for bar widgets.
Item {
  id: root

  property bool shown: true
  property real fraction: 0
  property color fillColor: "white"
  property real trackOpacity: 0.25
  property int lineHeight: 2
  property string pipStyle: "circle"
  property int pipSize: 9
  // Top of the line in this item's coordinates; Widget.qml places it on
  // whichever bar edge is chosen, always inside the bar strip.
  property real lineY: 0
  // Which way the triangle hangs: into the bar for the screen edge, out of
  // it for the inner edge.
  property bool hangDown: true

  enabled: false
  z: 10000

  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity {
    NumberAnimation { duration: Style.duration(root.shown ? 180 : 120); easing.type: Easing.OutCubic }
  }

  readonly property real lineMid: lineY + lineHeight / 2
  readonly property real headX: Math.round(fraction * width)

  Rectangle {
    x: 0
    y: root.lineY
    width: root.width
    height: root.lineHeight
    color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.trackOpacity)
  }

  Rectangle {
    x: 0
    y: root.lineY
    width: root.headX
    height: root.lineHeight
    color: root.fillColor
  }

  Item {
    id: pip
    readonly property real size: Math.max(root.pipSize, root.lineHeight + 4)
    visible: root.pipStyle !== "none"
    x: root.headX - size / 2
    y: root.lineMid - size / 2
    width: size
    height: size

    Rectangle {
      visible: root.pipStyle === "circle"
      anchors.fill: parent
      radius: width / 2
      color: root.fillColor
    }

    Rectangle {
      visible: root.pipStyle === "diamond"
      anchors.centerIn: parent
      width: parent.width / Math.SQRT2
      height: width
      rotation: 45
      antialiasing: true
      color: root.fillColor
    }

    Rectangle {
      visible: root.pipStyle === "tick"
      anchors.centerIn: parent
      width: Math.max(2, Math.round(root.lineHeight))
      height: parent.height + 2
      radius: width / 2
      color: root.fillColor
    }

    // Apex on the line.
    Shape {
      visible: root.pipStyle === "triangle"
      x: 0
      y: parent.height / 2 - (root.hangDown ? 0 : parent.height)
      width: parent.width
      height: parent.height
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.fillColor
        startX: pip.width / 2; startY: root.hangDown ? 0 : pip.height
        PathLine { x: pip.width; y: root.hangDown ? pip.height : 0 }
        PathLine { x: 0; y: root.hangDown ? pip.height : 0 }
        PathLine { x: pip.width / 2; y: root.hangDown ? 0 : pip.height }
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
          GradientStop { position: 0.0; color: root.fillColor }
          GradientStop { position: 0.25; color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 0.8) }
          GradientStop { position: 1.0; color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 0) }
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
