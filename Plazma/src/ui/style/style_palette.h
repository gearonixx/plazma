#pragma once

#include "src/ui/style/style_core.h"

namespace style {

// Plazma palette — the tdesktop-style palette object. Every UI primitive
// looks up colors here rather than baking hex strings into widgets, so a
// future theme swap is one assignment per slot.
//
// Slots are organised into rough buckets matching tdesktop's
// style_core_palette: window backgrounds, text shades, primary action,
// surface tints, and dividers/borders.
struct Palette {
    // Backgrounds
    color windowBg          { QStringLiteral("#F7F4FC") };  // app-wide canvas
    color windowBgOver      { QStringLiteral("#EEEBF3") };  // hovered surface
    color windowBgRipple    { 91, 33, 182, 38 };            // ripple tint
    color windowBgActive    { QStringLiteral("#7C3AED") };  // selected/active row
    color cardBg            { QStringLiteral("#FFFFFF") };  // card / nav surface
    color shadowFg          { 14, 14, 17, 40 };             // panel shadow

    // Text hierarchy
    color windowFg          { QStringLiteral("#1F1933") };
    color windowSubTextFg   { QStringLiteral("#6B6882") };
    color windowFgHint      { QStringLiteral("#A7A2BD") };
    color windowFgActive    { QStringLiteral("#FFFFFF") };  // text on accent
    color windowActiveTextFg{ QStringLiteral("#7C3AED") };  // accent-colored text

    // Primary action — purple family
    color buttonBg          { QStringLiteral("#8B5CF6") };
    color buttonBgOver      { QStringLiteral("#7C3AED") };
    color buttonBgRipple    { 255, 255, 255, 56 };
    color buttonFg          { QStringLiteral("#FFFFFF") };
    color buttonFgOver      { QStringLiteral("#FFFFFF") };

    // Tinted (soft) surfaces — accent badges, inline pills
    color tintedBg          { QStringLiteral("#EDE4FB") };
    color tintedFg          { QStringLiteral("#7C3AED") };

    // Inputs
    color inputBg           { QStringLiteral("#FFFFFF") };
    color inputBorder       { QStringLiteral("#E4DEF5") };
    color inputBorderActive { QStringLiteral("#8B5CF6") };
    color inputFg           { QStringLiteral("#1F1933") };
    color inputPlaceholderFg{ QStringLiteral("#A7A2BD") };

    // Dividers / outlines
    color dividerFg         { QStringLiteral("#EEEBF3") };
    color outlineFg         { QStringLiteral("#E4DEF5") };

    // Status colors
    color errorFg           { QStringLiteral("#D94040") };
    color successFg         { QStringLiteral("#22A06B") };

    // Toast / overlay
    color toastBg           { 26, 22, 38, 230 };
    color toastFg           { QStringLiteral("#FFFFFF") };
};

// The single palette instance. Mutate in-place via setTheme(...) if a future
// dark theme is added; widgets already hold references to slots, no rebind.
[[nodiscard]] Palette &palette();

// Default fonts. Pixel sizes match Telegram Desktop's defaults so a port
// of any of their .style structs lands at roughly the right metrics.
struct Fonts {
    font normal   { 13, QFont::Normal };
    font semibold { 13, QFont::DemiBold };
    font bold     { 13, QFont::Bold };
    font large    { 16, QFont::DemiBold };
    font title    { 22, QFont::Bold };
    font small    { 11, QFont::Normal };
};
[[nodiscard]] Fonts &fonts();

} // namespace style
