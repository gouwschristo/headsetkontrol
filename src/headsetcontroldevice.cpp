#include "headsetcontroldevice.h"

#include <QTimer>

#include <KLocalizedString>

#include "headsetcontrol.h"
#include "headsetkontrolconfig.h"

using namespace Qt::Literals::StringLiterals;

namespace
{
/// JSON arrays of numbers arrive as QVariantList; convert once, in one place.
QList<int> intList(const QVariantList &values)
{
    QList<int> out;
    out.reserve(values.size());
    for (const QVariant &value : values) {
        out.append(value.toInt());
    }
    return out;
}
} // namespace

HeadsetControlDevice::HeadsetControlDevice(HeadsetControl *parent)
    : QObject{parent}
    , m_battery{new HeadsetControlDeviceBattery(this)}
    , m_sidetoneDeviceLevel{-1}
    , m_headsetControl{parent}
{
    m_reApplyAction = new QAction(this);
    m_reApplyAction->setIcon(QIcon::fromTheme(u"dialog-ok-apply"_s));
    m_reApplyAction->setText(i18nc("@action apply all", "Re-apply all"));
    m_reApplyAction->setToolTip(i18nc("@info:tooltip apply all", "Re-apply all settings"));
    connect(m_reApplyAction, &QAction::triggered, this, &HeadsetControlDevice::reApply);

    m_setPrimaryAction = new QAction(this);
    m_setPrimaryAction->setIcon(QIcon::fromTheme(u"favorite"_s));
    m_setPrimaryAction->setCheckable(true);
    m_setPrimaryAction->setText(i18nc("@action", "Mark as primary"));
    m_setPrimaryAction->setToolTip(i18nc("@info:tooltip apply all", "Mark device as primary device"));
    connect(m_setPrimaryAction, &QAction::triggered, this, &HeadsetControlDevice::setPrimary);
    connect(HeadsetKontrolConfig::instance(), &HeadsetKontrolConfig::PrimaryChanged, this, [this]() {
        bool isPrimary = false;
        auto primary = HeadsetKontrolConfig::instance()->primary();
        if (primary.length() > 0 && primary.at(0) == vendorId()) {
            if (primary.length() > 1 && primary.at(1) == productId()) {
                isPrimary = true;
            }
        }
        m_setPrimaryAction->setChecked(isPrimary);
    });
}

HeadsetControlDevice::~HeadsetControlDevice()
{
}

HeadsetControlDeviceBattery *HeadsetControlDevice::battery() const
{
    return m_battery;
}

int HeadsetControlDevice::chatMix() const
{
    return m_chatMix;
}

void HeadsetControlDevice::setChatMix(int newChatMix)
{
    if (m_chatMix == newChatMix)
        return;
    m_chatMix = newChatMix;
    Q_EMIT chatMixChanged();
}

HeadsetControlDevice::Capabilities HeadsetControlDevice::capabilities() const
{
    return m_capabilities;
}

void HeadsetControlDevice::setCapabilities(const QStringList &newCapabilities)
{
    Capabilities cap;
    if (newCapabilities.contains(u"CAP_SIDETONE"_s)) {
        cap |= Sidetone;
    }

    if (newCapabilities.contains(u"CAP_BATTERY_STATUS"_s)) {
        cap |= Battery;
    }

    if (newCapabilities.contains(u"CAP_NOTIFICATION_SOUND"_s)) {
        cap |= NotificationSound;
    }

    if (newCapabilities.contains(u"CAP_LIGHTS"_s)) {
        cap |= Light;
    }

    if (newCapabilities.contains(u"CAP_INACTIVE_TIME"_s)) {
        cap |= InactiveTime;
    }

    if (newCapabilities.contains(u"CAP_CHATMIX_STATUS"_s)) {
        cap |= ChatMix;
    }

    if (newCapabilities.contains(u"CAP_VOICE_PROMPTS"_s)) {
        cap |= VoicePrompt;
    }

    if (newCapabilities.contains(u"CAP_ROTATE_TO_MUTE"_s)) {
        cap |= RotateToMute;
    }

    if (newCapabilities.contains(u"CAP_EQUALIZER_PRESET"_s)) {
        cap |= EqualizerPreset;
    }

    if (newCapabilities.contains(u"CAP_EQUALIZER"_s)) {
        cap |= Equalizer;
    }

    if (newCapabilities.contains(u"CAP_MICROPHONE_MUTE_LED_BRIGHTNESS"_s)) {
        cap |= MicrophoneMuteLedBrightness;
    }

    if (newCapabilities.contains(u"CAP_MICROPHONE_VOLUME"_s)) {
        cap |= MicrophoneVolume;
    }

    if (newCapabilities.contains(u"CAP_VOLUME_LIMITER"_s)) {
        cap |= VolumeLimiter;
    }

    if (newCapabilities.contains(u"CAP_SIDETONE_STATUS"_s)) {
        cap |= SidetoneStatus;
    }

    if (newCapabilities.contains(u"CAP_PARAMETRIC_EQUALIZER"_s)) {
        cap |= ParametricEqualizer;
    }

    if (m_capabilities == cap)
        return;
    m_capabilities = cap;
    Q_EMIT capabilitiesChanged();
}

