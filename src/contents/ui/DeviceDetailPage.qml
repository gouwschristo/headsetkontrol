import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as KirigamiFormCard

import com.gitlab.thebill2001.headsetkontrol

KirigamiFormCard.FormCardPage {
    id: deviceDetailPage

    property Device device: null

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
        title: i18nc("@title:group", "Information")
    }

    KirigamiFormCard.FormGridContainer {
        Layout.fillWidth: true

        infoCards: [
            KirigamiFormCard.FormGridContainer.InfoCard {
                title: i18nc("@label:textbox", "Product")
                subtitle: deviceDetailPage.device?.product ?? ""
            },
            KirigamiFormCard.FormGridContainer.InfoCard {
                title: i18nc("@label:textbox", "Product ID")
                subtitle: deviceDetailPage.device?.productId ?? ""
            },
            KirigamiFormCard.FormGridContainer.InfoCard {
                title: i18nc("@label:textbox", "Vendor")
                subtitle: deviceDetailPage.device?.vendor ?? ""
            },
            KirigamiFormCard.FormGridContainer.InfoCard {
                title: i18nc("@label:textbox", "Vendor ID")
                subtitle: deviceDetailPage.device?.vendorId ?? ""
            },
            KirigamiFormCard.FormGridContainer.InfoCard {
                title: i18nc("@label:textbox", "Device")
                subtitle: deviceDetailPage.device?.device ?? ""
            }
        ]
    }

    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Chat-Mix")
        visible: chatMixFormCard.visible
    }

    KirigamiFormCard.FormCard {
        id: chatMixFormCard

        visible: deviceDetailPage.device?.capabilities & Device.ChatMix ?? false

        KirigamiFormCard.AbstractFormDelegate {
            visible: deviceDetailPage.device?.battery.level > -1 ?? false
            hoverEnabled: false
            background: null

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Controls.Label {
                    Layout.fillWidth: true

                    text: i18nc("@label", "Chat-Mix level")
                }

                RowLayout {
                    Controls.ProgressBar {
                        Layout.fillWidth: true

                        from: 0
                        to: 128
                        value: deviceDetailPage.device?.chatMix ?? 0
                    }

                    Controls.Label {
                        Layout.leftMargin: Kirigami.Units.smallSpacing

                        text: deviceDetailPage.device?.chatMix ?? ""
                    }
                }
            }
        }
    }

    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Battery")
        visible: batteryFromCard.visible
    }

    KirigamiFormCard.FormCard {
        id: batteryFromCard

        visible: deviceDetailPage.device?.capabilities & Device.Battery ?? false

        KirigamiFormCard.FormTextDelegate {
            text: i18nc("@label", "Battery status")

            description: {
                if (!deviceDetailPage.device)
                    return "";

                switch (deviceDetailPage.device.battery.status) {
                case DeviceBattery.Available:
                    return i18nc("@item battery status", "Available");
                case DeviceBattery.Charging:
                    return i18nc("@item battery status", "Charging");
                default:
                    return i18nc("@item battery status", "Unavailable");
                }
            }
        }

        KirigamiFormCard.AbstractFormDelegate {
            visible: deviceDetailPage.device?.battery.level > -1 ?? false
            hoverEnabled: false
            background: null

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Controls.Label {
                    Layout.fillWidth: true

                    text: i18nc("@label", "Battery level")
                }

                RowLayout {
                    Controls.ProgressBar {
                        Layout.fillWidth: true

                        from: 0
                        to: 100
                        value: deviceDetailPage.device?.battery.level ?? 0
                    }

                    Controls.Label {
                        Layout.leftMargin: Kirigami.Units.smallSpacing

                        text: `${deviceDetailPage.device?.battery.level ?? 0}%`
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

        visible: deviceDetailPage.device?.capabilities & (Device.Light | Device.VoicePrompt | Device.Sidetone | Device.InactiveTime | Device.NotificationSound | Device.VolumeLimiter | Device.SidetoneStatus) ?? false

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

        // What the headset itself reports, when it can be read back. The
        // spinbox above shows the value this app would send; this row shows
        // the one the device actually holds, so a write that never landed is
        // visible instead of being remembered only here.
        KirigamiFormCard.FormTextDelegate {
            id: sidetoneReadBackDelegate

            visible: (deviceDetailPage.device?.capabilities & Device.SidetoneStatus) !== 0
                     && (deviceDetailPage.device?.sidetoneDeviceLevel ?? -1) >= 0
            text: i18nc("@label", "Sidetone stored on the headset")
            description: i18nc("@info:usagetip", "Level %1", deviceDetailPage.device?.sidetoneDeviceLevel ?? 0)
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

            visible: deviceDetailPage.device?.capabilities & Device.Equalizer ?? false
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
    }

    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Parametric equalizer")
        visible: (deviceDetailPage.device?.capabilities & Device.ParametricEqualizer) !== 0
                 && deviceDetailPage.device?.parametricBands?.length > 0
    }

    KirigamiFormCard.FormCard {
        id: parametricCard

        visible: (deviceDetailPage.device?.capabilities & Device.ParametricEqualizer) !== 0
                 && deviceDetailPage.device?.parametricBands?.length > 0

        // One row per band. The limits come from the headset (gain range and
        // step, Q range, frequency range) rather than from numbers guessed
        // here, so a control can never send a value the device would refuse.
        Repeater {
            model: deviceDetailPage.device?.parametricBands ?? []

            KirigamiFormCard.AbstractFormDelegate {
                id: bandDelegate

                required property int index
                required property var modelData

                readonly property var limits: deviceDetailPage.device?.parametricLimits ?? ({})
                readonly property var filterTypes: limits.filterTypes ?? ["peaking"]

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        Layout.fillWidth: true
                        text: i18nc("@label", "Band %1", bandDelegate.index + 1)
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18nc("@label", "Frequency, gain and Q")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Controls.SpinBox {
                            Layout.fillWidth: true
                            from: bandDelegate.limits.freqMin ?? 20
                            to: bandDelegate.limits.freqMax ?? 20000
                            stepSize: 1
                            editable: true
                            value: bandDelegate.modelData.frequency ?? 0
                            textFromValue: function (v) { return v + " Hz"; }
                            valueFromText: function (t) { return parseInt(t) || 0; }
                            onValueModified: {
                                if (deviceDetailPage.device)
                                    deviceDetailPage.device.setParametricBand(bandDelegate.index, "frequency", value);
                            }
                        }

                        // Gain and Q are fractional, and Qt's SpinBox is
                        // integer-only (its "decimals" went away in Qt 6), so
                        // these are validated text fields instead.
                        Controls.TextField {
                            Layout.fillWidth: true
                            text: Number(bandDelegate.modelData.gain ?? 0).toFixed(1)
                            selectByMouse: true
                            validator: DoubleValidator {
                                bottom: bandDelegate.limits.gainMin ?? -10
                                top: bandDelegate.limits.gainMax ?? 10
                                decimals: 1
                            }
                            onEditingFinished: {
                                const parsed = parseFloat(text);
                                if (deviceDetailPage.device && !isNaN(parsed))
                                    deviceDetailPage.device.setParametricBand(bandDelegate.index, "gain", parsed);
                            }
                        }

                        Controls.TextField {
                            Layout.fillWidth: true
                            text: Number(bandDelegate.modelData.qFactor ?? 1.41).toFixed(2)
                            selectByMouse: true
                            validator: DoubleValidator {
                                bottom: bandDelegate.limits.qMin ?? 0.2
                                top: bandDelegate.limits.qMax ?? 10
                                decimals: 2
                            }
                            onEditingFinished: {
                                const parsed = parseFloat(text);
                                if (deviceDetailPage.device && !isNaN(parsed))
                                    deviceDetailPage.device.setParametricBand(bandDelegate.index, "qFactor", parsed);
                            }
                        }

                        Controls.ComboBox {
                            Layout.fillWidth: true
                            model: bandDelegate.filterTypes
                            currentIndex: Math.max(0, bandDelegate.filterTypes.indexOf(bandDelegate.modelData.type ?? "peaking"))
                            onActivated: function (idx) {
                                if (deviceDetailPage.device)
                                    deviceDetailPage.device.setParametricBand(bandDelegate.index, "type", bandDelegate.filterTypes[idx]);
                            }
                        }
                    }
                }
            }
        }

        KirigamiFormCard.FormButtonDelegate {
            id: parametricApplyDelegate

            text: i18nc("@action:button", "Apply parametric curve")
            onClicked: {
                if (deviceDetailPage.device)
                    deviceDetailPage.device.applyParametricEqualizer();
            }
        }
    }

    KirigamiFormCard.FormHeader {
        title: i18nc("@title:group", "Microphone")
        visible: mircophoneFormCard.visible
    }

    KirigamiFormCard.FormCard {
        id: mircophoneFormCard

        visible: deviceDetailPage.device?.capabilities & (Device.MicrophoneMuteLedBrightness | Device.MicrophoneVolume) ?? false

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
}
