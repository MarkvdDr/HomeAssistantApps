import QtQuick 2.1
import qb.components 1.0

Tile {
    id: homeAssistantTile

    function init() {}

    onClicked: {
        if (app.homeAssistantScreen)
            app.homeAssistantScreen.show();
    }

    Text {
        id: txtTimeBig
        text: app.timeStr
        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
        anchors {
            left: parent.left
            leftMargin: 10
            baseline: parent.top
            baselineOffset: 54
        }
        font.pixelSize: dimState ? qfont.clockFaceText : qfont.timeAndTemperatureText - 4
        font.family: qfont.regular.name
        visible: app.clockTile ? true : false
    }

    Text {
        id: txtDate
        text: app.dateStr
        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
        anchors {
            left: txtTimeBig.left
            top: txtTimeBig.bottom
            topMargin: -10
        }
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: qfont.tileTitle - 2
        font.family: qfont.regular.name
        visible: app.clockTile ? (!dimState || app.dateInDim == 1) : false
    }

    Image {
        id: homeAssistantIconSmall
        source: "qrc:/tsc/homeAssistantIconSmall.png"
        anchors {
            bottom: txtDate.bottom
            right: parent.right
            rightMargin: 10
        }
        cache: false
        visible: app.clockTile ? !dimState : false
    }

    Image {
        id: homeAssistantIconSmallCenter
        source: dimState ? "qrc:/tsc/homeAssistantIconSmallDim.png" : "qrc:/tsc/homeAssistantIconSmall.png"
        anchors {
            baseline: parent.top
            horizontalCenter: parent.horizontalCenter
            baselineOffset: 15
        }
        cache: false
        visible: app.clockTile ? false : true
    }

    // rode melding als een rookmelder/lekkage-sensor aanslaat, of oranje bolletje bij verbindingsfout
    Text {
        id: alertBadge
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 4
            rightMargin: 8
        }
        text: app.alertCount() > 0 ? "! " + app.alertCount() : (app.linkError ? "\u25CF" : "")
        color: app.alertCount() > 0 ? "#ff5252" : "#ffa726"
        font.pixelSize: 20
        font.family: qfont.semiBold.name
    }

    Item {
        id: tileGrid
        width: parent.width - 20
        height: 60
        anchors {
            bottom: parent.bottom
            left: parent.left
            bottomMargin: 10
            leftMargin: 10
        }

        Column {
            Repeater {
                model: app.tileItems()
                delegate: Item {
                    width: tileGrid.width
                    height: 20

                    Text {
                        text: modelData["name"]
                        width: parent.width - valueText.paintedWidth - 6
                        elide: Text.ElideRight
                        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
                        font.pixelSize: 12
                        font.family: qfont.regular.name
                        font.bold: true
                    }

                    Text {
                        id: valueText
                        anchors.right: parent.right
                        text: app.showValue(modelData)
                        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
                        font.pixelSize: 12
                        font.family: qfont.regular.name
                        font.bold: true
                    }
                }
            }
        }
    }
}
