import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.12
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: screenItem
    smooth: false // Applied to children
    antialiasing: false // Applied to children
    enabled: mainWindow.activated
    clip: true

    property alias bigDesktopsRepeater: bigDesktopsRepeater
    property alias desktopBackground: desktopBackground

    property int screenIndex: model.index
    property int desktopsBarSize: mainWindow.horizontalDesktopsLayout ? Math.round(height / 6) : Math.round(width / 6)
    property real aspectRatio: width / height

    PlasmaCore.WindowThumbnail {
        id: desktopBackground
        width: parent.width / 2
        height: parent.height / 2
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

        property real mouseAreaX
        property real mouseAreaY
        property real mouseAreaWidth: screenItem.width * gridAreaScale
        property real mouseAreaHeight: screenItem.height * gridAreaScale

        property real gridAreaScale
        property real gridAreaX
        property real gridAreaY
        property real gridAreaWidth: screenItem.width * gridAreaScale
        property real gridAreaHeight: screenItem.height * gridAreaScale

        states: [
            State {
                when: mainWindow.horizontalDesktopsLayout
                PropertyChanges {
                    target: bigDesktops
                    orientation: Qt.Horizontal

                    mouseAreaX: 0
                    mouseAreaY: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ? screenItem.desktopsBarSize : 0
                    mouseAreaWidth: screenItem.width
                    mouseAreaHeight: screenItem.height - screenItem.desktopsBarSize

                    gridAreaScale: (mouseAreaHeight - mainWindow.desktopMargin * 2) / screenItem.height
                    gridAreaX: (screenItem.width - bigDesktops.gridAreaWidth) / 2
                    gridAreaY: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ?
                            screenItem.desktopsBarSize + mainWindow.desktopMargin :
                            mainWindow.desktopMargin
                }
            },
            State {
                when: !mainWindow.horizontalDesktopsLayout
                PropertyChanges {
                    target: bigDesktops
                    orientation: Qt.Vertical

                    mouseAreaX: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ? screenItem.desktopsBarSize : 0
                    mouseAreaY: 0
                    mouseAreaWidth: screenItem.width - screenItem.desktopsBarSize
                    mouseAreaHeight: screenItem.height

                    gridAreaScale: (mouseAreaWidth - mainWindow.desktopMargin * 2) / screenItem.width
                    gridAreaX: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ?
                            screenItem.desktopsBarSize + mainWindow.desktopMargin :
                            mainWindow.desktopMargin
                    gridAreaY: (screenItem.height - bigDesktops.gridAreaHeight) / 2
                }
            }
        ]

        Repeater {
            id: bigDesktopsRepeater
            model: screenItem.width > 0 && screenItem.height > 0 ? workspace.desktops : 0

            DesktopComponent { // Cannot set geometry of SwipeView's root item
                visible: Math.abs(model.index - mainWindow.currentDesktop) < 2
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

    ScrollView {
        id: desktopsBar
        property real desktopsScale
        property real desktopsWidth: screenItem.width * desktopsBar.desktopsScale
        property real desktopsHeight: screenItem.height * desktopsBar.desktopsScale
        property real gridAreaWidth: desktopsWidth - mainWindow.desktopMargin * 2
        property real gridAreaHeight: desktopsHeight - mainWindow.desktopMargin * 2

        background: Rectangle {
            id: desktopsBarBackground
            anchors.fill: parent
            color: "black"
            opacity: 0.1
            visible: mainWindow.configShowDesktopsBarBackground
        }

        Behavior on anchors.topMargin {
            enabled: mainWindow.activated
            NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on anchors.bottomMargin {
            enabled: mainWindow.activated
            NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on anchors.leftMargin {
            enabled: mainWindow.activated
            NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
        }

        Behavior on anchors.rightMargin {
            enabled: mainWindow.activated
            NumberAnimation { duration: mainWindow.configAnimationsDuration; easing.type: mainWindow.easingType; }
        }

        states: [
            State {
                when: mainWindow.horizontalDesktopsLayout
                PropertyChanges {
                    target: desktopsBar
                    height: desktopsBarSize
                    desktopsScale: (desktopsBar.height - mainWindow.desktopsBarSpacing * 2) / screenItem.height
                    anchors.topMargin: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ?
                            mainWindow.showDesktopsBar ? 0 : -screenItem.desktopsBarSize :
                            mainWindow.showDesktopsBar ? -screenItem.desktopsBarSize : 0
                }
                AnchorChanges {
                    target: desktopsBar
                    anchors.top: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ? screenItem.top : screenItem.bottom
                    anchors.left: screenItem.left
                    anchors.right: screenItem.right
                }
                PropertyChanges {
                    target: desktopsWrapper
                    columns: desktopsBarRepeater.count + 2 // 2 for add and remove buttons
                    rows: 1
                }
            },
            State {
                when: !mainWindow.horizontalDesktopsLayout
                PropertyChanges {
                    target: desktopsBar
                    width: desktopsBarSize
                    desktopsScale: (desktopsBar.width - mainWindow.desktopsBarSpacing * 2) / screenItem.width
                    anchors.leftMargin: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ?
                            mainWindow.showDesktopsBar ? 0 : -screenItem.desktopsBarSize :
                            mainWindow.showDesktopsBar ? -screenItem.desktopsBarSize : 0
                }
                AnchorChanges {
                    target: desktopsBar
                    anchors.top: screenItem.top
                    anchors.bottom: screenItem.bottom
                    anchors.left: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ? screenItem.left : screenItem.right
                }
                PropertyChanges {
                    target: desktopsWrapper
                    columns: 1
                    rows: desktopsBarRepeater.count + 2 // 2 for add and remove buttons
                }
            }
        ]

        Grid {
            id: desktopsWrapper
            spacing: mainWindow.desktopsBarSpacing
            padding: mainWindow.desktopsBarSpacing
            // anchors.centerIn: parent // <== don't know why but this doesn't work here, so we have to set x and y
            x: desktopsBar.width < desktopsWrapper.width ? 0 : (desktopsBar.width - desktopsWrapper.width) / 2
            y: desktopsBar.height < desktopsWrapper.height ? 0 : (desktopsBar.height - desktopsWrapper.height) / 2
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            RoundButton {
                id: removeDesktop
                implicitHeight: 36
                implicitWidth: 36
                radius: height / 2
                focusPolicy: Qt.NoFocus

                Image { source: "images/remove.svg"; anchors.fill: parent; }

                onClicked: {
                    // Evita ir pro primeiro desktop
                    const currentDesktop = workspace.currentDesktop === workspace.desktops ?
                            workspace.currentDesktop - 1 : workspace.currentDesktop;
                    workspace.desktops--; // workspace.removeDesktop(desktopIndex);
                    workspace.currentDesktop = currentDesktop;
                }
            }

            Repeater {
                id: desktopsBarRepeater
                model: screenItem.width > 0 && screenItem.height > 0 ? workspace.desktops : 0

                DesktopComponent {
                    width: desktopsBar.desktopsWidth
                    height: desktopsBar.desktopsHeight

                    mouseAreaX: 0
                    mouseAreaY: 0
                    mouseAreaWidth: desktopsBar.desktopsWidth
                    mouseAreaHeight: desktopsBar.desktopsHeight

                    gridAreaX: mainWindow.desktopMargin
                    gridAreaY: mainWindow.desktopMargin
                    gridAreaWidth: desktopsBar.gridAreaWidth
                    gridAreaHeight: desktopsBar.gridAreaHeight
                }
            }

            RoundButton {
                id: addDesktop
                implicitHeight: 36
                implicitWidth: 36
                radius: height / 2
                focusPolicy: Qt.NoFocus

                Image { source: "images/add.svg"; anchors.fill: parent; }

                onClicked: {
                    const currentDesktop = workspace.currentDesktop;
                    workspace.desktops++; // workspace.createDesktop(desktopIndex + 1, "New desktop");
                    workspace.currentDesktop = currentDesktop; 
                }
            }
        }
    }

    function getDesktopWindowId() {
        const clients = workspace.clientList(); 
        for (let i = 0; i < clients.length; i++) {
            if (clients[i].desktopWindow && clients[i].screen === screenIndex) {
                desktopBackground.winId = clients[i].windowId;
                return;
            }
        }
    }

    Component.onCompleted: {
        getDesktopWindowId();
    }
}