#include "file_dialog_model.h"

FileDialogModel::FileDialogModel(platform::FileDialog* fileDialog, QObject* parent)
    : QObject(parent), fileDialog_(fileDialog) {
    Q_ASSERT(fileDialog != nullptr);

    connect(fileDialog_, &platform::FileDialog::pathsPicked, this, [this](const QStringList& paths) {
        selectedPaths_ = paths;
        emit pathsChanged();
        if (!paths.isEmpty()) emit fileSelected(paths.first());
    });
}

QStringList FileDialogModel::selectedPaths() const { return selectedPaths_; }

void FileDialogModel::openFilePicker() { fileDialog_->attachFiles(plazma::task_queue::SendMediaType::Video); }
