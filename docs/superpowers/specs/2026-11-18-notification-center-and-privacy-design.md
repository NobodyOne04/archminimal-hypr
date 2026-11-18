# Notification center + mic/camera kill switches

Date: 2026-11-18 · Repo: `archminimal-hypr` · Status: draft, awaiting approval

## Why

Two things the bar can't do today:
- **Notifications vanish.** A popup expires after `Theme.notifyTimeout` and it's gone; under do not disturb
  it's dropped unseen. I want a list I can look back at, act on and clear.
- **No privacy switch.** I want one click to cut the mic and the camera, and to trust that the camera is
  really off, not just hidden from some apps.

The rest of the bar polish ideas (workspace icons, window switcher, calm stats, clock extras,
fullscreen hide) are deferred to a later round.

## Goals
1. A notification center: a panel listing every notification this session, newest first, with
   clear one / clear all, actions while the app still offers them, and a DND switch.
2. An unread count on the bar that opens the panel.
3. A mic switch: mutes every audio input, including ones plugged in later, until switched back.
4. A camera switch that is **hard off**: the kernel driver is unloaded and blocked from loading, so no
   app can reach the camera, whatever API it uses. (Chosen over a PipeWire-only block.)
5. Bar modules for both switches, IPC calls, and keys.

## Non-goals
- Saving notification history to disk or across shell restarts / logouts.
- Showing which app is using the mic or camera (separate idea, later).
- Covering cameras not driven by `uvcvideo` (e.g. Intel IPU6 MIPI cameras): noted as a limit.
- Any of the deferred polish items.

## Anti-goals (a failure even if it works)
- The camera switch says "off" while the camera still works.
- Any root step that runs without me confirming it (`make install` with sudo is a confirmed step;
  silent sudo prompts at shell start are not).
- Breaking "light by design" (ADR-0004): no polling process spawned per tick, popups exist only while shown.
- Shell text spliced into commands; root helper that takes arbitrary arguments.
- Clutter: the bar stays quiet when nothing needs attention.

## Constraints
- Quickshell, one process (ADR-0003); settings and colours in `Theme.qml`; archminimal look
  (`#00e5ff` accent, `Theme.panel`, monospace, lowercase, `Kv` rows in tips).
- ADR-0003 says "no history panel by design": this reverses that, so ADR-0003 is updated (or a new ADR
  supersedes that line) **before** the code. The root camera helper is a new decision: new ADR.
- Commands from QML via `Quickshell.execDetached([...])` / `Process` with argument arrays.
- Every new bind has a `"group: what"` description (ADR-0009); check clashes with existing binds,
  nvim, tmux and Ghostty before choosing keys.
- README tables updated in the same PR; `CHANGELOG.md` line; `make lint` clean; tried on the VM.
- The VM may have no camera: the camera module must cope with "no camera".

## Design

### Notification center
- **History store** (`NotifyState.qml`, extended): an array of snapshots
  `{ id, app, summary, body, icon, urgency, time, live }`, newest first, capped at
  `Theme.notifyHistory` (new setting, 50). In memory only. `unread` count = entries added since the panel
  was last opened.
- **Every incoming notification is recorded**, including those DND hides. DND still suppresses the
  popup (critical ones still pop, as today). *Changes today's behaviour, where DND drops them entirely.*
- **Popups** keep working as now (timeout, hover, click, right-click, `Theme.notifyMax`).
- **Actions:** while the app still holds the notification (`live`), the panel shows its default action
  and buttons; once it's expired or dismissed, the entry is plain text. The builder picks how to keep
  the live object reachable (e.g. keep it tracked after the popup hides, with a separate "popup shown"
  flag), as long as expiry is still reported to the app.
- **Panel:** opens under the bar at the right edge of that monitor, same frame as notification cards
  (`Theme.panel`, accent rule, corner look). Header: `sys::notifications`, count, `dnd on/off`, `clear all`.
  Rows: app · relative time (`2m`, `1h`), summary, body (clipped to a few lines), action buttons if live,
  `×` to clear the row. Click a row = default action if live. Empty state: one dim line.
  Closes on Escape, clicking outside, or the bar module again. Exists only while open.
- **Bar module** `ntf`: value = unread count, accent when > 0; hidden when history is empty and DND is
  off. The existing `dnd` module folds into it (shows `dnd` while on). Left click = panel, right click = DND.
- **IPC** (`notifications` target): keep `clear` (dismiss popups) and `dnd`; add `panel` (toggle),
  `clearAll` (empty history).

### Mic switch
- New singleton `Privacy.qml` with `micOff` and `camOff`.
- `micOff = true` mutes every PipeWire audio source node (not monitors of sinks, not app streams);
  while on, any new source that appears is muted too. `micOff = false` unmutes the sources it muted.
- At start, `micOff` is read back from PipeWire (true if every source is muted), since WirePlumber
  remembers mute state across restarts; the shell keeps no state of its own.

### Camera switch (hard off)
- **Root helper** `bin/archminimal-camera` installed to `/usr/local/bin/` (root-owned, 755), args
  `on | off | status` only, anything else exits non-zero.
  - `off`: writes `/etc/modprobe.d/archminimal-camera.conf` with `install uvcvideo /bin/false`
    (blocks loading, also for hot-plugged USB cameras, and survives reboot), then `modprobe -r uvcvideo`.
    If the driver is in use, it fails with "camera in use", the file is removed again, and state stays on.
  - `on`: removes the file, `modprobe uvcvideo`.
  - `status`: prints `off` (file present), `on` (driver loaded), or `none` (no file, driver not loaded and
    no `/dev/video*`).
- **Polkit rule** `/etc/polkit-1/rules.d/50-archminimal-camera.rules`: members of `wheel` may run exactly
  that program through `pkexec` without a password. Nothing else.
- **Install:** a new `make privacy` target (sudo, asks first; listed in `make help` and README), so
  plain `make install` stays rootless. `make check` reports whether the helper and rule are installed.
- **Shell:** `Privacy.qml` runs `status` once at start and after each toggle (no polling). Toggle runs
  `pkexec /usr/local/bin/archminimal-camera off|on`; on failure, a notification says why.
  If the helper isn't installed, the camera module is hidden.
- *State persists across reboot* (my call: a privacy switch that silently turns back on is worse).

### Bar
- One module right of `bt`: label `priv`, value e.g. `mic · cam`, each word dim when on and accent when
  switched off; tip lists `mic on/off`, `camera on/off/none/in use`, and the click hints.
  Left click mic, right click camera (my call; builder may use two modules if it reads better).
- **Keys** (proposal, check clashes): `Super+Shift+M` mic, `Super+Shift+C` camera;
  `Super+Alt+N` notification panel.
- **IPC** `privacy mic | cam | status`.

## Left to the builder
- Exact layout, spacing, animations of the panel, within the look.
- How live notification objects are kept for actions (see above).
- Two bar modules vs one, if one turns out cramped.
- Final key choices after the clash check.

## My calls (please check)
- DND notifications go into the history (silently).
- Camera "off" survives reboot; mic follows whatever WirePlumber remembers.
- Root setup is its own `make privacy` target, not part of `make install`.
- `uvcvideo` only.
