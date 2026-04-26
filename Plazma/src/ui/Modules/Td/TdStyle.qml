pragma Singleton

import QtQuick

// TdStyle — Plazma's port of `lib_ui/ui/basic.style` (and the per-widget
// .style files) from Telegram Desktop / Desktop App Toolkit.
//
// Numeric tokens are kept identical to upstream wherever possible, so any
// metric here can be cross-referenced against tdesktop's `*.style` files.

QtObject {
    id: style

    // ── Fonts (basic.style: fsize, normalFont, semiboldFont, boxTextFont) ──
    readonly property QtObject font: QtObject {
        readonly property string family:        Qt.application.font.family
        readonly property int    fsize:         13
        readonly property int    boxFontSize:   14
        readonly property int    largeFontSize: 17
        readonly property int    titleSize:     20
        readonly property int    captionSize:   11

        readonly property int weightNormal:   Font.Normal
        readonly property int weightMedium:   Font.Medium
        readonly property int weightSemibold: Font.DemiBold
        readonly property int weightBold:     Font.Bold
    }

    // ── Geometry (basic.style: lineWidth, roundRadius*, …) ─────────────────
    readonly property QtObject metrics: QtObject {
        readonly property int lineWidth:        1
        readonly property int roundRadiusSmall: 3
        readonly property int roundRadiusLarge: 6
        readonly property int dateRadius:       6

        readonly property int defaultVerticalListSkip: 6
        readonly property int transparentPlaceholderSize: 4

        // buttons
        readonly property int buttonHeight:      34
        readonly property int buttonRadius:      4
        readonly property int buttonPadding:     14
        readonly property int buttonIconPadding: 10
        readonly property int buttonIconSpacing: 8
        readonly property int buttonMinWidth:    64

        readonly property int iconButtonSize:    32
        readonly property int iconButtonRadius:  4
        readonly property int iconButtonIconSize: 20

        readonly property int flatButtonHeight:  28
        readonly property int flatButtonPadding: 8

        // input fields
        readonly property int inputFieldHeight:           40
        readonly property int inputFieldPlaceholderShift: 14
        readonly property int inputFieldBorderWidth:      1
        readonly property int inputFieldBorderActive:     2
        readonly property int inputFieldIconSize:         18

        readonly property int searchInputHeight:  32
        readonly property int searchInputRadius:  16
        readonly property int searchInputPadding: 12

        // popup menu
        readonly property int menuRadius:        8
        readonly property int menuPadding:       6
        readonly property int menuItemHeight:    32
        readonly property int menuItemPadding:   12
        readonly property int menuItemIconSpace: 24
        readonly property int menuShadowExtend:  18
        readonly property int menuSeparatorHeight: 9
        readonly property int menuMinWidth:      180

        // box / layer
        readonly property int boxRadius:    8
        readonly property int boxPadding:   24
        readonly property int boxTitleSize: 17
        readonly property int boxButtonSpacing: 12
        readonly property int boxButtonHeight:  38
        readonly property int boxMinWidth:  320
        readonly property int boxMaxWidth:  560

        // scroll area
        readonly property int scrollWidth:        10
        readonly property int scrollWidthOver:    14
        readonly property int scrollMinHeight:    24
        readonly property int scrollDeltaX:       3
        readonly property int scrollEdgeShadow:   12

        // shadows
        readonly property int shadowDepthSmall:  6
        readonly property int shadowDepthMedium: 12
        readonly property int shadowDepthLarge:  18

        // checkbox / radio
        readonly property int checkSize:         18
        readonly property int checkRadius:       3
        readonly property int checkBorderWidth:  2
        readonly property int checkSpacing:      8

        readonly property int radioSize:         18
        readonly property int radioBorderWidth:  2
        readonly property int radioInnerSize:    8

        // toggle (switch)
        readonly property int toggleWidth:       32
        readonly property int toggleHeight:      18
        readonly property int toggleHandleSize:  14
        readonly property int togglePadding:     2

        // slider
        readonly property int sliderHeight:      20
        readonly property int sliderTrackHeight: 4
        readonly property int sliderHandleSize:  14

        // progress
        readonly property int progressHeight:        4
        readonly property int progressRadialSize:    24
        readonly property int progressRadialLine:    3

        // tooltip
        readonly property int tooltipPadding:    8
        readonly property int tooltipRadius:     4
        readonly property int tooltipMaxWidth:   240

        // tabs
        readonly property int tabHeight:         40
        readonly property int tabPadding:        16
        readonly property int tabIndicatorH:     2
        readonly property int tabSpacing:        8

        // settings rows / list
        readonly property int rowHeight:         52
        readonly property int rowPadding:        16
        readonly property int rowIconSize:       24
        readonly property int rowIconSpacing:    16
        readonly property int rowChevronSize:    16
        readonly property int sectionHeaderHeight: 36

        // sidebar / dialog row
        readonly property int sidebarItemHeight:     72
        readonly property int sidebarItemPadding:    12
        readonly property int sidebarAvatarSize:     48
        readonly property int sidebarItemSpacing:    12

        // avatar
        readonly property int avatarSizeSmall:   24
        readonly property int avatarSizeMedium:  36
        readonly property int avatarSizeLarge:   48
        readonly property int avatarSizeHuge:    96

        // badge
        readonly property int badgeMinSize:      18
        readonly property int badgePadding:      6
        readonly property int badgeFontSize:     11
        readonly property int badgeDotSize:      8

        // title bar
        readonly property int titleBarHeight:        38
        readonly property int titleBarButtonWidth:   46
        readonly property int titleBarButtonHeight:  28

        // toast
        readonly property int toastHeight:       40
        readonly property int toastPadding:      16
        readonly property int toastRadius:       6
        readonly property int toastMaxWidth:     420

        // focus ring
        readonly property int focusRingWidth:    2
        readonly property int focusRingInset:    2

        // empty state
        readonly property int emptyStateIcon:    72
        readonly property int emptyStatePadding: 24
    }

    // ── Durations (basic.style) ────────────────────────────────────────────
    readonly property QtObject duration: QtObject {
        readonly property int instant:        80
        readonly property int universal:      120  // basic.style: universalDuration
        readonly property int slide:          240  // slideDuration
        readonly property int slideWrap:      150
        readonly property int fadeWrap:       200
        readonly property int activeFadeIn:   500
        readonly property int activeFadeOut:  3000
        readonly property int radial:         350
        readonly property int radialPeriod:   3000
        readonly property int rippleExpand:   200
        readonly property int rippleFade:     250
        readonly property int toast:          3500
        readonly property int tooltip:        500
        readonly property int spinnerCycle:   1200
    }

    // ── Easing curves (mirror tdesktop's Animations::Simple defaults) ──────
    readonly property QtObject easing: QtObject {
        readonly property int standard:  Easing.OutCubic
        readonly property int decel:     Easing.OutQuart
        readonly property int accel:     Easing.InQuart
        readonly property int sharp:     Easing.OutQuint
        readonly property int linear:    Easing.Linear
        readonly property int bounce:    Easing.OutBack
    }

    // ── Z-order (modal stacking) ───────────────────────────────────────────
    readonly property QtObject z: QtObject {
        readonly property int base:        0
        readonly property int sticky:      10
        readonly property int dropdown:    100
        readonly property int popup:       200
        readonly property int layer:       900
        readonly property int popupOnLayer: 1000
        readonly property int toast:       1500
        readonly property int tooltip:     2000
    }
}
