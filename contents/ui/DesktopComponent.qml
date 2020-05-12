import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQml.Models 2.2
import QtGraphicalEffects 1.12

Item {
    id: desktopItem
    visible: !big || desktopIndex === mainWindow.currentActivityOrDesktop

    property alias clientsRepeater: clientsRepeater

    property int desktopIndex: model.index
    property string activity
    property bool big: false
    property int bigDesktopMargin: 40

    property int clientsDecorationsHeight: big && mainWindow.configShowWindowTitles ? 22 : 0
    property int clientsPadding: big ? 10 : 0

    onBigDesktopMarginChanged: {
        if (bigDesktopMargin === 0 && mainWindow.easingType === Easing.InExpo) {
            if (mainWindow.activated) {
                for (let currentScreen = 0; currentScreen < screensRepeater.count; currentScreen++)
                    screensRepeater.itemAt(currentScreen).visible = false;
                mainWindow.activated = false;
            }
            desktopItem.updateToCalculated(mainWindow.noAnimation);
        }
    }

    Behavior on bigDesktopMargin {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { id: bigDesktopMarginAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
    }

    Rectangle {
        id: colorBackground
        anchors.fill: parent
        visible: !big && !screenItem.desktopBackground.thumbnailAvailable
        color: "#222222"
        radius: 10
    }

    DropShadow {
        anchors.fill: colorBackground
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8.0
        samples: 17
        color: "#80000000"
        visible: !big && mainWindow.configShowDesktopShadows
        source: colorBackground
    }

    OpacityMask {
        id: thumbBackground
        anchors.fill: parent
        source: screenItem.desktopBackground
        maskSource: colorBackground // has to be opaque
        visible: !big && screenItem.desktopBackground.thumbnailAvailable
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

        HoverHandler {
            id: desktopItemHoverHandler
            enabled: !big
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
            for (let i = 0; i < items.count; ++i) {
                let item = items.get(i);
                if (item.inVisible !== filterItem(item))
                    item.inVisible = !item.inVisible;
            }
        }
    }

    Item {
        id: clientsArea
        anchors.fill: parent
        anchors.margins: 10

        Repeater {
            id: clientsRepeater
            model: clientsModel

            onItemAdded: rearrangeClients();
            onItemRemoved: rearrangeClients();
        }

        HoverHandler {
            enabled: big && !bigDesktopMarginAnimation.running && !mainWindow.dragging

            onPointChanged: {
                if (mainWindow.keyboardSelected) {
                    mainWindow.keyboardSelected = false;
                    mainWindow.pointKeyboardSelected = point.position;
                    return;
                }

                if (mainWindow.selectedClientItem !== clientsArea.childAt(point.position.x, point.position.y) &&
                        point.position !== Qt.point(0, 0) &&
                        (mainWindow.pointKeyboardSelected === null ||
                        Math.abs(mainWindow.pointKeyboardSelected.x - point.position.x) > 3 ||
                        Math.abs(mainWindow.pointKeyboardSelected.y - point.position.y) > 3)) {
                    mainWindow.selectedClientItem = clientsArea.childAt(point.position.x, point.position.y);
                    mainWindow.pointKeyboardSelected = null;
                }
            }

            onHoveredChanged: if (!hovered) mainWindow.selectedClientItem = null;
        }
    }

    function rearrangeClients() {
        if (!mainWindow.desktopsInitialized) return;
        calculateTransformations();
        desktopItem.updateToCalculated(mainWindow.activated ? Easing.OutExpo : mainWindow.noAnimation);
    }

    function calculateTransformations() {
        if (clientsRepeater.count < 1) return;

        mainWindow.easingType = mainWindow.noAnimation;
        bigDesktops.anchors.topMargin = bigDesktops.parent.height / 6;
        bigDesktopMargin = 40;

        // Calculate the number of rows and columns
        let clientsCount = clientsRepeater.count;
        let columns = Math.floor(Math.sqrt(clientsCount));
        let addToColumns = Math.floor(clientsArea.width / clientsArea.height);
        (columns + addToColumns >= clientsCount) ? columns = clientsCount : columns += addToColumns;
        let rows = Math.ceil(clientsCount / columns);
        while ((columns - 1) * rows >= clientsCount) columns--;

        // Calculate client's geometry transformations
        let gridItemWidth = Math.floor(clientsArea.width / columns);
        let gridItemHeight = Math.floor(clientsArea.height / rows);
        let gridItemRatio = gridItemWidth / gridItemHeight;

        let currentClient = 0;
        for (let row = 0; row < rows; row++) {
            for (let column = 0; column < columns; column++) {
                // TODO FIXME sometimes clientItem is null (something related with yakuake or krunner?)
                let clientItem = clientsRepeater.itemAt(currentClient);

                // client.noBorder is non-NOTIFYable, so we'll update noBorderMargin here
                clientItem.noBorderMargin = clientItem.client.noBorder ? big ? 18 : 4 : 0;

                clientItem.originalX = clientItem.client.x - screenItem.x - clientsPadding;
                clientItem.originalY = clientItem.client.y - screenItem.y - clientsDecorationsHeight - clientsPadding;
                clientItem.originalWidth = clientItem.client.width + 2 * clientsPadding;
                clientItem.originalHeight = clientItem.client.height + clientsDecorationsHeight + 2 * clientsPadding;

                // calculate the scaling factor, avoiding windows bigger than original size
                if (gridItemRatio > clientItem.originalWidth / clientItem.originalHeight) {
                    clientItem.calculatedHeight = Math.min(gridItemHeight, clientItem.originalHeight);
                    clientItem.calculatedWidth = clientItem.calculatedHeight / clientItem.originalHeight * clientItem.originalWidth;
                } else {
                    clientItem.calculatedWidth = Math.min(gridItemWidth, clientItem.originalWidth);
                    clientItem.calculatedHeight = clientItem.calculatedWidth / clientItem.originalWidth * clientItem.originalHeight;
                }
                clientItem.calculatedX = column * gridItemWidth + (gridItemWidth - clientItem.calculatedWidth) / 2;
                clientItem.calculatedY = row * gridItemHeight + (gridItemHeight - clientItem.calculatedHeight) / 2;

                currentClient++;
                if (currentClient === clientsCount) {
                    column = columns; // exit inner for
                    row = rows; // exit outer for
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
            currentClientItem.x = currentClientItem.calculatedX;
            currentClientItem.y = currentClientItem.calculatedY;
            currentClientItem.width = currentClientItem.calculatedWidth;
            currentClientItem.height = currentClientItem.calculatedHeight;
        }
    }

    function updateToOriginal(animationType) {
        mainWindow.easingType = animationType;
        bigDesktops.anchors.topMargin = 0;
        bigDesktopMargin = 0;
        for (let currentClient = 0; currentClient < clientsRepeater.count; currentClient++) {
            let currentClientItem = clientsRepeater.itemAt(currentClient);
            currentClientItem.x = currentClientItem.originalX;
            currentClientItem.y = currentClientItem.originalY;
            currentClientItem.width = currentClientItem.originalWidth;
            currentClientItem.height = currentClientItem.originalHeight;
        }
    }
}