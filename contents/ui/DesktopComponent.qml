import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQml.Models 2.2
import QtGraphicalEffects 1.14

Item {
    id: desktopItem
    visible: !big || Math.abs(desktopIndex - mainWindow.currentActivityOrDesktop) < 2

    property alias clientsRepeater: clientsRepeater

    property int desktopIndex: model.index
    property string activity
    property bool big: false
    property int bigDesktopMargin: 40

    onBigDesktopMarginChanged: {
        if (bigDesktopMargin === 0 && mainWindow.easingType === Easing.InExpo) {
            if (mainWindow.activated) {
                for (var currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
                    screensRepeater.itemAt(currentScreen).visible = false;
                mainWindow.activated = false;
            }
            desktopItem.updateToCalculated(mainWindow.noAnimation);
        }
    }

    Behavior on bigDesktopMargin {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { duration: animationsDuration; easing.type: mainWindow.easingType; }
    }

    Rectangle {
        id: colorBackground
        anchors.fill: parent
        visible: !big && !screenItem.desktopThumbnail.thumbnailAvailable
        color: "#222222"
        radius: 10
    }

    OpacityMask {
        id: thumbBackground
        anchors.fill: parent
        source: screenItem.desktopThumbnail
        maskSource: colorBackground // has to be opaque
        visible: !big && screenItem.desktopThumbnail.thumbnailAvailable
        // cached: true
    }

    Rectangle {
        id: colorizeRect
        anchors.fill: parent
        color: "transparent"
        radius: 10
        border.width: !big && (desktopIndex === mainWindow.currentActivityOrDesktop) ? 2 : 0
        border.color: "white"

        states: [
            State {
                when: desktopDropArea.containsDrag
                PropertyChanges { target: colorizeRect; color: "#5000AA00"; }
            },
            State {
                when: !big && (desktopItemHoverHandler.hovered)
                PropertyChanges { target: colorizeRect; color: "#500055FF"; }
            }
        ]
    }

    HoverHandler {
        id: desktopItemHoverHandler
    }

    TapHandler {
        acceptedButtons: Qt.AllButtons

        onTapped: {
            if (mainWindow.clientTapped) {
                mainWindow.clientTapped = false;
                return;
            }

            if (big) {
                mainWindow.selectedClient = null;
                mainWindow.toggleActive();
            } else {
                workspace.currentDesktop = desktopIndex + 1;
            }
        }
    }

    DropArea {
        id: desktopDropArea
        anchors.fill: parent

        onEntered: {
            drag.accepted = false;            
            if (!mainWindow.workWithActivities && desktopIndex + 1 !== drag.source.desktop && drag.source.desktop !== -1) {
                drag.accepted = true;
                return;
            }
            if (mainWindow.workWithActivities && !drag.source.activities.includes(desktopItem.activity) && drag.source.activities.length !== 0) {
                drag.accepted = true;
                return;
            }
            if (screenItem.screenIndex !== drag.source.screen && drag.source.moveableAcrossScreens)
                drag.accepted = true;
        }

        onDropped: {
            if (!mainWindow.workWithActivities && desktopIndex + 1 !== drag.source.desktop && drag.source.desktop !== -1)
                drag.source.desktop = desktopIndex + 1;
            if (mainWindow.workWithActivities && !drag.source.activities.includes(desktopItem.activity) && drag.source.activities.length !== 0)
                drag.source.activities.push(desktopItem.activity);
            if (screenItem.screenIndex !== drag.source.screen && drag.source.moveableAcrossScreens)
                workspace.sendClientToScreen(drag.source, screenItem.screenIndex);
        }
    }

    DelegateModel {
        id: clientsModel
        model: mainWindow.workWithActivities ? clientsByScreen : clientsByScreenAndDesktop
        rootIndex: mainWindow.workWithActivities ? clientsByScreen.index(screenItem.screenIndex, 0) :
            clientsByScreenAndDesktop.index(desktopItem.desktopIndex, 0, clientsByScreenAndDesktop.index(screenItem.screenIndex,0))
        filterOnGroup: mainWindow.workWithActivities ? "visible" : "items"

        delegate: ClientComponent {}

        groups: DelegateModelGroup {
            name: "visible"
            includeByDefault: false
        }

        items.onChanged: if (mainWindow.workWithActivities) update();
        onFilterItemChanged: if (mainWindow.workWithActivities) update();
        
        property var filterItem: function(item) {
            if (item.model.client.desktopWindow) return false;
            if (item.model.client.activities.length === 0) return true;
            return item.model.client.activities.includes(desktopItem.activity);
        }

        function update() {
            for (var i = 0; i < items.count; ++i) {
                var item = items.get(i);
                if (item.inVisible !== filterItem(item))
                    item.inVisible = !item.inVisible;
            }
        }
    }

    Repeater {
        id: clientsRepeater
        model: clientsModel

        onItemAdded: rearrangeClients();
        onItemRemoved: rearrangeClients();
    }

    function rearrangeClients() {
        if (!mainWindow.desktopsInitialized) return;
        calculateTransformations();
        desktopItem.updateToCalculated(mainWindow.activated ? Easing.OutExpo : mainWindow.noAnimation);
    }

    function calculateTransformations() {
        mainWindow.easingType = mainWindow.noAnimation;
        bigDesktops.anchors.topMargin = bigDesktops.parent.height / 6;
        bigDesktopMargin = 40;

        if (clientsRepeater.count < 1) return;
        let clientsCount = clientsRepeater.count;
        const CLIENTS_PADDING = 10;
        const DESKTOP_PADDING = 10;

        const clientsAreaWidth = desktopItem.width - DESKTOP_PADDING * 2;
        const clientsAreaHeight = desktopItem.height - DESKTOP_PADDING * 2;

        // Calculate the number of rows and columns
        let columns = Math.floor(Math.sqrt(clientsCount));
        let addToColumns = Math.floor(clientsAreaWidth / clientsAreaHeight);
        (columns + addToColumns >= clientsCount) ? columns = clientsCount : columns += addToColumns;
        let rows = Math.ceil(clientsCount / columns);
        while ((columns - 1) * rows >= clientsCount) columns--;

        // Calculate client's geometry transformations
        let gridItemWidth = Math.floor(clientsAreaWidth / columns);
        let gridItemHeight = Math.floor(clientsAreaHeight / rows);
        let newThumbWidth = desktopItem.big ? gridItemWidth - CLIENTS_PADDING * 2 : gridItemWidth;
        let newThumbHeight = desktopItem.big ? gridItemHeight - CLIENTS_PADDING * 2 - mainWindow.clientDecorationsHeight : gridItemHeight;
        let newThumbRatio = newThumbWidth / newThumbHeight;

        let currentClient = 0;
        for (var row = 0; row < rows; row++) {
            for (var column = 0; column < columns; column++) {
                let clientItem = clientsRepeater.itemAt(currentClient);
                let gridItemX = DESKTOP_PADDING + column * gridItemWidth;
                let gridItemY = DESKTOP_PADDING + row * gridItemHeight;
                let scale;

                // this is here to avoid "non-NOTIFYable properties” warning
                clientItem.originalX = clientItem.client.x - screenItem.x;
                clientItem.originalY = clientItem.client.y - screenItem.y;
                clientItem.originalWidth = clientItem.client.width;
                clientItem.originalHeight = clientItem.client.height;

                if (newThumbRatio > clientItem.originalWidth / clientItem.originalHeight)
                    scale = newThumbHeight < clientItem.originalHeight ? newThumbHeight / clientItem.originalHeight : 1.0;
                else
                    scale = newThumbWidth < clientItem.originalWidth ? newThumbWidth / clientItem.originalWidth : 1.0;

                clientItem.calculatedWidth = clientItem.originalWidth * scale;
                clientItem.calculatedHeight = clientItem.originalHeight * scale;
                clientItem.calculatedX = gridItemX + (gridItemWidth - clientItem.calculatedWidth) / 2;

                if (desktopItem.big) {
                    clientItem.clientDecorations.width = Math.max(clientItem.calculatedWidth * 0.8, gridItemWidth / 2);
                    clientItem.clientDecorations.x = gridItemX + (gridItemWidth - clientItem.clientDecorations.width) / 2;
                    clientItem.clientDecorations.y = gridItemY +
                        (gridItemHeight - (clientItem.calculatedHeight + clientItem.clientDecorations.height)) / 2;

                    clientItem.calculatedY = clientItem.clientDecorations.y + clientItem.clientDecorations.height;

                    clientItem.selectedFrame.x = Math.min(clientItem.calculatedX, clientItem.clientDecorations.x) - CLIENTS_PADDING;
                    clientItem.selectedFrame.y = clientItem.clientDecorations.y - CLIENTS_PADDING;
                    clientItem.selectedFrame.width = Math.max(clientItem.calculatedWidth, clientItem.clientDecorations.width) + 2 * CLIENTS_PADDING;
                    clientItem.selectedFrame.height = clientItem.clientDecorations.height + clientItem.calculatedHeight + 2 * CLIENTS_PADDING;
                } else {
                    clientItem.calculatedY = gridItemY + (gridItemHeight - clientItem.calculatedHeight) / 2;

                    clientItem.selectedFrame.x = clientItem.calculatedX;
                    clientItem.selectedFrame.y = clientItem.calculatedY;
                    clientItem.selectedFrame.width = clientItem.calculatedWidth;
                    clientItem.selectedFrame.height = clientItem.calculatedHeight;
                }

                currentClient++;
                if (currentClient === clientsCount) {
                    row = rows;
                    column = columns;
                }
            }
        }
    }

    function updateToCalculated(animationType) {
        mainWindow.easingType = animationType;
        bigDesktops.anchors.topMargin = bigDesktops.parent.height / 6;
        bigDesktopMargin = 40;
        for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++) {
            let currentClientItem = clientsRepeater.itemAt(currentClient);
            currentClientItem.clientThumbnail.x = currentClientItem.calculatedX;
            currentClientItem.clientThumbnail.y = currentClientItem.calculatedY;
            currentClientItem.clientThumbnail.width = currentClientItem.calculatedWidth;
            currentClientItem.clientThumbnail.height = currentClientItem.calculatedHeight;
        }
    }

    function updateToOriginal(animationType) {
        mainWindow.easingType = animationType;
        bigDesktops.anchors.topMargin = 0;
        bigDesktopMargin = 0;
        for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++) {
            let currentClientItem = clientsRepeater.itemAt(currentClient);
            currentClientItem.clientThumbnail.x = currentClientItem.originalX;
            currentClientItem.clientThumbnail.y = currentClientItem.originalY;
            currentClientItem.clientThumbnail.width = currentClientItem.originalWidth;
            currentClientItem.clientThumbnail.height = currentClientItem.originalHeight;
        }
    }

    function isAnimating() {
        for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++)
            if (clientsRepeater.itemAt(currentClient).isAnimating) return true;
        return false;
    }
}