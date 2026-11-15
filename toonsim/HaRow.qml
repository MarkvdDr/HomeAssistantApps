import QtQuick 2.1

// Universele rij: titel/subtitel links, waarden rechts, optioneel schakelaar en -/+ knoppen
Item {
    id: row
    width: 366
    height: 44

    property string title: ""
    property string subtitle: ""
    property string value1: ""
    property string value2: ""
    property color value1Color: "#000000"
    property bool showSwitch: false
    property bool checked: false
    property bool showStep: false
    property bool active: true

    property int rightPad: (showSwitch ? 64 : 0) + (showStep ? 80 : 0)
    property int textWidth: Math.max(40, row.width - rightPad - 24 - Math.max(v1.paintedWidth, v2.paintedWidth))

    signal toggled()
    signal stepUp()
    signal stepDown()

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#e8e8e8"
        opacity: row.active ? 1.0 : 0.5
    }

    Text {
        x: 12
        y: row.subtitle === "" ? (row.height - height) / 2 : 5
        width: row.textWidth
        elide: Text.ElideRight
        text: row.title
        font.pixelSize: 15
        font.family: qfont.semiBold.name
        color: "#000000"
    }

    Text {
        x: 12
        y: 25
        width: row.textWidth
        visible: row.subtitle !== ""
        elide: Text.ElideRight
        text: row.subtitle
        font.pixelSize: 11
        font.family: qfont.regular.name
        color: "#616161"
    }

    Text {
        id: v1
        anchors.right: parent.right
        anchors.rightMargin: 10 + row.rightPad
        y: row.value2 === "" ? (row.height - height) / 2 : 5
        text: row.value1
        font.pixelSize: 15
        font.family: qfont.semiBold.name
        color: row.value1Color
    }

    Text {
        id: v2
        anchors.right: parent.right
        anchors.rightMargin: 10 + row.rightPad
        y: 25
        text: row.value2
        font.pixelSize: 11
        font.family: qfont.regular.name
        color: "#616161"
    }

    Row {
        visible: row.showStep
        anchors.right: parent.right
        anchors.rightMargin: 10 + (row.showSwitch ? 64 : 0)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        HaButton { width: 34; height: 34; text: "-"; onClicked: row.stepDown() }
        HaButton { width: 34; height: 34; text: "+"; onClicked: row.stepUp() }
    }

    HaSwitch {
        visible: row.showSwitch
        enabled: row.active
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        checked: row.checked
        onClicked: row.toggled()
    }
}
