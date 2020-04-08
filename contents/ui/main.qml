import QtQuick 2.14
import QtQuick.Window 2.14
import QtQuick.Controls 2.14
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
    property bool workWithActivities: false // Waiting for write access to client.activities, for now always work with virtual desktops
    property bool desktopsInitialized: false
    property int currentActivityOrDesktop: workWithActivities ? workspace.activities.indexOf(workspace.currentActivity) : workspace.currentDesktop - 1

    // Config
    property bool configBlurBackground: true
    property bool configShowDesktopBarBackground: true

    // Animations
    property real animationsDuration: 2 * units.longDuration - units.shortDuration
    property int noAnimation: 0 // Const to disable animations
    property int easingType: noAnimation

    // Selection (with mouse or keyboard)
    property var selectedClientItem: null
    property var outsideSelectedClient: null
    property var pointKeyboardWasSelected: null
    property bool keyboardSelected: false
    property bool shouldRequestActivate: true

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
                    if (selectedClientItem !== null) mainWindow.toggleActive();
                    break;
                case Qt.Key_Home:
                    selectedClientItem = screensRepeater.itemAt(0).bigDesktopsRepeater.itemAt(currentActivityOrDesktop).
                            bigDesktop.clientsRepeater.itemAt(0);
                    break;
                case Qt.Key_End:
                    let lastClientsRepeater = screensRepeater.itemAt(screensRepeater.count - 1).bigDesktopsRepeater.
                            itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
                    selectedClientItem = lastClientsRepeater.itemAt(lastClientsRepeater.count - 1);
                    break;
                case Qt.Key_Left:
                    if (selectedClientItem === null) {
                        selectedClientItem = screensRepeater.itemAt(0).bigDesktopsRepeater.itemAt(currentActivityOrDesktop).
                                bigDesktop.clientsRepeater.itemAt(0);
                    } else {
                        selectNextClientOn(Enums.Position.Left);
            }
                    break;
                case Qt.Key_Right:
                    if (selectedClientItem === null) {
                        let lastClientsRepeater = screensRepeater.itemAt(screensRepeater.count - 1).bigDesktopsRepeater.
                                itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
                        selectedClientItem = lastClientsRepeater.itemAt(lastClientsRepeater.count - 1);
                    } else {
                        selectNextClientOn(Enums.Position.Right);
        }
                    break;
                case Qt.Key_Up:
                    if (selectedClientItem === null) {
                        selectedClientItem = screensRepeater.itemAt(0).bigDesktopsRepeater.itemAt(currentActivityOrDesktop).
                                bigDesktop.clientsRepeater.itemAt(0);
                    } else {
                        selectNextClientOn(Enums.Position.Top);
    }
                    break;
                case Qt.Key_Down:
                    if (selectedClientItem === null) {
                        let lastClientsRepeater = screensRepeater.itemAt(screensRepeater.count - 1).bigDesktopsRepeater.
                                itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
                        selectedClientItem = lastClientsRepeater.itemAt(lastClientsRepeater.count - 1);
                    } else {
                        selectNextClientOn(Enums.Position.Bottom);
                    }
                    break;
            }
        }
    }

    // This model will be used for when we work with activities. Currently there is no ClientModelByScreenAndActivity
    KWinComponents.ClientModelByScreen {
        id: clientsByScreen
        exclusions: KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion
    }

    KWinComponents.ClientModelByScreenAndDesktop {
        id: clientsByScreenAndDesktop
        exclusions: KWinComponents.ClientModel.NotAcceptingFocusExclusion | KWinComponents.ClientModel.DockWindowsExclusion
                | KWinComponents.ClientModel.OtherActivitiesExclusion | KWinComponents.ClientModel.DesktopWindowsExclusion
    }

    Repeater {
        id: screensRepeater
        model: workspace.numScreens

        ScreenComponent {}
    }

    function toggleActive() {
        if (!mainWindow.desktopsInitialized) updateAllDesktops();

        // Return if any big desktop is animating
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
            if (screensRepeater.itemAt(currentScreen).bigDesktopsTopMarginAnimation.running) return;

        if (mainWindow.activated) {
            shouldRequestActivate = false;
            workspace.activeClient = selectedClientItem !== null ? selectedClientItem.client : mainWindow.outsideSelectedClient;

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                let currentScreenItem = screensRepeater.itemAt(currentScreen);
                // The window must be hide (mainWindow.activated = false) only in the end of animation
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal(Easing.InExpo);
            }
        } else {
            mainWindow.requestActivate();
            mainWindow.activated = true;
            selectedClientItem = null;

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                let currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal(mainWindow.noAnimation);
            }
            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                let currentScreenItem = screensRepeater.itemAt(currentScreen);
                currentScreenItem.visible = true;
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToCalculated(Easing.OutExpo);
            }
        }
    }

    Component.onCompleted: {
        mainWindow.width = workspace.displayWidth;
        mainWindow.height = workspace.displayHeight;

        keyboardHandler.forceActiveFocus();
        KWin.registerShortcut("Parachute", "Parachute", "Ctrl+Alt+W", toggleActive);
        clientActivated(workspace.activeClient);

        workspace.clientActivated.connect(clientActivated);
        workspace.numberScreensChanged.connect(function(count) {mainWindow.desktopsInitialized = false;});
        workspace.screenResized.connect(function(screen) {mainWindow.desktopsInitialized = false;});        
        workspace.currentDesktopChanged.connect(function(desktop, client) {selectedClientItem = null;});
    }

    Component.onDestruction: {
        workspace.clientActivated.disconnect(clientActivated);
    }

    function clientActivated(client) {
        // The correct thing to do would be to use the client parameter but sometimes it doesn't seem to be with the right value
        if (workspace.activeClient !== null) {
            mainWindow.outsideSelectedClient = workspace.activeClient;

            if (workspace.activeClient.desktopWindow) {
                let currentScreenItem = screensRepeater.itemAt(workspace.activeClient.screen);
                if (currentScreenItem.desktopThumbnail.winId === 0)
                    currentScreenItem.desktopThumbnail.winId = client.windowId;
            }

            // Doesn't requestActivate() if the client was selected in this script and the closing animation is running
            if (mainWindow.activated && shouldRequestActivate)
                requestActivateTimer.start();
        } else {
            requestActivateTimer.stop();
        }
        shouldRequestActivate = true;
    }

    // Ugly code to get keyboard focus back when this script is activated and a client is activated externally
    Timer {
        id: requestActivateTimer
        interval: 10; repeat: true; triggeredOnStart: false
        onTriggered: mainWindow.requestActivate();
    }

    function updateAllDesktops() {
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
            // Kwin.ScreenArea not working here, but Kwin.ScreenArea === 7
            let screenRect = workspace.clientArea(7, currentScreen, workspace.currentDesktop);
            let currentScreenItem = screensRepeater.itemAt(currentScreen);
            currentScreenItem.x = screenRect.x;
            currentScreenItem.y = screenRect.y;
            currentScreenItem.width = screenRect.width;
            currentScreenItem.height = screenRect.height;

            // Get desktop windowId to show backgrounds
            // let screenModelIndex = clientsByScreen.index(currentScreen, 0);
            // for (let currentClient = 0; currentClient < clientsByScreen.rowCount(screenModelIndex); currentClient++) {
            //     let clientModelIndex = clientsByScreen.index(currentClient, 0, screenModelIndex);
                // let client = clientsByScreen.data(clientModelIndex);
                // if (client.desktopWindow) { //} && client.activities.length === 1) {
                //     // let activityIndex = workspace.activities.indexOf(client.activities[0]);
                //     screensRepeater.itemAt(currentScreen).desktopThumbnail.winId = client.windowId;
                // }
            // }

            // Update desktops
            for (let currentDesktop = 0; currentDesktop < currentScreenItem.bigDesktopsRepeater.count; currentDesktop++) {
                let currentBigDesktopItem = currentScreenItem.bigDesktopsRepeater.itemAt(currentDesktop).bigDesktop;
                currentBigDesktopItem.calculateTransformations();
                currentBigDesktopItem.updateToCalculated(mainWindow.noAnimation);
                let currentDesktopBarItem = currentScreenItem.desktopsBarRepeater.itemAt(currentDesktop);
                currentDesktopBarItem.calculateTransformations();
                currentDesktopBarItem.updateToCalculated(mainWindow.noAnimation);
            }
        }
        desktopsInitialized = true;
    }

    function selectNextClientOn(position) {
        // Make the clients positions consider the screens positions.
        // The clients centers will be used to calculate distance between clients.
        let selectedClientItemX = selectedClientItem.x + screensRepeater.itemAt(selectedClientItem.client.screen).x;
        let selectedClientItemY = selectedClientItem.y + screensRepeater.itemAt(selectedClientItem.client.screen).y;
        let selectedClientItemXCenter = selectedClientItemX + selectedClientItem.width / 2;
        let selectedClientItemYCenter = selectedClientItemY + selectedClientItem.height / 2;

        let candidateClientItem = null;
        let candidateClientDistance = Number.MAX_VALUE;
        for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
            let currentScreenItem = screensRepeater.itemAt(currentScreen);
            let currentClientsRepeater = currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.clientsRepeater;
            for (let currentClient = 0; currentClient < currentClientsRepeater.count; currentClient++) {
                let currentClientItem = currentClientsRepeater.itemAt(currentClient);
                let currentClientItemX = currentClientItem.x + currentScreenItem.x;
                let currentClientItemY = currentClientItem.y + currentScreenItem.y;

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
                    let currentClientItemXCenter = currentClientItemX + currentClientItem.width / 2;
                    let currentClientItemYCenter = currentClientItemY + currentClientItem.height / 2;
                    let currentClientDistance = Math.hypot(Math.abs(currentClientItemXCenter - selectedClientItemXCenter),
                            Math.abs(currentClientItemYCenter - selectedClientItemYCenter));
                    if (currentClientDistance < candidateClientDistance) {
                        candidateClientDistance = currentClientDistance;
                        candidateClientItem = currentClientItem;
                    }
                }
            }
        }
        if (candidateClientItem !== null) selectedClientItem = candidateClientItem;
    }
}
