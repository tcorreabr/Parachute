import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import org.kde.kwin 2.0 as KWinComponents
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: clientItem

    property alias selectedFrame: selectedFrame
    property alias clientDecorations: clientDecorations
    property alias clientThumbnail: clientThumbnail

    property bool isAnimating: xAnimation.running || yAnimation.running || widthAnimation.running || heightAnimation.running
    property var client: model.client

    property real originalX
    property real originalY
    property real originalWidth
    property real originalHeight

    property real calculatedX
    property real calculatedY
    property real calculatedWidth
    property real calculatedHeight

    Item {
        id: selectedFrame

        PlasmaCore.FrameSvgItem {
            anchors.fill : parent
            imagePath: "widgets/viewitem"
            prefix: "hover"
            visible: big && !isAnimating && selectedFrameHoverHandler.hovered && !mainWindow.dragging
        }

        HoverHandler {
            id: selectedFrameHoverHandler
        }

        TapHandler {
            acceptedButtons: Qt.AllButtons

            onTapped: {
                if (!big) return;
                mainWindow.clientTapped = true;

                switch (eventPoint.event.button) {
                    case Qt.LeftButton:
                        mainWindow.selectedClient = client;
                        mainWindow.toggleActive();
                        break;
                    case Qt.MiddleButton:
                        clientItem.client.closeWindow();
                        break;
                    case Qt.RightButton:
                        if (mainWindow.workWithActivities)
                            if (clientItem.client.activities.length === 0)
                                clientItem.client.activities.push(desktopItem.activity);
                            else
                                clientItem.client.activities = [];
                        else
                            if (clientItem.client.desktop === -1)
                                clientItem.client.desktop = desktopItem.desktopIndex;
                            else
                                clientItem.client.desktop = -1;
                        break;
                }
            }
        }
    }

    Item {
        id: clientDecorations
        height: mainWindow.clientDecorationsHeight
        visible: big && !isAnimating && !clientThumbnail.Drag.active

        RowLayout {
            id: rowLayout
            x: (parent.width - width) / 2
            height: parent.height
            spacing: 10

            PlasmaCore.IconItem {
                id: wIcon
                source: clientItem.client.icon
                implicitHeight: parent.height
                implicitWidth: parent.height
            }

            Text {
                id: caption
                height: parent.height
                text: clientItem.client.caption
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: "white"
                Layout.maximumWidth: clientDecorations.width - wIcon.width - rowLayout.spacing - closeButton.width - rowLayout.spacing
            }

            // This wrapper is needed because QML recalculate Layouts when visibility of children change 
            Item {
                id: closeButtonWrapper
                implicitHeight: parent.height
                implicitWidth: parent.height

                // PlasmaComponents.Button {
                RoundButton {
                    id: closeButton
                    anchors.fill: parent
                    icon.name: "window-close"
                    visible: selectedFrameHoverHandler.hovered && !mainWindow.dragging
                    hoverEnabled: false
                    radius: height / 2
                    focusPolicy: Qt.NoFocus

                    onClicked: clientItem.client.closeWindow();
                }
            }
        }
    }

    Item {
        id: dragPlaceholder
        x: calculatedX; y: calculatedY; width: calculatedWidth; height: calculatedHeight

        DragHandler {
            id: myDragHandler
            target: null

            onActiveChanged: {
                mainWindow.dragging = myDragHandler.active;
                myDragHandler.active ? clientThumbnail.Drag.active = true : clientThumbnail.Drag.drop();
            }
        }
    }

    KWinComponents.ThumbnailItem {
        id: clientThumbnail
        wId: clientItem.client.internalId
        clipTo: screenItem
        clip: true
        renderTarget: KWinComponents.ThumbnailItem.FramebufferObject
        Drag.source: clientItem.client
        antialiasing: false
        smooth: false
        // visible: mainWindow.activated
        
        states: State {
            when: clientThumbnail.Drag.active
            PropertyChanges {
                target: clientThumbnail
                width: 250; height: 250; clip: false
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                x: calculatedX + myDragHandler.centroid.position.x - width / 2
                y: calculatedY + myDragHandler.centroid.position.y - height / 2
            }
        }

        Behavior on x {
            enabled: mainWindow.easingType !== mainWindow.noAnimation && !mainWindow.dragging
            NumberAnimation { id: xAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on y {
            enabled: mainWindow.easingType !== mainWindow.noAnimation && !mainWindow.dragging
            NumberAnimation { id: yAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on width {
            enabled: mainWindow.easingType !== mainWindow.noAnimation && !mainWindow.dragging
            NumberAnimation { id: widthAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on height {
            enabled: mainWindow.easingType !== mainWindow.noAnimation && !mainWindow.dragging
            NumberAnimation { id: heightAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
        }
    }

    onClientChanged: {
        if (client !== null && client !== undefined) {
            // client.geometryChanged.connect(function() {mainWindow.desktopsInitialized = false;});
            // client.activitiesChanged.connect(function() {desktopItem.clientsModel.update();});
        }
    }
}