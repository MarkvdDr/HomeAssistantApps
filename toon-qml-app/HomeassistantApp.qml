import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

import FileIO 1.0

App {
    id: homeassistantApp

    property int debug: 0

    property url tileUrl: "HomeassistantTile.qml"
    property url thumbnailIcon: "qrc:/tsc/homeAssistant.png"

    property HomeassistantConfigurationScreen homeAssistantConfigurationScreen
    property url homeAssistantConfigurationScreenUrl: "HomeassistantConfigurationScreen.qml"

    property HomeassistantScreen homeAssistantScreen
    property url homeAssistantScreenUrl: "HomeassistantScreen.qml"

    // ---- verbinding ----
    property string homeAssistantServer: ""
    property string homeAssistantPort: "8123"
    property string homeAssistantSSL: ""
    property string homeAssistantToken: ""
    property int clockTile: 0
    property int dateInDim: 0
    property string baseUrl: ""

    property int connected: 0
    property bool linkError: false
    property string statusText: ""
    property string cfgError: ""
    property string message: ""
    property bool screenActive: false
    property bool ready: false
    property bool reqBusy: false
    property real reqStart: 0

    // ---- data ----
    property var cfg: ({})
    property int cfgRev: 0
    property var haStates: ({})
    property int rev: 0
    property var priceData: ({"bars": [], "cur": -1, "min": 0, "max": 0, "avg": 0, "minAt": "", "maxAt": ""})

    property string timeStr
    property string dateStr

    // token.txt hoort naast de app; storedTokenFile is de oude, absolute locatie
    FileIO { id: tokenFile; source: "./token.txt" }
    FileIO { id: storedTokenFile; source: "file:///HCBv2/qml/apps/homeassistant/token.txt" }
    FileIO { id: userSettingsFile; source: "file:///HCBv2/qml/apps/homeassistant/userSettings.json" }
    FileIO { id: configFile; source: "./config.json" }

    // ------------------------------------------------------------ timers
    Timer {
        id: clockTimer
        interval: 1000
        triggeredOnStart: true
        running: homeassistantApp.clockTile == 1
        repeat: true
        onTriggered: updateClockInfo()
    }

    Timer {
        id: pollTimer
        interval: homeassistantApp.screenActive ? 5000 : 15000
        triggeredOnStart: true
        running: true
        repeat: true
        onTriggered: refresh()
    }

    Timer {
        id: quickTimer
        interval: 700
        repeat: false
        onTriggered: refresh()
    }

    function updateClockInfo() {
        var now = new Date().getTime();
        timeStr = i18n.dateTime(now, i18n.time_yes);
        dateStr = i18n.dateTime(now, i18n.mon_full);
    }

    function logText(log) {
        if (debug) {
            var d = new Date();
            message = "[" + d.toTimeString().split(' ')[0] + "] " + log + "\n" + message;
            if (message.length > 600) {
                message = message.substring(0, 600);
            }
        }
    }

    // ------------------------------------------------------------ init
    function init() {
        registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("homeAssistant"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, baseTileSolarWeight: 10, thumbIconVAlignment: "center"});
        registry.registerWidget("screen", homeAssistantConfigurationScreenUrl, this, "homeAssistantConfigurationScreen");
        registry.registerWidget("screen", homeAssistantScreenUrl, this, "homeAssistantScreen");
    }

    Component.onCompleted: {
        readDefaults();
    }

    function writeFile(name, content) {
        var doc = new XMLHttpRequest();
        doc.open("PUT", "file:///HCBv2/qml/apps/homeassistant/" + name);
        doc.send(content);
    }

    function readDefaults() {
        var s = {};
        try {
            s = JSON.parse(userSettingsFile.read());
        } catch (err) {
            logText("Error reading userSettings. " + err);
        }
        homeAssistantServer = s["Server"] ? s["Server"] : "";
        homeAssistantPort = s["Port"] ? String(s["Port"]) : "8123";
        homeAssistantSSL = s["SSL"] ? s["SSL"] : "";
        clockTile = s["Clock"] ? 1 : 0;
        dateInDim = s["DateInDim"] ? 1 : 0;

        readToken();
        loadConfig();
        updateBaseUrl();
        ready = true;
        refresh();
    }

    function readToken() {
        var localToken = "";
        var storedToken = "";
        try {
            localToken = tokenFile.read().trim();
        } catch (err) {
            logText("Error reading token.txt next to the app. " + err);
        }
        try {
            storedToken = storedTokenFile.read().trim();
        } catch (err) {
            logText("Error reading stored token.txt. " + err);
        }
        homeAssistantToken = localToken !== "" ? localToken : storedToken;
    }

    function saveToken(text) {
        homeAssistantToken = text.trim();
        var doc = new XMLHttpRequest();
        doc.open("PUT", Qt.resolvedUrl("token.txt").toString());
        doc.send(homeAssistantToken);
        writeFile("token.txt", homeAssistantToken);
    }

    function loadConfig() {
        try {
            cfg = JSON.parse(configFile.read());
            debug = cfg["debug"] ? 1 : 0;
            cfgError = "";
        } catch (err) {
            cfg = {};
            cfgError = "config.json: " + err;
            logText(cfgError);
        }
        cfgRev++;
    }

    // opnieuw inlezen van config.json zonder de Toon te herstarten
    function reloadConfig() {
        loadConfig();
        reqBusy = false;
        refresh();
    }

    function saveConfig() {
        return configFile.write(JSON.stringify(cfg, null, 2));
    }

    function updateBaseUrl() {
        baseUrl = (homeAssistantSSL == "yes" ? "https://" : "http://") + homeAssistantServer + ":" + homeAssistantPort;
    }

    function saveSettings() {
        var o = {
            "Server": homeAssistantServer,
            "SSL": homeAssistantSSL,
            "Port": homeAssistantPort,
            "Clock": clockTile,
            "DateInDim": dateInDim
        };
        writeFile("userSettings.json", JSON.stringify(o));
        updateBaseUrl();
        reqBusy = false;
    }

    // ------------------------------------------------------------ config helpers
    function cfgList(name) {
        var r = cfgRev;
        var l = cfg[name];
        return l ? l : [];
    }

    function cfgObj(name) {
        var r = cfgRev;
        var o = cfg[name];
        return o ? o : {};
    }

    // leesbare naam voor een entity: eerst uit config.json, anders de naam van Home Assistant
    function labelFor(e) {
        var r = cfgRev;
        var lists = ["lights", "switches", "buttons", "appliances"];
        for (var k = 0; k < lists.length; k++) {
            var l = cfg[lists[k]] || [];
            for (var i = 0; i < l.length; i++) {
                if (l[i]["entity"] === e && l[i]["name"]) return l[i]["name"];
            }
        }
        var n = nameOf(e);
        return n !== "" ? n : e;
    }

    function energyKey(k) {
        var o = cfgObj("energy");
        return o[k] ? o[k] : "";
    }

    function energyList(k) {
        var o = cfgObj("energy");
        return o[k] ? o[k] : [];
    }

    function tileItems() {
        var l = cfgList("tile");
        return l.slice(0, 3);
    }

    // verzamelt alle entity_id's uit config.json
    function collect(o, out, seen) {
        if (typeof o === "string") {
            if (/^[a-z_]+\.[a-z0-9_]+$/.test(o) && !seen[o]) {
                seen[o] = 1;
                out.push(o);
            }
        } else if (o && typeof o === "object") {
            for (var k in o) {
                collect(o[k], out, seen);
            }
        }
    }

    // ------------------------------------------------------------ HTTP
    function haRequest(method, path, body, cb) {
        if (homeAssistantToken == "") {
            cb(401, "");
            return;
        }
        var http = new XMLHttpRequest();
        http.onreadystatechange = function() {
            if (http.readyState == 4) {
                cb(http.status, http.responseText);
            }
        }
        http.open(method, baseUrl + path, true);
        http.setRequestHeader("Authorization", "Bearer " + homeAssistantToken);
        if (body !== null) {
            http.setRequestHeader("Content-Type", "application/json");
            http.send(JSON.stringify(body));
        } else {
            http.send();
        }
    }

    function setLink(ok, text) {
        connected = ok ? 1 : 0;
        linkError = !ok;
        statusText = text;
    }

    // Haalt in 1 verzoek de status van alle gebruikte entiteiten op via /api/template
    function refresh() {
        if (!ready) {
            return;
        }
        if (homeAssistantServer == "") {
            setLink(false, "Stel het server-IP in via Instellingen");
            return;
        }
        if (homeAssistantToken == "") {
            setLink(false, "Geen token gevonden in token.txt");
            return;
        }
        var now = new Date().getTime();
        if (reqBusy && (now - reqStart) < 20000) {
            return;
        }

        var ids = [];
        collect(cfg, ids, {});
        if (ids.length == 0) {
            setLink(false, cfgError != "" ? cfgError : "Geen entiteiten in config.json");
            return;
        }

        var pe = energyKey("price");
        var tpl = "{% set ids = " + JSON.stringify(ids) + " %}"
            + "{\"e\":[{% for i in ids %}{\"i\":{{ i|tojson }},\"s\":{{ states(i)|tojson }},"
            + "\"n\":{{ state_attr(i,'friendly_name')|tojson }},\"u\":{{ state_attr(i,'unit_of_measurement')|tojson }},"
            + "\"b\":{{ state_attr(i,'brightness')|tojson }}}{% if not loop.last %},{% endif %}{% endfor %}]";
        if (pe != "") {
            tpl += ",\"p\":{{ state_attr('" + pe + "','prices')|tojson }},\"t\":{{ state_attr('" + pe + "','times')|tojson }}";
        }
        tpl += "}";

        reqBusy = true;
        reqStart = now;
        haRequest("POST", "/api/template", {"template": tpl}, function(status, text) {
            reqBusy = false;
            if (status == 200) {
                try {
                    applyStates(JSON.parse(text));
                    setLink(true, "Verbonden");
                } catch (err) {
                    setLink(false, "Onverwacht antwoord van Home Assistant");
                    logText("Parse error: " + err + " " + text.substring(0, 200));
                }
            } else if (status == 401) {
                setLink(false, "Token ongeldig of ontbreekt (token.txt)");
            } else if (status == 0) {
                setLink(false, "Geen verbinding met " + baseUrl);
            } else {
                setLink(false, "Fout " + status + ": " + text.substring(0, 120));
            }
        });
    }

    function applyStates(data) {
        var m = {};
        var e = data["e"];
        for (var i = 0; i < e.length; i++) {
            m[e[i]["i"]] = {"s": e[i]["s"], "n": e[i]["n"], "u": e[i]["u"], "b": e[i]["b"]};
        }
        haStates = m;
        rev++;
        if (data["p"] && data["t"]) {
            buildPrices(data["p"], data["t"]);
        }
    }

    // ------------------------------------------------------------ prijzen
    function pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function buildPrices(p, t) {
        var d = new Date();
        var today = d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
        var nowHm = pad2(d.getHours()) + ":" + pad2(d.getMinutes());
        var bars = [];
        var mn = 1e9, mx = -1e9, sum = 0, cur = -1, mnAt = "", mxAt = "";

        for (var i = 0; i < t.length && i < p.length; i++) {
            if (typeof t[i] !== "string" || t[i].substring(0, 10) !== today) {
                continue;
            }
            var v = Number(p[i]);
            if (isNaN(v)) {
                continue;
            }
            var hm = t[i].substring(11, 16);
            bars.push({"v": v, "hm": hm});
            sum += v;
            if (v < mn) { mn = v; mnAt = hm; }
            if (v > mx) { mx = v; mxAt = hm; }
            if (hm <= nowHm) { cur = bars.length - 1; }
        }

        if (bars.length == 0) {
            priceData = {"bars": [], "cur": -1, "min": 0, "max": 0, "avg": 0, "minAt": "", "maxAt": ""};
        } else {
            priceData = {"bars": bars, "cur": cur, "min": mn, "max": mx, "avg": sum / bars.length, "minAt": mnAt, "maxAt": mxAt};
        }
    }

    function priceColor(v) {
        var o = cfgObj("energy");
        var lo = o["priceLow"] !== undefined ? o["priceLow"] : 0.2;
        var hi = o["priceHigh"] !== undefined ? o["priceHigh"] : 0.3;
        if (v < 0) return "#1e88e5";
        if (v < lo) return "#43a047";
        if (v < hi) return "#fb8c00";
        return "#e53935";
    }

    function priceScale() {
        var m = priceData["max"];
        return m > 0.3 ? m : 0.3;
    }

    function entityPriceColor(e) {
        var v = numOf(e);
        return isNaN(v) ? "#000000" : priceColor(v);
    }

    // ------------------------------------------------------------ state accessors
    function stateOf(e) {
        var r = rev;
        if (!e) return "";
        var o = haStates[e];
        return (o && o["s"] !== null && o["s"] !== undefined) ? String(o["s"]) : "";
    }

    function nameOf(e) {
        var r = rev;
        var o = e ? haStates[e] : null;
        return (o && o["n"]) ? o["n"] : "";
    }

    function unitOf(e) {
        var r = rev;
        var o = e ? haStates[e] : null;
        return (o && o["u"]) ? o["u"] : "";
    }

    function known(e) {
        var s = stateOf(e);
        return s !== "" && s !== "unknown" && s !== "unavailable" && s !== "None";
    }

    function numOf(e) {
        var s = stateOf(e);
        if (s === "") return NaN;
        return Number(s);
    }

    function isOn(e) {
        var s = stateOf(e);
        return s === "on" || s === "home" || s === "open" || s === "playing";
    }

    function pctOf(e) {
        var r = rev;
        var o = e ? haStates[e] : null;
        if (!o || o["b"] === null || o["b"] === undefined) return -1;
        return Math.round(o["b"] / 2.55);
    }

    // ------------------------------------------------------------ opmaak
    function dutch(v, dec) {
        return v.toFixed(dec).replace(".", ",");
    }

    function cap(s) {
        if (!s) return "";
        return s.charAt(0).toUpperCase() + s.substring(1).replace(/_/g, " ");
    }

    function fmtPower(e) {
        var v = numOf(e);
        if (isNaN(v)) return "-";
        if (Math.abs(v) >= 1000) return dutch(v / 1000, 2) + " kW";
        return Math.round(v) + " W";
    }

    function euroV(v, dec) {
        return "\u20AC " + dutch(v, dec);
    }

    function fmtEuro(e, dec) {
        var v = numOf(e);
        if (isNaN(v)) return "-";
        return euroV(v, dec === undefined ? 2 : dec);
    }

    function fmtValue(e, dec) {
        if (!known(e)) return "-";
        var v = numOf(e);
        var u = unitOf(e);
        if (isNaN(v)) return cap(stateOf(e));
        var d = dec === undefined ? (Math.abs(v) >= 100 ? 0 : 1) : dec;
        return dutch(v, d) + (u ? " " + u : "");
    }

    function clockOf(t) {
        var d = new Date(t);
        return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
    }

    function fmtTime(e) {
        if (!known(e)) return "";
        var t = new Date(stateOf(e)).getTime();
        if (isNaN(t)) return cap(stateOf(e));
        return clockOf(t);
    }

    // tijd alleen tonen als die nog in de toekomst ligt
    function futureTime(e) {
        if (!known(e)) return "";
        var t = new Date(stateOf(e)).getTime();
        if (isNaN(t) || t < new Date().getTime()) return "";
        return clockOf(t);
    }

    function showValue(item) {
        var r = rev;
        if (!item) return "";
        switch (item["kind"]) {
            case "power": return fmtPower(item["entity"]);
            case "euro": return fmtEuro(item["entity"], item["dec"]);
            case "text": return known(item["entity"]) ? cap(stateOf(item["entity"])) : "-";
            case "time": return fmtTime(item["entity"]);
            default: return fmtValue(item["entity"], item["dec"]);
        }
    }

    function rowValue1(item) {
        if (!item) return "";
        if (item["power"]) return fmtPower(item["power"]);
        if (item["value"]) return fmtValue(item["value"]);
        return "";
    }

    function rowValue2(item) {
        if (item && item["energy"] && known(item["energy"])) {
            return "vandaag " + fmtValue(item["energy"], 2);
        }
        return "";
    }

    function rowSubtitle(item) {
        var r = rev;
        if (!item) return "";
        var s = "";
        if (item["status"]) {
            s = known(item["status"]) ? cap(stateOf(item["status"])) : "-";
        } else if (item["power"] && known(item["power"])) {
            s = numOf(item["power"]) > 5 ? "Actief" : "Stand-by";
        }
        if (item["end"]) {
            var t = futureTime(item["end"]);
            if (t !== "") {
                s += (s !== "" ? " \u00B7 " : "") + "klaar " + t;
            }
        }
        return s;
    }

    function presenceText(e) {
        var s = stateOf(e);
        if (s === "home") return "Thuis";
        if (s === "not_home") return "Weg";
        if (!known(e)) return "-";
        return cap(s);
    }

    function alertOn(item) {
        return item ? stateOf(item["entity"]) === "on" : false;
    }

    function alertText(item) {
        if (!known(item["entity"])) return "-";
        if (alertOn(item)) return item["onText"] ? item["onText"] : "Aan";
        return item["offText"] ? item["offText"] : "Uit";
    }

    function alertColor(item) {
        if (!known(item["entity"])) return "#757575";
        if (alertOn(item)) return item["alarm"] ? "#c62828" : "#e65100";
        return "#2e7d32";
    }

    function alertCount() {
        var a = cfgList("alerts");
        var n = 0;
        for (var i = 0; i < a.length; i++) {
            if (a[i]["alarm"] && stateOf(a[i]["entity"]) === "on") n++;
        }
        return n;
    }

    // ------------------------------------------------------------ bediening
    function domainOf(e) {
        return e.substr(0, e.indexOf("."));
    }

    function setLocal(e, s) {
        var o = haStates[e];
        if (o) {
            o["s"] = s;
            rev++;
        }
    }

    function callService(domain, service, data) {
        if (!ready || !connected) {
            logText("Niet verbonden met Home Assistant");
            return;
        }
        haRequest("POST", "/api/services/" + domain + "/" + service, data, function(status, text) {
            if (status < 200 || status >= 300) {
                statusText = "Opdracht mislukt (" + status + ")";
                logText("Service " + domain + "." + service + " failed: " + status);
            }
            quickTimer.restart();
        });
    }

    function setEntity(e, on) {
        var d = domainOf(e);
        callService(d, on ? "turn_on" : "turn_off", {"entity_id": e});
        setLocal(e, on ? "on" : "off");
    }

    function toggleEntity(e) {
        setEntity(e, !isOn(e));
    }

    // scene / script / knop / automation uitvoeren
    function runEntity(e) {
        var d = domainOf(e);
        switch (d) {
            case "scene":
            case "script":
                callService(d, "turn_on", {"entity_id": e});
                break;
            case "button":
            case "input_button":
                callService(d, "press", {"entity_id": e});
                break;
            case "automation":
                callService("automation", "trigger", {"entity_id": e});
                break;
            default:
                toggleEntity(e);
        }
    }

    // ---- lichtgroepen (knop op het overzicht) ----
    function groupEntities(item) {
        return (item && item["entities"]) ? item["entities"] : [];
    }

    function groupByName(name) {
        var r = cfgRev;
        var l = cfgList("groups");
        for (var i = 0; i < l.length; i++) {
            if (l[i]["name"] === name) return l[i];
        }
        return null;
    }

    function groupOnCount(item) {
        var l = groupEntities(item);
        var n = 0;
        for (var i = 0; i < l.length; i++) {
            if (isOn(l[i])) n++;
        }
        return n;
    }

    // " (1/3)" als een groep maar gedeeltelijk aan staat
    function groupSuffix(item) {
        var n = groupOnCount(item);
        var t = groupEntities(item).length;
        return (n > 0 && n < t) ? "  " + n + "/" + t : "";
    }

    // staat er iets aan: alles uit, anders alles aan (1 opdracht voor de hele groep)
    function toggleGroup(item) {
        var l = groupEntities(item);
        if (l.length == 0) return;
        var on = groupOnCount(item) == 0;
        callService("homeassistant", on ? "turn_on" : "turn_off", {"entity_id": l});
        for (var i = 0; i < l.length; i++) {
            setLocal(l[i], on ? "on" : "off");
        }
    }

    // alle verlichtingseenheden met de groep die ze horen, gesorteerd op groep + naam
    // de groep waar deze entiteit nu in zit ("" = geen groep)
    function groupOf(e) {
        var r = cfgRev;
        var groups = cfgList("groups");
        for (var k = 0; k < groups.length; k++) {
            var l = groupEntities(groups[k]);
            for (var j = 0; j < l.length; j++) {
                if (l[j] === e) return groups[k]["name"];
            }
        }
        return "";
    }

    // zichtbaarheid in de tab Verlichting (standaard zichtbaar)
    function lightVisible(item) {
        return item ? item["visible"] !== false : false;
    }

    // zet de zichtbaarheid van een verlichting (opgeslagen in config.json)
    function setLightVisible(e, on) {
        var lights = cfgList("lights");
        for (var i = 0; i < lights.length; i++) {
            if (lights[i]["entity"] === e) {
                lights[i]["visible"] = on ? true : false;
                var ok = saveConfig();
                if (ok) {
                    cfgRev++;
                    refresh();
                }
                return ok;
            }
        }
        return false;
    }

    // alle zichtbare verlichting, gesorteerd op groep en naam (tab Verlichting)
    function visibleLights() {
        var r = cfgRev;
        var lights = cfgList("lights");
        var out = [];
        for (var i = 0; i < lights.length; i++) {
            if (lightVisible(lights[i])) out.push(lights[i]);
        }
        out.sort(function(a, b) {
            var c = String(groupOf(a["entity"])).localeCompare(String(groupOf(b["entity"])));
            if (c !== 0) return c;
            var na = a["name"] ? a["name"] : labelFor(a["entity"]);
            var nb = b["name"] ? b["name"] : labelFor(b["entity"]);
            return String(na).localeCompare(String(nb));
        });
        return out;
    }

    function groupLights() {
        var entries = [];
        var lights = cfgList("lights");
        for (var i = 0; i < lights.length; i++) {
            var e = lights[i]["entity"];
            entries.push({
                "name": lights[i]["name"] ? lights[i]["name"] : labelFor(e),
                "entity": e,
                "group": groupOf(e),
                "visible": lightVisible(lights[i])
            });
        }
        entries.sort(function(a, b) {
            var c = String(a["group"]).localeCompare(String(b["group"]));
            if (c !== 0) return c;
            return String(a["name"]).localeCompare(String(b["name"]));
        });
        return entries;
    }

    // zet een entiteit in een andere groep (naam "" = uit alle groepen halen),
    // opgeslagen in config.json zodat het ook na een herstart zo is
    function setGroupOf(e, name) {
        var groups = cfgList("groups");
        for (var k = 0; k < groups.length; k++) {
            var l = groupEntities(groups[k]);
            for (var j = l.length - 1; j >= 0; j--) {
                if (l[j] === e) l.splice(j, 1);
            }
            groups[k]["entities"] = l;
        }
        if (name !== "") {
            var g = groupByName(name);
            if (g) {
                var gl = groupEntities(g);
                gl.push(e);
                g["entities"] = gl;
            }
        }
        var ok = saveConfig();
        if (ok) {
            cfgRev++;
            refresh();
        }
        return ok;
    }

    function stepBrightness(e, delta) {
        var cur = pctOf(e);
        if (cur < 0) cur = 0;
        var n = Math.max(10, Math.min(100, cur + delta));
        callService("light", "turn_on", {"entity_id": e, "brightness_pct": n});
    }
}
