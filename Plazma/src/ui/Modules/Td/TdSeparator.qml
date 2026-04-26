import QtQuick
import Td 1.0

// TdSeparator — port of `Ui::PlainShadow` /
// `Ui::BoxContentDivider` (lib_ui/ui/widgets/box_content_divider.h).
// One-pixel divider in either orientation.

Rectangle {
    property bool vertical: false
    width:  vertical ? TdStyle.metrics.lineWidth : parent ? parent.width : 0
    height: vertical ? (parent ? parent.height : 0) : TdStyle.metrics.lineWidth
    color: TdPalette.c.menuSeparatorFg
}
