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

    property bool activated: false
    property bool dragging: false
    property real qtVersion
    property int currentDesktop: workspace.currentDesktop - 1 // workspace.currentDesktop is one based
    property bool horizontalDesktopsLayout: configDesktopsBarPlacement === Enums.Position.Top ||
            configDesktopsBarPlacement === Enums.Position.Bottom
    property int easingType: Easing.OutExpo
    property bool animating: false
    property color hoverColor: Qt.rgba(PlasmaCore.Theme.buttonHoverColor.r, PlasmaCore.Theme.buttonHoverColor.g,
            PlasmaCore.Theme.buttonHoverColor.b, 0.25)
    property bool handlersEnabled: mainWindow.activated && !mainWindow.animating && !mainWindow.dragging
    property bool ready: false
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

    // Get keyboard focus back when this script is activated and a client is activated externally
    Timer {
        id: requestActivateTimer; interval: 10; repeat: true; triggeredOnStart: true;
        running: mainWindow.activated && workspace.activeClient
        onTriggered: requestActivate();
    }

    Component.onCompleted: {
        getQtVersion();
        loadConfig();
        updateScreens();
        keyboardHandler.forceActiveFocus();
        KWin.registerShortcut("Parachute", "Parachute", "Ctrl+Meta+D", function() { selectedClientItem = null; toggleActive(); });
        clientActivated(workspace.activeClient);

        options.configChanged.connect(loadConfig);
        workspace.clientActivated.connect(clientActivated);
        workspace.numberScreensChanged.connect(function(count) { updateScreens(); });
        workspace.screenResized.connect(function(screen) { updateScreens(); });
        workspace.currentDesktopChanged.connect(function(desktop, client) { selectedClientItem = null; } );

        ready = true;
    }

    Component.onDestruction: {
        workspace.clientActivated.disconnect(clientActivated);
        options.configChanged.disconnect(loadConfig);
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
            if (easingType === Easing.InExpo) {
                activated = false;

                workspace.activeClient = selectedClientItem ? selectedClientItem.client : outsideSelectedClient;
                selectedClientItem = null;

                returnToGridTimer.start();
            }

            animating = false;
        }
    }

    // Return current bigDesktop to grid state. Desktops only have to be in original state for opening/closing animations.
    Timer {
        id: returnToGridTimer; interval: 10; repeat: false; triggeredOnStart: false;

        onTriggered: {
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
                screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.itemAt(currentDesktop).gridView = true;
        }
    }

    function clientActivated(client) {
        // The correct thing to do would be to use the client parameter but sometimes it doesn't seem to be with the right value
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

    function updateScreens() {
        mainWindow.width = workspace.displaySize.width;
        mainWindow.height = workspace.displaySize.height;

        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
            // Kwin.ScreenArea not working here, but Kwin.ScreenArea === 7
            const screenRect = workspace.clientArea(7, currentScreen, workspace.currentDesktop);
            const currentScreenItem = screensRepeater.itemAt(currentScreen);
            currentScreenItem.x = screenRect.x;
            currentScreenItem.y = screenRect.y;
            currentScreenItem.width = screenRect.width;
            currentScreenItem.height = screenRect.height;

            if (qtVersion >= 5.14 && currentScreenItem.children.length < 6)
                Qt.createComponent("WheelHandlerComponent.qml").createObject(currentScreenItem);
        }
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
        // Make the clients positions consider the screens positions.
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
