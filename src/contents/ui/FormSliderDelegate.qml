import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as KirigamiFormCard

KirigamiFormCard.AbstractFormDelegate {
    id: sliderDelegate

    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize

    /// Shown under the label, for a reading that is not the slider position.
    property string description: ""
    /// Shown instead of the raw value, for sliders that run over indices.
    property string valueText: ""

    signal moved

    hoverEnabled: false
    background: null

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            Layout.fillWidth: true

            text: sliderDelegate.text
            visible: sliderDelegate.text
        }

        Controls.Label {
            Layout.fillWidth: true

            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: sliderDelegate.description
            visible: sliderDelegate.description.length > 0
        }

        RowLayout {
            Controls.Slider {
                id: slider
                Layout.fillWidth: true

                snapMode: Controls.Slider.SnapAlways

                onMoved: sliderDelegate.moved()
            }

            Controls.Label {
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.preferredWidth: Kirigami.Units.gridUnit

                horizontalAlignment: Controls.Label.AlignRight
                text: sliderDelegate.valueText ? sliderDelegate.valueText : slider.value
            }
        }
    }
}
