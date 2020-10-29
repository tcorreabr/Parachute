import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQml.Models 2.2
import QtGraphicalEffects 1.12
import QtQuick.Layouts 1.12

Item {
    id: desktopItem

    property alias clientsRepeater: clientsRepeater
    property alias clientsArea : clientsArea

    property int desktopIndex: model.index
    property bool big: false
    property bool hovered: desktopItemHoverHandler.hovered || addButton.hovered || removeButton.hovered
    property int clientsPadding: big ? 10 : 0
    property int clientsDecorationsHeight: big && mainWindow.configShowWindowTitles ? mainWindow.buttonsSize : 0
    property real ratio: width / height

    property real scale: clientsArea.width / screenItem.width
    property bool gridView: true

    // Calculate the number of rows and columns of the desktop grid
    property real sqrtOfCount: Math.sqrt(clientsRepeater.count)
    property int addToColumns: (screenItem.ratio >= 2 && clientsRepeater.count > 2) ? 2 : (sqrtOfCount % 1 === 0) ? 0 : 1
    property int columns: Math.floor(sqrtOfCount) + addToColumns
    property int rows: Math.ceil(clientsRepeater.count / columns)

    property real gridItemWidth: columns !== 0 ? clientsRepeater.count === 1 ? clientsArea.width * 0.75 : clientsArea.width / columns : 0
    property real gridItemHeight: rows !== 0 ? clientsRepeater.count === 1 ? clientsArea.height * 0.75 : clientsArea.height / rows : 0
    property real gridItemRatio: gridItemHeight !== 0 ? gridItemWidth / gridItemHeight : 0

    Rectangle {
        id: colorBackground
        anchors.fill: parent
        visible: !big && !screenItem.desktopBackground.thumbnailAvailable
        color: "#222222"
        radius: 10
    }

    DropShadow {
        anchors.fill: parent
        horizontalOffset: 3
        verticalOffset: 3
        color: "#55000000"
        visible: !big && mainWindow.configShowDesktopShadows
        source: colorBackground
        cached: true
    }

    OpacityMask {
        id: thumbBackground
        anchors.fill: parent
        source: screenItem.desktopBackground
        maskSource: colorBackground // has to be opaque
        visible: !big && screenItem.desktopBackground.thumbnailAvailable
        cached: true
    }

    Rectangle {
        id: colorizeRect
        anchors.fill: parent
        color: "transparent"
        radius: 10
        border.width: !big && desktopIndex === mainWindow.currentDesktop ? 2 : 0
        border.color: "white"

        states: [
            State {
                when: desktopDropArea.containsDrag
                PropertyChanges { target: colorizeRect; color: "#3F006600"; }
            },
            State {
                when: !big && hovered
                PropertyChanges { target: colorizeRect; color: mainWindow.hoverColor; }
            }
        ]
    }

    ToolTip {
        visible: !big && hovered
        text: workspace.desktopName(desktopIndex + 1);
        delay: 1000
        timeout: 5000
    }

    Row {
        spacing: 10
        anchors.top: parent.top
        anchors.topMargin: -mainWindow.buttonsSize / 2
        anchors.horizontalCenter: parent.horizontalCenter
        visible: false // !big && hovered

        RoundButton {
            id: removeButton
            implicitHeight: mainWindow.buttonsSize
            implicitWidth: mainWindow.buttonsSize
            radius: height / 2
            focusPolicy: Qt.NoFocus

            Image { source: "images/remove.svg" }

            onClicked: { workspace.removeDesktop(desktopIndex); }
        }

        RoundButton {
            id: addButton
            implicitHeight: mainWindow.buttonsSize
            implicitWidth: mainWindow.buttonsSize
            radius: height / 2
            focusPolicy: Qt.NoFocus

            Image { source: "images/add.svg" }

            onClicked: { workspace.createDesktop(desktopIndex + 1, "New desktop"); }
        }
    }

    DropArea {
        id: desktopDropArea
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
                // Ensures mainWindow.outsideSelectedClient stays on current desktop
                if (drag.source === mainWindow.outsideSelectedClient) {
                    if (clientsRepeater.itemAt(0))
                        mainWindow.outsideSelectedClient = clientsRepeater.itemAt(0);
                    // TODO: create screenItem.desktopWindow?
                    // else
                    //      mainWindow.outsideSelectedClient = ??
                }

                drag.source.desktop = desktopIndex + 1;
            }
            if (screenItem.screenIndex !== drag.source.screen && drag.source.moveableAcrossScreens)
                workspace.sendClientToScreen(drag.source, screenItem.screenIndex);
        }
    }

    DelegateModel {
        id: clientsModel
        model: clientsByScreenAndDesktop
        rootIndex: clientsByScreenAndDesktop.index(desktopItem.desktopIndex, 0, clientsByScreenAndDesktop.index(screenItem.screenIndex,0))
        filterOnGroup: "visible"

        delegate: ClientComponent {}

        groups: DelegateModelGroup {
            name: "visible"
            includeByDefault: false
        }

        items.onChanged: update();
        onFilterItemChanged: update();
        
        property var filterItem: function(item) {
            const client = item.model.client;
            return client && !client.caption.endsWith(" — Yakuake") && !client.caption.endsWith(" — krunner") &&
                    client.width !== 0 && client.height !== 0; // To avoid division by zero later
        }

        function update() {
            for (let i = 0; i < items.count; ++i) {
                const item = items.get(i);
                if (item.inVisible !== filterItem(item))
                    item.inVisible = !item.inVisible;
            }
        }
    }

    Item {
        id: clientsArea
        anchors.centerIn: parent
        width: desktopItem.ratio <= screenItem.ratio ? desktopItem.width - (mainWindow.desktopMargin * 2)
                : clientsArea.height / screenItem.height * screenItem.width
        height: desktopItem.ratio > screenItem.ratio ? desktopItem.height - (mainWindow.desktopMargin * 2)
                : clientsArea.width / screenItem.width * screenItem.height

        Repeater {
            id: clientsRepeater
            model: clientsModel
        }
    }

    HoverHandler {
        id: desktopItemHoverHandler
        enabled: mainWindow.handlersEnabled

        onPointChanged: {
            if (mainWindow.keyboardSelected) {
                mainWindow.keyboardSelected = false;
                mainWindow.pointKeyboardSelected = point.position;
                return;
            }

            if (mainWindow.selectedClientItem !== clientsArea.childAt(point.position.x - clientsArea.x, point.position.y - clientsArea.y) &&
                    point.position !== Qt.point(0, 0) &&
                    (!mainWindow.pointKeyboardSelected ||
                    Math.abs(mainWindow.pointKeyboardSelected.x - point.position.x) > 3 ||
                    Math.abs(mainWindow.pointKeyboardSelected.y - point.position.y) > 3)) {
                mainWindow.selectedClientItem = clientsArea.childAt(point.position.x - clientsArea.x, point.position.y - clientsArea.y);
                mainWindow.pointKeyboardSelected = null;
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.AllButtons
        enabled: mainWindow.handlersEnabled

        onTapped: {
            switch (eventPoint.event.button) {
                case Qt.LeftButton:
                case Qt.NoButton:
                    if (workspace.currentDesktop === model.index + 1)
                        mainWindow.toggleActive();
                    else
                        workspace.currentDesktop = model.index + 1;
                    break;
                case Qt.MiddleButton:
                    if (mainWindow.selectedClientItem) mainWindow.selectedClientItem.client.closeWindow();
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