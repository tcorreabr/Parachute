import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import org.kde.kwin 2.0 as KWinComponents
import org.kde.plasma.core 2.0 as PlasmaCore

Window {
    id: mainWindow
    flags: Qt.X11BypassWindowManagerHint
    visible: true
    color: "transparent"
    x: activated ? 0 : mainWindow.width * 2
    y: activated ? 0 : mainWindow.height * 2

    property alias endAnimationTimer: endAnimationTimer

    property bool activated: false
    property bool dragging: false
    property real qtVersion
    property int currentDesktop: workspace.currentDesktop - 1 // workspace.currentDesktop is one based
    property bool horizontalDesktopsLayout: configDesktopsBarPlacement === Enums.Position.Top ||
            configDesktopsBarPlacement === Enums.Position.Bottom
    property int easingType: Easing.OutExpo
    property bool animating: false
    property bool idle: activated && !animating
    property bool mustUpdateScreens: true
    property bool showDesktopsBar: activated && easingType === Easing.OutExpo

    // Config
    property bool configBlurBackground
    property bool configShowDesktopsBarBackground
    property bool configShowWindowTitles
    property bool configShowDesktopShadows
    property bool configShowNotificationWindows
    property real configAnimationsDuration
    property int configDesktopsBarPlacement

    // Selection (by mouse or keyboard)
    property var selectedClientItem: null
    property var outsideSelectedClient: null
    property var pointAvoidUpdatingSelection: null
    property bool avoidUpdatingSelection: false

    // Consts
    property int desktopMargin: 5
    property int desktopsBarSpacing: 15
    property int clientsDecorationsHeight: 24
    property color highlightColor: PlasmaCore.Theme.highlightColor
    property color hoverColor: Qt.rgba(PlasmaCore.Theme.buttonHoverColor.r, PlasmaCore.Theme.buttonHoverColor.g,
            PlasmaCore.Theme.buttonHoverColor.b, 0.25)

    Item {
        id: keyboardHandler

        Keys.onPressed: {
            switch (event.key) {
                case Qt.Key_Escape:
                    selectedClientItem = null;
                    toggleActive();
                    break;
                case Qt.Key_Return:
                    if (selectedClientItem) toggleActive();
                    break;
                case Qt.Key_Home:
                    selectFirstClient();
                    break;
                case Qt.Key_End:
                    selectLastClient();
                    break;
                case Qt.Key_Left:
                    selectedClientItem ? selectNextClientOn(Enums.Position.Left) : selectFirstClient();
                    break;
                case Qt.Key_Right:
                    selectedClientItem ? selectNextClientOn(Enums.Position.Right) : selectLastClient();
                    break;
                case Qt.Key_Up:
                    selectedClientItem ? selectNextClientOn(Enums.Position.Top) : selectFirstClient();
                    break;
                case Qt.Key_Down:
                    selectedClientItem ? selectNextClientOn(Enums.Position.Bottom) : selectLastClient();
                    break;
                case Qt.Key_F5:
                    kwinReconfigure.call();
                    break;
            }
            event.accepted = true;
        }
    }

    KWinComponents.ClientModelByScreenAndDesktop {
        id: clientsByScreenAndDesktop
        exclusions: configShowNotificationWindows ?
                KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion |
                KWinComponents.ClientModel.OtherActivitiesExclusion | KWinComponents.ClientModel.DesktopWindowsExclusion :
                KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion |
                KWinComponents.ClientModel.OtherActivitiesExclusion | KWinComponents.ClientModel.DesktopWindowsExclusion |
                KWinComponents.ClientModel.SkipPagerExclusion | KWinComponents.ClientModel.SwitchSwitcherExclusion;
    }

    Repeater {
        id: screensRepeater
        model: workspace.numScreens

        ScreenComponent {}
    }

    KWinComponents.DBusCall {
        id: kwinReconfigure
        service: "org.kde.KWin"; path: "/KWin"; method: "reconfigure";
    }

    Connections {
        target: workspace
        function onClientActivated(client) { getOutsideSelectedClient(); }
        function onNumberScreensChanged(count) { mainWindow.mustUpdateScreens = true; }
        function onScreenResized(screen) { mainWindow.mustUpdateScreens = true; }
        function onCurrentDesktopChanged(desktop, client) { selectedClientItem = null; }
    }

    Connections {
        target: options
        function onConfigChanged() { loadConfig(); }
    }

    // Get keyboard focus back when this script is activated and a client is activated externally
    Timer {
        id: requestActivateTimer; interval: 10; repeat: true; triggeredOnStart: true;
        running: mainWindow.activated && workspace.activeClient
        onTriggered: requestActivate();
    }

    // Right after boot, KWin does not return:
    // 1 - Screen positions correctly. Screens overlap at position (0, 0).
    // 2 - Desktop windows id's.
    // This timer tries to recover this info by running one sec after the script initialization.
    Timer {
        id: updateScreensTimer; interval: 1000; repeat: true; triggeredOnStart: false;
        running: mainWindow.mustUpdateScreens

        property int attempt

        onTriggered: {
            attempt++;

            mainWindow.width = workspace.displayWidth;
            mainWindow.height = workspace.displayHeight;

            let screensOnPositionZero = 0;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                // KWin.ScreenArea not working here, but KWin.ScreenArea === 7
                const screenRect = workspace.clientArea(7, currentScreen, workspace.currentDesktop);
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.x = screenRect.x;
                currentScreenItem.y = screenRect.y;
                currentScreenItem.width = screenRect.width;
                currentScreenItem.height = screenRect.height;

                if (screenRect.x === 0 && screenRect.y === 0) {
                    if (screensOnPositionZero > 0) return;

                    screensOnPositionZero++;
                }

                if (qtVersion >= 5.14 && currentScreenItem.children.length < 5)
                    Qt.createComponent("WheelHandlerComponent.qml").createObject(currentScreenItem);
            }

            let desktopWindowsPicked = 0;
            const clients = workspace.clientList();
            for (let i = 0; i < clients.length; i++) {
                if (clients[i].desktopWindow) {
                    screensRepeater.itemAt(clients[i].screen).desktopBackground.winId = clients[i].windowId;
                    desktopWindowsPicked++;
                    if (desktopWindowsPicked === screensRepeater.count) {
                        mainWindow.mustUpdateScreens = false;
                        attempt = 0;
                        return;
                    }
                }
            }

            // Give up if this timer can't recover the correct info after 3 attempts
            if (attempt === 3) {
                mainWindow.mustUpdateScreens = false;
                attempt = 0;
            }
        }
    }

    // ThumbnailItem hides before ScreenComponent when activated = false, showing a empty frame (background image without windows)
    // in the end of closing animation. This timer runs just before endAnimationTimer to avoid this.
    Timer {
        id: avoidEmptyFrameTimer; interval: mainWindow.configAnimationsDuration - 60; repeat: false; triggeredOnStart: false;

        onTriggered: {
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
                screensRepeater.itemAt(currentScreen).opacity = 0;
        }
    }

    Timer {
        id: endAnimationTimer; interval: mainWindow.configAnimationsDuration; repeat: false; triggeredOnStart: false;

        onTriggered: {
            animating = false;

            if (easingType === Easing.InExpo) {
                activated = false;

                // Return current big desktop to grid state. Desktops only have to be in original state for opening/closing animations.
                for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
                    screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.itemAt(currentDesktop).gridView = true;

                workspace.activeClient = selectedClientItem ? selectedClientItem.client : outsideSelectedClient;
                selectedClientItem = null;
            }
        }
    }

    Component.onCompleted: {
        getQtVersion();
        loadConfig();
        keyboardHandler.forceActiveFocus();
        KWin.registerShortcut("Parachute", "Parachute", "Ctrl+Meta+D", function() { selectedClientItem = null; toggleActive(); });
        getOutsideSelectedClient();
    }

    function toggleActive() {
        if (animating) return;
        animating = true;

        if (activated) {
            easingType = Easing.InExpo;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.itemAt(currentDesktop).gridView = false;
            }

            avoidEmptyFrameTimer.start();
        } else {
            selectOutsideSelectedClient();

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.itemAt(currentDesktop).gridView = false;
                screensRepeater.itemAt(currentScreen).opacity = 1;
            }

            activated = true;

            easingType = Easing.OutExpo;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.itemAt(currentDesktop).gridView = true;
            }
        }

        endAnimationTimer.start();
    }

    function getOutsideSelectedClient() {
        if (workspace.activeClient) {
            outsideSelectedClient = workspace.activeClient;

            // Ugly code for KWin < 5.20
            if (workspace.activeClient.desktopWindow) {
                const currentScreenItem = screensRepeater.itemAt(workspace.activeClient.screen);
                if (currentScreenItem.desktopBackground.winId === 0)
                    currentScreenItem.desktopBackground.winId = workspace.activeClient.windowId;
            }
        }
    }

    function loadConfig() {
        configBlurBackground = KWin.readConfig("blurBackground", true);
        configShowDesktopsBarBackground = KWin.readConfig("showDesktopsBarBackground", true);
        configShowDesktopShadows = KWin.readConfig("showDesktopShadows", false);
        configShowWindowTitles = KWin.readConfig("showWindowTitles", true);
        configAnimationsDuration = KWin.readConfig("animationsDuration", 250); //units.longDuration
        configShowNotificationWindows = KWin.readConfig("showNotificationWindows", true);
        configDesktopsBarPlacement = KWin.readConfig("desktopsBarPlacement", Enums.Position.Top);
    }

    function selectFirstClient() {
        selectedClientItem = screensRepeater.itemAt(0).bigDesktopsRepeater.itemAt(currentDesktop).clientsRepeater.itemAt(0);
        avoidUpdatingSelection = true;
    }

    function selectLastClient() {
        const lastClientsRepeater = screensRepeater.itemAt(screensRepeater.count - 1).bigDesktopsRepeater.
                itemAt(currentDesktop).clientsRepeater;
        selectedClientItem = lastClientsRepeater.itemAt(lastClientsRepeater.count - 1);
        avoidUpdatingSelection = true;
    }

    function selectNextClientOn(position) {
        // Make client positions consider screen positions.
        // The clients centers will be used to calculate distance between clients.
        const selectedClientItemX = selectedClientItem.x + screensRepeater.itemAt(selectedClientItem.client.screen).x;
        const selectedClientItemY = selectedClientItem.y + screensRepeater.itemAt(selectedClientItem.client.screen).y;
        const selectedClientItemXCenter = selectedClientItemX + selectedClientItem.width / 2;
        const selectedClientItemYCenter = selectedClientItemY + selectedClientItem.height / 2;

        let candidateClientItem = null;
        let candidateClientDistance = Number.MAX_VALUE;
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
            const currentScreenItem = screensRepeater.itemAt(currentScreen);
            const currentClientsRepeater = currentScreenItem.bigDesktopsRepeater.itemAt(currentDesktop).clientsRepeater;
            for (let currentClient = 0; currentClient < currentClientsRepeater.count; currentClient++) {
                const currentClientItem = currentClientsRepeater.itemAt(currentClient);
                const currentClientItemX = currentClientItem.x + currentScreenItem.x;
                const currentClientItemY = currentClientItem.y + currentScreenItem.y;

                let candidate = false;
                switch (position) {
                    case Enums.Position.Left:
                        candidate = currentClientItemX + currentClientItem.width <= selectedClientItemX &&
                            currentClientItemY <= selectedClientItemY + selectedClientItemY + selectedClientItem.height &&
                            currentClientItemY + currentClientItemY + currentClientItem.height >= selectedClientItemY;
                        break;
                    case Enums.Position.Right:
                        candidate = selectedClientItemX + selectedClientItem.width <= currentClientItemX &&
                            currentClientItemY <= selectedClientItemY + selectedClientItemY + selectedClientItem.height &&
                            currentClientItemY + currentClientItemY + currentClientItem.height >= selectedClientItemY;
                        break;
                    case Enums.Position.Top:
                        candidate = currentClientItemY + currentClientItem.height <= selectedClientItemY &&
                            currentClientItemX <= selectedClientItemX + selectedClientItemX + selectedClientItem.width &&
                            currentClientItemX + currentClientItemX + currentClientItem.width >= selectedClientItemX;
                        break;
                    case Enums.Position.Bottom:
                        candidate = selectedClientItemY + selectedClientItem.height <= currentClientItemY &&
                            currentClientItemX <= selectedClientItemX + selectedClientItemX + selectedClientItem.width &&
                            currentClientItemX + currentClientItemX + currentClientItem.width >= selectedClientItemX;
                        break;
                }

                if (candidate) {
                    const currentClientItemXCenter = currentClientItemX + currentClientItem.width / 2;
                    const currentClientItemYCenter = currentClientItemY + currentClientItem.height / 2;
                    const currentClientDistance = Math.hypot(Math.abs(currentClientItemXCenter - selectedClientItemXCenter),
                            Math.abs(currentClientItemYCenter - selectedClientItemYCenter));

                    if (currentClientDistance < candidateClientDistance) {
                        candidateClientDistance = currentClientDistance;
                        candidateClientItem = currentClientItem;
                    }
                }
            }
        }

        if (candidateClientItem) {
            selectedClientItem = candidateClientItem;
            avoidUpdatingSelection = true;
        }
    }

    function selectOutsideSelectedClient() {
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
            const currentClientsRepeater = screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.
                    itemAt(currentDesktop).clientsRepeater;

            for (let currentClient = 0; currentClient < currentClientsRepeater.count; currentClient++) {
                if (currentClientsRepeater.itemAt(currentClient).client === mainWindow.outsideSelectedClient) {
                    selectedClientItem = currentClientsRepeater.itemAt(currentClient);
                    avoidUpdatingSelection = true;
                    return;
                }
            }
        }
    }

    function getQtVersion() {
        const regexpNames = /Qt Version: (\d+.\d+).\d+/mg;
        const match = regexpNames.exec(workspace.supportInformation());
        if (match) qtVersion = match[1];
    }
}
