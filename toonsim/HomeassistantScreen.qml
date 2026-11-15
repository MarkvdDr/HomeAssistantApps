import QtQuick 2.1
import qb.components 1.0

Screen {
    id: haScreen
    screenTitle: "Home Assistant"
    hasBackButton: true

    property int page: 0
    property string confirmEntity: ""
    property string confirmText: ""
    property var groupItem: null
    property bool groupEditorOpen: false
    property string groupPickEntity: ""
    property string groupPickName: ""
    property var groupPickList: []

    function openGroup(item) {
        if (item && app.groupEntities(item).length > 0) {
            groupItem = item;
        }
    }

    function closeGroup() {
        groupItem = null;
    }

    function openGroupEditor() {
        groupEditorOpen = true;
    }

    function closeGroupEditor() {
        groupEditorOpen = false;
    }

    // groep kiezen voor een losse verlichting
    function openGroupPick(entity, name) {
        groupPickEntity = entity;
        groupPickName = name;
        // vaste lijst: mag niet opnieuw gemaakt worden terwijl er op een groep getikt wordt
        groupPickList = app.cfgList("groups");
    }

    function closeGroupPick() {
        groupPickEntity = "";
    }

    property string gridEntity: app.energyKey("grid")
    property string priceEntity: app.energyKey("price")
    property string gasEntity: app.energyKey("gas")

    onShown: {
        addCustomTopRightButton("Instellingen");
        app.screenActive = true;
        app.refresh();
    }

    onVisibleChanged: {
        if (!visible) {
            groupItem = null;
            groupPickEntity = "";
        }
        if (app) {
            app.screenActive = visible;
        }
    }

    onCustomButtonClicked: {
        if (app.homeAssistantConfigurationScreen) {
            app.homeAssistantConfigurationScreen.show();
        }
    }

    function pressButton(item) {
        if (item["confirm"]) {
            confirmText = item["confirm"];
            confirmEntity = item["entity"];
        } else {
            app.runEntity(item["entity"]);
        }
    }

    // ------------------------------------------------------------ tabbalk
    Row {
        id: tabBar
        x: 30
        y: 8
        spacing: 8

        HaButton { width: 128; height: 40; text: "Overzicht"; primary: haScreen.page == 0; onClicked: haScreen.page = 0 }
        HaButton { width: 128; height: 40; text: "Verlichting"; primary: haScreen.page == 1; onClicked: haScreen.page = 1 }
        HaButton { width: 128; height: 40; text: "Schakelaars"; primary: haScreen.page == 2; onClicked: haScreen.page = 2 }
        HaButton { width: 128; height: 40; text: "Apparaten"; primary: haScreen.page == 3; onClicked: haScreen.page = 3 }
        HaButton { width: 128; height: 40; text: "Energie"; primary: haScreen.page == 4; onClicked: haScreen.page = 4 }
    }

    Rectangle {
        x: 30 + 5 * 128 + 4 * 8 + 14
        y: 8 + 14
        width: 12
        height: 12
        radius: 6
        color: app.connected ? "#43a047" : "#e53935"
    }

    // ------------------------------------------------------------ pagina 0: overzicht
    Item {
        id: pageOverview
        x: 30
        y: 58
        width: 740
        height: 330
        visible: haScreen.page == 0

        HaCard {
            x: 0; y: 0; width: 240; height: 160
            title: "Energie"

            Text {
                x: 12
                y: 26
                text: app.fmtPower(haScreen.gridEntity)
                font.pixelSize: 34
                font.family: qfont.semiBold.name
                color: app.numOf(haScreen.gridEntity) < 0 ? "#2e7d32" : "#000000"
            }

            Text {
                x: 12
                y: 70
                text: app.numOf(haScreen.gridEntity) < 0 ? "Teruglevering" : "Verbruik"
                font.pixelSize: 12
                font.family: qfont.regular.name
                color: "#616161"
            }

            Column {
                x: 12
                y: 96
                spacing: 4

                HaLine {
                    label: "Stroom nu"
                    value: app.fmtEuro(haScreen.priceEntity, 3)
                    valueColor: app.entityPriceColor(haScreen.priceEntity)
                }

                HaLine {
                    label: "Gas"
                    value: app.fmtEuro(haScreen.gasEntity, 2)
                }
            }
        }

        HaCard {
            x: 250; y: 0; width: 240; height: 160
            title: "Aanwezig"

            Column {
                x: 12
                y: 34
                spacing: 6

                Repeater {
                    model: app.cfgList("presence")
                    delegate: HaLine {
                        label: modelData["name"]
                        value: app.presenceText(modelData["entity"])
                        showDot: true
                        dotColor: app.stateOf(modelData["entity"]) === "home" ? "#43a047" : "#9e9e9e"
                    }
                }
            }
        }

        HaCard {
            x: 500; y: 0; width: 240; height: 160
            title: "Afvalkalender"

            Column {
                x: 12
                y: 34
                spacing: 6

                Repeater {
                    model: app.cfgList("waste")
                    delegate: HaLine {
                        label: modelData["name"]
                        value: app.known(modelData["entity"]) ? app.cap(app.stateOf(modelData["entity"])) : "-"
                    }
                }
            }
        }

        HaCard {
            x: 0; y: 170; width: 240; height: 160
            title: "Meldingen"

            Column {
                x: 12
                y: 34
                spacing: 6

                Repeater {
                    model: app.cfgList("alerts")
                    delegate: HaLine {
                        label: modelData["name"]
                        value: app.alertText(modelData)
                        valueColor: app.alertColor(modelData)
                    }
                }
            }
        }

        HaCard {
            x: 250; y: 170; width: 490; height: 160
            title: "Verlichting"

            Grid {
                x: 12
                y: 36
                columns: 2
                spacing: 8

                Repeater {
                    model: app.cfgList("groups")
                    delegate: HaButton {
                        width: 228
                        height: 54
                        text: modelData["name"] + app.groupSuffix(modelData)
                        primary: app.groupOnCount(modelData) > 0
                        activeColor: "#f9a825"
                        activeTextColor: "#000000"
                        longPressEnabled: true
                        onClicked: app.toggleGroup(modelData)
                        onLongPressed: haScreen.openGroup(modelData)
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ pagina 1: verlichting
    Item {
        id: pageLights
        x: 30
        y: 58
        width: 740
        height: 330
        visible: haScreen.page == 1

        Grid {
            columns: 2
            spacing: 8

            Repeater {
                model: app.visibleLights()
                delegate: HaRow {
                    width: 366
                    height: 48
                    title: modelData["name"] ? modelData["name"] : app.nameOf(modelData["entity"])
                    subtitle: {
                        var g = app.groupOf(modelData["entity"]);
                        var s = g !== "" ? "Groep: " + g : "Geen groep";
                        if (modelData["dimmable"] && app.isOn(modelData["entity"]) && app.pctOf(modelData["entity"]) >= 0) {
                            s += " - " + app.pctOf(modelData["entity"]) + "%";
                        }
                        return s;
                    }
                    value1: app.rowValue1(modelData)
                    value2: app.rowValue2(modelData)
                    showSwitch: true
                    checked: app.isOn(modelData["entity"])
                    active: app.known(modelData["entity"])
                    showStep: modelData["dimmable"] ? true : false
                    onToggled: app.toggleEntity(modelData["entity"])
                    onStepUp: app.stepBrightness(modelData["entity"], 10)
                    onStepDown: app.stepBrightness(modelData["entity"], -10)
                }
            }
        }

        Text {
            y: 60
            width: 740
            horizontalAlignment: Text.AlignHCenter
            visible: app.visibleLights().length === 0
            text: "Geen verlichting zichtbaar.\nTik op 'Verlichting sorteren' om verlichting te tonen."
            font.pixelSize: 14
            font.family: qfont.regular.name
            color: "#9e9e9e"
        }

        HaButton {
            id: groupEditorButton
            x: 20
            y: 288
            width: 700
            height: 40
            text: "Verlichting sorteren"
            onClicked: haScreen.openGroupEditor()
        }

        Row {
            y: 236
            spacing: 8

            Repeater {
                model: app.cfgList("scenes")
                delegate: HaButton {
                    width: 179
                    height: 50
                    text: modelData["name"]
                    onClicked: app.runEntity(modelData["entity"])
                }
            }
        }
    }

    // ------------------------------------------------------------ pagina 2: schakelaars
    Item {
        id: pageSwitches
        x: 30
        y: 58
        width: 740
        height: 330
        visible: haScreen.page == 2

        Grid {
            columns: 2
            spacing: 8

            Repeater {
                model: app.cfgList("switches")
                delegate: HaRow {
                    width: 366
                    height: 48
                    title: modelData["name"] ? modelData["name"] : app.nameOf(modelData["entity"])
                    value1: app.rowValue1(modelData)
                    value2: app.rowValue2(modelData)
                    showSwitch: true
                    checked: app.isOn(modelData["entity"])
                    active: app.known(modelData["entity"])
                    onToggled: app.toggleEntity(modelData["entity"])
                }
            }
        }

        Row {
            y: 266
            spacing: 8

            Repeater {
                model: app.cfgList("buttons")
                delegate: HaButton {
                    width: 366
                    height: 50
                    text: modelData["name"]
                    onClicked: haScreen.pressButton(modelData)
                }
            }
        }
    }

    // ------------------------------------------------------------ pagina 3: apparaten
    Item {
        id: pageAppliances
        x: 30
        y: 58
        width: 740
        height: 330
        visible: haScreen.page == 3

        Grid {
            columns: 2
            spacing: 8

            Repeater {
                model: app.cfgList("appliances")
                delegate: HaRow {
                    width: 366
                    height: 48
                    title: modelData["name"]
                    subtitle: app.rowSubtitle(modelData)
                    value1: app.rowValue1(modelData)
                    value2: app.rowValue2(modelData)
                }
            }
        }
    }

    // ------------------------------------------------------------ pagina 4: energie
    Item {
        id: pageEnergy
        x: 30
        y: 58
        width: 740
        height: 330
        visible: haScreen.page == 4

        Row {
            y: 0
            spacing: 12

            HaCard {
                width: 176; height: 56
                title: "Nu"
                Text {
                    x: 12; y: 28
                    text: app.fmtEuro(haScreen.priceEntity, 3)
                    font.pixelSize: 16
                    font.family: qfont.semiBold.name
                    color: app.entityPriceColor(haScreen.priceEntity)
                }
            }

            HaCard {
                width: 176; height: 56
                title: "Gemiddeld"
                Text {
                    x: 12; y: 28
                    text: app.priceData["bars"].length > 0 ? app.euroV(app.priceData["avg"], 3) : "-"
                    font.pixelSize: 16
                    font.family: qfont.semiBold.name
                }
            }

            HaCard {
                width: 176; height: 56
                title: app.priceData["bars"].length > 0 ? "Laagste om " + app.priceData["minAt"] : "Laagste"
                Text {
                    x: 12; y: 28
                    text: app.priceData["bars"].length > 0 ? app.euroV(app.priceData["min"], 3) : "-"
                    font.pixelSize: 16
                    font.family: qfont.semiBold.name
                    color: "#2e7d32"
                }
            }

            HaCard {
                width: 176; height: 56
                title: app.priceData["bars"].length > 0 ? "Hoogste om " + app.priceData["maxAt"] : "Hoogste"
                Text {
                    x: 12; y: 28
                    text: app.priceData["bars"].length > 0 ? app.euroV(app.priceData["max"], 3) : "-"
                    font.pixelSize: 16
                    font.family: qfont.semiBold.name
                    color: "#c62828"
                }
            }
        }

        HaCard {
            id: chartCard
            x: 0; y: 64; width: 740; height: 160
            title: "Stroomprijs vandaag (all-in, per kWh)"

            Item {
                id: chartArea
                x: 12
                y: 30
                width: 716
                height: 110

                Repeater {
                    model: app.priceData["bars"]
                    delegate: Rectangle {
                        property real barW: chartArea.width / Math.max(1, app.priceData["bars"].length)
                        x: index * barW
                        width: Math.max(1, barW - (barW > 6 ? 1 : 0))
                        height: Math.max(2, Math.min(chartArea.height, (Math.max(0, modelData["v"]) / app.priceScale()) * chartArea.height))
                        y: chartArea.height - height
                        color: app.priceColor(modelData["v"])
                        border.width: index == app.priceData["cur"] ? 2 : 0
                        border.color: "#000000"
                    }
                }

                Rectangle {
                    visible: app.priceData["cur"] >= 0
                    x: app.priceData["cur"] * (chartArea.width / Math.max(1, app.priceData["bars"].length)) + (chartArea.width / Math.max(1, app.priceData["bars"].length)) / 2 - 1
                    y: 0
                    width: 2
                    height: chartArea.height
                    color: "#000000"
                    opacity: 0.35
                }

                Text {
                    anchors.centerIn: parent
                    visible: app.priceData["bars"].length == 0
                    text: "Geen prijsgegevens"
                    font.pixelSize: 14
                    color: "#757575"
                }
            }

            Repeater {
                model: [0, 6, 12, 18, 24]
                delegate: Text {
                    x: 12 + modelData * 716 / 24 - (modelData == 24 ? 14 : (modelData == 0 ? 0 : 7))
                    y: 143
                    text: modelData
                    font.pixelSize: 10
                    color: "#616161"
                }
            }
        }

        Row {
            y: 232
            spacing: 16

            Repeater {
                model: app.energyList("flags")
                delegate: Rectangle {
                    width: 236
                    height: 30
                    radius: 8
                    color: "#e8e8e8"

                    Rectangle {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        radius: 6
                        color: app.isOn(modelData["entity"]) ? "#43a047" : "#9e9e9e"
                    }

                    Text {
                        x: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData["name"] + (app.isOn(modelData["entity"]) ? ": nu goedkoop" : "")
                        font.pixelSize: 13
                        font.family: qfont.regular.name
                    }
                }
            }
        }

        Row {
            y: 270
            spacing: 10

            Repeater {
                model: app.energyList("stats")
                delegate: HaCard {
                    width: 140
                    height: 52
                    title: modelData["name"]

                    Text {
                        x: 12
                        y: 26
                        width: parent.width - 20
                        elide: Text.ElideRight
                        text: app.showValue(modelData)
                        font.pixelSize: 15
                        font.family: qfont.semiBold.name
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ verbindingsfout
    Rectangle {
        x: 30
        y: 58
        width: 740
        height: 330
        color: "#f2ffffff"
        visible: app.linkError

        Text {
            anchors.centerIn: parent
            width: 600
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: app.statusText + "\n\nTik om opnieuw te proberen of open Instellingen."
            font.pixelSize: 18
            font.family: qfont.semiBold.name
            color: "#c62828"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: app.refresh()
        }
    }

    // ------------------------------------------------------------ bevestigingsvenster
    Rectangle {
        anchors.fill: parent
        z: 50
        color: "#80000000"
        visible: haScreen.confirmEntity !== ""

        MouseArea { anchors.fill: parent }

        Rectangle {
            width: 420
            height: 170
            radius: 12
            anchors.centerIn: parent
            color: "#ffffff"

            Text {
                x: 20
                y: 20
                width: 380
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: haScreen.confirmText
                font.pixelSize: 20
                font.family: qfont.semiBold.name
            }

            HaButton {
                x: 20
                y: 100
                width: 180
                height: 50
                text: "Annuleren"
                onClicked: haScreen.confirmEntity = ""
            }

            HaButton {
                x: 220
                y: 100
                width: 180
                height: 50
                text: "Ja"
                primary: true
                onClicked: {
                    app.runEntity(haScreen.confirmEntity);
                    haScreen.confirmEntity = "";
                }
            }
        }
    }

    // ------------------------------------------------------------ keuzevenster lichtgroep
    Rectangle {
        id: groupPopup
        anchors.fill: parent
        z: 60
        color: "#80000000"
        visible: haScreen.groupItem !== null

        property var entities: haScreen.groupItem ? app.groupEntities(haScreen.groupItem) : []

        MouseArea {
            anchors.fill: parent
            onClicked: haScreen.closeGroup()
        }

        Rectangle {
            width: 440
            height: 158 + entityScroll.height
            radius: 12
            anchors.centerIn: parent
            color: "#ffffff"

            // klikken in het venster mogen de achtergrond niet sluiten
            MouseArea { anchors.fill: parent }

            Text {
                x: 20
                y: 18
                width: 400
                text: "Kies verlichting"
                font.pixelSize: 20
                font.family: qfont.semiBold.name
                color: "#000000"
            }

            Text {
                x: 20
                y: 46
                width: 400
                elide: Text.ElideRight
                text: haScreen.groupItem ? haScreen.groupItem["name"] : ""
                font.pixelSize: 14
                font.family: qfont.regular.name
                color: "#616161"
            }

            Flickable {
                id: entityScroll
                x: 20
                y: 76
                width: 400
                height: Math.max(44, Math.min(groupPopup.entities.length, 4) * 52 - 8)
                contentHeight: entityColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: entityColumn
                    width: 400
                    spacing: 8

                    Repeater {
                        model: groupPopup.entities
                        delegate: Rectangle {
                            width: 400
                            height: 44
                            radius: 8
                            color: rowMouse.pressed ? "#e0e0e0" : "#f0f0f0"

                            Text {
                                x: 12
                                width: 300
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: app.labelFor(modelData)
                                font.pixelSize: 15
                                font.family: qfont.semiBold.name
                                color: "#000000"
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: app.isOn(modelData) ? "Aan" : "Uit"
                                font.pixelSize: 14
                                font.family: qfont.semiBold.name
                                color: app.isOn(modelData) ? "#2e7d32" : "#9e9e9e"
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                onClicked: app.toggleEntity(modelData)
                            }
                        }
                    }
                }
            }

            HaButton {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: 180
                height: 44
                text: "Sluiten"
                primary: true
                onClicked: haScreen.closeGroup()
            }
        }
    }

    // ------------------------------------------------------------ groepsinstellingen
    Rectangle {
        id: groupEditor
        anchors.fill: parent
        z: 70
        color: "#80000000"
        visible: haScreen.groupEditorOpen

        MouseArea {
            anchors.fill: parent
            onClicked: haScreen.closeGroupEditor()
        }

        Rectangle {
            id: groupEditorPanel
            width: 720
            height: 380
            radius: 12
            anchors.centerIn: parent
            color: "#ffffff"

            MouseArea { anchors.fill: parent }

            Text {
                x: 24
                y: 14
                width: 672
                text: "Verlichting sorteren"
                font.pixelSize: 20
                font.family: qfont.semiBold.name
                color: "#000000"
            }

            Text {
                x: 24
                y: 42
                width: 672
                text: "Tik op een verlichting om de groep te kiezen. Rechts bepaal je of hij in de tab Verlichting staat."
                font.pixelSize: 12
                font.family: qfont.regular.name
                color: "#616161"
            }

            Text {
                x: 36
                y: 68
                text: "Verlichting"
                font.pixelSize: 11
                font.family: qfont.semiBold.name
                color: "#9e9e9e"
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 98
                y: 68
                text: "Groep"
                font.pixelSize: 11
                font.family: qfont.semiBold.name
                color: "#9e9e9e"
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 36
                y: 68
                text: "Zichtbaar"
                font.pixelSize: 11
                font.family: qfont.semiBold.name
                color: "#9e9e9e"
            }

            Flickable {
                id: groupEditorList
                x: 24
                y: 86
                width: 672
                height: 216
                contentHeight: groupEditorColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: groupEditorColumn
                    width: 672
                    spacing: 8

                    Repeater {
                        model: app.groupLights()
                        delegate: Rectangle {
                            width: 672
                            height: 48
                            radius: 8
                            color: editMouse.pressed ? "#dcdcdc" : "#e8e8e8"

                            Text {
                                x: 12
                                width: Math.max(80, parent.width - groupChip.width - 98)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.name
                                font.pixelSize: 15
                                font.family: qfont.semiBold.name
                                color: "#000000"
                            }

                            Rectangle {
                                id: groupChip
                                anchors.right: parent.right
                                anchors.rightMargin: 74
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(groupChipText.implicitWidth + 20, 220)
                                height: 26
                                radius: 13
                                color: modelData.group !== "" ? "#e3f2fd" : "#f5f5f5"

                                Text {
                                    id: groupChipText
                                    width: parent.width - 20
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: modelData.group !== "" ? modelData.group : "Geen groep"
                                    font.pixelSize: 13
                                    font.family: qfont.semiBold.name
                                    color: modelData.group !== "" ? "#1565c0" : "#9e9e9e"
                                }
                            }

                            MouseArea {
                                id: editMouse
                                anchors.fill: parent
                                onClicked: haScreen.openGroupPick(modelData.entity, modelData.name)
                            }

                            HaSwitch {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                checked: modelData.visible
                                onClicked: app.setLightVisible(modelData.entity, !modelData.visible)
                            }
                        }
                    }
                }
            }

            Text {
                x: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                text: "Wijzigingen worden direct opgeslagen"
                font.pixelSize: 11
                font.family: qfont.regular.name
                color: "#9e9e9e"
            }

            HaButton {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: 180
                height: 44
                text: "Sluiten"
                primary: true
                onClicked: haScreen.closeGroupEditor()
            }
        }
    }

    // ------------------------------------------------------------ groepskeuze per verlichting
    Rectangle {
        id: groupPickPopup
        anchors.fill: parent
        z: 80
        color: "#80000000"
        visible: haScreen.groupPickEntity !== ""

        MouseArea {
            anchors.fill: parent
            onClicked: haScreen.closeGroupPick()
        }

        Rectangle {
            width: 480
            height: 150 + pickScroll.height
            radius: 12
            anchors.centerIn: parent
            color: "#ffffff"

            // klikken in het venster mogen de achtergrond niet sluiten
            MouseArea { anchors.fill: parent }

            Text {
                x: 20
                y: 18
                width: 440
                text: "Kies groep"
                font.pixelSize: 20
                font.family: qfont.semiBold.name
                color: "#000000"
            }

            Text {
                x: 20
                y: 46
                width: 440
                elide: Text.ElideRight
                text: haScreen.groupPickName
                font.pixelSize: 14
                font.family: qfont.regular.name
                color: "#616161"
            }

            Flickable {
                id: pickScroll
                x: 20
                y: 76
                width: 440
                height: Math.max(44, Math.min(app.cfgList("groups").length, 4) * 52 - 8)
                contentHeight: pickColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: pickColumn
                    width: 440
                    spacing: 8

                    Text {
                        width: 440
                        visible: haScreen.groupPickList.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: "Geen groepen in config.json"
                        font.pixelSize: 13
                        font.family: qfont.regular.name
                        color: "#9e9e9e"
                    }

                    Repeater {
                        model: haScreen.groupPickList
                        delegate: Rectangle {
                            width: 440
                            height: 44
                            radius: 8
                            property bool current: haScreen.groupPickEntity !== "" &&
                                                   app.groupOf(haScreen.groupPickEntity) === modelData.name
                            color: pickMouse.pressed ? "#e0e0e0" : (current ? "#ffe082" : "#f0f0f0")

                            Text {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 15
                                font.family: qfont.semiBold.name
                                color: "#000000"
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.current ? "Geselecteerd" : ""
                                font.pixelSize: 11
                                font.family: qfont.regular.name
                                color: "#616161"
                            }

                            MouseArea {
                                id: pickMouse
                                anchors.fill: parent
                                onClicked: {
                                    var e = haScreen.groupPickEntity;
                                    var g = modelData.name;
                                    app.setGroupOf(e, g);
                                    haScreen.closeGroupPick();
                                }
                            }
                        }
                    }
                }
            }

            HaButton {
                x: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: 210
                height: 44
                text: "Geen groep"
                primary: haScreen.groupPickEntity !== "" && app.groupOf(haScreen.groupPickEntity) === ""
                activeColor: "#ffe082"
                activeTextColor: "#000000"
                onClicked: {
                    app.setGroupOf(haScreen.groupPickEntity, "");
                    haScreen.closeGroupPick();
                }
            }

            HaButton {
                x: 250
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: 210
                height: 44
                text: "Sluiten"
                primary: true
                onClicked: haScreen.closeGroupPick()
            }
        }
    }
}
