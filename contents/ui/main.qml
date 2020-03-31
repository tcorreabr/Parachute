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
    property bool configBlurBackground: true
    property bool dragging: false
    property bool clientTapped: false // Qt bug: TapHandlers's eventInput.accepted = true doesn't stop propagation
    property bool workWithActivities: false // Waiting for write access to client.activities, for now always work with virtual desktops
    property bool shouldRequestActivate: true
    property bool desktopsInitialized: false
    property var selectedClient: null
    property var outsideSelectedClient: null
    property real clientDecorationsHeight: 22
    property real animationsDuration: units.longDuration + units.shortDuration * 2
    property int noAnimation: 0 // Const to disable animations
    property int easingType
    property int currentActivityOrDesktop: workWithActivities ? workspace.activities.indexOf(workspace.currentActivity) : workspace.currentDesktop - 1


    Item {
        id: keyboardHandler

        Keys.onPressed: {
            if (event.key === Qt.Key_Escape && mainWindow.activated) toggleActive();
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
            for (let currentDesktop = 0; currentDesktop < screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.count; currentDesktop++)
                if (screensRepeater.itemAt(currentScreen).bigDesktopsRepeater.itemAt(currentDesktop).bigDesktop.isAnimating())
                    return;

        if (mainWindow.activated) {
            shouldRequestActivate = false;
            workspace.activeClient = mainWindow.selectedClient !== null ? mainWindow.selectedClient : mainWindow.outsideSelectedClient;

            for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++) {
                let currentScreenItem = screensRepeater.itemAt(currentScreen);
                // The window must be hide (mainWindow.activated = false) only in the end of animation
                currentScreenItem.bigDesktopsRepeater.itemAt(currentActivityOrDesktop).bigDesktop.updateToOriginal(Easing.InExpo);
            }
        } else {
            mainWindow.requestActivate();
            mainWindow.activated = true;
            mainWindow.selectedClient = null;

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
    }

    Component.onDestruction: {
        workspace.clientActivated.disconnect(clientActivated);
    }

    function clientActivated(client) {
        if (workspace.activeClient !== null) {
            mainWindow.outsideSelectedClient = workspace.activeClient;

            if (workspace.activeClient.desktopWindow) {
                let currentScreenItem = screensRepeater.itemAt(workspace.activeScreen);
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

    // Get keyboard focus back when this script is activated and a client is activated externally
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
            // for (var currentClient = 0; currentClient < clientsByScreen.rowCount(screenModelIndex); currentClient++) {
            //     let clientModelIndex = clientsByScreen.index(currentClient, 0, screenModelIndex);
                // let client = clientsByScreen.data(clientModelIndex);
                // ^^^ this is the line that causes kwin to crash. I don't know why. Maybe some internal bug in data method? ^^^
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
}
