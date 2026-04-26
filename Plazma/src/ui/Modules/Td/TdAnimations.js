// TdAnimations — JS analogue of `Ui::Animations::Simple` from
// Telegram Desktop's lib_ui/ui/effects/animations.h.
//
// Pattern:
//   const anim = Td.Anim.simple(duration, easing)
//   anim.start(item, fromValue, toValue, onValue, onFinish)
//   anim.value()    // current eased value
//   anim.stop()
//
// Internally backed by a property animation on a hidden QtObject; we only
// drive a `t` (0..1) and project it through the easing curve into the
// caller's value range. This matches the Simple-animation contract in
// tdesktop where the caller owns the *meaning* of the value.

.pragma library

function _ease(curve, t) {
    // Subset of QtQuick easing curves we use most often. The arg matches
    // Easing.OutCubic etc. (integer enum values from QtQuick).
    switch (curve) {
    case 5:  return 1 - Math.pow(1 - t, 2);                      // OutQuad
    case 7:  return 1 - Math.pow(1 - t, 3);                      // OutCubic
    case 9:  return 1 - Math.pow(1 - t, 4);                      // OutQuart
    case 11: return 1 - Math.pow(1 - t, 5);                      // OutQuint
    case 13: return Math.sin((t * Math.PI) / 2);                 // OutSine
    case 6:  return -t * (t - 2);                                // alt OutQuad
    default: return 1 - Math.pow(1 - t, 3);                      // default OutCubic
    }
}

function simple(duration, easing) {
    var state = {
        running: false,
        from: 0,
        to: 0,
        startedAt: 0,
        duration: duration || 120,
        easing: (easing === undefined) ? 7 : easing,
        cur: 0,
        timer: null,
        onValue: null,
        onFinish: null
    };

    function tick() {
        if (!state.running) return;
        var now = Date.now();
        var elapsed = now - state.startedAt;
        var t = (state.duration <= 0) ? 1 : Math.min(1, elapsed / state.duration);
        var eased = _ease(state.easing, t);
        state.cur = state.from + (state.to - state.from) * eased;
        if (state.onValue) state.onValue(state.cur);
        if (t >= 1) {
            state.running = false;
            if (state.timer) { state.timer.stop(); state.timer.destroy(); state.timer = null; }
            if (state.onFinish) state.onFinish();
        }
    }

    function start(host, from, to, onValue, onFinish) {
        state.from = from;
        state.to = to;
        state.cur = from;
        state.startedAt = Date.now();
        state.running = true;
        state.onValue = onValue || null;
        state.onFinish = onFinish || null;
        if (state.onValue) state.onValue(state.cur);
        if (!state.timer) {
            state.timer = Qt.createQmlObject(
                'import QtQuick; Timer { interval: 16; repeat: true; running: true }',
                host || Qt.application,
                'TdAnimSimpleTimer');
            state.timer.triggered.connect(tick);
        } else {
            state.timer.restart();
        }
    }

    function stop() {
        state.running = false;
        if (state.timer) { state.timer.stop(); state.timer.destroy(); state.timer = null; }
    }

    function value() { return state.cur; }
    function isRunning() { return state.running; }

    return {
        start: start,
        stop: stop,
        value: value,
        isRunning: isRunning,
        setDuration: function (d) { state.duration = d; },
        setEasing:   function (e) { state.easing = e; }
    };
}
