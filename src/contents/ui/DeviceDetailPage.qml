import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as KirigamiFormCard

import com.gitlab.thebill2001.headsetkontrol

KirigamiFormCard.FormCardPage {
    id: deviceDetailPage

    property Device device: null

    readonly property bool parametricSectionVisible:
        (device?.capabilities & Device.ParametricEqualizer) !== 0 && device?.parametricBands?.length > 0

    /// Which band the detail card is editing; touching a fader selects it.
    property int selectedBand: 0

    readonly property bool microphoneCapable:
        (device?.capabilities & (Device.MicrophoneMuteLedBrightness | Device.MicrophoneVolume)) !== 0

    function selectedBandData(): var {
        const bands = device?.parametricBands ?? [];
        if (bands.length < 1)
            return ({});
        return bands[Math.max(0, Math.min(selectedBand, bands.length - 1))];
    }

    function formatFrequency(hz: real): string {
        return hz >= 1000 ? (hz / 1000) + " kHz" : hz + " Hz";
    }

    title: i18nc("@title:window", "Device details")

    actions: [
        Kirigami.Action {
            id: reApplyAction
        },
        Kirigami.Action {
            id: setPrimaryAction
        }
    ]

    Connections {
        target: deviceDetailPage
        function onDeviceChanged() {
            if (device) {
                reApplyAction.fromQAction = device.reApplyAction;
                setPrimaryAction.fromQAction = device.setPrimaryAction;
            }
        }
    }

    header: Kirigami.InlineMessage {
        id: headerMessage

        showCloseButton: true
        position: Kirigami.InlineMessage.Position.Header
        type: Kirigami.MessageType.Error

        Connections {
            target: HeadsetControl
            function onParsingErrorOccurred(error) {
                headerMessage.showError(error);
            }

            function onProcessErrorOccurred(error) {
                headerMessage.showError(error);
            }
        }

        function showError(error) {
            if (deviceDetailPage.isCurrentPage) {
                text = error;
                visible = true;
            }
        }
    }


    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Device")
    }

    // One block for everything the headset reports about itself. The IDs only
    // matter when something is wrong, so they ride along as a description
    // instead of taking rows of their own.
    // Everything the headset reports about itself, on one line: the ids only
    // matter when something is wrong, so they are the small print, and the two
    // readings are meters rather than rows of their own.
    KirigamiFormCard.FormCard {
        KirigamiFormCard.AbstractFormDelegate {
            hoverEnabled: false
            background: null

            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 8
                    spacing: 0

                    Controls.Label {
                        id: productLabel

                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: deviceDetailPage.device?.product ?? ""

                        HoverHandler {
                            id: productHover
                        }

                        Controls.ToolTip.visible: productHover.hovered
                        Controls.ToolTip.text: {
                            const d = deviceDetailPage.device;
                            if (!d)
                                return "";

                            return i18nc("@info:usagetip", "%1, product ID %2, vendor ID %3",
                                         d.device ?? "", d.productId ?? "", d.vendorId ?? "");
                        }
                    }
                }

                RowLayout {
                    visible: deviceDetailPage.device?.capabilities & Device.ChatMix ?? false
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        font: Kirigami.Theme.smallFont
                        text: i18nc("@label", "Chat-Mix")
                    }

                    Controls.ProgressBar {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2

                        from: 0
                        to: 128
                        value: deviceDetailPage.device?.chatMix ?? 0
                    }

                    Controls.Label {
                        font: Kirigami.Theme.smallFont
                        text: deviceDetailPage.device?.chatMix ?? ""
                    }
                }

                RowLayout {
                    visible: deviceDetailPage.device?.capabilities & Device.Battery ?? false
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        font: Kirigami.Theme.smallFont
                        text: i18nc("@label", "Battery")
                    }

                    Controls.ProgressBar {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2

                        from: 0
                        to: 100
                        value: deviceDetailPage.device?.battery.level ?? 0
                    }

                    Controls.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        horizontalAlignment: Text.AlignRight
                        font: Kirigami.Theme.smallFont

                        text: {
                            const battery = deviceDetailPage.device?.battery;
                            if (!battery)
                                return "";
                            if (battery.level < 0)
                                return i18nc("@item battery status", "Unavailable");
                            if (battery.status === DeviceBattery.Charging)
                                return i18nc("@item battery status", "Charging %1%", battery.level);
                            return `${battery.level}%`;
                        }
                    }
                }
            }
        }
    }

    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Configurations")
        visible: configFormCard.visible
    }

    KirigamiFormCard.FormCard {
        id: configFormCard

        visible: deviceDetailPage.microphoneCapable
                 || ((deviceDetailPage.device?.capabilities
                      & (Device.Light | Device.VoicePrompt | Device.Sidetone | Device.InactiveTime
                         | Device.NotificationSound | Device.VolumeLimiter | Device.SidetoneStatus)) ?? false)

        KirigamiFormCard.FormSwitchDelegate {
            id: lightDelegate

            text: i18nc("@option:check", "Lights")
            visible: deviceDetailPage.device?.capabilities & Device.Light ?? false

            checked: deviceDetailPage.device?.light ?? true
            onCheckedChanged: {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.light = lightDelegate.checked;
            }
        }

        KirigamiFormCard.FormSwitchDelegate {
            id: voicePromptDelegate

            text: i18nc("@option:check", "Voice prompts")
            visible: deviceDetailPage.device?.capabilities & Device.VoicePrompt ?? false
            checked: deviceDetailPage.device?.voicePrompt ?? true
            onCheckedChanged: {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.voicePrompt = voicePromptDelegate.checked;
            }
        }

        // Devices that quantise sidetone publish the steps they actually have
        // (the Nova 5 has 11 between 0 and 128); anything else is snapped
        // silently, so those get a picker over the real values instead of a
        // free 0..128 spinner.
        KirigamiFormCard.FormComboBoxDelegate {
            id: sidetoneLevelDelegate

            visible: (deviceDetailPage.device?.capabilities & Device.Sidetone ?? false)
                     && (deviceDetailPage.device?.sidetoneLevels?.length ?? 0) > 0
            text: i18nc("@label:listbox", "Sidetone")
            // What the headset holds, when it can be read back: a write that
            // never landed should be visible, not remembered only here.
            description: (deviceDetailPage.device?.capabilities & Device.SidetoneStatus) !== 0
                         && (deviceDetailPage.device?.sidetoneDeviceLevel ?? -1) >= 0
                         ? i18nc("@info:usagetip", "Headset reports level %1",
                                 deviceDetailPage.device?.sidetoneDeviceLevel ?? 0)
                         : ""
            model: deviceDetailPage.device?.sidetoneLevels ?? []
            currentIndex: (deviceDetailPage.device?.sidetoneLevels ?? []).indexOf(deviceDetailPage.device?.sidetone ?? 0)
            onActivated: function (index) {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.sidetone = model[index];
            }
        }

        KirigamiFormCard.FormSpinBoxDelegate {
            id: sidetoneDelegate

            label: i18nc("@label:spinbox", "Sidetone")
            from: 0
            to: 128
            visible: (deviceDetailPage.device?.capabilities & Device.Sidetone ?? false)
                     && (deviceDetailPage.device?.sidetoneLevels?.length ?? 0) === 0

            value: deviceDetailPage.device?.sidetone ?? 0
            onValueChanged: {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.sidetone = sidetoneDelegate.value;
            }
        }

        KirigamiFormCard.FormSpinBoxDelegate {
            id: inactiveTimeDelegate

            label: i18nc("@label:spinbox", "Inactive time")
            from: 0
            to: 90
            visible: deviceDetailPage.device?.capabilities & Device.InactiveTime ?? false
            textFromValue: function (value, locale) {
                return i18ncp("@item:valuesuffix", "%1 minute", "%1 minutes", value);
            }
            valueFromText: function (text, locale) {
                const matches = text.match(/\d+/);
                return matches ? parseInt(matches.join('')) : 0;
            }

            value: deviceDetailPage.device?.inactiveTime ?? 0
            onValueChanged: {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.inactiveTime = inactiveTimeDelegate.value;
            }
        }

        KirigamiFormCard.FormSwitchDelegate {
            id: volumeLimiterDelegate

            visible: deviceDetailPage.device?.capabilities & Device.VolumeLimiter ?? false
            text: i18nc("@option:check", "Volume limiter")
            description: i18nc("@info:usagetip", "Caps the headset's output level")

            checked: deviceDetailPage.device?.volumeLimiter ?? false
            onCheckedChanged: {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.volumeLimiter = volumeLimiterDelegate.checked;
            }
        }

        FormTextFieldWithButtonDelegate {
            id: notificationDelegate

            visible: deviceDetailPage.device?.capabilities & Device.NotificationSound ?? false
            label: i18nc("@label:textbox", "Notification sound")
            placeholderText: i18nc("@info:placeholder", "Sound ID (depends on device)")
            buttonText: i18nc("@action:button", "Play")

            onAccepted: {
                if (deviceDetailPage.device) {
                    if (!notificationDelegate.text) {
                        headerMessage.showError(i18nc("@info", "Sound ID cannot be empty."));
                    } else {
                        deviceDetailPage.device.playNotification(notificationDelegate.text);
                    }
                }
            }
        }

        FormSliderDelegate {
            id: microphoneLightBrightnessDelegate

            visible: deviceDetailPage.device?.capabilities & Device.MicrophoneMuteLedBrightness ?? false

            text: i18nc("@label:slider", "Microphone mute light brightness")
            from: 0
            to: 3
            stepSize: 1
            value: deviceDetailPage.device?.microphoneBrightness ?? 3
            onMoved: {
                if (deviceDetailPage.device) {
                    deviceDetailPage.device.microphoneBrightness = microphoneLightBrightnessDelegate.value;
                }
            }
        }

        FormSliderDelegate {
            id: microphoneVolumeDelegate

            visible: deviceDetailPage.device?.capabilities & Device.MicrophoneVolume ?? false

            text: i18nc("@label:slider", "Microphone volume")
            from: 0
            to: 128
            stepSize: 1
            value: deviceDetailPage.device?.microphoneVolume ?? 3
            onMoved: {
                if (deviceDetailPage.device) {
                    deviceDetailPage.device.microphoneVolume = microphoneVolumeDelegate.value;
                }
            }
        }
    }
    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Equalizer")
        visible: equalizerFormCard.visible
    }

    KirigamiFormCard.FormCard {
        id: equalizerFormCard

        visible: deviceDetailPage.device?.capabilities & (Device.Equalizer | Device.EqualizerPreset | Device.ParametricEqualizer) ?? false

        // No idea what the validator is
        FormTextFieldWithButtonDelegate {
            id: equalizerDelegate

            // Only for devices without a parametric editor: two ways to write
            // the same curve invites writing the wrong one.
            visible: (deviceDetailPage.device?.capabilities & Device.Equalizer ?? false)
                     && !deviceDetailPage.parametricSectionVisible
            label: i18nc("@label:textbox", "Equalizer curve")
            placeholderText: i18nc("@info:placeholder", "Values separated by spaces, or commas")
            buttonText: i18nc("@action:button", "Apply")

            text: deviceDetailPage.device?.equalizer ?? ""
            onAccepted: {
                if (deviceDetailPage.device) {
                    if (!equalizerDelegate.text) {
                        headerMessage.showError(i18nc("@info", "Equalizer curve cannot be empty."));
                    } else {
                        deviceDetailPage.device.equalizer = equalizerDelegate.text;
                    }
                }
            }
        }

        KirigamiFormCard.FormComboBoxDelegate {
            id: equalizerPresetDelegate

            visible: deviceDetailPage.device?.capabilities & Device.EqualizerPreset ?? false
            text: i18nc("@label:listbox", "Equalizer preset")
            // Names come from headsetcontrol in --equalizer-preset index
            // order; without them (older builds) fall back to the numbers.
            model: {
                const names = deviceDetailPage.device?.equalizerPresetNames ?? [];
                if (names.length > 0) {
                    return names.map((name, index) => ({
                        "display": name.charAt(0).toUpperCase() + name.slice(1),
                        "value": index
                    }));
                }
                return [
                    {
                        "display": i18nc("@item:inlistbox", "Default"),
                        "value": 0
                    },
                    {
                        "display": i18nc("@item:inlistbox", "Preset %1", 1),
                        "value": 1
                    },
                    {
                        "display": i18nc("@item:inlistbox", "Preset %1", 2),
                        "value": 2
                    },
                    {
                        "display": i18nc("@item:inlistbox", "Preset %1", 3),
                        "value": 3
                    }
                ];
            }
            textRole: "display"
            valueRole: "value"
            currentIndex: deviceDetailPage.device?.equalizerPreset ?? 0
            onActivated: function (index) {
                if (deviceDetailPage.device) {
                    deviceDetailPage.device.equalizerPreset = equalizerPresetDelegate.currentIndex;
                }
            }
        }
        // A ten-band fader bank, the way the hardware exposes these:
        // frequencies across the top, a shared dB scale at the edges, one
        // fader per band.
        KirigamiFormCard.AbstractFormDelegate {
            id: faderBankDelegate

            hoverEnabled: false
            background: null

            readonly property var limits: deviceDetailPage.device?.parametricLimits ?? ({})
            readonly property var bands: deviceDetailPage.device?.parametricBands ?? []
            readonly property real gainMin: limits.gainMin ?? -10
            readonly property real gainMax: limits.gainMax ?? 10
            readonly property real gainStep: limits.gainStep ?? 0.5
            readonly property real faderHeight: Kirigami.Units.gridUnit * 8

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                // Left scale, so a fader position can be read as a number
                // without selecting it.
                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.preferredHeight: faderBankDelegate.faderHeight

                    Controls.Label {
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        y: 0
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label decibel scale", "+%1", faderBankDelegate.gainMax.toFixed(0))
                    }
                    Controls.Label {
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label decibel scale", "0")
                    }
                    Controls.Label {
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        anchors.bottom: parent.bottom
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label decibel scale", "%1", faderBankDelegate.gainMin.toFixed(0))
                    }
                }

                Repeater {
                    model: faderBankDelegate.bands

                    ColumnLayout {
                        id: faderColumn

                        required property int index
                        required property var modelData

                        /// The gain the fader is showing. Dragging updates
                        /// this, and only releasing commits it: the model
                        /// resets on every write, which would end the drag.
                        property real bandGain: modelData.gain ?? 0

                        HoverHandler {
                            id: faderColumnHover
                        }

                        Layout.fillWidth: true
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 1.4
                        spacing: Kirigami.Units.smallSpacing / 2

                        Controls.Label {
                            readonly property bool selected: deviceDetailPage.selectedBand === faderColumn.index

                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            font: Kirigami.Theme.smallFont
                            opacity: selected ? 1 : 0.8
                            color: selected ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

                            // The band's shape rides along with its
                            // frequency: a shelf band is not a bell, and the
                            // difference should be visible without opening
                            // anything.
                            text: {
                                const f = faderColumn.modelData.frequency ?? 0;
                                const label = f >= 1000 ? (f / 1000) + "K" : String(Math.round(f));
                                switch (faderColumn.modelData.type) {
                                case "lowshelf":
                                    return label + " LS";
                                case "highshelf":
                                    return label + " HS";
                                case "lowpass":
                                    return label + " LP";
                                case "highpass":
                                    return label + " HP";
                                default:
                                    return label;
                                }
                            }

                            Controls.ToolTip.visible: faderColumnHover.hovered
                            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                            Controls.ToolTip.text: {
                                const band = faderColumn.modelData;
                                return i18nc("@info:tooltip", "%1 Hz, gain %2 dB, Q %3, %4",
                                             Math.round(band.frequency ?? 0),
                                             (band.gain ?? 0).toFixed(1),
                                             (band.qFactor ?? 1.41).toFixed(2),
                                             band.type ?? "peaking");
                            }
                        }

                        Controls.Slider {
                            id: gainFader

                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.preferredHeight: faderBankDelegate.faderHeight
                            orientation: Qt.Vertical
                            from: faderBankDelegate.gainMin
                            to: faderBankDelegate.gainMax
                            stepSize: faderBankDelegate.gainStep
                            snapMode: Controls.Slider.SnapAlways
                            value: faderColumn.bandGain
                            onMoved: {
                                faderColumn.bandGain = value;
                                deviceDetailPage.selectedBand = faderColumn.index;
                            }
                            onPressedChanged: {
                                if (pressed) {
                                    deviceDetailPage.selectedBand = faderColumn.index;
                                } else if (deviceDetailPage.device) {
                                    deviceDetailPage.device.setParametricBand(faderColumn.index, "gain", faderColumn.bandGain);
                                    deviceDetailPage.device.applyParametricEqualizer();
                                }
                            }

                            // Hardware-style groove and fader cap.
                            background: Rectangle {
                                x: Math.round((gainFader.width - width) / 2)
                                width: Kirigami.Units.gridUnit * 0.4
                                height: gainFader.availableHeight
                                y: gainFader.topPadding
                                radius: width / 2
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                            }

                            handle: Rectangle {
                                x: Math.round((gainFader.width - width) / 2)
                                y: gainFader.topPadding
                                   + (1.0 - gainFader.visualPosition) * (gainFader.availableHeight - height)
                                width: Kirigami.Units.gridUnit * 1.4
                                height: Kirigami.Units.gridUnit * 1.1
                                radius: Math.min(width, height) / 4
                                color: gainFader.pressed
                                    ? Kirigami.Theme.highlightColor
                                    : Qt.rgba(Kirigami.Theme.textColor.r,
                                              Kirigami.Theme.textColor.g,
                                              Kirigami.Theme.textColor.b, 0.85)
                                border.color: Qt.rgba(0, 0, 0, 0.6)
                                border.width: 1

                                // Centre line on the cap, as on a real fader.
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: 1
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                }
                            }
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                            text: i18nc("@label decibel value", "%1 dB", faderColumn.bandGain.toFixed(1))
                        }
                    }
                }

                // Right scale, mirroring the left one: a fader bank reads
                // better with the scale on both sides once it is this wide.
                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
                    Layout.preferredHeight: faderBankDelegate.faderHeight

                    Controls.Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        y: 0
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label decibel scale", "+%1", faderBankDelegate.gainMax.toFixed(0))
                    }
                    Controls.Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label decibel scale", "0")
                    }
                    Controls.Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.bottom: parent.bottom
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label decibel scale", "%1", faderBankDelegate.gainMin.toFixed(0))
                    }
                }
            }
        }

    }
}
