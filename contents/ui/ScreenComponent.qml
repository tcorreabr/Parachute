import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.12
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: screenItem
    visible: false
    clip: true // Fixes the glitches? The glitches are caused by desktopsBar going out of screen?

    property alias desktopsBarRepeater: desktopsBarRepeater
    property alias bigDesktopsRepeater: bigDesktopsRepeater
    property alias desktopBackground: desktopBackground
    property alias bigDesktopsTopMarginAnimation: bigDesktopsTopMarginAnimation
    // property alias activitiesBackgrounds: activitiesBackgrounds

    property int screenIndex: model.index

    // Repeater {
    //     id: activitiesBackgrounds
    //     model: workspace.activities.length
    PlasmaCore.WindowThumbnail {
        id: desktopBackground
        anchors.fill: parent
        visible: winId !== 0
        opacity: mainWindow.configBlurBackground ? 0 : 1
    }
    // }

    FastBlur {
        id: blurBackground
        anchors.fill: parent
        source: desktopBackground
        radius: 64
        visible: desktopBackground.winId !== 0 && mainWindow.configBlurBackground
        // cached: true
    }

    Rectangle { // To apply some transparency without interfere with children transparency
        id: desktopsBarBackground
        anchors.fill: desktopsBar
        color: "black"
        opacity: 0.1
        visible: mainWindow.configShowDesktopBarBackground
    }

    ScrollView {
        id: desktopsBar
        height: parent.height / 6
        anchors.bottom: bigDesktops.top
        anchors.right: parent.right
        anchors.left: parent.left
        contentWidth: desktopsWrapper.width
        clip: true

        Item { // To centralize children
            id: desktopsWrapper
            width: childrenRect.width + 15
            height: childrenRect.height + 15
            x: desktopsBar.width < desktopsWrapper.width ? 0 : (desktopsBar.width - desktopsWrapper.width) / 2
            // anchors.horizontalCenter: parent.horizontalCenter
            // anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: desktopsBarRepeater
                model: mainWindow.workWithActivities ? workspace.activities.length : workspace.desktops

                DesktopComponent {
                    x: 15 + model.index * (width + 15)
                    y: 15
                    width: (height / screenItem.height) * screenItem.width
                    height: desktopsBar.height - 30
                    activity: mainWindow.workWithActivities ? workspace.activities[model.index] : ""

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: workspace.currentDesktop = model.index + 1;
                    }
                }
            }
        }
    }

    SwipeView {
        id: bigDesktops
        anchors.fill: parent
        anchors.topMargin: parent.height / 6
        clip: true
        currentIndex: mainWindow.currentActivityOrDesktop
        //vertical: true

        Behavior on anchors.topMargin {
            enabled: mainWindow.easingType !== mainWindow.noAnimation
            NumberAnimation { id: bigDesktopsTopMarginAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
        }

        Repeater {
            id: bigDesktopsRepeater
            model: mainWindow.workWithActivities ? workspace.activities.length : workspace.desktops

            Item { // Cannot set geometry of SwipeView's root item
                property alias bigDesktop: bigDesktop

                TapHandler {
                    acceptedButtons: Qt.AllButtons
                    acceptedDevices: PointerDevice.AllDevices & ~PointerDevice.TouchScreen

                    onTapped: {
                        if (mainWindow.selectedClientItem)
                            switch (eventPoint.event.button) {
                                case Qt.LeftButton:
                                    mainWindow.toggleActive();
                                    break;
                                case Qt.MiddleButton:
                                    mainWindow.selectedClientItem.client.closeWindow();
                                    break;
                                case Qt.RightButton:
                                    if (mainWindow.workWithActivities)
                                        if (mainWindow.selectedClientItem.client.activities.length === 0)
                                            mainWindow.selectedClientItem.client.activities.push(workspace.activities[model.index]);
                                        else
                                            mainWindow.selectedClientItem.client.activities = [];
                                    else
                                        if (mainWindow.selectedClientItem.client.desktop === -1)
                                            mainWindow.selectedClientItem.client.desktop = model.index + 1;
                                        else
                                            mainWindow.selectedClientItem.client.desktop = -1;
                                    break;
                            }
                        else 
                            mainWindow.toggleActive();
                    }
                }

                DesktopComponent {
                    id: bigDesktop
                    big: true
                    activity: mainWindow.workWithActivities ? workspace.activities[model.index] : ""
                    anchors.centerIn: parent
                    width: desktopRatio < screenRatio ? parent.width - bigDesktopMargin
                            : parent.height / screenItem.height * screenItem.width - bigDesktopMargin
                    height: desktopRatio > screenRatio ? parent.height - bigDesktopMargin
                            : parent.width / screenItem.width * screenItem.height - bigDesktopMargin

                    property real desktopRatio: parent.width / parent.height
                    property real screenRatio: screenItem.width / screenItem.height
                }
            }
        }

        onCurrentIndexChanged: {
            mainWindow.workWithActivities ? workspace.currentActivity = workspace.activities[currentIndex]
                    : workspace.currentDesktop = currentIndex + 1;
        }
    }

    function updateDesktopWindowId() {
        let clients = workspace.clientList(); 
        for (let i = 0; i < clients.length; i++) {
            if (clients[i].desktopWindow && clients[i].screen === screenItem.screenIndex) {
                screenItem.desktopBackground.winId = clients[i].windowId;
                return;
            }
        }
    }

    Component.onCompleted: {
        updateDesktopWindowId();
    }
}
