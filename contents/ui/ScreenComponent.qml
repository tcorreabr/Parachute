import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.12
import org.kde.plasma.core 2.0 as PlasmaCore

Rectangle {
    id: screenItem
    color: "#333333"
    smooth: false
    antialiasing: false
    enabled: mainWindow.activated

    property alias bigDesktopsRepeater: bigDesktopsRepeater
    property alias desktopBackground: desktopBackground

    property int desktopsBarHeight: Math.round(height / 6) // valid only if position of desktopsBar is top or bottom
    property int desktopsBarWidth: Math.round(width / 6) // valid only if position of desktopsBar is left or right
    property real ratio: width / height

    property int screenIndex: model.index

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

    ScrollView {
        id: desktopsBar

        background: Rectangle {
            id: desktopsBarBackground
            anchors.fill: parent
            color: "black"
            opacity: 0.1
            visible: mainWindow.configShowDesktopsBarBackground
        }

        states: [
            State {
                when: mainWindow.horizontalDesktopsLayout
                PropertyChanges {
                    target: desktopsBar
                    height: desktopsBarHeight
                }
                AnchorChanges {
                    target: desktopsBar
                    anchors.bottom: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ? bigDesktops.top : undefined
                    anchors.top: mainWindow.configDesktopsBarPlacement === Enums.Position.Bottom ? bigDesktops.bottom : undefined
                    anchors.left: screenItem.left
                    anchors.right: screenItem.right
                }
                PropertyChanges {
                    target: desktopsWrapper
                    columns: desktopsBarRepeater.count
                    rows: 1
                    leftPadding: mainWindow.desktopsBarSpacing
                    rightPadding: mainWindow.desktopsBarSpacing
                }
            },
            State {
                when: !mainWindow.horizontalDesktopsLayout
                PropertyChanges {
                    target: desktopsBar
                    width: desktopsBarWidth
                }
                AnchorChanges {
                    target: desktopsBar
                    anchors.bottom: screenItem.bottom
                    anchors.top: screenItem.top
                    anchors.left: mainWindow.configDesktopsBarPlacement === Enums.Position.Right ? bigDesktops.right : undefined
                    anchors.right: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ? bigDesktops.left : undefined
                }
                PropertyChanges {
                    target: desktopsWrapper
                    columns: 1
                    rows: desktopsBarRepeater.count
                    topPadding: mainWindow.desktopsBarSpacing
                    bottomPadding: mainWindow.desktopsBarSpacing
                }
            }
        ]

        Grid {
            id: desktopsWrapper
            spacing: mainWindow.desktopsBarSpacing
            // anchors.centerIn: parent // <== don't know why but this doesn't work here, so we have to set x and y
            x: desktopsBar.width < desktopsWrapper.width ? 0 : (desktopsBar.width - desktopsWrapper.width) / 2
            y: desktopsBar.height < desktopsWrapper.height ? 0 : (desktopsBar.height - desktopsWrapper.height) / 2

            Repeater {
                id: desktopsBarRepeater
                model: workspace.desktops

                DesktopComponent {
                    id: smallDesktop

                    states: [
                        State {
                            when: mainWindow.horizontalDesktopsLayout
                            PropertyChanges {
                                target: smallDesktop
                                width: smallDesktop.height / screenItem.height * screenItem.width
                                height: desktopsBar.height - mainWindow.desktopsBarSpacing * 2
                            }
                        },
                        State {
                            when: !mainWindow.horizontalDesktopsLayout
                            PropertyChanges {
                                target: smallDesktop
                                width: desktopsBar.width - mainWindow.desktopsBarSpacing * 2
                                height: smallDesktop.width / screenItem.width * screenItem.height
                            }
                        }
                    ]
                }
            }
        }
    }

    SwipeView {
        id: bigDesktops
        anchors.fill: parent
        anchors.topMargin: mainWindow.configDesktopsBarPlacement === Enums.Position.Top ? desktopsBarHeight : 0
        anchors.bottomMargin: mainWindow.configDesktopsBarPlacement === Enums.Position.Bottom ? desktopsBarHeight : 0
        anchors.leftMargin: mainWindow.configDesktopsBarPlacement === Enums.Position.Left ? desktopsBarWidth : 0
        anchors.rightMargin: mainWindow.configDesktopsBarPlacement === Enums.Position.Right ? desktopsBarWidth : 0
        currentIndex: mainWindow.currentDesktop
        orientation: mainWindow.horizontalDesktopsLayout ? Qt.Horizontal : Qt.Vertical

        Repeater {
            id: bigDesktopsRepeater
            model: workspace.desktops

            DesktopComponent { // Cannot set geometry of SwipeView's root item
                visible: model.index === mainWindow.currentDesktop
                big: true
            }
        }

        onCurrentIndexChanged: workspace.currentDesktop = currentIndex + 1;
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