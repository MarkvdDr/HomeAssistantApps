# A2 Racer II voor Home Assistant OS

Deze add-on speelt A2 Racer II in de browser via Home Assistant-ingress. De
add-on gebruikt de engine
[jjmhalew/A2RacerIIRE](https://github.com/jjmhalew/A2RacerIIRE), een
reimplementatie in C die de originele spelbestanden leest. De engine is met
Emscripten naar WebAssembly gebouwd en draait op de computer of telefoon
waarmee je de add-on opent, niet op de Home Assistant-server.

De add-on bevat **geen spelbestanden**. A2 Racer II is eigendom van Davilex;
gebruik je eigen kopie (Nederlandse versie, v1.01). Op een apparaat met
aanraakscherm verschijnen de aanraakknoppen van de engine automatisch.

## Wat je nodig hebt

- Home Assistant OS op een van de architecturen hieronder.
- Een eigen kopie van A2 Racer II v1.01.
- De volledige inhoud van de `data`-map van de cd of van de geïnstalleerde
  game. De engine controleert in ieder geval op `spel.dat`, `RCS.IMG`,
  `RCS.IND`, `etappe0.rmp` en `Raser.ini`; kopieer daarom de hele map en niet
  alleen `RCS.IMG`.

De spelbestanden worden eenmalig in de browser opgeslagen (IndexedDB). De
add-on zoekt ze standaard in **`/share/A2racer2`** en kopieert ze bij de
eerste start automatisch naar de browser. Je kunt ook een map op het apparaat
zelf kiezen met **Kies de gamemap…**.

De browser moet genoeg opslagruimte hebben; de spelmap is ongeveer 115 MB. Bij
het wissen van websitegegevens moet je de bestanden opnieuw laden. Gebruik bij
voorkeur een desktopbrowser: de mapkiezer werkt niet in elke mobiele webview.
Op een telefoon of tablet kun je beter de bestanden op de server zetten.

## Installeren

1. Ga in Home Assistant naar **Instellingen → Add-ons → Add-on store**.
2. Open rechtsboven het menu (drie puntjes) en kies **Repositories**.
3. Voeg `https://github.com/MarkvdDr/HomeAssistantApps` toe.
4. Installeer **A2 Racer II** en start de add-on.
5. Zet je spelbestanden in `/share/A2racer2` (zie hieronder) of kies ze in de
   add-on.
6. Open de add-on via het paneel in de zijbalk of via **Open web UI**. De
   add-on kopieert de bestanden uit `/share/A2racer2` automatisch; daarna
   verschijnt **Spelen**.

De add-on heeft geen configuratie-opties nodig.

## Spelbestanden op de server zetten

De add-on heeft read-only toegang tot `/share`. In de **Samba NAS**-app heet
deze map standaard `share` en zie je hem als SMB-share. Zet de bestanden in de
submap `A2racer2`:

1. Open in de Samba NAS-app de share `share` (of gebruik een bestandseditor of
   SSH).
2. Maak in die share de map `A2racer2` aan. De naam is hoofdlettergevoelig:
   gebruik precies `A2racer2`, niet `a2racer2` of `A2Racer2`.
3. Kopieer de inhoud van de spelmap naar `/share/A2racer2`, zodat `RCS.IMG`,
   `spel.dat`, `RCS.IND`, `etappe0.rmp` en `Raser.ini` direct in die map staan.
   Heb je de cd, kopieer dan de inhoud van de `data`-map. Een losse submap
   `data` met daarin de bestanden werkt ook.
4. Start de add-on (opnieuw) zodat de share-koppeling actief is.
5. Open de add-on. De bestanden worden automatisch naar de browseropslag
   gekopieerd. Daarna verschijnt **Spelen**.

De share heet in Samba NAS standaard `share`; wijst jouw share naar dezelfde
map, gebruik dan die naam. De add-on schrijft niets naar `/share`; carrières en
instellingen worden in de browser opgeslagen. Wijzig je later bestanden in
`/share/A2racer2`, kies dan eerst **Spelbestanden vergeten** en open de add-on
opnieuw.

## Spelen

- **Spelen** start het spel in het huidige venster.
- **Volledig scherm** vraagt de browser om volledig scherm. In een HA-paneel
  kan de browser dat blokkeren; open de add-on dan in een eigen tabblad.
- **Spelbestanden vergeten** verwijdert de gekopieerde spelbestanden uit de
  browseropslag. Je carrières en instellingen blijven daarbij bewaard.

De eerste keer kopiëren kan even duren. Daarna staan de bestanden in de browser
en start het spel zonder opnieuw kiezen.

### Aanraakbediening

Op een apparaat met aanraakscherm zet de engine de aanraakknoppen meteen aan.
In de race:

- linksonder: sturen (twee knoppen, of een sleepzone als `steer=drag` in
  `controller.ini` staat);
- rechtsonder: gas, rem, turbo en handrem;
- linksboven: pauze en camera.

Zodra je een toetsenbord of controller gebruikt, verdwijnen de knoppen; bij de
eerste aanraking komen ze terug. De engine regelt dit zelf via zijn eigen
touch-laag. De instellingen staan in `controller.ini` in de browseropslag van
het spel (sectie `[touch]`).

## Architecturen

De add-on is opgebouwd uit een architectuuronafhankelijke WASM-bundel en
`nginx:1.29-alpine`. Daardoor werkt dezelfde add-on op:

- `aarch64` (Raspberry Pi 4/5, Home Assistant Yellow/Green, 64-bit ARM)
- `amd64` (x86-64, NUC, VM)
- `armv7` (32-bit ARM, Raspberry Pi 2/3)
- `armhf` (ARMv6, Raspberry Pi 1/Zero)
- `i386` (32-bit x86)

De spelprestaties hangen vooral af van de browser en de CPU van de client,
niet van de architectuur van de Home Assistant-server.

## Opnieuw bouwen

De map `web/` bevat de kant-en-klare Emscripten-build. Na een wijziging aan de
engine of aan `engine/web.patch` bouw je die opnieuw met:

```sh
./build.sh
```

Dat haalt de vastgezette versie van `jjmhalew/A2RacerIIRE` op, past
`engine/web.patch` toe en schrijft `web/a2racer2.js` en `web/a2racer2.wasm`.
Je hebt Emscripten (`emcc`) nodig; de add-on zelf heeft die toolchain niet
nodig omdat de bundel wordt meegeleverd. Daarna laat je Home Assistant de
add-on opnieuw bouwen (add-on openen en **Opnieuw bouwen** kiezen, of de
add-on verwijderen en opnieuw installeren).

De webmap wordt bewust meegeleverd: zo hoeft Home Assistant OS tijdens het
bouwen van de add-on geen Emscripten-toolchain te downloaden en werkt de
add-on op alle architecturen.

## Bestanden

| Pad | Functie |
|---|---|
| `config.yaml` | Add-on-definitie, ingress en architecturen |
| `Dockerfile` | Nginx-image met de voorgebouwde webmap |
| `nginx.conf` | Statische server op poort 8099 en de `/game/`-listing |
| `web/` | `a2racer2.html`, `loader.js` en de voorgebouwde `a2racer2.js`/`.wasm` |
| `engine/` | Buildscript, patch, GPLv3-tekst en toelichting voor de engine |
| `build.sh` | Bouwt `web/a2racer2.js` en `web/a2racer2.wasm` opnieuw |
| `NOTICE` | Herkomst en licenties |
| `icon.png`, `logo.png` | Add-on-illustraties in de add-on store |

## Problemen oplossen

- **Het spel blijft zwart of WebGL ontbreekt.** Gebruik een recente Chrome,
  Firefox, Edge of Safari met WebGL ingeschakeld. In een oude webview of met
  hardwareversnelling uit kan de 3D-weergave falen.
- **De engine meldt dat `spel.dat` ontbreekt of niet versie 1.01 is.** De
  spelmap is onvolledig of van een andere versie. Kopieer de volledige
  `data`-map van de Nederlandse A2 Racer II v1.01 (cd of installatie).
- **De add-on vindt de bestanden op de server niet.** Controleer of de map
  precies `/share/A2racer2` heet (hoofdlettergevoelig) en of `RCS.IMG`,
  `spel.dat`, `RCS.IND`, `etappe0.rmp` en `Raser.ini` erin staan. Start de
  add-on na het aanmaken van de map opnieuw.
- **De mapkiezer ontbreekt.** Gebruik een desktopbrowser; niet elke mobiele
  webview ondersteunt `webkitdirectory`. Zet de bestanden anders in
  `/share/A2racer2`.
- **De aanraakknoppen verschijnen niet.** De engine toont ze alleen als de
  browser het apparaat als aanraakapparaat meldt. Raak het scherm één keer aan,
  of gebruik een toetsenbord of controller. Op een gewone desktop met muis
  blijven ze weg.
- **Het spel is traag.** De WASM-versie draait op de client. Sluit zware
  tabbladen en probeer een andere browser of computer.
- **De add-on start niet.** Bekijk het add-on-logboek in Home Assistant. De
  container heeft geen speciale rechten of poorten nodig; `/share` wordt
  read-only gekoppeld.
- **De pagina meldt dat browseropslag niet beschikbaar is.** IndexedDB is
  geblokkeerd (bijvoorbeeld in een privévenster of door een extensie). Open de
  add-on in een normaal venster.
- **Bestanden kwijt.** Browseropslag kan door de browser worden opgeruimd. Kies
  de spelmap opnieuw of gebruik de serverimport. De add-on bewaart zelf geen
  speldata of saves.

## Hulp en bugs

- Engine en broncode: <https://github.com/jjmhalew/A2RacerIIRE>
- Deze HAOS-verpakking: <https://github.com/MarkvdDr/HomeAssistantApps>

## Licentie en herkomst

De engine `jjmhalew/A2RacerIIRE` valt onder de GNU GPL v3 of later; de
licentietekst staat in `engine/LICENSE`, de herkomst en wijzigingen in
`NOTICE`. De Home Assistant-verpakking (nginx, Dockerfile, pagina en loader)
valt onder de BOLA-licentie in `LICENSE`. A2 Racer II, de speldata en de
boxart zijn eigendom van hun rechthebbenden. Deze add-on distribueert geen
speldata.
