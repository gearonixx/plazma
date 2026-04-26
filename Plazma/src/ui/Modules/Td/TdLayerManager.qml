pragma Singleton

import QtQuick

// TdLayerManager — singleton modal stack manager. Mirrors the role of
// `Window::Controller::show(Layer)` / `LayerStackWidget` in tdesktop.
//
// Use:
//   TdLayerManager.attach(rootItem)        // once, on app startup
//   TdLayerManager.show(component, props)  // push a layer (component is a QML
//                                          // Component or url to a .qml file)
//   TdLayerManager.hide()                  // pop top layer
//   TdLayerManager.hideAll()               // close everything
//
// Each pushed layer is instantiated as a child of the attached host Item
// at `z = TdStyle.z.layer + depth`. The manager exposes `topLayer` so
// callers can react to stack changes.

QtObject {
    id: manager

    property Item host: null
    property var stack: []                     // array of created Item layers
    property Item topLayer: null

    function attach(item) {
        host = item;
    }

    function show(componentOrUrl, props) {
        if (!host) {
            console.warn("TdLayerManager: not attached. Call TdLayerManager.attach(root) first.");
            return null;
        }
        let comp;
        if (typeof componentOrUrl === 'string') {
            comp = Qt.createComponent(componentOrUrl);
        } else {
            comp = componentOrUrl;
        }
        if (!comp) return null;
        if (comp.status === Component.Error) {
            console.warn("TdLayerManager: component error:", comp.errorString());
            return null;
        }

        const finalProps = props || {};
        const layer = comp.createObject(host, finalProps);
        if (!layer) {
            console.warn("TdLayerManager: failed to instantiate layer");
            return null;
        }
        layer.parent = host;
        layer.anchors.fill = host;
        layer.z = 900 + stack.length;
        stack.push(layer);
        topLayer = layer;
        if (typeof layer.show === 'function') layer.show();
        if (layer.closed && typeof layer.closed.connect === 'function') {
            layer.closed.connect(function () { manager.hideLayer(layer) });
        }
        return layer;
    }

    function hide() {
        if (stack.length === 0) return;
        const top = stack[stack.length - 1];
        hideLayer(top);
    }

    function hideLayer(layer) {
        const idx = stack.indexOf(layer);
        if (idx < 0) return;
        stack.splice(idx, 1);
        topLayer = stack.length > 0 ? stack[stack.length - 1] : null;
        if (typeof layer.hide === 'function' && layer.open) layer.hide();
        // Defer destruction so the close animation can run
        const t = Qt.createQmlObject(
            'import QtQuick; Timer { interval: 400; repeat: false; running: true }',
            manager, 'TdLayerDestroyTimer');
        t.triggered.connect(function () { layer.destroy(); t.destroy() });
    }

    function hideAll() {
        while (stack.length > 0) hide();
    }
}
