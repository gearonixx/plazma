#pragma once

#include <QtGlobal>

// SpeedMeter
// ──────────
// Samples a monotonically-growing byte counter and reports an EMA-smoothed
// throughput in bytes / second. Designed for download-progress meters where
// the source delivers bytes in unevenly-sized chunks at unpredictable times,
// and the consumer wants a steady speed reading (no flicker between 0 and a
// burst value) plus an ETA.
//
// The instantaneous-rate calculation runs at most once per `kSampleMinMs`
// (caller-tuneable via the constructor). Below that interval the new bytes
// just accumulate against the existing window — calling tick() too often is
// cheap and produces no spurious noise.
//
// Lifecycle: cheap value type, copyable, no Qt object overhead. The wall
// clock is held internally as a millisecond counter the caller passes in
// (typically QElapsedTimer::elapsed()), so the meter doesn't depend on any
// particular time source — easier to test, easier to relocate to a thread.
class SpeedMeter {
public:
    explicit SpeedMeter(int sampleMinMs = 300, double emaAlpha = 0.30) noexcept
        : sampleMinMs_(sampleMinMs), alpha_(emaAlpha) {}

    // Reset to a fresh state, optionally seeding the byte counter so that a
    // resumed transfer doesn't report an artificial speed spike from the
    // already-on-disk bytes.
    void reset(qint64 seedBytes = 0) noexcept {
        speedBps_ = 0.0;
        lastSampleMsec_ = 0;
        lastSampleBytes_ = seedBytes;
        seededBytes_ = seedBytes;
    }

    // Feed a fresh observation: total bytes received so far + the wall-clock
    // millisecond reading. Returns true if the EMA was updated this call
    // (caller can use that to decide whether the UI is worth refreshing).
    bool tick(qint64 totalReceived, qint64 nowMsec) noexcept {
        if (lastSampleMsec_ == 0) {
            lastSampleMsec_ = nowMsec;
            lastSampleBytes_ = totalReceived;
            return false;
        }
        const auto dt = nowMsec - lastSampleMsec_;
        if (dt < sampleMinMs_) return false;

        const auto db = totalReceived - lastSampleBytes_;
        const double inst = (db > 0 && dt > 0)
            ? static_cast<double>(db) * 1000.0 / static_cast<double>(dt)
            : 0.0;

        if (speedBps_ <= 0.0) {
            speedBps_ = inst;
        } else {
            speedBps_ = alpha_ * inst + (1.0 - alpha_) * speedBps_;
        }
        lastSampleMsec_ = nowMsec;
        lastSampleBytes_ = totalReceived;
        return true;
    }

    [[nodiscard]] double bytesPerSecond() const noexcept { return speedBps_; }

    // Seconds until completion, or -1 when unknown (no total, or speed not
    // yet converged). 0 means "any moment now".
    [[nodiscard]] qint64 etaSec(qint64 totalReceived, qint64 totalBytes) const noexcept {
        if (totalBytes <= 0 || speedBps_ <= 0.0) return -1;
        const auto remaining = totalBytes - totalReceived;
        if (remaining <= 0) return 0;
        return static_cast<qint64>(static_cast<double>(remaining) / speedBps_);
    }

private:
    int sampleMinMs_;
    double alpha_;

    double speedBps_ = 0.0;
    qint64 lastSampleMsec_ = 0;
    qint64 lastSampleBytes_ = 0;
    qint64 seededBytes_ = 0;
};
