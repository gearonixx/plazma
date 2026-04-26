#pragma once

#include "src/ui/widgets/rp_widget.h"

#include <QPointer>

class Session;
class LanguageModel;
class PhoneNumberModel;
class PageController;

namespace Ui {

class FlatLabel;
class RoundButton;
class IconButton;

// PageStart — landing page. Two-panel layout: brand on the left, primary
// "Start Watching" CTA on the right. Mirrors the QML version 1:1 visually
// but uses our new C++ widget primitives (RoundButton, FlatLabel,
// IconButton with ripple/hover transitions).
class PageStart : public RpWidget {
    Q_OBJECT

public:
    PageStart(
        QWidget *parent,
        Session *session,
        LanguageModel *languages,
        PhoneNumberModel *phones,
        PageController *pages);

protected:
    void paintEvent(QPaintEvent *e) override;
    void resizeEvent(QResizeEvent *e) override;

private:
    void layoutChildren();
    void rebindFromSession();
    void onLanguageToggleClicked();
    void onStartClicked();

    Session          *_session   = nullptr;
    LanguageModel    *_languages = nullptr;
    PhoneNumberModel *_phones    = nullptr;
    PageController   *_pages     = nullptr;

    QPointer<IconButton>  _langButton;
    QPointer<FlatLabel>   _brandTitle;
    QPointer<FlatLabel>   _brandSubtitle;
    QPointer<FlatLabel>   _ctaTitle;
    QPointer<FlatLabel>   _ctaSubtitle;
    QPointer<RoundButton> _startButton;
    QPointer<FlatLabel>   _errorLabel;
};

} // namespace Ui