QString HeadsetControlDevice::device() const
{
    return m_device;
}

void HeadsetControlDevice::setDevice(const QString &newDevice)
{
    if (m_device == newDevice)
        return;
    m_device = newDevice;
    Q_EMIT deviceChanged();
}

QString HeadsetControlDevice::vendor() const
{
    return m_vendor;
}

void HeadsetControlDevice::setVendor(const QString &newVendor)
{
    if (m_vendor == newVendor)
        return;
    m_vendor = newVendor;
    Q_EMIT vendorChanged();
}

QString HeadsetControlDevice::product() const
{
    return m_product;
}

QString HeadsetControlDevice::vendorId() const
{
    return m_vendorId;
}

void HeadsetControlDevice::setVendorId(const QString &newVendorId)
{
    if (m_vendorId == newVendorId)
        return;
    m_vendorId = newVendorId;
    Q_EMIT vendorIdChanged();
}

QString HeadsetControlDevice::productId() const
{
    return m_productId;
}

void HeadsetControlDevice::update(const QVariantHash &hash)
{
    setStatus(hash.value(u"status"_s, QString()).toString());
    setDevice(hash.value(u"device"_s, QString()).toString());
    setVendor(hash.value(u"vendor"_s, QString()).toString());
    setProduct(hash.value(u"product"_s, QString()).toString());
    setVendorId(hash.value(u"id_vendor"_s, QString()).toString());
    setProductId(hash.value(u"id_product"_s, QString()).toString());
    // A write answers with an action result, not a state snapshot: `-o json -s
    // 40` carries the identity and the capabilities but no battery, chat-mix or
    // sidetone. Reading the absent keys as defaults would blank the panel for a
    // poll cycle every time a control is used, which looks exactly like the
    // headset disconnecting and coming back. So state is only applied when the
    // response actually carries it.
    if (hash.contains(u"chatmix"_s))
        setChatMix(hash.value(u"chatmix"_s).toInt());
    if (hash.contains(u"capabilities"_s))
        setCapabilities(hash.value(u"capabilities"_s, QStringList()).toStringList());
    // The headset answers with the level it actually stores (headsetcontrol
    // reports it as sidetone.device_level when the family can be read back).
    // Shown next to the control so a value that never reached the device is
    // visible instead of only being remembered by this app.
    if (hash.contains(u"sidetone"_s)) {
        const QVariantHash sidetone = hash.value(u"sidetone"_s).toHash();
        setSidetoneDeviceLevel(sidetone.value(u"device_level"_s, -1).toInt());
    }
    // Preset names in the order --equalizer-preset indexes them. The
    // equalizer_presets object cannot be used for this: its key order is not
    // preserved by every JSON reader (Qt sorts object keys), so the Nth name
    // would not be the Nth preset. Older headsetcontrol builds do not emit
    // the array, and the UI falls back to "Preset N".
    if (hash.contains(u"equalizer_presets_ordered"_s))
        setEqualizerPresetNames(hash.value(u"equalizer_presets_ordered"_s, QStringList()).toStringList());

    // Parametric equalizer: the limits come from the device. The bands only do
    // when the family can be read back; otherwise the editor starts from the
    // family's own default frequencies, so it can never invent a layout the
    // headset does not have.
    if (hash.contains(u"parametric_equalizer"_s)) {
        const QVariantHash peq = hash.value(u"parametric_equalizer"_s).toHash();

        QVariantMap limits;
        limits.insert(u"bands"_s, peq.value(u"bands"_s).toInt());

        const QVariantHash gain = peq.value(u"gain"_s).toHash();
        limits.insert(u"gainMin"_s, gain.value(u"min"_s).toDouble());
        limits.insert(u"gainMax"_s, gain.value(u"max"_s).toDouble());
        limits.insert(u"gainStep"_s, gain.value(u"step"_s, 0.5).toDouble());

        const QVariantHash q = peq.value(u"q_factor"_s).toHash();
        limits.insert(u"qMin"_s, q.value(u"min"_s, 0.2).toDouble());
        limits.insert(u"qMax"_s, q.value(u"max"_s, 10.0).toDouble());

        const QVariantHash freq = peq.value(u"frequency"_s).toHash();
        limits.insert(u"freqMin"_s, freq.value(u"min"_s, 20).toInt());
        limits.insert(u"freqMax"_s, freq.value(u"max"_s, 20000).toInt());

        limits.insert(u"filterTypes"_s, peq.value(u"filter_types"_s).toStringList());
        limits.insert(u"defaultFrequencies"_s, QVariant::fromValue(intList(peq.value(u"default_frequencies"_s).toList())));
        setParametricLimits(limits);

        QVariantList bands;
        const QVariantList deviceBands = peq.value(u"current_bands"_s).toList();
        for (const QVariant &entry : deviceBands) {
            const QVariantHash band = entry.toHash();
            if (!band.contains(u"frequency"_s))
                continue;
            QVariantMap model;
            model.insert(u"frequency"_s, band.value(u"frequency"_s).toDouble());
            model.insert(u"gain"_s, band.value(u"gain"_s).toDouble());
            model.insert(u"qFactor"_s, band.value(u"q_factor"_s, 1.41).toDouble());
            model.insert(u"type"_s, band.value(u"type"_s, u"peaking"_s).toString());
            bands.append(model);
        }

        if (bands.isEmpty()) {
            const QList<int> defaults = intList(peq.value(u"default_frequencies"_s).toList());
            for (const int frequency : defaults) {
                QVariantMap model;
                model.insert(u"frequency"_s, frequency);
                model.insert(u"gain"_s, 0.0);
                model.insert(u"qFactor"_s, 1.41);
                model.insert(u"type"_s, u"peaking"_s);
                bands.append(model);
            }
        }
        setParametricBands(bands);
    }

    // Some devices quantise sidetone: the Nova 5 has 11 steps between 0 and
    // 128, and every other value is silently snapped. Offering the real steps
    // is the difference between a control that means something and one that
    // guesses for the user.
    if (hash.contains(u"sidetone"_s)) {
        QList<int> levels;
        const QVariantList raw = hash.value(u"sidetone"_s).toHash().value(u"levels"_s).toList();
        levels.reserve(raw.size());
        for (const QVariant &level : raw) {
            levels.append(level.toInt());
        }
        setSidetoneLevels(levels);
    }
    if (hash.contains(u"battery"_s))
        battery()->update(hash.value(u"battery"_s).toHash());

    if (product().length() > 0) {
        m_setPrimaryAction->setData(product());
    } else {
        m_setPrimaryAction->setData(device());
    }

    bool isPrimary = false;
    auto primary = HeadsetKontrolConfig::instance()->primary();
    if (primary.length() > 0 && primary.at(0) == vendorId()) {
        if (primary.length() > 1 && primary.at(1) == productId()) {
            isPrimary = true;
        }
    }
    m_setPrimaryAction->setChecked(isPrimary);

    auto errors = hash.value(u"errors"_s, QString()).toStringList();
    for (auto const &error : std::as_const(errors)) {
        Q_EMIT errorOccurred(error);
    }
}

