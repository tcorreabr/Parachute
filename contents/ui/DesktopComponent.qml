import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQml.Models 2.2
import QtGraphicalEffects 1.12

Item {
    id: desktopItem

    property alias clientsRepeater: clientsRepeater

    property int desktopIndex: model.index
    property bool big: false
    property bool gridView: true
    property int clientsPadding: big ? 10 : 0

    property real mouseAreaX
    property real mouseAreaY
    property real mouseAreaWidth
    property real mouseAreaHeight

    ////////////////////////////
    // Grid view calculations //
    ////////////////////////////
    property real gridAreaX
    property real gridAreaY
    property real gridAreaWidth
    property real gridAreaHeight

    property real sqrtOfCount: Math.sqrt(clientsRepeater.count)
    property int addToColumns: (screenItem.aspectRatio >= 2 && clientsRepeater.count > 2) ? 2 : (sqrtOfCount % 1 === 0) ? 0 : 1
    property int columns: Math.floor(sqrtOfCount) + addToColumns
    property int rows: Math.ceil(clientsRepeater.count / columns)

    property real gridItemWidth: clientsRepeater.count <= 1 ? gridAreaWidth * 0.75 : gridAreaWidth / columns
    property real gridItemHeight: clientsRepeater.count <= 1 ? gridAreaHeight * 0.75 : gridAreaHeight / rows
    property real gridItemAspectRatio: gridItemWidth / gridItemHeight
    //////////////////////////////

    Rectangle {
        id: roundedRect
        anchors.fill: parent
        visible: false
        color: "#222222"
        radius: 10
    }

    OpacityMask {
        id: desktopBackground
        anchors.fill: parent
        source: screenItem.desktopBackground
        maskSource: roundedRect
        visible: !big && screenItem.desktopBackground.thumbnailAvailable
        cached: true
    }

    DropShadow {
        anchors.fill: parent
        horizontalOffset: 3
        verticalOffset: 3
        color: "#55000000"
        visible: !big && mainWindow.configShowDesktopShadows
        source: desktopBackground
        cached: true
    }

    ToolTip {
        visible: !big && hoverHandler.hovered
        text: workspace.desktopName(desktopIndex + 1);
        delay: 1000
        timeout: 5000
    }

    Rectangle {
        id: mouseArea
        x: mouseAreaX
        y: mouseAreaY
        width: mouseAreaWidth
        height: mouseAreaHeight
        color: "transparent"
        radius: 10
        border.width: !big && desktopIndex === mainWindow.currentDesktop ? 3 : 0
        border.color: mainWindow.highlightColor

        states: [
            State {
                when: dropArea.containsDrag || (!big && mainWindow.idle && hoverHandler.hovered)
                PropertyChanges { target: mouseArea; color: mainWindow.highlightColor; opacity: 0.4; }
            }
        ]

        DropArea {
            id: dropArea
            anchors.fill: parent

            onEntered: {
                drag.accepted = false;
                if (desktopIndex + 1 !== drag.source.desktop && drag.source.desktop !== -1) {
                    drag.accepted = true;
                    return;
                }
                if (screenItem.screenIndex !== drag.source.screen && drag.source.moveableAcrossScreens)
                    drag.accepted = true;
            }

            onDropped: {
                if (desktopIndex + 1 !== drag.source.desktop && drag.source.desktop !== -1) {
                    // Ensures mainWindow.externallySelectedClient stays on current desktop
                    if (drag.source === mainWindow.externallySelectedClient) {
                        const tmpDragSourceDesktop = drag.source.desktop;
                        drag.source.desktop = desktopIndex + 1;
                        workspace.currentDesktop = desktopIndex + 1;
                        workspace.currentDesktop = tmpDragSourceDesktop; // Change desktop to select a new mainWindow.externallySelectedClient
                    } else {
                        drag.source.desktop = desktopIndex + 1;
                    }
                }

                if (screenItem.screenIndex !== drag.source.screen && drag.source.moveableAcrossScreens)
                    workspace.sendClientToScreen(drag.source, screenItem.screenIndex);
            }
        }

        HoverHandler {
            id: hoverHandler
            enabled: mainWindow.idle

            onPointChanged: {
                // Just to get pointAvoidUpdatingSelection
                if (mainWindow.avoidUpdatingSelection) {
                    mainWindow.avoidUpdatingSelection = false;
                    mainWindow.pointAvoidUpdatingSelection = point.position;
                    return;
                }

                // Continue only if mouse moved from pointAvoidUpdatingSelection
                if (mainWindow.pointAvoidUpdatingSelection &&
                        Math.abs(mainWindow.pointAvoidUpdatingSelection.x - point.position.x) < 1 &&
                        Math.abs(mainWindow.pointAvoidUpdatingSelection.y - point.position.y) < 1) {
                    return;
                }

                // Update selected client if needed
                const clientAtMousePosition = clientAtPos(point.position.x + mouseAreaX, point.position.y + mouseAreaY);
                if (mainWindow.selectedClientItem !== clientAtMousePosition) {
                    mainWindow.selectedClientItem = clientAtMousePosition;
                    mainWindow.pointAvoidUpdatingSelection = point.position;
                }
            }

            function clientAtPos(posX, posY) {
                for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++) {
                    const currentClientItem = clientsRepeater.itemAt(currentClient);
                    if (posX >= currentClientItem.x && posX <= currentClientItem.x + currentClientItem.width &&
                        posY >= currentClientItem.y && posY <= currentClientItem.y + currentClientItem.height) {
                        return currentClientItem;
                    }
                }
                return null;
            }
        }

        TapHandler {
            acceptedButtons: Qt.AllButtons

            onSingleTapped: {
                switch (eventPoint.event.button) {
                    case Qt.LeftButton:
                    case Qt.NoButton:
                        if (workspace.currentDesktop === model.index + 1)
                            mainWindow.toggleActive();
                        else
                            workspace.currentDesktop = model.index + 1;
                        break;
                    case Qt.MiddleButton:
                        if (mainWindow.selectedClientItem && mainWindow.configCloseOnMiddleClick)
                            mainWindow.selectedClientItem.client.closeWindow();
                        break;
                    case Qt.RightButton:
                        if (!mainWindow.selectedClientItem) break;

                        if (mainWindow.selectedClientItem.client.desktop === -1)
                            mainWindow.selectedClientItem.client.desktop = model.index + 1;
                        else
                            mainWindow.selectedClientItem.client.desktop = -1;
                        break;
                }
            }
        }
    }

    DelegateModel {
        id: clientsModel
        model: clientsFilterModel
        rootIndex: clientsFilterModel.index(desktopItem.desktopIndex, 0, clientsFilterModel.index(screenItem.screenIndex,0))
        filterOnGroup: "showing"

        delegate: ClientComponent {}

        groups: DelegateModelGroup {
            name: "showing"
            includeByDefault: false
        }

        items.onChanged: {
            for (let i = 0; i < items.count; ++i) {
                const item = items.get(i);
                const client = item.model.client;
                const show = client && !client.caption.endsWith(" — Yakuake") && !client.caption.endsWith(" — krunner") &&
                        client.width !== 0 && client.height !== 0; // To avoid division by zero later

                if (item.inShowing !== show) item.inShowing = !item.inShowing;
            }

            if (mainWindow.activated) {
                mainWindow.animating = true;
                mainWindow.easingType = Easing.OutExpo;
                endAnimationTimer.start();
            }
        }
    }

    Repeater {
        id: clientsRepeater
        model: big && mainWindow.searchText && mainWindow.configSearchMethod === Enums.SearchMethod.Krunner ? 0 : clientsModel
    }
}