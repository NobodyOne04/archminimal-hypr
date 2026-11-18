// Notification state shared by the popups, the bar and the notification center (ADR-0011):
// do not disturb, the session history and which entries are popped up.
//
// history: newest first, at most Theme.notifyHistory snapshots (key, app, summary, body, icon,
// critical, time), in memory only. live: key -> Notification while the app still holds it, so
// actions keep working after the popup has gone. Values are replaced, never mutated in place,
// so bindings see every change.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: st

    property bool dnd: false
    property bool panelOpen: false
    property var history: []
    property var popups: []          // snapshots currently popped up, oldest first
    property var live: ({})
    property int unread: 0
    property int nextKey: 1

    onPanelOpenChanged: if (panelOpen) unread = 0

    function iconOf(n) {
        return n.image !== "" ? n.image
            : n.appIcon !== "" ? Quickshell.iconPath(n.appIcon, true)
            : n.desktopEntry !== "" ? Quickshell.iconPath(n.desktopEntry, true) : ""
    }

    function add(n) {
        const e = {
            key: nextKey++, transient: n.transient,
            app: n.appName || "notification", summary: n.summary, body: n.body, icon: iconOf(n),
            critical: n.urgency === NotificationUrgency.Critical, time: new Date()
        }
        live = Object.assign({}, live, { [e.key]: n })
        n.closed.connect(() => st.closed(e.key))

        // transient = the app asked not to be kept: popup only, expired when the popup goes
        if (!e.transient) {
            const h = [e].concat(history)
            history = h.slice(0, Theme.notifyHistory)
            // over the cap: the oldest go, and their apps hear they expired
            for (const old of h.slice(Theme.notifyHistory)) expire(old.key)
            if (!panelOpen) unread++
        }

        if (dnd && !e.critical) {                           // recorded, but no popup
            if (e.transient) expire(e.key)
            return
        }
        popups = popups.concat([e])
        while (popups.length > Theme.notifyMax) unpop(popups[0].key)
    }

    // the app (or we) closed it: keep the text, drop the live object and its popup
    function closed(key) {
        if (!(key in live)) return
        const l = Object.assign({}, live)
        delete l[key]
        live = l
        popups = popups.filter(e => e.key !== key)
    }

    function expire(key) { const n = live[key]; if (n) n.expire() }
    function dismiss(key) { const n = live[key]; if (n) n.dismiss() }

    function unpop(key) {
        const e = popups.find(x => x.key === key)
        popups = popups.filter(x => x.key !== key)
        if (e && e.transient) expire(key)
    }
    function hidePopups() { for (const e of popups.slice()) unpop(e.key) }

    function remove(key) {
        history = history.filter(x => x.key !== key)
        popups = popups.filter(x => x.key !== key)
        dismiss(key)
    }

    function clearAll() {
        const keys = Object.keys(live).map(Number).filter(k => !popups.some(e => e.key === k && e.transient))
        history = []
        popups = popups.filter(e => e.transient)
        unread = 0
        for (const k of keys) dismiss(k)
    }

    // run an action (or the default one) while the app still holds the notification
    function act(key, action) {
        const n = live[key]
        if (!n) return
        const a = action || n.actions.find(x => x.identifier === "default")
        if (a) a.invoke()
    }
}
