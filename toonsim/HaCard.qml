import QtQuick 2.1

Rectangle {
    id: card
    radius: 10
    color: "#e8e8e8"

    property string title: ""

    Text {
        x: 12
        y: 6
        text: card.title
        font.pixelSize: 14
        font.family: qfont.semiBold.name
        color: "#424242"
    }
}