HeadsetControlDevice::Status HeadsetControlDevice::status() const
{
    return m_status;
}

bool HeadsetControlDevice::light() const
{
    return readConfig(u"Light"_s, true).toBool();
}

void HeadsetControlDevice::setLight(bool state)
{
    applyLight(state);
}

bool HeadsetControlDevice::voicePrompt() const
{
    return readConfig(u"VoicePrompt"_s, true).toBool();
}

void HeadsetControlDevice::setVoicePrompt(bool state)
{
    applyVoicePrompt(state);
}

int HeadsetControlDevice::sidetone() const
{
    return readConfig(u"Sidetone"_s, 0).toInt();
}

void HeadsetControlDevice::setSidetone(int level)
{
    applySidetone(level);
}

int HeadsetControlDevice::inactiveTime() const
{
    return readConfig(u"InactiveTime"_s, 10).toInt();
}

void HeadsetControlDevice::setInactiveTime(int time)
{
    applyInactiveTime(time);
}

QString HeadsetControlDevice::equalizer() const
{
    return readConfig(u"Equalizer"_s, QString()).toString();
}

void HeadsetControlDevice::setEqualizer(const QString &eqString)
{
    applyEqualizer(eqString);
}

int HeadsetControlDevice::equalizerPreset() const
{
    return readConfig(u"EqualizerPreset"_s, 0).toInt();
}

