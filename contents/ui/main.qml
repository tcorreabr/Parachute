import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import org.kde.kwin 2.0 as KWinComponents

Window {
    id: mainWindow
    flags: Qt.X11BypassWindowManagerHint
    visible: true
    color: "#333333"
    x: mainWindow.activated ? 0 : -mainWindow.width * 2
    y: mainWindow.activated ? 0 : -mainWindow.height * 2

    property bool activated: false
    property bool dragging: false
    property real qtVersion
    property bool workWithActivities: false // Waiting for write access to client.activities, for now always work with virtual desktops
    property bool desktopsInitialized: false
    property int currentActivityOrDesktop: workWithActivities ? workspace.activities.indexOf(workspace.currentActivity) :
            workspace.currentDesktop - 1

    // Config
    property bool configBlurBackground: true
    property bool configShowDesktopBarBackground: true
    property bool configShowWindowTitles: true
    property bool configShowDesktopShadows: false
    property int configDesktopBarPosition: Enums.Position.Top

    // Animations
    property real animationsDuration: 200 //units.longDuration * 2
    property int noAnimation: 0 // Const to disable animations
    property int easingType: noAnimation

    // Selection (with mouse or keyboard)
    property var selectedClientItem: null
    property var outsideSelectedClient: null
    property var pointKeyboardSelected: null
    property bool keyboardSelected: false
    property bool shouldRequestActivate: true

    // Consts
    property int bigDesktopMargin: 40

    Item {
        id: keyboardHandler

        Keys.onPressed: {
            keyboardSelected = true;
            switch (event.key) {
                case Qt.Key_Escape:
                    selectedClientItem = null;
                    mainWindow.toggleActive();
                    break;
                case Qt.Key_Return:
                    if (selectedClientItem) mainWindow.toggleActive();
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

    // This model will be used for when we work with activities. Currently there is no ClientModelByScreenAndActivity
    KWinComponents.ClientModelByScreen {
        id: clientsByScreen
    }

    KWinComponents.ClientModelByScreenAndDesktop {
        id: clientsByScreenAndDesktop
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

    // Ugly code to get keyboard focus back when this script is activated and a client is activated externally
    Timer {
        id: requestActivateTimer; interval: 10; repeat: true; triggeredOnStart: true;
        onTriggered: mainWindow.requestActivate();
    }

    Component.onCompleted: {
        mainWindow.width = workspace.displaySize.width;
        mainWindow.height = workspace.displaySize.height;

        loadConfig();
        keyboardHandler.forceActiveFocus();
        getQtVersion();
        KWin.registerShortcut("Parachute", "Parachute", "Ctrl+Meta+D", function() { selectedClientItem = null; toggleActive(); });
        clientActivated(workspace.activeClient);

        options.configChanged.connect(loadConfig);
        workspace.clientActivated.connect(clientActivated);
        workspace.numberScreensChanged.connect(function(count) { mainWindow.desktopsInitialized = false; });
        workspace.screenResized.connect(function(screen) { mainWindow.desktopsInitialized = false; });
        workspace.currentDesktopChanged.connect(function(desktop, client) { mainWindow.selectedClientItem = null;} );
    }

    Component.onDestruction: {
        workspace.clientActivated.disconnect(clientActivated);
        options.configChanged.disconnect(loadConfig);
    }

    function toggleActive() {
        if (!mainWindow.desktopsInitialized) updateAllDesktops();

        // Return if any big desktop is animating
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
            if (screensRepeater.itemAt(currentScreen).bigDesktopsTopMarginAnimation.running) return;

        if (mainWindow.activated) {
            shouldRequestActivate = false;
            workspace.activeClient = selectedClientItem ? selectedClientItem.client : mainWindow.outsideSelectedClient;

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                // The window must be hide (mainWindow.activated = false) only in the end of animation
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal(Easing.InExpo);
            }
        } else {
            requestActivateTimer.start();

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal(mainWindow.noAnimation);
            }
            mainWindow.activated = true;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.visible = true;
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToCalculated(Easing.OutExpo);
            }
        }
    }

    function clientActivated(client) {
        // The correct thing to do would be to use the client parameter but sometimes it doesn't seem to be with the right value
        if (workspace.activeClient) {
            mainWindow.outsideSelectedClient = workspace.activeClient;

            if (workspace.activeClient.desktopWindow) {
                const currentScreenItem = screensRepeater.itemAt(workspace.activeClient.screen);
                if (currentScreenItem.desktopBackground.winId === 0)
                    currentScreenItem.desktopBackground.winId = workspace.activeClient.windowId;
            }

            // Doesn't requestActivate() if the client was selected in this script and the closing animation is running
            if (mainWindow.activated && shouldRequestActivate)
                requestActivateTimer.start();
        } else {
            requestActivateTimer.stop();
        }
        shouldRequestActivate = true;
    }

    function loadConfig() {
        configBlurBackground = KWin.readConfig("blurBackground", true);
        configShowDesktopBarBackground = KWin.readConfig("showDesktopsBarBackground", true);
        configShowDesktopShadows = KWin.readConfig("showDesktopShadows", false);
        configShowWindowTitles = KWin.readConfig("showWindowTitles", true);

        if (KWin.readConfig("showNotificationWindows", true)) {
            clientsByScreen.exclusions = KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion;

            clientsByScreenAndDesktop.exclusions = KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion |
                    KWinComponents.ClientModel.OtherActivitiesExclusion | KWinComponents.ClientModel.DesktopWindowsExclusion;
        } else {
            clientsByScreen.exclusions = KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion |
                    KWinComponents.ClientModel.SkipPagerExclusion | KWinComponents.ClientModel.SwitchSwitcherExclusion;

            clientsByScreenAndDesktop.exclusions = KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion |
                    KWinComponents.ClientModel.OtherActivitiesExclusion | KWinComponents.ClientModel.DesktopWindowsExclusion |
                    KWinComponents.ClientModel.SkipPagerExclusion | KWinComponents.ClientModel.SwitchSwitcherExclusion;
        }
    }

    function updateAllDesktops() {
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

            if (mainWindow.qtVersion >= 5.14 && currentScreenItem.children.length < 6)
                Qt.createComponent("WheelHandlerComponent.qml").createObject(currentScreenItem);

            // Get desktop windowId to show backgrounds
            // const screenModelIndex = clientsByScreen.index(currentScreen, 0);
            // for (let currentClient = 0; currentClient < clientsByScreen.rowCount(screenModelIndex); currentClient++) {
            //     const clientModelIndex = clientsByScreen.index(currentClient, 0, screenModelIndex);
                // const client = clientsByScreen.data(clientModelIndex);
                // ^^^ this is the line that causes kwin to crash. I don't know why. Maybe some internal bug in data method? ^^^
                // if (client.desktopWindow) { //} && client.activities.length === 1) {
                //     // const activityIndex = workspace.activities.indexOf(client.activities[0]);
                //     screensRepeater.itemAt(currentScreen).desktopBackground.winId = client.windowId;
                // }
            // }

            // Update desktops
            for (let currentDesktop = 0; currentDesktop < currentScreenItem.bigDesktopsRepeater.count; currentDesktop++) {
                const currentBigDesktopItem = currentScreenItem.bigDesktopsRepeater.itemAt(currentDesktop).bigDesktop;
                currentBigDesktopItem.calculateTransformations();
                currentBigDesktopItem.updateToCalculated(mainWindow.noAnimation);
                const currentDesktopBarItem = currentScreenItem.desktopsBarRepeater.itemAt(currentDesktop);
                currentDesktopBarItem.calculateTransformations();
                currentDesktopBarItem.updateToCalculated(mainWindow.noAnimation);
            }
        }
        desktopsInitialized = true;
    }

    function selectFirstClient() {
        selectedClientItem = screensRepeater.itemAt(0).bigDesktopsRepeater.itemAt(currentActivityOrDesktop).
                bigDesktop.clientsRepeater.itemAt(0);
    }

    function selectLastClient() {
        const lastClientsRepeater = screensRepeater.itemAt(screensRepeater.count - 1).bigDesktopsRepeater.
                itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
        selectedClientItem = lastClientsRepeater.itemAt(lastClientsRepeater.count - 1);
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
            const currentClientsRepeater = currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
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
        if (candidateClientItem) selectedClientItem = candidateClientItem;
    }

    function getQtVersion() {
        const regexpNames = /Qt Version: (\d+.\d+).\d+/mg;
        const match = regexpNames.exec(workspace.supportInformation());
        if (match) mainWindow.qtVersion = match[1];
    }
}
