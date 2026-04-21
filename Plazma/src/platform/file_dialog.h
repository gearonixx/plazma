#pragma once

#include <QByteArray>
#include <QFileDialog>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QWidget>

#include "../core/file_utilities.h"
#include "src/api.h"
#include "src/storage/prepare.h"
#include "src/storage/task_queue.h"

namespace platform {

struct DialogResult final {
    QStringList paths;
    QByteArray remoteContent;
};

using ResultCb = Fn<void(const DialogResult& result)>;

enum class Type {
    ReadFile,
    ReadFiles,
    ReadFolder,
    WriteFile,
};

bool GetFileDialog(
    QPointer<QWidget> parent,
    QStringList& files,
    QByteArray& remoteContent,
    const QString& caption,
    const QString& filter,
    Type type
);

class FileDialog : public QObject {
    Q_OBJECT

public:
    explicit FileDialog(Api* api, QObject* parent = nullptr);
    ~FileDialog();

signals:
    void pathsPicked(const QStringList& paths);

public:
    void GetOpenPaths(
        QPointer<QWidget> parent,
        const QString& caption,
        const QString& filter,
        ResultCb callback,
        Fn<void()> failed
    );

    void prepareFileTasks(
        storages::prepare::PreparedList&& bundle,
        plazma::task_queue::SendMediaType type = plazma::task_queue::SendMediaType::File
    );

    void attachFiles(plazma::task_queue::SendMediaType type = plazma::task_queue::SendMediaType::File);

private:
    Api* api_ = nullptr;
};

}  // namespace platform

namespace Platform::FileDialog {

inline bool Get(
    QPointer<QWidget> parent,
    QStringList& files,
    QByteArray& /*remoteContent*/,
    const QString& caption,
    const QString& /*filter*/,
    platform::Type type,
    const QString& startFile
) {
    QFileDialog dialog(parent, caption, startFile);
    dialog.setNameFilters(
        {QObject::tr("Video files") + " (*.mp4 *.mkv *.avi *.mov *.webm *.flv *.wmv *.m4v *.ts)",
         QObject::tr("All files") + " (*)"}
    );
    dialog.setFileMode(type == platform::Type::ReadFiles ? QFileDialog::ExistingFiles : QFileDialog::ExistingFile);

    if (dialog.exec() != QDialog::Accepted) return false;
    files = dialog.selectedFiles();
    return !files.isEmpty();
}

}  // namespace Platform::FileDialog
