import QtQuick 2.1
import qb.components 1.0

Screen {
    id: homeAssistantConfigurationScreen

    screenTitle: "Home Assistant Configuratie"
    hasBackButton: true

    function tokenInfo() {
        return app.homeAssistantToken.length > 0 ? "ingesteld (" + app.homeAssistantToken.length + " tekens)" : "NIET ingesteld";
    }

    function saveServer(text) {
        app.homeAssistantServer = text;
        serverLabel.inputText = text;
    }

    function savePort(text) {
        app.homeAssistantPort = text;
        portLabel.inputText = text;
    }

    function saveToken(text) {
        app.saveToken(text);
        tokenLabel.inputText = tokenInfo();
    }

    function numValidate(text, isFinal) {
        if (isFinal) {
            if (text.match(/^[0-9]*$/)) {
                return null;
            }
            return {content: "Poortnummer onjuist"};
        }
        return null;
    }

    onShown: {
        addCustomTopRightButton("Opslaan");
        serverLabel.inputText = app.homeAssistantServer;
        portLabel.inputText = app.homeAssistantPort;
        tokenLabel.inputText = tokenInfo();
        sslToggle.isSwitchedOn = (app.homeAssistantSSL == "yes");
        clockToggle.isSwitchedOn = (app.clockTile == 1);
        dimDateToggle.isSwitchedOn = (app.dateInDim == 1);
    }

    onCustomButtonClicked: {
        app.saveSettings();
        hide();
        app.refresh();
    }

    EditTextLabel {
        id: serverLabel
        x: 20
        y: 20
        width: 560
        height: 36
        leftTextAvailableWidth: 250
        leftText: "Server IP:"
        onClicked: qkeyboard.open("Voer het IP adres van Home Assistant in", serverLabel.inputText, saveServer)
    }

    Item {
        x: 600
        y: 20
        width: 180
        height: 36

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "SSL"
            font.pixelSize: 14
            font.family: qfont.regular.name
            color: "#000000"
        }

        OnOffToggle {
            id: sslToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onSelectedChangedByUser: app.homeAssistantSSL = isSwitchedOn ? "yes" : "no"
        }
    }

    EditTextLabel {
        id: portLabel
        x: 20
        y: 70
        width: 560
        height: 36
        leftTextAvailableWidth: 250
        leftText: "Poort:"
        onClicked: {
            qnumKeyboard.open("Voer het poort nr. van Home Assistant in", portLabel.inputText, "", 1, savePort, numValidate);
            qnumKeyboard.maxTextLength = 5;
            qnumKeyboard.state = "num_integer_clear_backspace";
        }
    }

    Item {
        x: 600
        y: 70
        width: 180
        height: 36

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Klok in tegel"
            font.pixelSize: 14
            font.family: qfont.regular.name
            color: "#000000"
        }

        OnOffToggle {
            id: clockToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onSelectedChangedByUser: app.clockTile = isSwitchedOn ? 1 : 0
        }
    }

    Item {
        x: 600
        y: 120
        width: 180
        height: 36

        Text {
            width: 120
            anchors.verticalCenter: parent.verticalCenter
            text: "Datum bij\nscherm dimmen"
            wrapMode: Text.NoWrap
            font.pixelSize: 14
            font.family: qfont.regular.name
            color: "#000000"
        }

        OnOffToggle {
            id: dimDateToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onSelectedChangedByUser: app.dateInDim = isSwitchedOn ? 1 : 0
        }
    }

    EditTextLabel {
        id: tokenLabel
        x: 20
        y: 120
        width: 560
        height: 36
        leftTextAvailableWidth: 250
        leftText: "Toegangstoken:"
        onClicked: qkeyboard.open("Voer het 'long-lived access token' in", "", saveToken)
    }

    HaButton {
        x: 20
        y: 180
        width: 270
        height: 44
        text: "Herlaad config.json"
        onClicked: app.reloadConfig()
    }

    HaButton {
        x: 310
        y: 180
        width: 270
        height: 44
        text: "Test verbinding"
        onClicked: {
            app.updateBaseUrl();
            app.reqBusy = false;
            app.refresh();
        }
    }

    Text {
        x: 20
        y: 240
        width: 760
        wrapMode: Text.WordWrap
        text: "Status: " + app.statusText + (app.cfgError !== "" ? "\n" + app.cfgError : "")
        font.pixelSize: 14
        font.family: qfont.regular.name
        color: app.linkError ? "#c62828" : "#2e7d32"
    }

    Text {
        x: 20
        y: 300
        width: 760
        wrapMode: Text.WordWrap
        text: "Entiteiten, namen en indeling pas je aan in config.json (in de app-map). Tik op 'Herlaad config.json' om wijzigingen direct te zien."
        font.pixelSize: 12
        font.family: qfont.regular.name
        color: "#616161"
    }

    Text {
        x: 20
        y: 340
        width: 760
        wrapMode: Text.WordWrap
        text: app.message
        font.pixelSize: 10
        font.family: qfont.regular.name
        color: "#9e9e9e"
    }
}
