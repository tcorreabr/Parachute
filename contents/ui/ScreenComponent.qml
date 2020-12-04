import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.12
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

Item {
    id: screenItem
    smooth: false // Applied to children
    antialiasing: false // Applied to children
    clip: true

    property alias bigDesktopsRepeater: bigDesktopsRepeater
    property alias desktopBackground: desktopBackground

    property int screenIndex: model.index
    property real aspectRatio: width / height
    property bool wheelHandlerCreated: false

    states: [
        State {
            when: mainWindow.horizontalDesktopsLayout
            PropertyChanges {
                target: bigDesktops
                orientation: Qt.Horizontal

                mouseAreaX: 0
                mouseAreaY: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ? desktopsBar.height : 0
                mouseAreaWidth: screenItem.width
                mouseAreaHeight: screenItem.height - desktopsBar.height

                gridAreaX: (screenItem.width - bigDesktops.gridAreaWidth) / 2
                gridAreaY: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ?
                        desktopsBar.height + searchFieldContainer.height + mainWindow.desktopMargin :
                        searchFieldContainer.height + mainWindow.desktopMargin
                gridAreaWidth: bigDesktops.gridAreaHeight * screenItem.aspectRatio
                gridAreaHeight: mouseAreaHeight - searchFieldContainer.height - mainWindow.desktopMargin * 2
            }

            PropertyChanges {
                target: searchFieldContainer
                x: (screenItem.width - searchFieldContainer.width) / 2
                y: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ? desktopsBar.height: 0
            }

            PropertyChanges {
                target: desktopsBar
                x: 0
                y: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ?
                        mainWindow.showDesktopsBar ? 0 : -desktopsBar.height :
                        mainWindow.showDesktopsBar ? screenItem.height - desktopsBar.height : screenItem.height
                height: Math.round(screenItem.height / 6)
                width: screenItem.width

                desktopsFullSize: (desktopsBar.height - desktopsWrapper.padding * 2) * screenItem.aspectRatio
                shrinkDesktopsToFit: desktopsBar.width < (desktopsBar.desktopsFullSize + desktopsWrapper.spacing) * workspace.desktops +
                        2 * desktopsWrapper.padding + removeDesktop.width + addDesktop.width
                desktopsWidth: desktopsBar.shrinkDesktopsToFit ?
                        ((desktopsBar.width - (2 * desktopsWrapper.padding + removeDesktop.width + addDesktop.width)) / workspace.desktops) - desktopsWrapper.spacing :
                        desktopsBar.desktopsFullSize
                desktopsHeight: desktopsBar.desktopsWidth / screenItem.aspectRatio
            }

            PropertyChanges {
                target: desktopsWrapper
                rows: 1
            }
        },
        State {
            when: !mainWindow.horizontalDesktopsLayout
            PropertyChanges {
                target: bigDesktops
                orientation: Qt.Vertical

                mouseAreaX: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ? desktopsBar.width : 0
                mouseAreaY: 0
                mouseAreaWidth: screenItem.width - desktopsBar.width
                mouseAreaHeight: screenItem.height

                gridAreaX: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ?
                        desktopsBar.width + mainWindow.desktopMargin :
                        mainWindow.desktopMargin
                gridAreaY: searchFieldContainer.height + (screenItem.height - searchFieldContainer.height - bigDesktops.gridAreaHeight) / 2
                gridAreaWidth: mouseAreaWidth - mainWindow.desktopMargin * 2
                gridAreaHeight: bigDesktops.gridAreaWidth / screenItem.aspectRatio
            }

            PropertyChanges {
                target: searchFieldContainer
                x: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ?
                        desktopsBar.width + (bigDesktops.mouseAreaWidth - searchFieldContainer.width) / 2 :
                        (bigDesktops.mouseAreaWidth - searchFieldContainer.width) / 2
                y: 0
            }

            PropertyChanges {
                target: desktopsBar
                x: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ?
                        mainWindow.showDesktopsBar ? 0 : -desktopsBar.width :
                        mainWindow.showDesktopsBar ? screenItem.width - desktopsBar.width : screenItem.width
                y: 0
                width: Math.round(screenItem.width / 6)
                height: screenItem.height

                desktopsFullSize: (desktopsBar.width - desktopsWrapper.padding * 2) / screenItem.aspectRatio
                shrinkDesktopsToFit: desktopsBar.height < (desktopsBar.desktopsFullSize + desktopsWrapper.spacing) * workspace.desktops +
                        2 * desktopsWrapper.padding + removeDesktop.height + addDesktop.height
                desktopsWidth: desktopsBar.desktopsHeight * screenItem.aspectRatio
                desktopsHeight: desktopsBar.shrinkDesktopsToFit ?
                        ((desktopsBar.height - (2 * desktopsWrapper.padding + removeDesktop.height + addDesktop.height)) / workspace.desktops) - desktopsWrapper.spacing :
                        desktopsBar.desktopsFullSize
            }

            PropertyChanges {
                target: desktopsWrapper
                columns: 1
            }
        }
    ]

    PlasmaCore.WindowThumbnail {
        id: desktopBackground
        anchors.fill: parent
        visible: winId !== 0
        opacity: mainWindow.configBlurBackground ? 0 : 1
    }

    FastBlur {
        id: blurBackground
        anchors.fill: parent
        source: desktopBackground
        radius: 64
        visible: desktopBackground.winId !== 0 && mainWindow.configBlurBackground
        cached: true
    }

    SwipeView {
        id: bigDesktops
        anchors.fill: parent
        currentIndex: mainWindow.currentDesktop
        focusPolicy: Qt.NoFocus
        activeFocusOnTab: false

        property real mouseAreaX
        property real mouseAreaY
        property real mouseAreaWidth
        property real mouseAreaHeight

        property real gridAreaX
        property real gridAreaY
        property real gridAreaWidth
        property real gridAreaHeight

        Repeater {
            id: bigDesktopsRepeater
            model: mainWindow.ready ? workspace.desktops : 0

            DesktopComponent { // Cannot set geometry of SwipeView's root item
                visible: Math.abs(model.index - mainWindow.currentDesktop) < 2
                enabled: model.index === mainWindow.currentDesktop
                big: true

                mouseAreaX: bigDesktops.mouseAreaX
                mouseAreaY: bigDesktops.mouseAreaY
                mouseAreaWidth: bigDesktops.mouseAreaWidth
                mouseAreaHeight: bigDesktops.mouseAreaHeight

                gridAreaX: bigDesktops.gridAreaX
                gridAreaY: bigDesktops.gridAreaY
                gridAreaWidth: bigDesktops.gridAreaWidth
                gridAreaHeight: bigDesktops.gridAreaHeight
            }
        }

        onCurrentIndexChanged: workspace.currentDesktop = currentIndex + 1;
    }

    Item {
        id: searchFieldContainer
        height: 120
        width: 400
     
        TextField {
            id: searchField

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            color: "white"
            placeholderText: "Type to search"
            // placeholderTextColor: "red"
            activeFocusOnTab: true

            background: Rectangle {
                color: "white"
                border.width: 1
                border.color: mainWindow.hoverColor
                radius: 4
                opacity: 0.1
            }

            Keys.onPressed: {
                if (searchField.text === "") return;

                switch (event.key) {
                    case Qt.Key_Escape:
                        searchField.text = "";
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        keyboardHandler.focus = true;
                        event.accepted = true;
                        break;
                }
            }
        }
    }

    Item {
        id: desktopsBar

        property real desktopsFullSize // Size of desktops if we don't need to shrink them more to fit in the bar
        property bool shrinkDesktopsToFit
        property real desktopsWidth
        property real desktopsHeight

        Rectangle {
            id: desktopsBarBackground
            anchors.fill: parent
            color: "black"
            opacity: 0.1
            visible: mainWindow.configShowDesktopsBarBackground
        }

        HoverHandler {
            id: desktopsBarHoverHandler
            enabled: mainWindow.idle && !mainWindow.dragging
        }

        Behavior on x {
            enabled: mainWindow.activated
            NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on y {
            enabled: mainWindow.activated
            NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
        }

        Grid {
            id: desktopsWrapper
            spacing: mainWindow.desktopsBarSpacing
            padding: mainWindow.desktopsBarSpacing
            anchors.centerIn: parent
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            PlasmaComponents.Button {
                id: removeDesktop
                height: 48
                width: 48
                icon.name: "remove"
                flat: true
                opacity: desktopsBarHoverHandler.hovered ? 1 : 0
                focusPolicy: Qt.NoFocus

                onClicked: {
                    const currentDesktop = workspace.currentDesktop === workspace.desktops ?
                            workspace.currentDesktop - 1 : workspace.currentDesktop;
                    workspace.desktops--; // workspace.removeDesktop(desktopIndex);
                    workspace.currentDesktop = currentDesktop; // Avoid going to the first desktop
                }
            }

            Repeater {
                id: desktopsBarRepeater
                model: mainWindow.ready ? workspace.desktops : 0

                DesktopComponent {
                    width: desktopsBar.desktopsWidth
                    height: desktopsBar.desktopsHeight

                    mouseAreaX: 0
                    mouseAreaY: 0
                    mouseAreaWidth: desktopsBar.desktopsWidth
                    mouseAreaHeight: desktopsBar.desktopsHeight

                    gridAreaX: mainWindow.desktopMargin
                    gridAreaY: mainWindow.desktopMargin
                    gridAreaWidth: desktopsBar.desktopsWidth - mainWindow.desktopMargin * 2
                    gridAreaHeight: desktopsBar.desktopsHeight - mainWindow.desktopMargin * 2
                }
            }

            PlasmaComponents.Button {
                id: addDesktop
                height: 48
                width: 48
                icon.name: "add"
                flat: true
                opacity: desktopsBarHoverHandler.hovered ? 1 : 0
                focusPolicy: Qt.NoFocus

                onClicked: {
                    const currentDesktop = workspace.currentDesktop;
                    workspace.desktops++; // workspace.createDesktop(desktopIndex + 1, "New desktop");
                    workspace.currentDesktop = currentDesktop; // Avoid going to the first desktop
                }
            }
        }
    }
}