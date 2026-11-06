// Session lock: the same screen as the login greeter (../../sddm-login/greeter),
// drawn on every monitor through ext-session-lock and unlocked with PAM.
//
//   qs -c archminimal ipc call lock lock      (hypridle's lock_cmd)
//
// If quickshell dies while locked the session stays locked (Hyprland shows its
// fallback screen); restart with `qs -c archminimal` and it locks again.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: session

    readonly property string user: Quickshell.env("USER")

    // Shared by every monitor, so typing on one shows on all.
    property string password: ""
    property bool busy: false
    property bool failed: false
    property string failMsg: ""
    property string pending: ""
    property int failCount: 0          // bumped on every failure, drives the shake

    function lockNow() {
        if (sessionLock.locked)
            return
        password = ""
        failed = false
        busy = false
        sessionLock.locked = true
    }

    function submit() {
        if (busy || password === "")
            return
        pending = password
        busy = true
        failed = false
        if (!pam.start())
            fail("pam unavailable")
    }

    function fail(message) {
        busy = false
        pending = ""
        password = ""
        failMsg = message
        failed = true
        failCount++
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            color: "#28292d"
            LockScreen { anchors.fill: parent; lock: session }
        }
    }

    PamContext {
        id: pam
        user: session.user
        // same stack hyprlock used (auth include login)
        config: "hyprlock"

        onResponseRequiredChanged: {
            if (!responseRequired)
                return
            respond(session.pending)
            session.pending = ""
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                session.busy = false
                session.password = ""
                session.failed = false
                sessionLock.locked = false
            } else {
                session.fail("")
            }
        }

        onError: error => session.fail("pam: " + PamError.toString(error))
    }

    IpcHandler {
        target: "lock"
        function lock(): void { session.lockNow() }
        function isLocked(): bool { return sessionLock.locked }
    }
}
