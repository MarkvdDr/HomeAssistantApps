#!/usr/bin/env python3
"""Proton Mail Bridge web terminal for Home Assistant.

Runs the official Proton Mail Bridge CLI on a pseudo terminal, keeps a small
scroll-back buffer and exposes it over HTTP so the add-on ingress panel can be
used as a terminal. No third-party Python packages are required.
"""

import codecs
import fcntl
import json
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import threading
import time
import zoneinfo
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

BRIDGE_BIN = os.environ.get("BRIDGE_BIN", "/usr/lib/protonmail/bridge/bridge")
HYDROXIDE_BIN = os.environ.get("HYDROXIDE_BIN", "/usr/local/bin/hydroxide")
# Proton treats the default "Other" client string as a bot and forces a CAPTCHA
# that Hydroxide cannot complete reliably. Announce a real web-client version;
# it can be overridden without rebuilding the app if Proton changes the value.
HYDROXIDE_APP_VERSION = os.environ.get(
    "HYDROXIDE_APP_VERSION", "web-mail@5.0.124.7"
)
HYDROXIDE_DIR = os.environ.get("HYDROXIDE_DIR", "/data/hydroxide")
HYDROXIDE_CONFIG_DIR = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", "/data/home/.config"), "hydroxide"
)
HYDROXIDE_AUTH_FILE = os.path.join(HYDROXIDE_CONFIG_DIR, "auth.json")
HYDROXIDE_PASSWORD_FILE = os.path.join(HYDROXIDE_DIR, "bridge_password")
HYDROXIDE_CERT_FILE = os.path.join(HYDROXIDE_DIR, "tls.crt")
HYDROXIDE_KEY_FILE = os.path.join(HYDROXIDE_DIR, "tls.key")
WEB_PORT = int(os.environ.get("WEB_PORT", "8099"))
APP_DIR = os.path.dirname(os.path.abspath(__file__))
OPTIONS_PATH = os.environ.get("OPTIONS_PATH", "/data/options.json")

MAX_LINES = 4000
MAX_CHARS = 150_000
RESTART_DELAY = 5.0

DEFAULT_OPTIONS = {
    "bridge_implementation": "official",
    "log_level": "info",
    "timezone": "Europe/Amsterdam",
    "telemetry_disabled": True,
    "proxy_allowed": False,
    "show_all_mail": True,
    "bridge_autoupdate": False,
    "imap_security": "starttls",
    "smtp_security": "starttls",
    "log_imap": "off",
    "log_smtp": False,
    "auto_restart": True,
}


def log(message: str) -> None:
    print(f"[web] {message}", flush=True)


