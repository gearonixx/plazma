#include "src/ui/style/style_palette.h"

namespace style {

Palette &palette() {
    static Palette instance;
    return instance;
}

Fonts &fonts() {
    static Fonts instance;
    return instance;
}

} // namespace style
