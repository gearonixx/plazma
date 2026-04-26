#include "settings_model.h"

#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QUrl>

#include "src/storage/download_paths.h"

namespace paths = plazma::download_paths;

SettingsModel::SettingsModel(std::shared_ptr<Settings> settings, QObject* parent)
    : QObject(parent), settings_(std::move(settings)) {
    Q_ASSERT(settings_);

    // Settings is the single source of truth; relay its change notification
    // outward so QML bindings on `downloadPath` / `effectiveDownloadPath`
    // re-evaluate without a manual refresh.
    connect(settings_.get(), &Settings::downloadPathChanged,
            this, &SettingsModel::downloadPathChanged);
}

QString SettingsModel::downloadPath() const {
    return settings_->getDownloadPath();
}

QString SettingsModel::effectiveDownloadPath() const {
    const auto raw = settings_->getDownloadPath();
    return raw.isEmpty() ? paths::defaultRoot() : raw;
}

QString SettingsModel::defaultDownloadPath() const {
    return paths::defaultRoot();
}

bool SettingsModel::usingDefaultDownloadPath() const {
    return settings_->getDownloadPath().isEmpty();
}

QString SettingsModel::chooseDownloadFolder() {
    // Seed the dialog with the current effective folder so the picker opens
    // somewhere familiar. Make sure it exists so the native dialog doesn't
    // silently fall back to the user's home directory.
    const auto seed = effectiveDownloadPath();
    QDir().mkpath(seed);

    const auto picked = QFileDialog::getExistingDirectory(
        nullptr,
        tr("Choose download folder"),
        seed,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );
    if (picked.isEmpty()) return {};   // user cancelled

    const QFileInfo info(picked);
    if (!info.exists() || !info.isDir()) {
        emit downloadPathError(tr("That folder doesn't exist."));
        return {};
    }
    if (!info.isWritable()) {
        emit downloadPathError(tr("Plazma can't write to that folder."));
        return {};
    }

    // Fold a redundant pick of the platform default back into the "default"
    // sentinel, so flipping to and from the OS default is a true no-op
    // rather than freezing today's path into QSettings.
    const auto normalized = QDir::cleanPath(picked);
    if (normalized == QDir::cleanPath(paths::defaultRoot())) {
        settings_->setDownloadPath(QString());
    } else {
        settings_->setDownloadPath(normalized);
    }
    return effectiveDownloadPath();
}

void SettingsModel::resetDownloadPath() {
    settings_->setDownloadPath(QString());
}

void SettingsModel::revealDownloadFolder() {
    const auto path = effectiveDownloadPath();
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}
