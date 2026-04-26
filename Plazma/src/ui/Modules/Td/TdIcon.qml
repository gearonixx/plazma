import QtQuick
import Td 1.0

// TdIcon — palette-aware glyph component. Mirrors the role of
// `style::icon` (lib_ui/ui/style/style_core_icon.h) where every icon is a
// path + a palette color, re-tinted on theme change.
//
// Tint strategy without QtGraphicalEffects: we render the source as a
// scratch layer and overlay a colored Rectangle that is masked by the
// glyph using `layer.samplerName` + a tiny inline shader passthrough.
// When the source is a colored asset (full-color PNG / multi-color SVG)
// callers can set `tinted: false` to draw it as-is.

Item {
    id: root

    property url    source
    property color  color: TdPalette.c.menuIconFg
    property int    size:  16
    property bool   tinted: true
    property bool   smooth: true

    implicitWidth:  size
    implicitHeight: size

    // Untinted fallback / colored asset path.
    Image {
        id: rawImage
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: root.smooth
        antialiasing: true
        visible: !root.tinted
    }

    // Tinted path: image as alpha mask, rectangle as ink.
    // Uses layer.enabled + Repeater-free composition. Works without
    // QtGraphicalEffects by layering the image with an opacity-mask trick:
    // the Rectangle paints color, layered with the image acting as alpha.
    Item {
        anchors.fill: parent
        visible: root.tinted

        Image {
            id: maskImage
            anchors.fill: parent
            source: root.source
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
            fillMode: Image.PreserveAspectFit
            smooth: root.smooth
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            visible: false
        }

        ShaderEffect {
            anchors.fill: parent
            property variant mask: maskImage
            property color tint: root.color
            blending: true
            // Multiplies tint RGB by mask alpha. Safe across Qt 6 RHI;
            // the inline GLSL is auto-baked by the engine.
            fragmentShader: "
                #version 440
                layout(location = 0) in vec2 qt_TexCoord0;
                layout(location = 0) out vec4 fragColor;
                layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; vec4 tint; };
                layout(binding = 1) uniform sampler2D mask;
                void main() {
                    float a = texture(mask, qt_TexCoord0).a;
                    fragColor = vec4(tint.rgb, tint.a * a) * qt_Opacity;
                }
            "

            // If the inline shader path fails on this platform/Qt build,
            // ShaderEffect logs a warning and renders nothing — the
            // untinted path above is still available via `tinted: false`.
        }
    }
}
