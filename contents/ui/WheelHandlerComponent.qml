import QtQuick 2.14

Item {
    anchors.fill: parent

    WheelHandler {
        property int wheelDelta: 0

        onWheel: wheelDelta += event.angleDelta.y;

        onActiveChanged: {        
            if (active) return;

            if (wheelDelta >= 120 || wheelDelta <= -120) {
                wheelDelta > 0 ? workspace.slotSwitchDesktopPrevious() : workspace.slotSwitchDesktopNext();
                wheelDelta = 0;
            }
        }
    }
}