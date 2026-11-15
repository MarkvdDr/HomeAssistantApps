import QtQuick 2.1

Rectangle {
    id: btn
    width: 120
    height: 44
    radius: 8

    property string text: ""
    property bool primary: false
    property color activeColor: "#5c6bc0"
    property color activeTextColor: "#ffffff"

    // lang indrukken (standaard 1 seconde)
    property int longPressInterval: 1000
    property bool longPressEnabled: false
    property bool longPressFired: false

    signal clicked()
    signal longPressed()

    color: mouse.pressed ? "#9fa8da" : (primary ? activeColor : "#cfd8dc")

    Text {
        anchors.centerIn: parent
        width: btn.width - 10
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: btn.text
        font.pixelSize: 15
        font.family: qfont.semiBold.name
        color: btn.primary ? btn.activeTextColor : "#000000"
    }

    Timer {
        id: pressTimer
        interval: btn.longPressInterval
        repeat: false
        onTriggered: {
            btn.longPressFired = true;
            btn.longPressed();
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        onPressed: {
            btn.longPressFired = false;
            if (btn.longPressEnabled) {
                pressTimer.restart();
            }
        }
        onReleased: pressTimer.stop()
        onCanceled: pressTimer.stop()
        onClicked: {
            if (!btn.longPressFired) {
                btn.clicked();
            }
        }
    }
}
