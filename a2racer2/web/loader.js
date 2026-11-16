/*
 * The page around the A2 Racer II engine.
 *
 * The engine is the jjmhalew/A2RacerIIRE reimplementation, built for the
 * browser with Emscripten. It reads the original game data from /data and
 * writes its settings and saves to /user; both are IndexedDB-backed, so the
 * player chooses the game folder once and keeps it in this browser.
 *
 * The add-on ships no game data. The page can use a folder chosen on the
 * device or, in the Home Assistant add-on, the files in /share/A2racer2 that
 * nginx lists under /game/.
 */
(function () {
  'use strict';

  var DATA = '/data';
  var USER = '/user';
  var GAME = 'game/';
  var RCS = /^RCS\.IMG$/i;
  // The engine's data_find() accepts a folder only when these exist. It checks
  // case-insensitively, so the page does too.
  var REQUIRED = ['spel.dat', 'RCS.IMG', 'RCS.IND', 'etappe0.rmp', 'Raser.ini'];
  var LAST_MESSAGE = 'a2racer2.message';
  var SKIP_AUTO = 'a2racer2.skipAutoImport';
  // The same files the loader has always skipped: Windows leftovers and backups.
  var SKIP = /(^debug\.txt$)|(\.(exe|dll|ico|bak[^/]*)$)|(\.bak_)/i;

  var started = false;
  var ended = false;
  var busy = false;

  function $(id) {
    return document.getElementById(id);
  }

  function status(text) {
    var el = $('status');
    if (el) el.textContent = text;
  }

  function log(text) {
    var el = $('log');
    if (!el) return;
    el.textContent += text + '\n';
    el.scrollTop = el.scrollHeight;
  }

  function showMessage(text) {
    try {
      sessionStorage.setItem(LAST_MESSAGE, text);
    } catch (e) {}
    var overlay = $('overlay');
    if (overlay && !overlay.classList.contains('hidden')) {
      var el = $('message');
      if (el) {
        el.textContent = text;
        el.classList.remove('hidden');
      }
      status(text);
      return;
    }
    // The game covers the panel: show the message over the canvas.
    var toast = $('toast');
    if (toast) {
      toast.textContent = text;
      toast.classList.remove('hidden');
    }
  }

  function restoreMessage() {
    var text = null;
    try {
      text = sessionStorage.getItem(LAST_MESSAGE);
    } catch (e) {}
    if (!text) return;
    showMessage(text);
    try {
      sessionStorage.removeItem(LAST_MESSAGE);
    } catch (e) {}
  }

  function isTouchDevice() {
    try {
      return navigator.maxTouchPoints > 0 ||
        (window.matchMedia && window.matchMedia('(pointer: coarse)').matches);
    } catch (e) {
      return false;
    }
  }

  function sync(populate) {
    return new Promise(function (ok, fail) {
      Module.FS.syncfs(populate, function (e) {
        if (e) fail(e);
        else ok();
      });
    });
  }

  function dataNames() {
    try {
      return Module.FS.readdir(DATA).filter(function (name) {
        return name !== '.' && name !== '..';
      });
    } catch (e) {
      return [];
    }
  }

  function missingFiles(names) {
    var have = {};
    names.forEach(function (name) {
      have[String(name).toLowerCase()] = true;
    });
    return REQUIRED.filter(function (name) {
      return !have[name.toLowerCase()];
    });
  }

  function haveData() {
    return missingFiles(dataNames()).length === 0;
  }

  function showReady() {
    status('De spelbestanden staan klaar in deze browser.');
    $('pick').classList.add('hidden');
    $('ready').classList.remove('hidden');
    if (isTouchDevice()) {
      $('note').classList.remove('hidden');
      $('note').textContent =
        'Dit apparaat heeft aanraakbediening. In de race verschijnen de ' +
        'knoppen vanzelf: links sturen, rechts gas, rem, turbo en handrem, ' +
        'linksboven pauze en camera.';
    }
  }

  function welcome() {
    status('Deze add-on bevat geen spelbestanden. De add-on zoekt ze in ' +
      '/share/A2racer2; je kunt ook een map op dit apparaat kiezen. De ' +
      'bestanden worden daarna in deze browser bewaard.');
    $('pick').classList.remove('hidden');
  }

  // ---- a local folder -----------------------------------------------------

  async function importFolder(files) {
    if (busy) return;
    try {
      sessionStorage.removeItem(SKIP_AUTO);
    } catch (e) {}
    busy = true;
    setPickerBusy(true);
    try {
      await copyFolder(files);
    } finally {
      busy = false;
      setPickerBusy(false);
    }
  }

  async function copyFolder(files) {
    var list = Array.from(files);
    if (!list.length) return;
    var dirOf = function (f) {
      return (f.webkitRelativePath || f.name).split('/').slice(0, -1).join('/');
    };
    var rcs = list.filter(function (f) {
      return RCS.test(f.name);
    }).sort(function (a, b) {
      return dirOf(a).length - dirOf(b).length;
    })[0];
    if (!rcs) {
      status('Die map bevat geen RCS.IMG. Kies de map van de geïnstalleerde ' +
        'game (met spel.dat, RCS.IMG, RCS.IND, etappe0.rmp en Raser.ini).');
      $('pick').classList.remove('hidden');
      return;
    }
    var dir = dirOf(rcs);
    var use = list.filter(function (f) {
      return dirOf(f) === dir && !SKIP.test(f.name);
    });
    var missing = missingFiles(use.map(function (f) {
      return f.name;
    }));
    if (missing.length) {
      status('Deze map is onvolledig; ontbreekt: ' + missing.join(', ') +
        '. Kies de volledige data-map van A2 Racer II v1.01.');
      $('pick').classList.remove('hidden');
      return;
    }
    $('pick').classList.add('hidden');
    $('progress').classList.remove('hidden');
    var done = 0;
    try {
      for (var i = 0; i < use.length; i++) {
        status('Bezig met kopiëren: ' + use[i].name + '…');
        Module.FS.writeFile(DATA + '/' + use[i].name, new Uint8Array(await use[i].arrayBuffer()));
        $('progress').value = (++done / use.length) * 100;
      }
      status('De spelbestanden in deze browser bewaren…');
      await sync(false);
      $('progress').classList.add('hidden');
      log(use.length + ' bestanden uit de gekozen map gekopieerd');
      showReady();
    } catch (e) {
      $('progress').classList.add('hidden');
      $('pick').classList.remove('hidden');
      status('De map kon niet worden geladen: ' + (e && e.message ? e.message : e));
    }
  }

  // ---- the add-on's own /share/A2racer2 -----------------------------------

  function listDir(dir) {
    var url = GAME + dir.map(encodeURIComponent).join('/');
    if (url.slice(-1) !== '/') url += '/';
    return fetch(url, { cache: 'no-store', headers: { Accept: 'application/json' } })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .then(function (data) {
        if (!Array.isArray(data)) throw new Error('onverwachte bestandslijst');
        return data;
      });
  }

  function fileUrl(dir, name) {
    return GAME + dir.concat(name).map(encodeURIComponent).join('/');
  }

  // The shallowest folder that holds RCS.IMG: /share/A2racer2 itself, or a
  // copied CD with its data folder one level down.
  async function findGame() {
    var queue = [[]];
    var visited = 0;
    while (queue.length && visited < 25) {
      var dir = queue.shift();
      visited++;
      var entries = await listDir(dir);
      var files = entries.filter(function (e) {
        return e && e.type === 'file';
      });
      for (var i = 0; i < files.length; i++) {
        if (RCS.test(files[i].name)) return { dir: dir, files: files };
      }
      if (dir.length === 0) {
        entries.filter(function (e) {
          return e && e.type === 'directory';
        }).forEach(function (e) {
          queue.push([e.name]);
        });
      }
    }
    return null;
  }

  function setPickerBusy(on) {
    var folder = $('folder');
    var server = $('server');
    if (folder) folder.disabled = on;
    if (server) server.disabled = on;
  }

  // Writes one complete server folder into /data. The caller holds `busy`.
  // Returns false when the folder is found but incomplete; the message stays
  // on screen then.
  async function copyGame(game) {
    var list = game.files.filter(function (e) {
      return !SKIP.test(e.name);
    });
    if (!list.length) throw new Error('de servermap is leeg');
    var missing = missingFiles(list.map(function (e) {
      return e.name;
    }));
    if (missing.length) {
      status('Op de server ontbreekt: ' + missing.join(', ') + '. Zet de ' +
        'volledige data-map van A2 Racer II v1.01 in /share/A2racer2.');
      return false;
    }
    $('pick').classList.add('hidden');
    $('progress').classList.remove('hidden');
    for (var i = 0; i < list.length; i++) {
      var file = list[i];
      status('Downloaden: ' + file.name + '…');
      var r = await fetch(fileUrl(game.dir, file.name), { cache: 'no-store' });
      if (!r.ok) throw new Error(file.name + ': HTTP ' + r.status);
      Module.FS.writeFile(DATA + '/' + file.name, new Uint8Array(await r.arrayBuffer()));
      $('progress').value = ((i + 1) / list.length) * 100;
    }
    status('De spelbestanden in deze browser bewaren…');
    await sync(false);
    $('progress').classList.add('hidden');
    log(list.length + ' bestanden uit /share/A2racer2 geladen');
    showReady();
    return true;
  }

  async function loadFromServer() {
    if (busy) return;
    try {
      sessionStorage.removeItem(SKIP_AUTO);
    } catch (e) {}
    busy = true;
    setPickerBusy(true);
    try {
      status('Zoeken naar de spelbestanden op de server…');
      var game = await findGame();
      if (!game) {
        status('Geen spelbestanden op de server gevonden. Zet RCS.IMG, ' +
          'spel.dat en de andere bestanden in /share/A2racer2.');
        return;
      }
      await copyGame(game);
    } catch (e) {
      $('progress').classList.add('hidden');
      $('pick').classList.remove('hidden');
      status('De spelbestanden konden niet van de server worden geladen: ' +
        (e && e.message ? e.message : e));
    } finally {
      busy = false;
      setPickerBusy(false);
    }
  }

  // On a first start, use /share/A2racer2 without asking: the add-on is the
  // player's own server, and the import is what the share mapping is for.
  async function tryServerImport() {
    if (busy || haveData()) return;
    var skip = false;
    try {
      skip = sessionStorage.getItem(SKIP_AUTO) === '1';
    } catch (e) {}
    if (skip) {
      // After "Spelbestanden vergeten" the player chooses again.
      var button = $('server');
      if (button) button.classList.remove('hidden');
      return;
    }
    busy = true;
    setPickerBusy(true);
    try {
      var game;
      try {
        game = await findGame();
      } catch (e) {
        // Without the share mapping there is simply no /game/.
        console.log('A2 Racer II: geen spelbestanden op de server: ' + e.message);
        return;
      }
      if (!game || haveData()) return;
      status('Spelbestanden gevonden in /share/A2racer2; ze worden eenmalig ' +
        'naar deze browser gekopieerd…');
      try {
        var done = await copyGame(game);
        if (!done) {
          var button = $('server');
          if (button) button.classList.remove('hidden');
        }
      } catch (e) {
        $('progress').classList.add('hidden');
        $('pick').classList.remove('hidden');
        var retry = $('server');
        if (retry) retry.classList.remove('hidden');
        status('De spelbestanden op de server konden niet worden geladen: ' +
          (e && e.message ? e.message : e));
      }
    } finally {
      busy = false;
      setPickerBusy(false);
    }
  }

  function installServerImport() {
    var button = $('server');
    if (button) {
      button.addEventListener('click', function () {
        loadFromServer();
      });
    }
    if (haveData()) return;
    tryServerImport();
  }

  // ---- starting the engine ------------------------------------------------

  function gameEnded() {
    if (ended) return;
    ended = true;
    // The runtime is finished; reloading brings back the loader with the
    // game files and the saves still in IndexedDB.
    sync(false).catch(function () {}).then(function () {
      setTimeout(function () {
        location.reload();
      }, 1200);
    });
  }

  function start(fullscreen) {
    if (started || !haveData()) return;
    started = true;
    $('overlay').classList.add('hidden');
    var toast = $('toast');
    if (toast) toast.classList.add('hidden');
    var message = $('message');
    if (message) message.classList.add('hidden');
    try {
      sessionStorage.removeItem(LAST_MESSAGE);
    } catch (e) {}
    var canvas = $('canvas');
    canvas.focus();
    if (fullscreen && document.documentElement.requestFullscreen) {
      document.documentElement.requestFullscreen().catch(function () {});
    }
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'hidden') sync(false).catch(function () {});
    });
    window.addEventListener('pagehide', function () {
      sync(false).catch(function () {});
    });
    try {
      var run = Module.callMain([DATA]);
      if (run && typeof run.then === 'function') run.then(gameEnded, gameEnded);
    } catch (e) {
      gameEnded();
    }
  }

  // ---- boot ---------------------------------------------------------------

  async function boot() {
    try {
      Module.FS.mkdir(DATA);
    } catch (e) {}
    try {
      Module.FS.mkdir(USER);
    } catch (e) {}
    try {
      Module.FS.mount(Module.IDBFS, {}, DATA);
      Module.FS.mount(Module.IDBFS, { autoPersist: true }, USER);
    } catch (e) {
      log('Browseropslag is niet beschikbaar: ' + e);
    }
    try {
      await sync(true);
    } catch (e) {
      log('Browseropslag kon niet worden gelezen: ' + e);
    }
    if (haveData()) {
      showReady();
    } else {
      welcome();
      installServerImport();
    }
    restoreMessage();
  }

  var Module = {
    canvas: $('canvas'),
    print: function (text) {
      console.log(text);
    },
    printErr: function (text) {
      console.error(text);
    },
    setStatus: function (text) {
      if (text) status(text);
    },
    onRuntimeInitialized: boot,
    onExit: gameEnded,
    onAbort: function (what) {
      showMessage('De engine stopte: ' + what);
      gameEnded();
    }
  };
  window.Module = Module;

  $('folder').addEventListener('change', function (e) {
    importFolder(e.target.files);
  });
  $('play').addEventListener('click', function () {
    start(false);
  });
  $('fullscreen').addEventListener('click', function () {
    start(true);
  });
  $('forget').addEventListener('click', async function () {
    try {
      Module.FS.readdir(DATA).forEach(function (name) {
        if (name !== '.' && name !== '..') Module.FS.unlink(DATA + '/' + name);
      });
      await sync(false);
    } catch (e) {
      log('Vergeten mislukte: ' + e);
    }
    try {
      sessionStorage.setItem(SKIP_AUTO, '1');
    } catch (e) {}
    location.reload();
  });
  window.addEventListener('a2-message', function (e) {
    showMessage(e.detail);
  });
  $('message').addEventListener('click', function () {
    $('message').classList.add('hidden');
  });
  var toast = $('toast');
  if (toast) {
    toast.addEventListener('click', function () {
      toast.classList.add('hidden');
    });
  }
})();
