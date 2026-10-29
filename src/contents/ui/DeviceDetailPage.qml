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

    /// Magnitude response of one band at one frequency, in dB. RBJ audio EQ
    /// cookbook coefficients evaluated on the unit circle; the sample rate
    /// only has to be comfortably above the top band.
    function bandResponseDb(band: var, frequency: real): real {
        const sampleRate = 48000;
        const f0 = band.frequency ?? 1000;
        const gain = band.gain ?? 0;
        const q = Math.max(0.1, band.qFactor ?? 1.41);
        const type = band.type ?? "peaking";
        const a = Math.pow(10, gain / 40);
        const w0 = 2 * Math.PI * f0 / sampleRate;
        const cosW0 = Math.cos(w0);
        const sinW0 = Math.sin(w0);

        let b0, b1, b2, a0, a1, a2;

        if (type === "lowshelf" || type === "highshelf") {
            const alpha = sinW0 / 2 * Math.sqrt((a + 1 / a) * (1 / q - 1) + 2);
            const beta = 2 * Math.sqrt(a) * alpha;
            if (type === "lowshelf") {
                b0 = a * ((a + 1) - (a - 1) * cosW0 + beta);
                b1 = 2 * a * ((a - 1) - (a + 1) * cosW0);
                b2 = a * ((a + 1) - (a - 1) * cosW0 - beta);
                a0 = (a + 1) + (a - 1) * cosW0 + beta;
                a1 = -2 * ((a - 1) + (a + 1) * cosW0);
                a2 = (a + 1) + (a - 1) * cosW0 - beta;
            } else {
                b0 = a * ((a + 1) + (a - 1) * cosW0 + beta);
                b1 = -2 * a * ((a - 1) + (a + 1) * cosW0);
                b2 = a * ((a + 1) + (a - 1) * cosW0 - beta);
                a0 = (a + 1) - (a - 1) * cosW0 + beta;
                a1 = 2 * ((a - 1) - (a + 1) * cosW0);
                a2 = (a + 1) - (a - 1) * cosW0 - beta;
            }
        } else {
            const alpha = sinW0 / (2 * q);
            b0 = 1 + alpha * a;
            b1 = -2 * cosW0;
            b2 = 1 - alpha * a;
            a0 = 1 + alpha / a;
            a1 = -2 * cosW0;
            a2 = 1 - alpha / a;
        }

        const w = 2 * Math.PI * frequency / sampleRate;
        const cosW = Math.cos(w);
        const sinW = Math.sin(w);
        const numeratorReal = b0 + b1 * cosW + b2 * Math.cos(2 * w);
        const numeratorImaginary = -(b1 * sinW + b2 * Math.sin(2 * w));
        const denominatorReal = a0 + a1 * cosW + a2 * Math.cos(2 * w);
        const denominatorImaginary = -(a1 * sinW + a2 * Math.sin(2 * w));
        const numerator = numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary;
        const denominator = denominatorReal * denominatorReal + denominatorImaginary * denominatorImaginary;
        if (numerator <= 0 || denominator <= 0)
            return 0;
        return 10 * Math.log(numerator / denominator) / Math.LN10;
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


    // One card for the whole headset: identity, the readings, the
    // configurations and the equalizer, separated by rules rather than split
    // into boxes that each need a heading.
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
                        id: chatMixLabel

                        font: Kirigami.Theme.smallFont
                        text: i18nc("@label", "Chat-Mix")

                        HoverHandler {
                            id: chatMixHover
                        }

                        // headsetcontrol exposes chat-mix as a read only
                        // value: the balance is reported by the headset and
                        // there is no command to set it, so this row is a
                        // reading and not a control.
                        Controls.ToolTip.visible: chatMixHover.hovered
                        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
                        Controls.ToolTip.text: i18nc("@info:tooltip", "Reported by the headset; headsetcontrol cannot set it")
                    }

                    Controls.ProgressBar {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
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
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2

                        from: 0
                        to: 100
                        value: deviceDetailPage.device?.battery.level ?? 0
                    }

                    Controls.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
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

        KirigamiFormCard.FormDelegateSeparator {
        }

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
        // silently, so the slider runs over the real steps rather than over a
        // free 0..128 range.
        FormSliderDelegate {
            id: sidetoneSliderDelegate

            readonly property var levels: deviceDetailPage.device?.sidetoneLevels ?? []

            visible: (deviceDetailPage.device?.capabilities & Device.Sidetone ?? false) && levels.length > 1
            text: i18nc("@label:slider", "Sidetone")
            description: (deviceDetailPage.device?.capabilities & Device.SidetoneStatus) !== 0
            && (deviceDetailPage.device?.sidetoneDeviceLevel ?? -1) >= 0
            ? i18nc("@info:usagetip", "Headset reports level %1",
                    deviceDetailPage.device?.sidetoneDeviceLevel ?? 0)
            : ""

            from: 0
            to: Math.max(0, levels.length - 1)
            stepSize: 1
            value: Math.max(0, levels.indexOf(deviceDetailPage.device?.sidetone ?? 0))
            valueText: levels.length > 0 ? String(levels[Math.round(value)] ?? 0) : ""

            onMoved: {
                if (deviceDetailPage.device && levels.length > 0)
                    deviceDetailPage.device.sidetone = levels[Math.round(value)];
            }
        }

        KirigamiFormCard.FormSpinBoxDelegate {
            id: sidetoneDelegate

            label: i18nc("@label:spinbox", "Sidetone")
            from: 0
            to: 128
            visible: (deviceDetailPage.device?.capabilities & Device.Sidetone ?? false)
            && (deviceDetailPage.device?.sidetoneLevels?.length ?? 0) <= 1

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

        KirigamiFormCard.FormDelegateSeparator {
        }

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

            visible: parametricSectionVisible
            hoverEnabled: false
            background: null

            readonly property var limits: deviceDetailPage.device?.parametricLimits ?? ({})
            readonly property var bands: deviceDetailPage.device?.parametricBands ?? []
            readonly property real gainMin: limits.gainMin ?? -10
            readonly property real gainMax: limits.gainMax ?? 10
            readonly property real gainStep: limits.gainStep ?? 0.5
            /// Fixed, so the curve behind the faders can be drawn against
            /// the same track the faders use.
            readonly property real columnLabelHeight: Kirigami.Units.gridUnit * 1.0
            readonly property real faderPadding: Kirigami.Units.gridUnit * 0.55
            readonly property real faderHeight: Kirigami.Units.gridUnit * 9

            contentItem: Item {
                implicitHeight: faderRow.implicitHeight

                // The sum of every band's response, drawn behind the faders so
                // the shape of what is being applied is visible while dragging:
                // a shelf is not a bell, and Q shows up as sharpness.
                Canvas {
                    id: responseCanvas

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Kirigami.Units.gridUnit * 1.6 + Kirigami.Units.smallSpacing
                    anchors.rightMargin: Kirigami.Units.gridUnit * 1.6 + Kirigami.Units.smallSpacing
                    anchors.topMargin: faderBankDelegate.columnLabelHeight + Kirigami.Units.smallSpacing / 2
                    + faderBankDelegate.faderPadding
                    anchors.bottomMargin: faderBankDelegate.columnLabelHeight + Kirigami.Units.smallSpacing / 2
                    + faderBankDelegate.faderPadding

                    renderStrategy: Canvas.Immediate

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    Connections {
                        target: faderBankDelegate

                        function onBandsChanged() {
                            responseCanvas.requestPaint();
                        }
                    }

                    onPaint: {
                        const context = getContext("2d");
                        context.clearRect(0, 0, width, height);

                        const bands = faderBankDelegate.bands;
                        if (bands.length < 2 || width < 8 || height < 8)
                            return;

                        const first = bands[0].frequency ?? 32;
                        const last = bands[bands.length - 1].frequency ?? 16000;
                        const range = Math.max(6, faderBankDelegate.gainMax - faderBankDelegate.gainMin);
                        const middle = height / 2;

                        // Zero line, so the drawn curve has something to be
                        // read against.
                        context.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r,
                                Kirigami.Theme.textColor.g,
                                Kirigami.Theme.textColor.b, 0.15);
                        context.lineWidth = 1;
                        context.beginPath();
                        context.moveTo(0, middle);
                        context.lineTo(width, middle);
                        context.stroke();

                        context.strokeStyle = Qt.rgba(Kirigami.Theme.highlightColor.r,
                                Kirigami.Theme.highlightColor.g,
                                Kirigami.Theme.highlightColor.b, 0.9);
                        context.lineWidth = 2;
                        context.lineJoin = "round";
                        context.beginPath();

                        const steps = 120;
                        for (let step = 0; step <= steps; ++step) {
                            const t = step / steps;
                            const frequency = first * Math.pow(last / first, t);
                            let decibels = 0;
                            for (const band of bands) {
                                decibels += deviceDetailPage.bandResponseDb(band, frequency);
                            }
                            const x = t * width;
                            const y = middle - (decibels / range) * height;
                            if (step === 0)
                                context.moveTo(x, y);
                            else
                            context.lineTo(x, y);
                        }
                        context.stroke();
                    }
                }

                RowLayout {
                    id: faderRow

                    anchors.fill: parent
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
                                Layout.preferredHeight: faderBankDelegate.columnLabelHeight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
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

                            // A fader in the hardware sense: absolute position,
                            // boost up, cut down. Qt's vertical slider runs the
                            // other way and positions its own handle, so the
                            // geometry here is explicit instead.
                            Item {
                                id: gainFader

                                readonly property real trackInset: faderBankDelegate.faderPadding
                                readonly property real trackHeight: height - 2 * trackInset
                                readonly property real gainSpan: Math.max(0.001, faderBankDelegate.gainMax - faderBankDelegate.gainMin)
                                readonly property real normalised: (faderColumn.bandGain - faderBankDelegate.gainMin) / gainSpan

                                /// Where the drag started, so a slow drag is not
                                /// eaten by rounding.
                                property real dragStartGain: faderColumn.bandGain

                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: faderBankDelegate.faderHeight

                                Rectangle {
                                    x: Math.round((parent.width - width) / 2)
                                    y: gainFader.trackInset
                                    width: Kirigami.Units.gridUnit * 0.4
                                    height: gainFader.trackHeight
                                    radius: width / 2
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                }

                                Rectangle {
                                    id: faderCap

                                    readonly property real travel: gainFader.trackHeight - height

                                    x: Math.round((gainFader.width - width) / 2)
                                    y: gainFader.trackInset + (1.0 - Math.max(0, Math.min(1, gainFader.normalised))) * travel
                                    width: Kirigami.Units.gridUnit * 1.4
                                    height: Kirigami.Units.gridUnit * 1.1
                                    radius: Math.min(width, height) / 4
                                    color: faderDrag.active
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

                                function commit(): void {
                                    if (!deviceDetailPage.device)
                                        return;
                                    deviceDetailPage.device.setParametricBand(faderColumn.index, "gain", faderColumn.bandGain);
                                    deviceDetailPage.device.applyParametricEqualizer();
                                }

                                function gainAt(y: real): real {
                                    const travel = Math.max(1, trackHeight - faderCap.height);
                                    const ratio = Math.max(0, Math.min(1, 1.0 - (y - trackInset) / travel));
                                    const raw = faderBankDelegate.gainMin + ratio * gainSpan;
                                    const step = Math.max(0.01, faderBankDelegate.gainStep);
                                    return Math.round(raw / step) * step;
                                }

                                DragHandler {
                                    id: faderDrag

                                    target: null
                                    xAxis.enabled: false
                                    cursorShape: Qt.SplitVCursor

                                    onActiveChanged: {
                                        if (active) {
                                            gainFader.dragStartGain = faderColumn.bandGain;
                                            deviceDetailPage.selectedBand = faderColumn.index;
                                        } else {
                                            gainFader.commit();
                                        }
                                    }

                                    onTranslationChanged: {
                                        if (!active)
                                            return;
                                        const travel = Math.max(1, gainFader.trackHeight - faderCap.height);
                                        const delta = -translation.y / travel * gainFader.gainSpan;
                                        const step = Math.max(0.01, faderBankDelegate.gainStep);
                                        const next = gainFader.dragStartGain + delta;
                                        faderColumn.bandGain = Math.round(next / step) * step;
                                    }
                                }

                                TapHandler {
                                    onTapped: function (eventPoint) {
                                        deviceDetailPage.selectedBand = faderColumn.index;
                                        faderColumn.bandGain = gainFader.gainAt(eventPoint.position.y);
                                        gainFader.commit();
                                    }
                                }
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                Layout.preferredHeight: faderBankDelegate.columnLabelHeight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
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
}
