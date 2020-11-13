import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.kde.kwin 2.0 as KWinComponents
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: clientItem

    property var client: model.client
    property int noBorderMargin // margin to add to clients without borders (mainly gtk csd or fullscreen windows)
    property bool ready: false

    // Client dimensions are non notifyable
    property int clientX
    property int clientY
    property int clientWidth
    property int clientHeight
    
    ////////////////////////////
    // Grid view calculations //
    ////////////////////////////
    property int row: Math.floor(model.index / desktopItem.columns)
    property int column: model.index - desktopItem.columns * row

    property real clientGridScale: clientWidth / clientHeight > desktopItem.gridItemAspectRatio ?
            desktopItem.gridItemWidth / clientWidth :
            desktopItem.gridItemHeight / clientHeight
    property real gridX: clientsRepeater.count === 1 ?
            desktopItem.gridAreaX + (desktopItem.gridAreaWidth - gridWidth) / 2 :
            desktopItem.gridAreaX + column * desktopItem.gridItemWidth + (desktopItem.gridItemWidth - gridWidth) / 2
    property real gridY: clientsRepeater.count === 1 ?
            desktopItem.gridAreaY + (desktopItem.gridAreaHeight - gridHeight) / 2 :
            desktopItem.gridAreaY + row * desktopItem.gridItemHeight + (desktopItem.gridItemHeight - gridHeight) / 2
    property real gridWidth: clientWidth * clientGridScale
    property real gridHeight: clientHeight * clientGridScale
    ////////////////////////////

    states: [
        State {
            when: !ready
            PropertyChanges {
                target: clientItem
                x: desktopItem.gridAreaX
                y: desktopItem.gridAreaY
                width: 250
                height: 250
            }
        },
        State {
            when: !desktopItem.gridView && ready
            PropertyChanges {
                target: clientItem
                x: clientX
                y: clientY
                width: clientWidth
                height: clientHeight
            }
        },
        State {
            when: desktopItem.gridView && ready
            PropertyChanges {
                target: clientItem
                x: gridX
                y: gridY
                width: gridWidth
                height: gridHeight
            }
        }
    ]

    Behavior on x {
        enabled: mainWindow.activated
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on y {
        enabled: mainWindow.activated
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on width {
        enabled: mainWindow.activated
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on height {
        enabled: mainWindow.activated
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    PlasmaCore.FrameSvgItem {
        id: selectedFrame
        anchors.fill : parent
        imagePath: "widgets/viewitem"
        prefix: "hover"
        visible: desktopItem.big && !mainWindow.animating && mainWindow.selectedClientItem === clientItem && !mainWindow.dragging
        opacity: 0.7
    }

    Item {
        id: clientDecorations
        height: desktopItem.clientsDecorationsHeight
        width: clientThumbnail.width * 0.8
        anchors.top: parent.top
        anchors.topMargin: desktopItem.clientsPadding
        anchors.horizontalCenter: parent.horizontalCenter
        visible: desktopItem.big && mainWindow.configShowWindowTitles && !mainWindow.animating && !clientThumbnail.Drag.active

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            spacing: 10

            PlasmaCore.IconItem {
                id: icon
                source: clientItem.client ? clientItem.client.icon : null
                implicitHeight: parent.height
                implicitWidth: parent.height
            }

            Text {
                id: caption
                height: parent.height
                text: clientItem.client ? clientItem.client.caption : null
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: "white"
                Layout.maximumWidth: clientDecorations.width - icon.width - parent.spacing - closeButton.width - parent.spacing
            }

            // This wrapper is needed because QML recalculate Layouts when children visibility change 
            Item {
                id: closeButtonWrapper
                implicitHeight: parent.height
                implicitWidth: parent.height

                RoundButton {
                    id: closeButton
                    anchors.fill: parent
                    visible: selectedFrame.visible
                    focusPolicy: Qt.NoFocus
                    background: Rectangle { color: "firebrick"; radius: height / 2; }

                    Image { source: "images/close.svg" }

                    onClicked: clientItem.client.closeWindow();
                }
            }
        }
    }

    KWinComponents.ThumbnailItem {
        id: clientThumbnail
        anchors.fill: Drag.active ? undefined : parent // tried to change in the state, but doesn't work
        anchors.margins: desktopItem.clientsPadding + noBorderMargin
        anchors.topMargin: desktopItem.clientsPadding + noBorderMargin + desktopItem.clientsDecorationsHeight
        wId: clientItem.client ? clientItem.client.internalId : "{00000000-0000-0000-0000-000000000000}"
        Drag.source: clientItem.client
        clip: true
        clipTo: screenItem
        
        states: State {
            when: clientThumbnail.Drag.active

            PropertyChanges {
                target: clientThumbnail
                x: desktopItem.clientsPadding + clientDragHandler.centroid.position.x - clientThumbnail.width / 2
                y: desktopItem.clientsPadding + desktopItem.clientsDecorationsHeight + clientDragHandler.centroid.position.y - clientThumbnail.height / 2
                width: 250; height: 250; clip: false
                Drag.hotSpot.x: clientThumbnail.width / 2
                Drag.hotSpot.y: clientThumbnail.height / 2
            }
        }
    }

    Item {
        id: dragPlaceholder
        anchors.fill: parent
        anchors.margins: desktopItem.clientsPadding + noBorderMargin
        anchors.topMargin: desktopItem.clientsPadding + noBorderMargin + desktopItem.clientsDecorationsHeight

        DragHandler {
            id: clientDragHandler
            target: null

            onActiveChanged: {
                mainWindow.dragging = active;
                active ? clientThumbnail.Drag.active = true : clientThumbnail.Drag.drop();
            }
        }
    }

    Component.onCompleted: ready = true;

    onClientChanged: {
        if (!client) return;

        updateClientProperties();
        client.clientFinishUserMovedResized.connect(function(clientParam) { updateClientProperties(); });
        client.clientMaximizedStateChanged.connect(function(clientParam, h, v) { updateClientProperties(); });
    }

    function updateClientProperties() {
        if (!client) return;

        clientX = client.x - screenItem.x;
        clientY = client.y - screenItem.y;
        clientWidth = client.width;
        clientHeight = client.height;

        noBorderMargin = client.noBorder ? desktopItem.big ? 18 : 4 : 0;
    }
}