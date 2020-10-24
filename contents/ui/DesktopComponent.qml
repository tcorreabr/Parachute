import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQml.Models 2.2
import QtGraphicalEffects 1.12
import QtQuick.Layouts 1.12

Item {
    id: desktopItem

    property alias clientsRepeater: clientsRepeater

    property int desktopIndex: model.index
    property bool big: false
    property bool hovered: desktopItemHoverHandler.hovered || addButton.hovered || removeButton.hovered
    property int padding: 10
    property int clientsPadding: big ? 10 : 0
    property int clientsDecorationsHeight: big && mainWindow.configShowWindowTitles ? 24 : 0
    property real ratio: width / height

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

    RowLayout {
        height: 20
        spacing: 10
        anchors.top: parent.top
        anchors.topMargin: -10
        anchors.horizontalCenter: parent.horizontalCenter
        visible: false // !big && hovered

        RoundButton {
            id: removeButton
            implicitHeight: parent.height
            implicitWidth: parent.height
            radius: height / 2
            focusPolicy: Qt.NoFocus

            Image { source: "images/remove.svg"; anchors.fill: parent; }

            onClicked: {
                workspace.removeDesktop(desktopIndex);
            }
        }

        RoundButton {
            id: addButton
            implicitHeight: parent.height
            implicitWidth: parent.height
            radius: height / 2
            focusPolicy: Qt.NoFocus

            Image { source: "images/add.svg"; anchors.fill: parent; }

            onClicked: {
                workspace.createDesktop(desktopIndex + 1, "New desktop");
            }
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
        // onFilterItemChanged: update();
        
        property var filterItem: function(item) {
            return !item.model.client.caption.endsWith(" — Yakuake") && !item.model.client.caption.endsWith(" — krunner");
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

    function rearrangeClients() {
        if (!mainWindow.desktopsInitialized) return;

        mainWindow.easingType = mainWindow.activated ? Easing.OutExpo : mainWindow.noAnimation;
        calculateTransformations();
        updateToGrid();
    }

    function calculateTransformations() {
        if (clientsRepeater.count < 1) return;

        // Calculate the number of rows and columns
        const clientsCount = clientsRepeater.count;
        const addToColumns = Math.floor((clientsArea.width - padding * 2) / (clientsArea.height - padding * 2));
        let columns = Math.floor(Math.sqrt(clientsCount));
        (columns + addToColumns >= clientsCount) ? columns = clientsCount : columns += addToColumns;
        let rows = Math.ceil(clientsCount / columns);
        while ((columns - 1) * rows >= clientsCount) columns--;

        // Calculate client's geometry transformations
        const gridItemWidth = Math.floor((clientsArea.width - padding * 2) / columns);
        const gridItemHeight = Math.floor((clientsArea.height - padding * 2) / rows);
        const gridItemRatio = gridItemWidth / gridItemHeight;

        let currentClient = 0;
        for (let row = 0; row < rows; row++) {
            for (let column = 0; column < columns; column++) {
                // TODO FIXME sometimes clientItem is null (something related with yakuake or krunner?)
                const clientItem = clientsRepeater.itemAt(currentClient);

                // calculate the scaling factor, avoiding windows bigger than original size
                if (gridItemRatio > clientItem.client.width / clientItem.client.height) {
                    clientItem.gridHeight = Math.min(gridItemHeight, clientItem.client.height);
                    clientItem.gridWidth = clientItem.gridHeight / clientItem.client.height * clientItem.client.width;
                } else {
                    clientItem.gridWidth = Math.min(gridItemWidth, clientItem.client.width);
                    clientItem.gridHeight = clientItem.gridWidth / clientItem.client.width * clientItem.client.height;
                }
                clientItem.gridX = column * gridItemWidth + padding + (gridItemWidth - clientItem.gridWidth) / 2;
                clientItem.gridY = row * gridItemHeight + padding + (gridItemHeight - clientItem.gridHeight) / 2;

                currentClient++;
                if (currentClient === clientsCount) {
                    column = columns; // exit inner for
                    row = rows; // exit outer for
                }
            }
        }
    }

    function updateToGrid() {
        for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++) {
            const currentClientItem = clientsRepeater.itemAt(currentClient);
            currentClientItem.x = currentClientItem.gridX;
            currentClientItem.y = currentClientItem.gridY;
            currentClientItem.width = currentClientItem.gridWidth;
            currentClientItem.height = currentClientItem.gridHeight;
        }
    }

    function updateToOriginal() {
        for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++) {
            const currentClientItem = clientsRepeater.itemAt(currentClient);
            currentClientItem.x = currentClientItem.client.x - screenItem.x;
            currentClientItem.y = currentClientItem.client.y - screenItem.y;
            currentClientItem.width = currentClientItem.client.width;
            currentClientItem.height = currentClientItem.client.height;
        }
    }
}