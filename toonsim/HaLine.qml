import QtQuick 2.1

// Regel met label links en waarde rechts (optioneel met gekleurd bolletje)
Item {
    id: line
    width: 216
    height: 26

    property string label: ""
    property string value: ""
    property color valueColor: "#000000"
    property bool showDot: false
    property color dotColor: "#9e9e9e"

    Rectangle {
        visible: line.showDot
        width: 12
        height: 12
        radius: 6
        color: line.dotColor
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        x: line.showDot ? 20 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(20, line.width - (line.showDot ? 20 : 0) - valueText.paintedWidth - 8)
        elide: Text.ElideRight
        text: line.label
        font.pixelSize: 15
        font.family: qfont.regular.name
        color: "#000000"
    }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: line.value
        font.pixelSize: 15
        font.family: qfont.semiBold.name
        color: line.valueColor
    }
}
