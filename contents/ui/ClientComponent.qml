import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.kde.kwin 2.0 as KWinComponents
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: clientItem

    property var client: model.client
    property int noBorderMargin

    property real calculatedX
    property real calculatedY
    property real calculatedWidth
    property real calculatedHeight

    Behavior on x {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on y {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on width {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on height {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
    }

    PlasmaCore.FrameSvgItem {
        id: selectedFrame
        anchors.fill : parent
        imagePath: "widgets/viewitem"
        prefix: "hover"
        visible: big && !mainWindow.animating && mainWindow.selectedClientItem === clientItem && !mainWindow.dragging
        opacity: 0.7
    }

    Item {
        id: clientDecorations
        height: desktopItem.clientsDecorationsHeight
        width: clientThumbnail.width * 0.8
        anchors.top: parent.top
        anchors.topMargin: desktopItem.clientsPadding
        anchors.horizontalCenter: parent.horizontalCenter
        visible: big && mainWindow.configShowWindowTitles && !mainWindow.animating && !clientThumbnail.Drag.active

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
                    background: Rectangle { color: "red"; radius: height / 2; }

                    Image { source: "images/close.svg" }

                    onClicked: clientItem.client.closeWindow();
                }
            }
        }
    }

    KWinComponents.ThumbnailItem {
        id: clientThumbnail
        anchors.fill: Drag.active ? undefined : parent // tried to change in the state, but doesn't work
        anchors.margins: desktopItem.clientsPadding + clientItem.noBorderMargin
        anchors.topMargin: desktopItem.clientsPadding + clientItem.noBorderMargin + desktopItem.clientsDecorationsHeight
        wId: clientItem.client ? clientItem.client.internalId : "{00000000-0000-0000-0000-000000000000}"
        clipTo: screenItem
        clip: true
        Drag.source: clientItem.client
        renderTarget: KWinComponents.ThumbnailItem.FramebufferObject
        antialiasing: false
        smooth: false
        // fillColor: "green"
        
        states: State {
            when: clientThumbnail.Drag.active

            PropertyChanges {
                target: clientThumbnail
                x: desktopItem.clientsPadding + myDragHandler.centroid.position.x - clientThumbnail.width / 2
                y: desktopItem.clientsPadding + desktopItem.clientsDecorationsHeight + myDragHandler.centroid.position.y - clientThumbnail.height / 2
                width: 250; height: 250; clip: false
                Drag.hotSpot.x: clientThumbnail.width / 2
                Drag.hotSpot.y: clientThumbnail.height / 2
            }
        }
    }

    Item {
        id: dragPlaceholder
        anchors.fill: parent
        anchors.margins: desktopItem.clientsPadding + clientItem.noBorderMargin
        anchors.topMargin: desktopItem.clientsPadding + clientItem.noBorderMargin + desktopItem.clientsDecorationsHeight

        DragHandler {
            id: myDragHandler
            target: null

            onActiveChanged: {
                mainWindow.dragging = myDragHandler.active;
                myDragHandler.active ? clientThumbnail.Drag.active = true : clientThumbnail.Drag.drop();
            }
        }
    }

    onClientChanged: {
        if (client) {
            client.moveResizedChanged.connect(function() { mainWindow.desktopsInitialized = false; });
            clientItem.noBorderMargin = client.noBorder ? desktopItem.big ? 18 : 4 : 0;
        }
    }
}