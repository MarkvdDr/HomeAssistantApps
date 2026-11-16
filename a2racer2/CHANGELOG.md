# Changelog

## 2.0.0 - 2026-11-16

- Nieuwe engine: de add-on draait nu op
  [jjmhalew/A2RacerIIRE](https://github.com/jjmhalew/A2RacerIIRE) in plaats van
  de eerdere berobloom-port. De engine is met Emscripten naar WebAssembly
  gebouwd en is merkbaar beter speelbaar op minder krachtige apparaten.
- Aanraakbediening van de engine zelf: op een aanraakscherm verschijnen de
  stuur-, gas-, rem-, turbo- en handremknoppen automatisch in de race.
- Nieuwe pagina en loader: de add-on zoekt bij de eerste start automatisch in
  `/share/A2racer2` en kopieert de bestanden naar de browser. Een eigen map
  kiezen kan nog steeds. `touch.js` en `server-load.js` zijn vervallen.
- **Let op:** de standaardmap heet nu `/share/A2racer2` (met hoofdletters).
  Hernoem je bestaande map of verplaats de inhoud.
- `build.sh` bouwt de bundel opnieuw uit een vastgezette upstream-commit met
  `engine/web.patch`; de kant-en-klare `web/a2racer2.js` en `.wasm` blijven
  meegeleverd.
- De add-on bevat nog steeds geen spelbestanden; je eigen A2 Racer II v1.01 is
  nodig.
- Oude `port/`, `research/` en `reverse-engineering/`-mappen verwijderd; ze
  blijven in de git-geschiedenis.
- Documentatie, licentietekst (GPLv3 voor de engine) en een CI-buildworkflow
  toegevoegd.

## 1.1.0 - 2026-11-06

- Spelbestanden kunnen op de server staan: `/share` wordt read-only
  gekoppeld en nginx serveert `/share/a2racer2` onder `/game/`.
- De pagina toont **Use the game files on the server** zodra daar een
  `RCS.IMG` staat; de mapkiezer blijft als alternatief bestaan.

## 1.0.0 - 2026-11-06

- Eerste Home Assistant OS-add-on rond de bestaande WebAssembly-port.
- Werkt via Home Assistant-ingress op `aarch64`, `amd64`, `armv7`, `armhf`
  en `i386`.
- De volledige game blijft beschikbaar; speldata wordt niet meegeleverd.
- De WASM-bundel is vooraf gebouwd, zodat de add-on geen Emscripten-toolchain
  nodig heeft tijdens het bouwen.
