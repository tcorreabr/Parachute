import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.kde.kwin 2.0 as KWinComponents
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: clientItem

    property bool isAnimating: xAnimation.running || yAnimation.running || widthAnimation.running || heightAnimation.running
    property var client: model.client
    property int noBorderMargin

    property real originalX
    property real originalY
    property real originalWidth
    property real originalHeight

    property real calculatedX
    property real calculatedY
    property real calculatedWidth
    property real calculatedHeight

    Behavior on x {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { id: xAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on y {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { id: yAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on width {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { id: widthAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
    }

    Behavior on height {
        enabled: mainWindow.easingType !== mainWindow.noAnimation
        NumberAnimation { id: heightAnimation; duration: animationsDuration; easing.type: mainWindow.easingType; }
    }

    PlasmaCore.FrameSvgItem {
        id: selectedFrame
        anchors.fill : parent
        imagePath: "widgets/viewitem"
        prefix: "hover"
        visible: big && !isAnimating && mainWindow.selectedClientItem === clientItem && !mainWindow.dragging
        opacity: 0.5
    }

    Item {
        id: clientDecorations
        height: desktopItem.clientsDecorationsHeight
        anchors.horizontalCenter: parent.horizontalCenter
        width: clientThumbnail.width * 0.8
        anchors.top: parent.top
        anchors.topMargin: desktopItem.clientsPadding
        visible: big && mainWindow.configShowWindowTitles && !isAnimating && !clientThumbnail.Drag.active

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
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
                Layout.maximumWidth: clientDecorations.width - wIcon.width - parent.spacing - closeButton.width - parent.spacing
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
        wId: clientItem.client.internalId
        clipTo: screenItem
        clip: true
        renderTarget: KWinComponents.ThumbnailItem.FramebufferObject
        Drag.source: clientItem.client
        antialiasing: false
        smooth: false
        // fillColor: "green"
        
        states: State {
            when: clientThumbnail.Drag.active
            PropertyChanges {
                target: clientThumbnail
                width: 250; height: 250; clip: false
                Drag.hotSpot.x: clientThumbnail.width / 2
                Drag.hotSpot.y: clientThumbnail.height / 2
                x: desktopItem.clientsPadding + myDragHandler.centroid.position.x - clientThumbnail.width / 2
                y: desktopItem.clientsPadding + desktopItem.clientsDecorationsHeight + myDragHandler.centroid.position.y - clientThumbnail.height / 2
            }
        }
    }

    Item {
        id: dragPlaceholder
        anchors.fill: parent
        anchors.margins: desktopItem.clientsPadding
        anchors.topMargin: desktopItem.clientsPadding + desktopItem.clientsDecorationsHeight

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
        if (client)
            client.moveResizedChanged.connect(function() { mainWindow.desktopsInitialized = false; print(client.width); });
    }
}