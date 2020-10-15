import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import org.kde.kwin 2.0 as KWinComponents

Window {
    id: mainWindow
    flags: Qt.X11BypassWindowManagerHint
    visible: true
    color: "#333333"
    x: activated ? 0 : -mainWindow.width * 2
    y: activated ? 0 : -mainWindow.height * 2

    property bool activated: false
    property bool dragging: false
    property real qtVersion
    property bool workWithActivities: false // Waiting for write access to client.activities, for now always work with virtual desktops
    property bool desktopsInitialized: false
    property int currentActivityOrDesktop: workWithActivities ? workspace.activities.indexOf(workspace.currentActivity) :
            workspace.currentDesktop - 1
    property bool horizontalDesktopsLayout: configDesktopsBarPlacement === Enums.Position.Top ||
            configDesktopsBarPlacement === Enums.Position.Bottom
    property int easingType: noAnimation
    property bool animating: false

    // Config
    property bool configBlurBackground
    property bool configShowDesktopsBarBackground
    property bool configShowWindowTitles
    property bool configShowDesktopShadows
    property real configAnimationsDuration
    property int configDesktopsBarPlacement

    // Selection (with mouse or keyboard)
    property var selectedClientItem: null
    property var outsideSelectedClient: null
    property var pointKeyboardSelected: null
    property bool keyboardSelected: false
    property bool shouldRequestActivate: true

    // Consts
    property int noAnimation: 0
    property int bigDesktopMargin: 10
    property int smallDesktopMargin: 15

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
                case Qt.Key_Left: case Qt.Key_H:
                    if (event.modifiers == Qt.ShiftModifier) {
                        workspace.currentDesktop--
                    } else {
                        selectedClientItem ? selectNextClientOn(Enums.Position.Left) : selectLastClient();
                    }
                    break;
                case Qt.Key_Right: case Qt.Key_L:
                    if (event.modifiers == Qt.ShiftModifier) {
                        workspace.currentDesktop++
                    } else {
                        selectedClientItem ? selectNextClientOn(Enums.Position.Right) : selectFirstClient();
                    }
                    break;
                case Qt.Key_Up: case Qt.Key_K:
                    selectedClientItem ? selectNextClientOn(Enums.Position.Top) : selectLastClient();
                    break;
                case Qt.Key_Down: case Qt.Key_J:
                    selectedClientItem ? selectNextClientOn(Enums.Position.Bottom) : selectFirstClient();
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
        onTriggered: requestActivate();
    }

    Component.onCompleted: {
        getQtVersion();
        loadConfig();
        updateAllDesktops();
        keyboardHandler.forceActiveFocus();
        KWin.registerShortcut("Parachute", "Parachute", "Ctrl+Meta+D", function() { selectedClientItem = null; toggleActive(); });
        clientActivated(workspace.activeClient);

        options.configChanged.connect(loadConfig);
        workspace.clientActivated.connect(clientActivated);
        workspace.numberScreensChanged.connect(function(count) { desktopsInitialized = false; });
        workspace.screenResized.connect(function(screen) { desktopsInitialized = false; });
        workspace.currentDesktopChanged.connect(function(desktop, client) { selectedClientItem = null;} );
    }

    Component.onDestruction: {
        workspace.clientActivated.disconnect(clientActivated);
        options.configChanged.disconnect(loadConfig);
    }

    function toggleActive() {
        if (animating) return;
        
        if (!desktopsInitialized) updateAllDesktops();

        if (activated) {
            shouldRequestActivate = false;
            workspace.activeClient = selectedClientItem ? selectedClientItem.client : outsideSelectedClient;

            easingType = Easing.InExpo;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.hideDesktopsBar();
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal();
                // The window must be hide (activated = false) only in the end of animation
            }
        } else {
            requestActivateTimer.start();

            easingType = noAnimation;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.hideDesktopsBar();
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal();
            }
            easingType = Easing.OutExpo;
            activated = true;
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.visible = true;
                currentScreenItem.showDesktopsBar();
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToCalculated();
            }
        }
    }

    function deactivate() {
        activated = false;
        easingType = noAnimation;
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
            const currentScreenItem = screensRepeater.itemAt(currentScreen);
            currentScreenItem.visible = false;
            currentScreenItem.showDesktopsBar();
            currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).
                    bigDesktop.updateToCalculated();
        }
    }

    function clientActivated(client) {
        // The correct thing to do would be to use the client parameter but sometimes it doesn't seem to be with the right value
        if (workspace.activeClient) {
            outsideSelectedClient = workspace.activeClient;

            if (workspace.activeClient.desktopWindow) {
                const currentScreenItem = screensRepeater.itemAt(workspace.activeClient.screen);
                if (currentScreenItem.desktopBackground.winId === 0)
                    currentScreenItem.desktopBackground.winId = workspace.activeClient.windowId;
            }

            // Doesn't requestActivate() if the client was selected in this script and the closing animation is running
            if (activated && shouldRequestActivate)
                requestActivateTimer.start();
        } else {
            requestActivateTimer.stop();
        }
        shouldRequestActivate = true;
    }

    function loadConfig() {
        configBlurBackground = KWin.readConfig("blurBackground", true);
        configShowDesktopsBarBackground = KWin.readConfig("showDesktopsBarBackground", true);
        configShowDesktopShadows = KWin.readConfig("showDesktopShadows", false);
        configShowWindowTitles = KWin.readConfig("showWindowTitles", true);
        configAnimationsDuration = KWin.readConfig("animationsDuration", 250); //units.longDuration

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

        // updating configDesktopsBarPlacement is a little more tricky than the others options
        const tmpConfigDesktopsBarPlacement = KWin.readConfig("desktopsBarPlacement", Enums.Position.Top);
        if (configDesktopsBarPlacement !== tmpConfigDesktopsBarPlacement) {
            configDesktopsBarPlacement = tmpConfigDesktopsBarPlacement;
            easingType = noAnimation;

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                const currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.hideDesktopsBar();
                currentScreenItem.showDesktopsBar();
                for (let currentDesktop = 0; currentDesktop < currentScreenItem.bigDesktopsRepeater.count; currentDesktop++) {
                    const currentBigDesktopItem = currentScreenItem.bigDesktopsRepeater.itemAt(currentDesktop).bigDesktop;
                    currentBigDesktopItem.calculateTransformations();
                    currentBigDesktopItem.updateToCalculated();
                    const currentDesktopBarItem = currentScreenItem.desktopsBarRepeater.itemAt(currentDesktop);
                    currentDesktopBarItem.calculateTransformations();
                    currentDesktopBarItem.updateToCalculated();
                }
            }
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

            if (qtVersion >= 5.14 && currentScreenItem.children.length < 6)
                Qt.createComponent("WheelHandlerComponent.qml").createObject(currentScreenItem);

            // Update desktops
            easingType = noAnimation;
            currentScreenItem.showDesktopsBar();
            for (let currentDesktop = 0; currentDesktop < currentScreenItem.bigDesktopsRepeater.count; currentDesktop++) {
                const currentBigDesktopItem = currentScreenItem.bigDesktopsRepeater.itemAt(currentDesktop).bigDesktop;
                currentBigDesktopItem.calculateTransformations();
                currentBigDesktopItem.updateToCalculated();
                const currentDesktopBarItem = currentScreenItem.desktopsBarRepeater.itemAt(currentDesktop);
                currentDesktopBarItem.calculateTransformations();
                currentDesktopBarItem.updateToCalculated();
            }
        }
        desktopsInitialized = true;
    }

    function selectFirstClient() {
        keyboardSelected = true;
        selectedClientItem = screensRepeater.itemAt(0).bigDesktopsRepeater.itemAt(currentActivityOrDesktop).
                bigDesktop.clientsRepeater.itemAt(0);
    }

    function selectLastClient() {
        keyboardSelected = true;
        const lastClientsRepeater = screensRepeater.itemAt(screensRepeater.count - 1).bigDesktopsRepeater.
                itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
        selectedClientItem = lastClientsRepeater.itemAt(lastClientsRepeater.count - 1);
    }

    function selectNextClientOn(position) {
        keyboardSelected = true;
        
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
        if (match) qtVersion = match[1];
    }
}