void HeadsetControlDevice::setEqualizerPreset(int equalizerPreset)
{
    applyEqualizerPreset(equalizerPreset);
}

bool HeadsetControlDevice::rotateToMute() const
{
    return readConfig(u"RotateToMute"_s, true).toBool();
}

void HeadsetControlDevice::setRotateToMute(bool state)
{
    applyRotateToMute(state);
}

int HeadsetControlDevice::microphoneBrightness() const
{
    return readConfig(u"MicrophonBrightness"_s, 3).toInt();
}

void HeadsetControlDevice::setMicrophoneBrightness(int brightness)
{
    applyMicrophoneBrightness(brightness);
}

int HeadsetControlDevice::microphoneVolume() const
{
    return readConfig(u"MicrophonVolume"_s, 128).toInt();
}

void HeadsetControlDevice::setMicrophoneVolume(int volume)
{
    applyMicrophoneVolume(volume);
}

bool HeadsetControlDevice::volumeLimiter() const
{
    return readConfig(u"VolumeLimiter"_s, false).toBool();
}

void HeadsetControlDevice::setVolumeLimiter(bool state)
{
    applyVolumeLimiter(state);
}

int HeadsetControlDevice::sidetoneDeviceLevel() const
{
    return m_sidetoneDeviceLevel;
}

QStringList HeadsetControlDevice::equalizerPresetNames() const
{
    return m_equalizerPresetNames;
}

QList<int> HeadsetControlDevice::sidetoneLevels() const
{
    return m_sidetoneLevels;
}

void HeadsetControlDevice::setSidetoneLevels(const QList<int> &levels)
{
    if (m_sidetoneLevels == levels)
        return;
    m_sidetoneLevels = levels;
    Q_EMIT sidetoneLevelsChanged();
}

QVariantList HeadsetControlDevice::parametricBands() const
{
    return m_parametricBands;
}

QVariantMap HeadsetControlDevice::parametricLimits() const
{
    return m_parametricLimits;
}

void HeadsetControlDevice::setParametricBands(const QVariantList &bands)
{
    if (m_parametricBands == bands)
        return;
    m_parametricBands = bands;
    Q_EMIT parametricBandsChanged();
}

void HeadsetControlDevice::setParametricLimits(const QVariantMap &limits)
{
    if (m_parametricLimits == limits)
        return;
    m_parametricLimits = limits;
    Q_EMIT parametricLimitsChanged();
}

void HeadsetControlDevice::setParametricBand(int index, const QString &field, const QVariant &value)
{
    if (index < 0 || index >= m_parametricBands.size())
        return;

    QVariantMap band = m_parametricBands.at(index).toMap();
    if (!band.contains(field) || band.value(field) == value)
        return;

    band.insert(field, value);
    m_parametricBands[index] = band;
    Q_EMIT parametricBandsChanged();
}

