import QtQuick 2.1

// Aan/uit schakelaar met de officiële TSC-afbeeldingen
Item {
    id: sw
    width: 50
    height: 36

    property bool checked: false
    signal clicked()

    Image {
        anchors.fill: parent
        source: sw.checked ? "qrc:/tsc/button_on.png" : "qrc:/tsc/button_off.png"
        smooth: true
    }

    Image {
        y: 0
        x: sw.checked ? 18 : 1
        width: 32
        height: 36
        source: "qrc:/tsc/knob.png"
        smooth: true
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        onClicked: sw.clicked()
    }
}
