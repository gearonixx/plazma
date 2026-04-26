pragma Singleton

import QtQuick

// TdNotifications — singleton toast manager. Mirrors the role of
// `Ui::Toast::Show` (lib_ui/ui/toast/toast.cpp). Stacks toasts at the
// bottom of the attached host item, animates them in/out, and limits
// concurrent count.
//
// Usage:
//   TdNotifications.attach(rootItem)
//   TdNotifications.info("Saved")
//   TdNotifications.success("Uploaded 3 files")
//   TdNotifications.error("Network failure")

QtObject {
    id: manager

    property Item host: null
    property int  maxConcurrent: 3
    property var  active: []

    function attach(item) {
        host = item;
    }

    function info(text)    { return _push(text, 0) }
    function success(text) { return _push(text, 1) }
    function error(text)   { return _push(text, 2) }

    function _push(text, state) {
        if (!host) {
            console.warn("TdNotifications: not attached. Call TdNotifications.attach(root) first.");
            return null;
        }
        if (active.length >= maxConcurrent) {
            const oldest = active.shift();
            if (oldest) oldest.destroy();
        }

        const comp = Qt.createComponent('qrc:/ui/Modules/Td/TdToast.qml');
        if (comp.status === Component.Error) {
            console.warn("TdNotifications: TdToast missing:", comp.errorString());
            return null;
        }
        const t = comp.createObject(host, { text: text, state_: state });
        if (!t) return null;
        t.parent = host;
        t.anchors.horizontalCenter = host.horizontalCenter;
        t.anchors.bottom = host.bottom;
        t.anchors.bottomMargin = 24 + active.length * (t.height + 8);
        active.push(t);
        t.closed.connect(function () { _remove(t) });
        return t;
    }

    function _remove(t) {
        const i = active.indexOf(t);
        if (i >= 0) active.splice(i, 1);
        t.destroy();
        // restack remaining
        for (let k = 0; k < active.length; ++k) {
            active[k].anchors.bottomMargin = 24 + k * (active[k].height + 8);
        }
    }
}
