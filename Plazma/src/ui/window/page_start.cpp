#include "src/ui/window/page_start.h"

#include "src/controllers/pageController.h"
#include "src/models/language_model.h"
#include "src/models/phone_number_model.h"
#include "src/session.h"

#include "src/ui/painting/painter.h"
#include "src/ui/style/style_palette.h"
#include "src/ui/style/style_widgets.h"
#include "src/ui/widgets/buttons.h"
#include "src/ui/widgets/labels.h"

#include <QPaintEvent>
#include <QResizeEvent>

namespace Ui {

namespace {

constexpr int kMinSplitWidth   = 780;
constexpr int kSplitLeftRatio  = 42;     // percent of the canvas
constexpr int kCtaMaxWidth     = 300;
constexpr int kBrandLogoSize   = 88;
constexpr int kErrorPadding    = 8;
constexpr int kErrorHeight     = 56;

} // namespace

PageStart::PageStart(
    QWidget *parent,
    Session *session,
    LanguageModel *languages,
    PhoneNumberModel *phones,
    PageController *pages)
: RpWidget(parent)
, _session(session)
, _languages(languages)
, _phones(phones)
, _pages(pages) {

    // ── Top-left language toggle (the 🌐 button in the QML) ─────────
    style::IconButton langSt = style::st::iconButton();
    langSt.iconText = QStringLiteral("🌐");
    langSt.iconFont = style::font(18, QFont::Normal);
    _langButton = new IconButton(this, langSt);
    _langButton->setClickedCallback([this] { onLanguageToggleClicked(); });

    // ── Brand panel ──────────────────────────────────────────────────
    _brandTitle = new FlatLabel(this,
        tr("Plazma"),
        style::FlatLabel{
            .textFont = style::font(26, QFont::Bold),
            .textFg   = style::palette().windowFg,
            .align    = Qt::AlignHCenter | Qt::AlignVCenter,
        });
    _brandSubtitle = new FlatLabel(this,
        tr("Your private video feed,\npowered by Telegram"),
        style::FlatLabel{
            .textFont = style::font(13, QFont::Normal),
            .textFg   = style::palette().windowSubTextFg,
            .lineHeight = 20,
            .align    = Qt::AlignHCenter | Qt::AlignVCenter,
        });

    // ── CTA panel ────────────────────────────────────────────────────
    _ctaTitle = new FlatLabel(this,
        tr("Get started"),
        style::FlatLabel{
            .textFont = style::font(20, QFont::Bold),
            .textFg   = style::palette().windowFg,
            .align    = Qt::AlignHCenter | Qt::AlignVCenter,
        });
    _ctaSubtitle = new FlatLabel(this,
        tr("Connect with your Telegram\naccount to start watching"),
        style::FlatLabel{
            .textFont = style::font(13, QFont::Normal),
            .textFg   = style::palette().windowSubTextFg,
            .lineHeight = 20,
            .align    = Qt::AlignHCenter | Qt::AlignVCenter,
        });

    _startButton = new RoundButton(this,
        tr("Start Watching"),
        style::st::primaryButton());
    _startButton->setClickedCallback([this] { onStartClicked(); });

    // ── Error banner — hidden until Session reports a failure ────────
    _errorLabel = new FlatLabel(this,
        QString(),
        style::FlatLabel{
            .textFont = style::font(12, QFont::Normal),
            .textFg   = style::color(QStringLiteral("#842029")),
            .padding  = QMargins(10, 10, 10, 10),
            .align    = Qt::AlignLeft | Qt::AlignVCenter,
        });
    _errorLabel->hide();

    // ── Live bindings ────────────────────────────────────────────────
    if (_session) {
        connect(_session, &Session::sessionChanged, this, &PageStart::rebindFromSession);
        connect(_session, &Session::errorChanged,   this, &PageStart::rebindFromSession);
    }
    if (_phones) {
        connect(_phones, &PhoneNumberModel::waitingForPhoneChanged,
                this, &PageStart::rebindFromSession);
    }
    if (_languages) {
        connect(_languages, &LanguageModel::translationsUpdated,
                this, [this] {
            _brandTitle->setText(tr("Plazma"));
            _brandSubtitle->setText(tr("Your private video feed,\npowered by Telegram"));
            _ctaTitle->setText(tr("Get started"));
            _ctaSubtitle->setText(tr("Connect with your Telegram\naccount to start watching"));
            _startButton->setText(tr("Start Watching"));
        });
    }

    rebindFromSession();
}

void PageStart::onLanguageToggleClicked() {
    if (!_languages) return;
    using L = LanguageSettings::AvailablePageEnum;
    const auto next = (_languages->getCurrentLanguageIndex() == 0)
        ? L::Russian
        : L::English;
    _languages->changeLanguage(next);
}

void PageStart::onStartClicked() {
    if (!_pages) return;
    _pages->goToPage(PageLoader::PageEnum::PageLogin);
}

void PageStart::rebindFromSession() {
    if (!_session) return;
    const auto err = _session->errorMessage();
    if (err.isEmpty()) {
        _errorLabel->hide();
        if (_startButton) _startButton->setDisabled(false);
    } else {
        _errorLabel->setText(tr("Login failed: %1").arg(err));
        _errorLabel->show();
        if (_startButton) _startButton->setDisabled(true);
    }
    layoutChildren();
}

void PageStart::paintEvent(QPaintEvent *) {
    Painter p(this);

    // Canvas
    p.fillRect(rect(), style::palette().windowBg);

    // Vertical divider between the brand and CTA panels.
    const auto leftWidth = (width() * kSplitLeftRatio) / 100;
    const QRect divider(leftWidth, 48, 1, height() - 96);
    p.fillRect(divider, style::palette().outlineFg);

    // Brand circle — soft lavender disc with a centered "P" glyph.
    const auto brandLeftCenter = QPoint(leftWidth / 2, height() / 2 - 90);
    const auto logoRect = QRect(
        brandLeftCenter.x() - kBrandLogoSize / 2,
        brandLeftCenter.y() - kBrandLogoSize / 2,
        kBrandLogoSize,
        kBrandLogoSize);
    {
        PainterHighQualityEnabler hq(p);
        p.setPen(Qt::NoPen);
        p.setBrush(style::palette().tintedBg.brush());
        p.drawEllipse(logoRect);
        p.setPen(style::palette().tintedFg.pen());
        QFont logoFont; logoFont.setPixelSize(38); logoFont.setBold(true);
        p.setFont(logoFont);
        p.drawText(logoRect, Qt::AlignCenter, QStringLiteral("P"));
    }

    // Error banner background — drawn here so it stays under the label text
    // (which is its own QWidget child).
    if (_errorLabel && _errorLabel->isVisible()) {
        const auto eb = _errorLabel->geometry().adjusted(-1, -1, 1, 1);
        PainterHighQualityEnabler hq(p);
        p.setPen(QPen(QColor(QStringLiteral("#F5C2C7"))));
        p.setBrush(QColor(QStringLiteral("#F8D7DA")));
        p.drawRoundedRect(eb, 8, 8);
    }
}

void PageStart::resizeEvent(QResizeEvent *e) {
    RpWidget::resizeEvent(e);
    layoutChildren();
}

void PageStart::layoutChildren() {
    if (width() <= 0 || height() <= 0) return;

    if (_langButton) {
        _langButton->move(14, 14);
    }

    const auto leftWidth = (width() * kSplitLeftRatio) / 100;

    // Brand panel — title sits below the painted logo, subtitle below it.
    const auto brandCenterX = leftWidth / 2;
    const auto brandTitleY  = height() / 2 - 30;
    if (_brandTitle) {
        _brandTitle->resizeToWidth(leftWidth - 32);
        _brandTitle->move(brandCenterX - _brandTitle->width() / 2, brandTitleY);
    }
    if (_brandSubtitle) {
        _brandSubtitle->resizeToWidth(leftWidth - 64);
        _brandSubtitle->move(
            brandCenterX - _brandSubtitle->width() / 2,
            brandTitleY + _brandTitle->height() + 10);
    }

    // CTA panel — content is vertically centered inside the right column.
    const auto rightLeft   = leftWidth + 1;
    const auto rightWidth  = width() - rightLeft;
    const auto rightCenter = rightLeft + rightWidth / 2;
    const auto ctaWidth    = std::min(rightWidth - 64, kCtaMaxWidth);

    if (_ctaTitle) {
        _ctaTitle->resizeToWidth(ctaWidth);
        _ctaTitle->move(rightCenter - _ctaTitle->width() / 2,
                        height() / 2 - 80);
    }
    if (_ctaSubtitle) {
        _ctaSubtitle->resizeToWidth(ctaWidth);
        _ctaSubtitle->move(rightCenter - _ctaSubtitle->width() / 2,
                           _ctaTitle->y() + _ctaTitle->height() + 6);
    }
    if (_startButton) {
        _startButton->setFullWidth(ctaWidth);
        _startButton->move(rightCenter - _startButton->width() / 2,
                           _ctaSubtitle->y() + _ctaSubtitle->height() + 28);
    }

    // Error banner — full-width pill above everything else.
    if (_errorLabel) {
        _errorLabel->resize(width() - kErrorPadding * 2, kErrorHeight);
        _errorLabel->move(kErrorPadding, kErrorPadding);
        _errorLabel->raise();
    }
}

} // namespace Ui