QString HeadsetControlDevice::parametricEqualizerArgument() const
{
    // headsetcontrol's format: FREQ,GAIN,Q,TYPE;FREQ,GAIN,Q,TYPE;...
    QStringList bands;
    bands.reserve(m_parametricBands.size());
    for (const QVariant &entry : m_parametricBands) {
        const QVariantMap band = entry.toMap();
        bands.append(QStringLiteral("%1,%2,%3,%4")
                         .arg(band.value(u"frequency"_s).toDouble(), 0, 'f', 0)
                         .arg(band.value(u"gain"_s).toDouble(), 0, 'f', 1)
                         .arg(band.value(u"qFactor"_s).toDouble(), 0, 'f', 2)
                         .arg(band.value(u"type"_s).toString()));
    }
    return bands.join(u';');
}

void HeadsetControlDevice::applyParametricEqualizer()
{
    if (!m_capabilities.testFlag(ParametricEqualizer) || m_parametricBands.isEmpty())
        return;

    const QString argument = parametricEqualizerArgument();
    writeConfig(u"ParametricEqualizer"_s, argument);
    m_headsetControl->queue(u"--parametric-equalizer"_s, argument);
}

void HeadsetControlDevice::setEqualizerPresetNames(const QStringList &names)
{
    if (m_equalizerPresetNames == names)
        return;
    m_equalizerPresetNames = names;
    Q_EMIT equalizerPresetNamesChanged();
}

void HeadsetControlDevice::setSidetoneDeviceLevel(int level)
{
    if (m_sidetoneDeviceLevel == level)
        return;
    m_sidetoneDeviceLevel = level;
    Q_EMIT sidetoneDeviceLevelChanged();
}

QAction *HeadsetControlDevice::reApplyAction() const
{
    return m_reApplyAction;
}

QAction *HeadsetControlDevice::setPrimaryAction() const
{
    return m_setPrimaryAction;
}

void HeadsetControlDevice::playNotification(const QString &audioId)
{
    if (m_capabilities.testFlag(NotificationSound)) {
        if (audioId.isEmpty())
            return;
        m_headsetControl->queue(u"--notificate"_s, audioId.isEmpty());
    }
}

void HeadsetControlDevice::reApply()
{
    applyLight(light(), true);
    applyVoicePrompt(voicePrompt(), true);
    applySidetone(sidetone(), true);
    applyInactiveTime(inactiveTime(), true);
    applyEqualizer(equalizer(), true);
    applyEqualizerPreset(equalizerPreset(), true);
    applyVolumeLimiter(volumeLimiter(), true);
    applyParametricEqualizer();
    applyRotateToMute(rotateToMute(), true);
    applyMicrophoneBrightness(microphoneBrightness(), true);
    applyMicrophoneVolume(microphoneVolume(), true);
}

void HeadsetControlDevice::setPrimary()
{
    HeadsetKontrolConfig::instance()->setPrimary({vendorId(), productId()});
}

void HeadsetControlDevice::setStatus(const QString &newStatus)
{
    Status stat = Failure;
    if (newStatus == u"partial"_s)
        stat = Partial;
    else if (newStatus == u"success"_s)
        stat = Success;

    if (m_status == stat)
        return;
    m_status = stat;
    Q_EMIT statusChanged();
}

void HeadsetControlDevice::applyLight(bool state, bool force)
{
    if (m_capabilities.testFlag(Light)) {
        if (light() == state && !force)
            return;

        writeConfig(u"Light"_s, state);
        Q_EMIT lightChanged();

        m_headsetControl->queue(u"--light"_s, state ? u"1"_s : u"0"_s);
    }
}

void HeadsetControlDevice::applyVoicePrompt(bool state, bool force)
{
    if (m_capabilities.testFlag(VoicePrompt)) {
        if (voicePrompt() == state && !force)
            return;

        writeConfig(u"VoicePrompt"_s, state);
        Q_EMIT voicePromptChanged();

        m_headsetControl->queue(u"--voice-prompt"_s, state ? u"1"_s : u"0"_s);
    }
}

void HeadsetControlDevice::applySidetone(int level, bool force)
{
    if (m_capabilities.testFlag(Sidetone)) {
        if (sidetone() == level && !force)
            return;

        writeConfig(u"Sidetone"_s, level);
        Q_EMIT sidetoneChanged();

        m_headsetControl->queue(u"--sidetone"_s, QString::number(level));
    }
}

