import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.statefulapp as StatefulApplication

import com.gitlab.thebill2001.headsetkontrol

StatefulApplication.StatefulWindow {
    id: root

    objectName: "root"

    windowName: i18nc("@title:window", "Control your headset")

    minimumWidth: Kirigami.Units.gridUnit * 50
    minimumHeight: Kirigami.Units.gridUnit * 20

    property Device selectedDevice: null

    application: App {
        id: app

        configurationView: SettingsView {
            id: settingsView

            shortcutModel: app.shortcutsModel
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        id: globalDrawer

        isMenu: true

        actions: [
            Kirigami.Action {
                fromQAction: app.action(App.AboutApp)
            },
            Kirigami.Action {
                fromQAction: app.action(App.ReportBug)
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                fromQAction: app.action(App.KeyBindings)
            },
            Kirigami.Action {
                fromQAction: app.action(App.Preferences)
            },
            Kirigami.Action {
                fromQAction: app.action(App.ConfigureNotifications)
            },
            Kirigami.Action {
                separator: true
            },
            Kirigami.Action {
                fromQAction: app.action(App.Quit)
            }
        ]
    }

    pageStack.initialPage: DevicesPage {
        id: devicesPage

        app: app
    }

    onVisibleChanged: {
        if (visible)
            HeadsetControl.startCountDownUpdateTimer();
        else
            HeadsetControl.stopCountDownUpdateTimer();
    }

    Component.onCompleted: {
        if (Config.runInBackground) {
            root.visible = !Config.startMinimized;
        } else {
            root.visible = true;
        }

        // The device list is only a chooser; the detail page needs the room.
        root.pageStack.defaultColumnWidth = Kirigami.Units.gridUnit * 13;

        root.autoOpenFirstDevice();
    }

    // A single headset should not require a click to see its controls: on the
    // first run, with nothing selected yet, open the first device's page. Only
    // while the user is still looking at the device list, so this never yanks
    // them out of a page they chose, and only once, so going back to the list
    // stays possible.
    property bool autoOpenDone: false

    function autoOpenFirstDevice() {
        if (root.autoOpenDone)
            return;
        if (root.selectedDevice !== null)
            return;
        if (root.pageStack.depth !== 1)
            return;

        const devices = HeadsetControl.devices;
        if (!devices || devices.length < 1)
            return;

        root.autoOpenDone = true;
        root.openDeviceDetailPage(devices[0]);
    }

    Connections {
        target: HeadsetControl

        function onDevicesChanged() {
            root.autoOpenFirstDevice();
        }
    }

    Connections {
        target: app

        function onShowWindow() {
            root.restore();
        }

        function onShowDevice(device) {
            root.restore();
            root.openDeviceDetailPage(device);
        }
    }

    DeviceDetailPage {
        id: deviceDetailPage

        device: root.selectedDevice
    }

    function openSettingsPage(module = null) {
        settingsView.open(module ? module : '');
    }

    function openDeviceDetailPage(device) {
        root.selectedDevice = device;

        while (root.pageStack.depth > 1) {
            root.pageStack.pop();
        }

        root.pageStack.push(deviceDetailPage);
    }

    function restore() {
        root.show();
        root.raise();
    }
}
