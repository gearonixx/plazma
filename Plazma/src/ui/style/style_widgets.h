#pragma once

#include "src/ui/style/style_core.h"
#include "src/ui/style/style_palette.h"

#include <QString>

namespace style {

// Descriptor structs — these are immutable, const-ref-passed bundles of
// palette + font + geometry that describe a *style* of a widget. tdesktop
// generates these from .style DSL files; we just hand-write them here.

// RippleAnimation — params for the circular ripple drawn on a button press.
struct RippleAnimation {
    color rippleColor   { palette().windowBgRipple };
    int   showDuration  = 200;
    int   hideDuration  = 200;
};

// FlatLabel — text label primitive (think tdesktop's flat_label).
struct FlatLabel {
    style::font textFont{ 13, QFont::Normal };
    color   textFg{ palette().windowFg };
    int     maxHeight = 0;          // 0 == unlimited
    int     minWidth  = 0;
    margins padding{};
    int     lineHeight = 0;         // 0 == use font's natural height
    Qt::Alignment align = Qt::AlignLeft | Qt::AlignVCenter;
};

// RoundButton — primary action button (Telegram blue, but purple here).
struct RoundButton {
    color textFg            { palette().buttonFg };
    color textFgOver        { palette().buttonFgOver };
    color numbersTextFg     { palette().buttonFg };
    color textBg            { palette().buttonBg };
    color textBgOver        { palette().buttonBgOver };

    int     width           = 0;       // 0 == auto from text + padding
    int     height          = 36;
    margins padding         { 14, 0, 14, 0 };
    int     radius          = 8;       // negative == pill (height/2)
    int     textTop         = 0;       // baseline tweak
    style::font textFont    { 14, QFont::DemiBold };

    RippleAnimation ripple{};
};

// IconButton — square icon-only button (chrome around an icon).
struct IconButton {
    int   width             = 36;
    int   height            = 36;
    int   iconPosition      = 0;        // reserved
    color iconColor         { palette().tintedFg };
    color iconColorOver     { palette().windowActiveTextFg };
    color rippleColor       { palette().windowBgRipple };

    QString iconText;                   // emoji or single glyph
    style::font iconFont    { 18, QFont::Normal };

    RippleAnimation ripple{};
};

// FlatButton — full-width text-on-flat-bg button (settings rows etc).
struct FlatButton {
    color textFg            { palette().windowFg };
    color textFgOver        { palette().windowActiveTextFg };
    color bg                { palette().cardBg };
    color bgOver            { palette().windowBgOver };

    int   width             = 0;
    int   height            = 48;
    style::font textFont    { 14, QFont::Normal };

    RippleAnimation ripple{};
};

// LinkButton — inline tappable text (used for "forgot password?" style).
struct LinkButton {
    color textFg            { palette().windowActiveTextFg };
    color textFgOver        { palette().buttonBgOver };
    style::font textFont    { 13, QFont::Normal };
    margins padding         { 0, 0, 0, 0 };
};

// InputField — single-line text input box.
struct InputField {
    color borderFg          { palette().inputBorder };
    color borderFgActive    { palette().inputBorderActive };
    color borderFgError     { palette().errorFg };
    color textBg            { palette().inputBg };
    color textFg            { palette().inputFg };
    color placeholderFg     { palette().inputPlaceholderFg };

    int   height            = 44;
    int   radius            = 10;
    int   borderWidth       = 1;
    margins padding         { 12, 0, 12, 0 };
    style::font textFont        { 14, QFont::Normal };
    style::font placeholderFont { 14, QFont::Normal };
};

// ScrollArea — Qt's QScrollArea looks foreign on a tdesktop-style canvas;
// these are the colors we paint our own scrollbar with.
struct ScrollArea {
    color bg                { palette().windowBg };
    color barFg             { palette().outlineFg };
    color barFgOver         { palette().windowFgHint };

    int   width             = 8;
    int   margin            = 4;
    int   minHeight         = 32;
    int   round             = 4;
    int   hideTimeoutMs     = 1200;
    int   deltaX            = 1;
    int   deltaY            = 1;
};

// Shadow — used by floating panels (popups, dropdowns).
struct Shadow {
    color shadowColor       { palette().shadowFg };
    int   extend            = 6;
};

// Default style instances — inline so headers can reference them without
// linker fuss; tdesktop generates these in `style::st::` from .style files.
namespace st {

inline const FlatLabel &defaultFlatLabel() {
    static const FlatLabel value{};
    return value;
}

inline const FlatLabel &titleLabel() {
    static const FlatLabel value{ .textFont = fonts().title };
    return value;
}

inline const FlatLabel &subtitleLabel() {
    static const FlatLabel value{
        .textFont = fonts().large,
        .textFg   = palette().windowFg,
    };
    return value;
}

inline const FlatLabel &hintLabel() {
    static const FlatLabel value{
        .textFont = fonts().normal,
        .textFg   = palette().windowSubTextFg,
    };
    return value;
}

inline const RoundButton &primaryButton() {
    static const RoundButton value{
        .height   = 46,
        .padding  = margins(20, 0, 20, 0),
        .radius   = 12,
        .textFont = style::font(15, QFont::DemiBold),
    };
    return value;
}

inline const RoundButton &secondaryButton() {
    static const RoundButton value{
        .textFg     = palette().windowActiveTextFg,
        .textFgOver = palette().windowActiveTextFg,
        .textBg     = palette().tintedBg,
        .textBgOver = palette().windowBgOver,
        .height     = 46,
        .padding    = margins(20, 0, 20, 0),
        .radius     = 12,
        .textFont   = style::font(15, QFont::DemiBold),
    };
    return value;
}

inline const IconButton &iconButton() {
    static const IconButton value{};
    return value;
}

inline const InputField &inputField() {
    static const InputField value{};
    return value;
}

inline const ScrollArea &scrollArea() {
    static const ScrollArea value{};
    return value;
}

inline const Shadow &defaultShadow() {
    static const Shadow value{};
    return value;
}

} // namespace st

} // namespace style