def _as_bool(value, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in ("true", "1", "yes", "on"):
            return True
        if lowered in ("false", "0", "no", "off"):
            return False
    return default


def _as_choice(value, choices: tuple[str, ...], default: str) -> str:
    if isinstance(value, str) and value.strip().lower() in choices:
        return value.strip().lower()
    return default


def _as_timezone(value, default: str) -> str:
    if not isinstance(value, str) or not value.strip():
        return default
    name = value.strip()
    try:
        zoneinfo.ZoneInfo(name)
    except (zoneinfo.ZoneInfoNotFoundError, ValueError):
        log(f"unknown timezone {name!r}, falling back to {default}")
        return default
    return name


def load_options() -> dict:
    """Read /data/options.json and normalise every value.

    Every option is validated against a fixed set of values. A malformed value
    falls back to its default so an add-on option can never prevent startup.
    """
    options = dict(DEFAULT_OPTIONS)
    raw = None
    try:
        with open(OPTIONS_PATH, encoding="utf-8") as handle:
            raw = json.load(handle)
    except FileNotFoundError:
        log(f"options file {OPTIONS_PATH} not found, using defaults")
    except (OSError, ValueError) as error:
        log(f"could not read options file {OPTIONS_PATH}: {error}; using defaults")

    if not isinstance(raw, dict):
        raw = {}

    # Bridge calls its log levels panic|fatal|error|warn|info|debug. The add-on
    # historically offered trace, which is mapped to debug.
    log_level = _as_choice(raw.get("log_level"), ("trace", "debug", "info", "warn", "error"), DEFAULT_OPTIONS["log_level"])
    if log_level == "trace":
        log_level = "debug"

    options.update(
        {
            "bridge_implementation": _as_choice(
                raw.get("bridge_implementation"),
                ("official", "hydroxide"),
                DEFAULT_OPTIONS["bridge_implementation"],
            ),
            "log_level": log_level,
            "timezone": _as_timezone(raw.get("timezone"), DEFAULT_OPTIONS["timezone"]),
            "telemetry_disabled": _as_bool(raw.get("telemetry_disabled"), DEFAULT_OPTIONS["telemetry_disabled"]),
            "proxy_allowed": _as_bool(raw.get("proxy_allowed"), DEFAULT_OPTIONS["proxy_allowed"]),
            "show_all_mail": _as_bool(raw.get("show_all_mail"), DEFAULT_OPTIONS["show_all_mail"]),
            "bridge_autoupdate": _as_bool(raw.get("bridge_autoupdate"), DEFAULT_OPTIONS["bridge_autoupdate"]),
            "imap_security": _as_choice(raw.get("imap_security"), ("starttls", "ssl"), DEFAULT_OPTIONS["imap_security"]),
            "smtp_security": _as_choice(raw.get("smtp_security"), ("starttls", "ssl"), DEFAULT_OPTIONS["smtp_security"]),
            "log_imap": _as_choice(raw.get("log_imap"), ("off", "all", "client", "server"), DEFAULT_OPTIONS["log_imap"]),
            "log_smtp": _as_bool(raw.get("log_smtp"), DEFAULT_OPTIONS["log_smtp"]),
            "auto_restart": _as_bool(raw.get("auto_restart"), DEFAULT_OPTIONS["auto_restart"]),
        }
    )
    return options


def apply_timezone(options: dict) -> None:
    os.environ["TZ"] = options["timezone"]
    try:
        time.tzset()
    except AttributeError:  # pragma: no cover - every supported platform has tzset
        pass
    log(f"timezone set to {options['timezone']}")


class Screen:
    """Very small line-oriented terminal emulator.

    Bridge's CLI (ishell/readline) redraws the prompt with carriage returns and
    erases the rest of the line with CSI K. Handling those two control
    sequences is enough to render its output legibly in a browser.
    """

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.lines: list[str] = []
        self.cur: list[str] = []
        self.col = 0
        self.total = 0
        self.state = "normal"
        self.csi = ""

    def _put(self, char: str) -> None:
        if self.col < len(self.cur):
            self.cur[self.col] = char
        else:
            if self.col > len(self.cur):
                self.cur.extend(" " * (self.col - len(self.cur)))
            self.cur.append(char)
        self.col += 1

    def _newline(self) -> None:
        line = "".join(self.cur).rstrip()
        self.lines.append(line)
        self.total += len(line) + 1
        self.cur = []
        self.col = 0
        self._trim()

    def _trim(self) -> None:
        while self.total > MAX_CHARS and self.lines:
            self.total -= len(self.lines.pop(0)) + 1
        while len(self.lines) > MAX_LINES:
            self.total -= len(self.lines.pop(0)) + 1

    def _erase_line(self, mode: int) -> None:
        if mode == 1:
            for index in range(min(self.col + 1, len(self.cur))):
                self.cur[index] = " "
        elif mode == 2:
            self.cur = []
        else:
            del self.cur[self.col:]

    def _handle_csi(self, final: str, params: str) -> None:
        numbers = [int(part) if part.isdigit() else 0 for part in params.split(";")] if params else []
        first = numbers[0] if numbers else 0
        if final == "K":
            self._erase_line(first)
        elif final == "J":
            if first in (2, 3):
                self.lines = []
                self.total = 0
                self.cur = []
                self.col = 0
            else:
                del self.cur[self.col:]
        elif final in "Hf":
            self.cur = []
            self.col = 0
        elif final == "G":
            self.col = max(0, first - 1)
        elif final == "C":
            self.col += max(1, first)
        elif final == "D":
            self.col = max(0, self.col - max(1, first))
        elif final == "P":
            del self.cur[self.col:self.col + max(1, first)]
        elif final == "X":
            for index in range(self.col, min(self.col + max(1, first), len(self.cur))):
                self.cur[index] = " "

    def feed(self, text: str) -> None:
        for char in text:
            if self.state == "normal":
                if char == "\x1b":
                    self.state = "esc"
                elif char == "\r":
                    self.col = 0
                elif char == "\n":
                    self._newline()
                elif char == "\b":
                    self.col = max(0, self.col - 1)
                elif char == "\t":
                    self.col += 8 - (self.col % 8)
                elif char in ("\x07", "\x00"):
                    continue
                elif char >= " ":
                    self._put(char)
            elif self.state == "esc":
                if char == "[":
                    self.state = "csi"
                    self.csi = ""
                elif char == "]":
                    self.state = "osc"
                else:
                    self.state = "normal"
            elif self.state == "csi":
                if "@" <= char <= "~":
                    self._handle_csi(char, self.csi)
                    self.state = "normal"
                else:
                    self.csi += char
                    if len(self.csi) > 32:
                        self.csi = ""
                        self.state = "normal"
            elif self.state == "osc":
                if char == "\x07":
                    self.state = "normal"
                elif char == "\x1b":
                    self.state = "osc_esc"
            elif self.state == "osc_esc":
                self.state = "normal" if char == "\\" else "osc"

    def text(self) -> str:
        lines = self.lines + ["".join(self.cur).rstrip()]
        while len(lines) > 1 and not lines[-1].strip() and not lines[-2].strip():
            lines.pop()
        return "\n".join(lines)

    def append_system(self, message: str) -> None:
        self._newline()
        for part in message.splitlines() or [""]:
            self.lines.append(part)
            self.total += len(part) + 1
        self.cur = []
        self.col = 0
        self._trim()


class BridgeProcess:
    def __init__(self, options: dict) -> None:
        self.screen = Screen()
        self.cond = threading.Condition()
        self.version = 0
        self.running = False
        self.exit_code = None
        self.started_at = None
        self.pid = None
        self.fd = None
        self._start_lock = threading.Lock()
        self._write_lock = threading.Lock()
        self._stopping = False
        self._restart_failures = 0
        self.options = options
        self.log_level = options["log_level"]
        self.settings_applying = False
        self.settings_error = None
        self._settings_applied = False

    # -- lifecycle ---------------------------------------------------------
    def start(self) -> None:
        with self._start_lock:
            if self.running:
                return
            if not os.path.isfile(BRIDGE_BIN):
                self._system_line(f"Bridge binary not found: {BRIDGE_BIN}")
                return

            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 160, 0, 0))
            env = dict(os.environ)
            env.setdefault("TERM", "xterm-256color")

            args = [BRIDGE_BIN, "--cli", "-l", self.log_level]
            if self.options["log_imap"] != "off":
                args.extend(["--log-imap", self.options["log_imap"]])
            if self.options["log_smtp"]:
                args.append("--log-smtp")

            try:
                proc = subprocess.Popen(
                    args,
                    stdin=slave,
                    stdout=slave,
                    stderr=slave,
                    env=env,
                    start_new_session=True,
                    close_fds=True,
                )
            except OSError as error:
                os.close(master)
                os.close(slave)
                self._system_line(f"Could not start Proton Mail Bridge: {error}")
                log(f"could not start bridge: {error}")
                return
            os.close(slave)

            self.screen.reset()
            self.pid = proc.pid
            self.fd = master
            self.running = True
            self.exit_code = None
            self.started_at = time.time()
            self.settings_applying = not self._settings_applied
            if self.settings_applying:
                self.settings_error = None
            self._bump()
            log(f"bridge started (pid {proc.pid})")
            threading.Thread(target=self._read_loop, args=(proc, master), daemon=True).start()
            if self.settings_applying:
                threading.Thread(
                    target=self._apply_settings, args=(proc.pid,), daemon=True
                ).start()

    def _read_loop(self, proc: subprocess.Popen, fd: int) -> None:
        decoder = codecs.getincrementaldecoder("utf-8")("replace")
        while True:
            try:
                ready, _, _ = select.select([fd], [], [], 1.0)
            except (OSError, ValueError):
                break
            if not ready:
                continue
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            text = decoder.decode(chunk)
            if text:
                with self.cond:
                    self.screen.feed(text)
                    self.version += 1
                    self.cond.notify_all()

        remaining = decoder.decode(b"", final=True)
        if remaining:
            with self.cond:
                self.screen.feed(remaining)
                self.version += 1
                self.cond.notify_all()

        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        try:
            os.close(fd)
        except OSError:
            pass

        uptime = time.time() - (self.started_at or time.time())
        with self.cond:
            self.running = False
            self.exit_code = proc.returncode
            self.fd = None
            if self.settings_applying:
                self.settings_applying = False
                self.settings_error = "Bridge stopped while applying settings"
            self.version += 1
            self.cond.notify_all()
        log(f"bridge exited with code {proc.returncode} after {uptime:.0f}s")

        if not self._stopping:
            if self.options["auto_restart"]:
                if uptime >= 60:
                    self._restart_failures = 0
                delay = min(
                    RESTART_DELAY * (2 ** min(self._restart_failures, 4)), 60.0
                )
                self._restart_failures += 1
                log(
                    f"restarting bridge in {delay:.0f}s "
                    f"(consecutive quick exits: {self._restart_failures})"
                )
                timer = threading.Timer(delay, self.start)
                timer.daemon = True
                timer.start()
            else:
                log("auto_restart is disabled; not restarting bridge")

    def _system_line(self, message: str) -> None:
        with self.cond:
            self.screen.append_system(message)
            self.version += 1
            self.cond.notify_all()

    def _bump(self) -> None:
        with self.cond:
            self.version += 1
            self.cond.notify_all()

    def text(self) -> str:
        with self.cond:
            return self.screen.text()

    # -- add-on options ----------------------------------------------------
    def _alive(self, pid: int) -> bool:
        return self.running and self.pid == pid

    def _state(self) -> tuple[int, str, bool]:
        with self.cond:
            return self.version, self.screen.text(), self.running

    def _wait_for_prompt(self, pid: int, since_version: int, timeout: float) -> bool:
        """Wait until the CLI shows its `>>>` prompt after new output."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            if not self._alive(pid):
                return False
            version, text, _ = self._state()
            if version > since_version and text.rstrip().endswith(">>>"):
                # Require the prompt to stay put for a moment, so a prompt from
                # the previous command cannot be mistaken for this one.
                time.sleep(0.3)
                if not self._alive(pid):
                    return False
                version_after, text_after, _ = self._state()
                if version_after >= version and text_after.rstrip().endswith(">>>"):
                    return True
            time.sleep(0.1)
        return False

    @staticmethod
    def _new_output(prefix: str, text: str) -> str:
        """Return only the output produced after `prefix` where possible."""
        if text.startswith(prefix):
            return text[len(prefix):]
        # The scroll-back buffer may have been trimmed; fall back to the tail.
        return text[-1200:]

    def _run_command(self, pid: int, command: str, timeout: float = 25.0) -> bool:
        """Run an idempotent CLI command and accept its confirmation prompt."""
        version, prefix, _ = self._state()
        if not self.write(command + "\r"):
            return False
        deadline = time.time() + timeout
        confirmed = False
        while time.time() < deadline:
            if not self._alive(pid):
                return False
            current, text, _ = self._state()
            if current > version:
                tail = self._new_output(prefix, text)
                if not confirmed and "yes/no" in tail:
                    version = current
                    prefix = text
                    confirmed = True
                    if not self.write("yes\r"):
                        return False
                    deadline = time.time() + timeout
                elif text.rstrip().endswith(">>>"):
                    # The prompt may have been queued before our echo arrived.
                    time.sleep(0.3)
                    if not self._alive(pid):
                        return False
                    _, text_after, _ = self._state()
                    if text_after.rstrip().endswith(">>>"):
                        return True
            time.sleep(0.1)
        return False

    def _set_security(self, pid: int, kind: str, desired: str) -> bool:
        """Set IMAP/SMTP security without blindly toggling.

        `change imap-security` and `change smtp-security` toggle the current
        value. The confirmation question names the value it is about to switch
        to, so answer `yes` only when that is the requested value and `no`
        otherwise. This keeps the option stable across restarts.
        """
        version, prefix, _ = self._state()
        if not self.write(f"change {kind}-security\r"):
            return False
        pattern = re.compile(
            rf'change {kind.upper()} setting to "?(SSL|STARTTLS)"?', re.IGNORECASE
        )
        deadline = time.time() + 25.0
        new_value = None
        while time.time() < deadline:
            if not self._alive(pid):
                return False
            current, text, _ = self._state()
            if current > version:
                tail = self._new_output(prefix, text)
                match = pattern.search(tail)
                if match:
                    new_value = match.group(1).lower()
                if new_value and "yes/no" in tail:
                    break
                if text.rstrip().endswith(">>>"):
                    # The prompt may have been queued before our echo arrived.
                    time.sleep(0.3)
                    if not self._alive(pid):
                        return False
                    _, text_after, _ = self._state()
                    if text_after.rstrip().endswith(">>>"):
                        return False
            time.sleep(0.1)
        if not new_value:
            return False

        answer = "yes" if new_value == desired else "n"
        version, prefix, _ = self._state()
        if not self.write(answer + "\r"):
            return False
        return self._wait_for_prompt(pid, version, 25.0)

    def _finish_settings(self, error: str | None) -> None:
        with self.cond:
            self.settings_applying = False
            self.settings_error = error
            if error is None:
                self._settings_applied = True
            self.version += 1
            self.cond.notify_all()

    def _apply_settings(self, pid: int) -> None:
        """Apply the add-on Configuration tab values once per add-on start."""
        log("applying add-on options to Bridge")
        if not self._wait_for_prompt(pid, self._state()[0] - 1, 90.0):
            message = "Bridge CLI did not become ready"
            log(message)
            self._finish_settings(message)
            return

        self._system_line("[addon] Applying settings from the Configuration tab...")
        commands = [
            ("telemetry", "telemetry disable" if self.options["telemetry_disabled"] else "telemetry enable"),
            ("proxy", "proxy allow" if self.options["proxy_allowed"] else "proxy disallow"),
            ("all-mail-visibility", "all-mail-visibility show" if self.options["show_all_mail"] else "all-mail-visibility hide"),
            ("updates", "updates autoupdates disable" if not self.options["bridge_autoupdate"] else "updates autoupdates enable"),
        ]
        failures = []
        for name, command in commands:
            if not self._run_command(pid, command):
                failures.append(name)
                log(f"could not apply {name}")
        for kind in ("imap", "smtp"):
            if not self._set_security(pid, kind, self.options[f"{kind}_security"]):
                failures.append(f"{kind}-security")
                log(f"could not apply {kind}-security")

        if failures:
            message = "Could not apply: " + ", ".join(failures)
            self._system_line(f"[addon] {message}. Check the Bridge output above.")
            self._finish_settings(message)
            log(message)
        else:
            self._system_line("[addon] Settings applied.")
            self._finish_settings(None)
            log("add-on options applied")

    def stop(self) -> None:
        self._stopping = True
        pid = self.pid
        if not pid or not self.running:
            return
        try:
            os.killpg(pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            return
        deadline = time.time() + 8
        while time.time() < deadline and self.running:
            time.sleep(0.1)
        if self.running:
            try:
                os.killpg(pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass

    def restart(self) -> None:
        self._stopping = True
        pid = self.pid
        if pid and self.running:
            try:
                os.killpg(pid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass
            deadline = time.time() + 8
            while time.time() < deadline and self.running:
                time.sleep(0.1)
            if self.running:
                try:
                    os.killpg(pid, signal.SIGKILL)
                except (ProcessLookupError, PermissionError):
                    pass
                deadline = time.time() + 3
                while time.time() < deadline and self.running:
                    time.sleep(0.1)
        self._stopping = False
        self._restart_failures = 0
        self.start()

    # -- IO ----------------------------------------------------------------
    def write(self, data: str) -> bool:
        with self._write_lock:
            fd = self.fd
            if not self.running or fd is None:
                return False
            try:
                os.write(fd, data.encode("utf-8"))
                return True
            except OSError:
                return False

    # -- state -------------------------------------------------------------
    def snapshot(self) -> dict:
        with self.cond:
            return {
                "version": self.version,
                "text": self.screen.text(),
                "running": self.running,
                "exit_code": self.exit_code,
                "uptime": int(time.time() - self.started_at) if self.running and self.started_at else 0,
                "settings_applying": self.settings_applying,
                "settings_error": self.settings_error,
                "implementation": "official",
                "settings": {
                    "imap_security": self.options["imap_security"],
                    "smtp_security": self.options["smtp_security"],
                },
            }

    def wait_for_change(self, version: int, timeout: float) -> None:
        deadline = time.time() + timeout
        with self.cond:
            while self.version == version:
                remaining = deadline - time.time()
                if remaining <= 0:
                    return
                self.cond.wait(remaining)


class HydroxideBridge:
    """Run Hydroxide for the optional third-party free-account mode.

    Hydroxide has no interactive shell: ``auth`` is a one-shot command and
    ``serve`` is a long-running server. This class presents both through the
    same web terminal and stores the generated bridge password in /data so
    ``serve`` can start unattended after a restart.
    """

    AUTH_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    PASSWORD_RE = re.compile(r"Bridge password:\s*([A-Za-z0-9+/=]+)")

    def __init__(self, options: dict) -> None:
        self.options = options
        self.screen = Screen()
        self.cond = threading.Condition()
        self.version = 0
        self.running = False
        self.exit_code = None
        self.started_at = None
        self.pid = None
        self.fd = None
        self.proc = None
        self.phase = "idle"
        self.signed_in = False
        self.account = None
        self.bridge_password = None
        self.settings_applying = False
        self.settings_error = None
        self._auth_capture = bytearray()
        self._auth_username = None
        self._start_lock = threading.Lock()
        self._write_lock = threading.Lock()
        self._stopping = False
        self._serve_failures = 0

    # -- files -------------------------------------------------------------
    @staticmethod
    def _ensure_dirs() -> None:
        os.makedirs(HYDROXIDE_DIR, mode=0o700, exist_ok=True)
        os.makedirs(HYDROXIDE_CONFIG_DIR, mode=0o700, exist_ok=True)
        try:
            os.chmod(HYDROXIDE_DIR, 0o700)
        except OSError:
            pass

    @staticmethod
    def _read_password():
        try:
            with open(HYDROXIDE_PASSWORD_FILE, encoding="utf-8") as handle:
                value = handle.read().strip()
        except OSError:
            return None
        return value or None

    def _write_password(self, password: str) -> bool:
        temp = HYDROXIDE_PASSWORD_FILE + ".tmp"
        try:
            self._ensure_dirs()
            with open(temp, "w", encoding="utf-8") as handle:
                handle.write(password)
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temp, 0o600)
            os.replace(temp, HYDROXIDE_PASSWORD_FILE)
            return True
        except OSError as error:
            try:
                os.remove(temp)
            except OSError:
                pass
            self.settings_error = f"Could not save the bridge password: {error}"
            self._system_line("[addon] " + self.settings_error)
            return False

    @staticmethod
    def _read_accounts():
        try:
            with open(HYDROXIDE_AUTH_FILE, encoding="utf-8") as handle:
                data = json.load(handle)
        except (OSError, ValueError):
            return []
        if isinstance(data, dict):
            return sorted(str(name) for name in data)
        return []

    def _refresh_identity(self) -> None:
        accounts = self._read_accounts()
        self.signed_in = bool(accounts)
        self.account = ", ".join(accounts) if accounts else None

    def _system_line(self, message: str) -> None:
        with self.cond:
            self.screen.append_system(message)
            self.version += 1
            self.cond.notify_all()

    def _show_idle(self) -> None:
        if self.signed_in and not self.bridge_password:
            self._system_line(
                "[addon] A Proton login was found, but its bridge password is missing. "
                "Run: auth you@proton.me"
            )
        elif not self.signed_in:
            self._system_line("[addon] Hydroxide mode is active. Not signed in.")
            self._system_line("[addon] Enter your Proton address below, or type: auth you@proton.me")
        self._system_line("[addon] Mail clients use SSL on ports 1143 and 1025 once the server is running.")

    # -- TLS ---------------------------------------------------------------
    def _ensure_tls(self):
        self._ensure_dirs()
        if os.path.isfile(HYDROXIDE_CERT_FILE) and os.path.isfile(HYDROXIDE_KEY_FILE):
            return None
        if not os.path.isfile(HYDROXIDE_BIN):
            return f"Hydroxide binary not found: {HYDROXIDE_BIN}"

        temp_key = HYDROXIDE_KEY_FILE + ".tmp"
        temp_cert = HYDROXIDE_CERT_FILE + ".tmp"
        command = [
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-days", "3650", "-subj", "/CN=homeassistant.local",
            "-keyout", temp_key, "-out", temp_cert,
        ]
        try:
            result = subprocess.run(
                command,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                check=False,
                timeout=60,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            return f"Could not create the TLS certificate: {error}"
        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", "replace").strip()
            return f"Could not create the TLS certificate: {detail or result.returncode}"
        try:
            os.chmod(temp_key, 0o600)
            os.chmod(temp_cert, 0o644)
            os.replace(temp_key, HYDROXIDE_KEY_FILE)
            os.replace(temp_cert, HYDROXIDE_CERT_FILE)
        except OSError as error:
            return f"Could not store the TLS certificate: {error}"
        finally:
            for path in (temp_key, temp_cert):
                try:
                    os.remove(path)
                except OSError:
                    pass
        log("hydroxide TLS certificate generated")
        return None

    # -- process lifecycle -------------------------------------------------
    def _spawn(self, args, kind: str, env_extra=None):
        if not os.path.isfile(HYDROXIDE_BIN):
            self.settings_error = f"Hydroxide binary not found: {HYDROXIDE_BIN}"
            self._system_line("[addon] " + self.settings_error)
            return None

        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 160, 0, 0))
        if kind == "auth":
            # Hydroxide disables echo itself for its password prompt, but do it
            # on the PTY before the process starts so even a fast typist cannot
            # race the prompt and leave a password in the scroll-back buffer.
            try:
                attrs = termios.tcgetattr(slave)
                attrs[3] &= ~termios.ECHO
                termios.tcsetattr(slave, termios.TCSANOW, attrs)
            except termios.error:
                pass
        env = dict(os.environ)
        env.setdefault("TERM", "xterm-256color")
        if env_extra:
            env.update(env_extra)

        try:
            proc = subprocess.Popen(
                args,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                env=env,
                start_new_session=True,
                close_fds=True,
            )
        except OSError as error:
            os.close(master)
            os.close(slave)
            self.settings_error = f"Could not start Hydroxide: {error}"
            self._system_line("[addon] " + self.settings_error)
            log(f"could not start hydroxide {kind}: {error}")
            return None
        os.close(slave)

        with self.cond:
            self.proc = proc
            self.pid = proc.pid
            self.fd = master
            self.running = True
            self.exit_code = None
            self.started_at = time.time()
            self.version += 1
            self.cond.notify_all()
        log(f"hydroxide {kind} started (pid {proc.pid})")
        threading.Thread(
            target=self._read_loop, args=(proc, master, kind), daemon=True
        ).start()
        return proc

    def _read_loop(self, proc: subprocess.Popen, fd: int, kind: str) -> None:
        decoder = codecs.getincrementaldecoder("utf-8")("replace")
        capture = bytearray()
        while True:
            try:
                ready, _, _ = select.select([fd], [], [], 1.0)
            except (OSError, ValueError):
                break
            if not ready:
                continue
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            if kind == "auth" and len(capture) < 262144:
                capture.extend(chunk[: 262144 - len(capture)])
            text = decoder.decode(chunk)
            if text:
                with self.cond:
                    self.screen.feed(text)
                    self.version += 1
                    self.cond.notify_all()

        remaining = decoder.decode(b"", final=True)
        if remaining:
            with self.cond:
                self.screen.feed(remaining)
                self.version += 1
                self.cond.notify_all()

        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                pass
        try:
            os.close(fd)
        except OSError:
            pass

        uptime = time.time() - (self.started_at or time.time())
        with self.cond:
            if self.proc is not proc:
                return
            self.proc = None
            self.running = False
            self.exit_code = proc.returncode
            self.fd = None
            self.phase = "idle" if kind == "auth" else "stopped"
            self.version += 1
            self.cond.notify_all()
        log(f"hydroxide {kind} exited with code {proc.returncode} after {uptime:.0f}s")

        if kind == "auth":
            self._finish_auth(bytes(capture))
        else:
            self._finish_serve(proc.returncode, uptime)

    def _stop_current(self) -> None:
        proc = self.proc
        with self.cond:
            self.proc = None
            self.running = False
            self.fd = None
            self.pid = None
            self.version += 1
            self.cond.notify_all()
        if proc is None:
            return
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                pass

    def _start_serve_locked(self) -> None:
        self._refresh_identity()
        if not self.signed_in or not self.bridge_password:
            self.phase = "idle"
            self._show_idle()
            return

        error = self._ensure_tls()
        if error:
            self.settings_error = error
            self.phase = "stopped"
            self._system_line("[addon] " + error)
            log(error)
            return

        self.settings_error = None
        self.phase = "serve"
        args = [HYDROXIDE_BIN]
        if self.options["log_level"] in ("debug", "trace"):
            args.append("-debug")
        args.extend(["-app-version", HYDROXIDE_APP_VERSION])
        args.extend(
            [
                "-imap-host", "0.0.0.0",
                "-imap-port", "1143",
                "-smtp-host", "0.0.0.0",
                "-smtp-port", "1025",
                "-disable-carddav",
                "-tls-cert", HYDROXIDE_CERT_FILE,
                "-tls-key", HYDROXIDE_KEY_FILE,
                "serve",
            ]
        )
        proc = self._spawn(
            args, "serve", {"HYDROXIDE_BRIDGE_PASS": self.bridge_password}
        )
        if proc is None:
            self.phase = "stopped"
            return
        self._system_line(
            "[addon] Hydroxide server running with SSL on ports 1143 (IMAP) and 1025 (SMTP)."
        )

    def _start_auth(self, username: str) -> None:
        username = username.strip()
        if not self.AUTH_RE.match(username):
            self._system_line("[addon] Usage: auth you@proton.me")
            return
        with self._start_lock:
            if self.phase == "auth":
                self._system_line("[addon] A login is already in progress.")
                return
            self._serve_failures = 0
            self._system_line(f"[addon] Starting Hydroxide login for {username}.")
            self._system_line(
                "[addon] Enter your Proton password (or mailbox password) when prompted; "
                "2FA and CAPTCHA follow if enabled."
            )
            self._stop_current()
            self.phase = "auth"
            self._auth_capture = bytearray()
            self._auth_username = username
            self.settings_error = None
            args = [HYDROXIDE_BIN]
            if self.options["log_level"] in ("debug", "trace"):
                args.append("-debug")
            args.extend(["-app-version", HYDROXIDE_APP_VERSION])
            args.extend(["auth", username])
            proc = self._spawn(args, "auth")
            if proc is None:
                self.phase = "idle"
                if self.signed_in and self.bridge_password:
                    self._start_serve_locked()
                else:
                    self._show_idle()

    def _finish_auth(self, capture: bytes) -> None:
        text = capture.decode("utf-8", "replace")
        match = self.PASSWORD_RE.search(text)
        self._refresh_identity()
        if not match:
            self._system_line(
                "[addon] Login did not complete; no bridge password was found in the output."
            )
            if self.signed_in and self.bridge_password:
                self._system_line("[addon] Keeping the existing login and restarting the server...")
                with self._start_lock:
                    self._start_serve_locked()
            else:
                self._show_idle()
            return

        password = match.group(1)
        self.bridge_password = password
        self._auth_capture = bytearray()
        self._auth_username = None
        if not self._write_password(password):
            self._show_idle()
            return
        self._refresh_identity()
        self._system_line(
            "[addon] Proton login saved. The bridge password is stored in /data/hydroxide/bridge_password."
        )
        self._system_line("[addon] Starting the Hydroxide server...")
        with self._start_lock:
            self._start_serve_locked()

    def _finish_serve(self, returncode, uptime: float) -> None:
        if self._stopping or self.phase == "auth":
            return
        if uptime >= 60:
            self._serve_failures = 0
        else:
            self._serve_failures += 1
        if self._serve_failures >= 3:
            self.settings_error = (
                "Hydroxide stopped repeatedly; check the log and sign in again if needed"
            )
            self.phase = "stopped"
            self._system_line("[addon] " + self.settings_error)
            return
        if not self.options["auto_restart"]:
            self.phase = "stopped"
            self._system_line(
                f"[addon] Hydroxide stopped (exit {returncode}); auto_restart is disabled."
            )
            return
        self._system_line(
            f"[addon] Hydroxide stopped (exit {returncode}); restarting in {RESTART_DELAY:.0f} seconds..."
        )
        timer = threading.Timer(RESTART_DELAY, self._restart_serve)
        timer.daemon = True
        timer.start()

    def _restart_serve(self) -> None:
        if self._stopping:
            return
        with self._start_lock:
            if self._stopping or self.phase == "auth":
                return
            self._refresh_identity()
            if self.signed_in and self.bridge_password:
                self._start_serve_locked()
            else:
                self.phase = "idle"
                self._show_idle()

    # -- commands ----------------------------------------------------------
    def _run_status(self) -> None:
        if not os.path.isfile(HYDROXIDE_BIN):
            self._system_line("[addon] Hydroxide binary not found.")
            return
        try:
            result = subprocess.run(
                [HYDROXIDE_BIN, "status"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=15,
                env=dict(os.environ),
                text=True,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            self._system_line(f"[status] {error}")
            return
        output = (result.stdout or "").strip() or f"exit code {result.returncode}"
        for line in output.splitlines():
            self._system_line(f"[status] {line}")

    def _show_password(self) -> None:
        if self.bridge_password:
            self._system_line(f"[addon] Bridge password: {self.bridge_password}")
        else:
            self._system_line(
                "[addon] No bridge password is stored yet. Sign in first with: auth you@proton.me"
            )

    def _help(self) -> None:
        for line in (
            "Hydroxide commands:",
            "  auth <address>   Sign in to Proton (password, 2FA, CAPTCHA)",
            "  status           Show the signed-in account(s)",
            "  password         Show the bridge password for mail clients",
            "  restart          Restart the Hydroxide server",
            "  logout confirm   Remove the stored Proton login and bridge password",
            "  help             Show this help",
        ):
            self._system_line(line)

    def _logout(self) -> None:
        with self._start_lock:
            self._stop_current()
            self.phase = "idle"
            self.bridge_password = None
            self.signed_in = False
            self.account = None
            removed = False
            for path in (HYDROXIDE_AUTH_FILE, HYDROXIDE_PASSWORD_FILE):
                try:
                    os.remove(path)
                    removed = True
                except FileNotFoundError:
                    pass
                except OSError as error:
                    self._system_line(f"[addon] Could not remove {path}: {error}")
            self._system_line(
                "[addon] Signed out." if removed else "[addon] No stored login was found."
            )
            self._show_idle()

    def _handle_command(self, line: str) -> None:
        lowered = line.lower()
        if lowered in ("help", "?"):
            self._help()
        elif lowered == "status":
            self._run_status()
        elif lowered in ("password", "bridge password", "bridge-password"):
            self._show_password()
        elif lowered in ("restart", "reload"):
            threading.Thread(target=self.restart, daemon=True).start()
        elif lowered == "logout":
            self._system_line(
                "[addon] This removes the stored Proton login and bridge password. Type: logout confirm"
            )
        elif lowered == "logout confirm":
            self._logout()
        elif lowered == "auth":
            self._system_line("[addon] Usage: auth you@proton.me")
        elif lowered.startswith("auth "):
            self._start_auth(line[5:].strip())
        elif self.AUTH_RE.match(line):
            # Accept a bare address typed into the terminal as a login shortcut.
            self._start_auth(line)
        else:
            self._system_line(f"[addon] Unknown command: {line}. Type help.")

    # -- public API --------------------------------------------------------
    def start(self) -> None:
        with self._start_lock:
            self._stopping = False
            self._serve_failures = 0
            self._ensure_dirs()
            self.bridge_password = self._read_password()
            self._refresh_identity()
            if self.signed_in and self.bridge_password:
                self._start_serve_locked()
            else:
                self.phase = "idle"
                self._show_idle()

    def stop(self) -> None:
        self._stopping = True
        self._stop_current()

    def restart(self) -> None:
        self._stopping = True
        self._stop_current()
        self._stopping = False
        self._serve_failures = 0
        with self._start_lock:
            self.bridge_password = self._read_password()
            self._refresh_identity()
            if self.signed_in and self.bridge_password:
                self._start_serve_locked()
            else:
                self.phase = "idle"
                self._show_idle()

    def write(self, data: str) -> bool:
        with self._write_lock:
            if self.phase == "auth" and self.running and self.fd is not None:
                try:
                    os.write(self.fd, data.encode("utf-8"))
                    return True
                except OSError:
                    return False
        line = data.replace("\r", "").replace("\n", "").strip()
        if line:
            self._handle_command(line)
        return True

    def text(self) -> str:
        with self.cond:
            return self.screen.text()

    def snapshot(self) -> dict:
        with self.cond:
            return {
                "version": self.version,
                "text": self.screen.text(),
                "running": self.running,
                "exit_code": self.exit_code,
                "uptime": int(time.time() - self.started_at)
                if self.running and self.started_at
                else 0,
                "settings_applying": False,
                "settings_error": self.settings_error,
                "implementation": "hydroxide",
                "settings": {
                    "imap_security": "ssl",
                    "smtp_security": "ssl",
                },
                "hydroxide": {
                    "phase": self.phase,
                    "signed_in": self.signed_in,
                    "password_available": bool(self.bridge_password),
                    "account": self.account,
                },
            }

    def wait_for_change(self, version: int, timeout: float) -> None:
        deadline = time.time() + timeout
        with self.cond:
            while self.version == version:
                remaining = deadline - time.time()
                if remaining <= 0:
                    return
                self.cond.wait(remaining)


OPTIONS = load_options()
apply_timezone(OPTIONS)
if OPTIONS["bridge_implementation"] == "hydroxide":
    BRIDGE = HydroxideBridge(OPTIONS)
else:
    BRIDGE = BridgeProcess(OPTIONS)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "ProtonBridgeAddon/1.2.2"

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003 - silence access log
        return

    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _json(self, payload: dict, status: int = 200) -> None:
        self._send(status, json.dumps(payload).encode("utf-8"), "application/json; charset=utf-8")

    def _read_json(self) -> dict:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return {}
        if length <= 0 or length > 65536:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            try:
                with open(os.path.join(APP_DIR, "index.html"), "rb") as handle:
                    body = handle.read()
            except OSError:
                self._send(500, b"index.html missing", "text/plain; charset=utf-8")
                return
            self._send(200, body, "text/html; charset=utf-8")
            return
        if parsed.path == "/health":
            self._send(200, b"ok", "text/plain; charset=utf-8")
            return
        if parsed.path == "/api/state":
            query = parse_qs(parsed.query)
            try:
                version = int(query.get("v", ["-1"])[0])
            except ValueError:
                version = -1
            try:
                timeout = float(query.get("timeout", ["20"])[0])
            except ValueError:
                timeout = 20.0
            BRIDGE.wait_for_change(version, max(0.0, min(timeout, 25.0)))
            self._json(BRIDGE.snapshot())
            return
        self._send(404, b"not found", "text/plain; charset=utf-8")

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        parsed = urlparse(self.path)
        if parsed.path == "/api/input":
            if BRIDGE.settings_applying:
                self._json({"ok": False, "error": "applying settings"}, 409)
                return
            payload = self._read_json()
            data = payload.get("data")
            if not isinstance(data, str) or not data:
                self._json({"ok": False, "error": "no input"}, 400)
                return
            if len(data) > 4096:
                self._json({"ok": False, "error": "input too large"}, 413)
                return
            self._json({"ok": BRIDGE.write(data)})
            return
        if parsed.path == "/api/restart":
            threading.Thread(target=BRIDGE.restart, daemon=True).start()
            self._json({"ok": True})
            return
        self._send(404, b"not found", "text/plain; charset=utf-8")


def main() -> None:
    BRIDGE.start()
    server = ThreadingHTTPServer(("0.0.0.0", WEB_PORT), Handler)
    server.daemon_threads = True

    def shutdown(_signum, _frame):
        log("shutting down")
        threading.Thread(target=BRIDGE.stop, daemon=True).start()
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    log(f"web terminal listening on port {WEB_PORT}")
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        BRIDGE.stop()
        log("stopped")


if __name__ == "__main__":
    main()