void HeadsetControlDevice::applyInactiveTime(int time, bool force)
{
    if (m_capabilities.testFlag(InactiveTime)) {
        if (inactiveTime() == time && !force)
            return;

        writeConfig(u"InactiveTime"_s, time);
        Q_EMIT inactiveTimeChanged();

        m_headsetControl->queue(u"--inactive-time"_s, QString::number(time));
    }
}

void HeadsetControlDevice::applyEqualizer(const QString &eqString, bool force)
{
    if (m_capabilities.testFlag(Equalizer)) {
        if (eqString.isEmpty())
            return;

        if (equalizer() == eqString && !force)
            return;

        writeConfig(u"Equalizer"_s, eqString);
        Q_EMIT equalizerChanged();

        m_headsetControl->queue(u"--equalizer"_s, eqString);
    }
}

void HeadsetControlDevice::applyEqualizerPreset(int equalizerPreset, bool force)
{
    if (m_capabilities.testFlag(EqualizerPreset)) {
        if (equalizerPreset < 0 || equalizerPreset > 3)
            return;

        if (this->equalizerPreset() == equalizerPreset && !force)
            return;

        writeConfig(u"EqualizerPreset"_s, equalizerPreset);
        Q_EMIT equalizerPresetChanged();

        m_headsetControl->queue(u"--equalizer-preset"_s, QString::number(equalizerPreset));
    }
}

void HeadsetControlDevice::applyRotateToMute(bool state, bool force)
{
    if (m_capabilities.testFlag(RotateToMute)) {
        if (rotateToMute() == state && !force)
            return;

        writeConfig(u"RotateToMute"_s, state);
        Q_EMIT rotateToMuteChanged();

        m_headsetControl->queue(u"--rotate-to-mute"_s, state ? u"1"_s : u"0"_s);
    }
}

void HeadsetControlDevice::applyMicrophoneBrightness(int brightness, bool force)
{
    if (m_capabilities.testFlag(MicrophoneMuteLedBrightness)) {
        if (brightness < 0 || brightness > 3)
            return;

        if (microphoneBrightness() == brightness && !force)
            return;

        writeConfig(u"MicrophonBrightness"_s, brightness);
        Q_EMIT microphoneBrightnessChanged();

        m_headsetControl->queue(u"--microphone-mute-led-brightness"_s, QString::number(brightness));
    }
}

void HeadsetControlDevice::applyMicrophoneVolume(int volume, bool force)
{
    if (m_capabilities.testFlag(MicrophoneVolume)) {
        if (volume < 0 || volume > 128)
            return;

        if (microphoneVolume() == volume && !force)
            return;

        writeConfig(u"MicrophonVolume"_s, volume);
        Q_EMIT microphoneVolumeChanged();

        m_headsetControl->queue(u"--microphone-volume"_s, QString::number(volume));
    }
}

void HeadsetControlDevice::applyVolumeLimiter(bool state, bool force)
{
    if (m_capabilities.testFlag(VolumeLimiter)) {
        if (volumeLimiter() == state && !force)
            return;

        writeConfig(u"VolumeLimiter"_s, state);
        Q_EMIT volumeLimiterChanged();

        // headsetcontrol takes this as an explicit 0/1 rather than a flag.
        m_headsetControl->queue(u"--volume-limiter"_s, state ? u"1"_s : u"0"_s);
    }
}

void HeadsetControlDevice::writeConfig(const QString &key, const QVariant &value)
{
    auto vendorConfigGroup = HeadsetKontrolConfig::instance()->config()->group(vendorId());
    auto productConfigGroup = vendorConfigGroup.group(productId());
    productConfigGroup.writeEntry(key, value);
}

QVariant HeadsetControlDevice::readConfig(const QString &key, const QVariant &defaultValue) const
{
    auto vendorConfigGroup = HeadsetKontrolConfig::instance()->config()->group(vendorId());
    auto productConfigGroup = vendorConfigGroup.group(productId());
    return productConfigGroup.readEntry(key, defaultValue);
}

void HeadsetControlDevice::setProductId(const QString &newProductId)
{
    if (m_productId == newProductId)
        return;
    m_productId = newProductId;
    Q_EMIT productIdChanged();
}

void HeadsetControlDevice::setProduct(const QString &newProduct)
{
    if (m_product == newProduct)
        return;
    m_product = newProduct;
    Q_EMIT productChanged();
}
