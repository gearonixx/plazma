#pragma once

#include <QObject>
#include <QString>
#include <memory>

#include "src/settings.h"

// SettingsModel
// ─────────────
// Thin QML-facing facade over `Settings`. Owns no state of its own — every
// getter delegates to Settings, every setter pushes into Settings and lets
// the persistence layer fire the change notification we re-emit here.
//
// Exists so QML can bind to scalar properties (downloadPath,
// effectiveDownloadPath, …) instead of calling Q_INVOKABLE getters; mirrors
// how LanguageModel wraps the language slice.
//
// Folder selection is performed natively via QFileDialog so the user gets
// the platform's own picker (Win32 IFileDialog, NSOpenPanel, GTK on Linux),
// matching tdesktop's Core::FileDialog flow.
class SettingsModel : public QObject {
    Q_OBJECT

    // Raw user override. Empty string means "use platform default" — kept as
    // a separate property so the dialog can render an "is default" affordance
    // without parsing the path.
    Q_PROPERTY(QString downloadPath READ downloadPath NOTIFY downloadPathChanged)
    // Resolved path: the override if set, else defaultDownloadPath. This is
    // the value the next started download will actually use.
    Q_PROPERTY(QString effectiveDownloadPath READ effectiveDownloadPath NOTIFY downloadPathChanged)
    // Platform default: ~/Videos/Plazma on Linux/macOS, %USERPROFILE%\Videos\Plazma
    // on Windows. Resolved fresh each call so it tracks XDG dir changes.
    Q_PROPERTY(QString defaultDownloadPath READ defaultDownloadPath NOTIFY downloadPathChanged)
    Q_PROPERTY(bool usingDefaultDownloadPath READ usingDefaultDownloadPath NOTIFY downloadPathChanged)

public:
    explicit SettingsModel(std::shared_ptr<Settings> settings, QObject* parent = nullptr);

    [[nodiscard]] QString downloadPath() const;
    [[nodiscard]] QString effectiveDownloadPath() const;
    [[nodiscard]] QString defaultDownloadPath() const;
    [[nodiscard]] bool    usingDefaultDownloadPath() const;

public slots:
    // Open the native folder picker, validate the choice, and persist on
    // success. Returns the chosen path on success; an empty string on
    // cancel or validation failure (in which case downloadPathError is also
    // emitted with a localized reason).
    Q_INVOKABLE QString chooseDownloadFolder();

    // Switch back to the platform default by clearing the override.
    Q_INVOKABLE void resetDownloadPath();

    // Reveal the current effective folder in the system file manager.
    // Creates the directory tree first so a fresh install can preview the
    // location even before the first download.
    Q_INVOKABLE void revealDownloadFolder();

signals:
    void downloadPathChanged();
    // Emitted when the picked folder fails validation (doesn't exist, not
    // writable, etc.). The dialog binds to this to surface an inline error
    // rather than silently letting the next download fail.
    void downloadPathError(const QString& reason);

private:
    std::shared_ptr<Settings> settings_;
};
