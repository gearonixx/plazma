import QtQuick
import Td 1.0

// TdFlatLabel — port of `Ui::FlatLabel`
// (lib_ui/ui/widgets/labels.h). Supports the three weight presets used
// throughout tdesktop.

Text {
    id: root

    enum Style { Normal, Semibold, Bold, Sub, BoxTitle }

    property int variant: TdFlatLabel.Normal

    color: {
        switch (variant) {
        case TdFlatLabel.Sub:      return TdPalette.c.windowSubTextFg;
        case TdFlatLabel.BoxTitle: return TdPalette.c.windowBoldFg;
        case TdFlatLabel.Bold:
        case TdFlatLabel.Semibold: return TdPalette.c.windowBoldFg;
        default:                   return TdPalette.c.windowFg;
        }
    }

    font.family: TdStyle.font.family
    font.pixelSize: variant === TdFlatLabel.BoxTitle ? TdStyle.metrics.boxTitleSize
                                                     : TdStyle.font.fsize
    font.weight: {
        switch (variant) {
        case TdFlatLabel.Bold:     return TdStyle.font.weightBold;
        case TdFlatLabel.Semibold:
        case TdFlatLabel.BoxTitle: return TdStyle.font.weightSemibold;
        default:                   return TdStyle.font.weightNormal;
        }
    }
    renderType: Text.NativeRendering
    wrapMode: Text.WordWrap
}
