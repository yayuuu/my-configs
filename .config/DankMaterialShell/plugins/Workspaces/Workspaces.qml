import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property string screenName: ""
    property real widgetHeight: {
        return parent.implicitHeight - margin*2
    }
    property real barThickness: parent.implicitHeight
    property var parentScreen: null
    property int _desktopEntriesUpdateTrigger: 0
    readonly property var sortedToplevels: {
        return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
    }

    property real margin: {
        return parseInt((parent.implicitHeight-2*Theme.spacingS)*0.27)
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++
        }
    }

    property var workspaceList: {
        let baseList
        switch (CompositorService.compositor) {
        case "niri":
            baseList = getNiriWorkspaces()
            break
        default:
            return null
        }
        return baseList
    }

    function parseWorkspaceName(name) {
        if (name === null || name === undefined)
            return Infinity; // nulle → na koniec

        const m = name.match(/\d+/);
        if (m) return Number(m[0]); // nazwa zawiera liczbę → zwróć liczbę

        return name; // nazwa bez liczby → zwróć string
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0) {
            return null
        }

        let workspaces=NiriService.allWorkspaces;

        const result = {};

        // Grupowanie po output (monitor)
        for (let ws of workspaces) {
            if (!result[ws.output])
                result[ws.output] = [];

            result[ws.output].push(ws);
        }

        // Sortowanie w każdej grupie
        for (let monitor in result) {
            result[monitor].sort((a, b) => {
                const A = parseWorkspaceName(a.name);
                const B = parseWorkspaceName(b.name);

                const typeA = typeof A;
                const typeB = typeof B;

                // 1. Liczby przed stringami
                if (typeA === "number" && typeB === "string") return -1;
                if (typeA === "string" && typeB === "number") return 1;

                // 2. Stringi przed Infinity
                if (typeA === "string" && B === Infinity) return -1;
                if (A === Infinity && typeB === "string") return 1;

                // 3. Liczby przed Infinity (i odwrotnie)
                if (typeA === "number" && B === Infinity) return -1;
                if (A === Infinity && typeB === "number") return 1;

                // 4. Oba liczby → rosnąco
                if (typeA === "number" && typeB === "number") return A - B;

                // 5. Oba stringi → sortuj alfabetycznie
                if (typeA === "string" && typeB === "string") return A.localeCompare(B);

                // 6. Oba Infinity → na koniec, stabilne
                return 0;
            });
        }

        let resultSorted = [];
        for (let monitor in result) {
            resultSorted.push({
                output: monitor,
                workspaces: result[monitor]
            })
        }

        resultSorted = resultSorted.sort((a, b) => {
            const aFirstName = a.workspaces?.[0]?.name ?? null;
            const bFirstName = b.workspaces?.[0]?.name ?? null;

            const A = parseWorkspaceName(aFirstName);
            const B = parseWorkspaceName(bFirstName);

            const typeA = typeof A;
            const typeB = typeof B;

            // liczby przed stringami
            if (typeA === "number" && typeB === "string") return -1;
            if (typeA === "string" && typeB === "number") return 1;

            // stringi przed Infinity
            if (typeA === "string" && B === Infinity) return -1;
            if (A === Infinity && typeB === "string") return 1;

            // liczby przed Infinity
            if (typeA === "number" && B === Infinity) return -1;
            if (A === Infinity && typeB === "number") return 1;

            // oba liczby → sort rosnący
            if (typeA === "number" && typeB === "number") return A - B;

            // oba stringi → sort alfabetycznie
            if (typeA === "string" && typeB === "string") return A.localeCompare(B);

            // oba Infinity lub przypadki mieszane → zostaw bez zmian
            return 0;
        });

        return resultSorted
    }

    readonly property real padding: Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property real visualWidth: isVertical ? widgetHeight : (monitorRow.implicitWidth + padding * 2)
    readonly property real visualHeight: isVertical ? (monitorRow.implicitHeight + padding * 2) : widgetHeight

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => {
            return ws !== -1
        })
    }

    function switchWorkspace(direction) {
        if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? Math.min(validIndex + 1, realWorkspaces.length - 1) : Math.max(validIndex - 1, 0)

            if (nextIndex === validIndex) {
                return
            }

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1)
        }
    }

    width: isVertical ? barThickness : visualWidth
    height: isVertical ? visualHeight : barThickness
    visible: CompositorService.isNiri

    Rectangle {
        id: visualBackground
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent
        //anchors.verticalCenterOffset: -1
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (SettingsData.dankBarNoBackground)
                return "transparent"
            const baseColor = Theme.widgetBaseBackgroundColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (CompositorService.isNiri) {
                    NiriService.toggleOverview()
                }
            }
        }
    }


    Flow {
        id: monitorRow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        flow: isVertical ? Flow.TopToBottom : Flow.LeftToRight

        Component.onCompleted: {
            console.log("workspaceList =", JSON.stringify(Theme))
            console.log(root.barThickness)
        }

        Repeater {
            model: ScriptModel {
                values: root.workspaceList
            }

            Item {
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height

                Flow {
                    id: workspaceRow
                    flow: isVertical ? Flow.TopToBottom : Flow.LeftToRight
                    property var workspaces: modelData.workspaces

                    spacing: Theme.spacingS / 2

                    Item {
                        implicitWidth: {isVertical? root.width : childrenRect.width}
                        implicitHeight: {isVertical? childrenRect.height : root.height}

                        Text {
                            id: textItem
                            text: {
                                return modelData.output
                                    .split("-")                // podziel na sekcje
                                    .map(part => part[0])      // bierz pierwszą literę/cyfrę z każdej
                                    .join("")
                            }
                            color: Theme.surfaceText
                            font.pixelSize: Theme.barTextSize(barThickness)
                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                            anchors.centerIn: parent

                            Component.onCompleted: console.log("aaa =", JSON.stringify(textItem.text))
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            values: modelData.workspaces
                        }

                        Item {
                            id: delegateRoot

                            property bool isActive: {
                                return modelData.is_active
                            }
                            property bool isPlaceholder: {
                                return modelData === -1
                            }
                            property bool isHovered: mouseArea.containsMouse

                            property var loadedWorkspaceData: null
                            property bool loadedIsUrgent: false
                            property bool isUrgent: {
                                return false
                            }
                            property var loadedIconData: null
                            property bool loadedHasIcon: false
                            property var loadedIcons: []

                            readonly property real visualWidth: widgetHeight * 0.6
                            readonly property real visualHeight: widgetHeight * 0.6

                            anchors.margins: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: !isPlaceholder
                                cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !isPlaceholder
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (isPlaceholder) return

                                    const isRightClick = mouse.button === Qt.RightButton

                                    if (root.useExtWorkspace && (modelData?.id || modelData?.name)) {
                                        ExtWorkspaceService.activateWorkspace(modelData.id || modelData.name, modelData.groupID || "")
                                    } else if (CompositorService.isNiri) {
                                        if (isRightClick) {
                                            NiriService.toggleOverview()
                                        } else {
                                            NiriService.switchToWorkspace(modelData - 1)
                                        }
                                    }
                                }
                            }

                            Timer {
                                id: dataUpdateTimer
                                interval: 50
                                onTriggered: {
                                    if (isPlaceholder) {
                                        delegateRoot.loadedWorkspaceData = null
                                        delegateRoot.loadedIsUrgent = false
                                        return
                                    }

                                    var wsData = null;
                                    if (root.useExtWorkspace) {
                                        wsData = modelData;
                                    } else if (CompositorService.isNiri) {
                                        wsData = NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null;
                                    } else if (CompositorService.isHyprland) {
                                        wsData = modelData;
                                    } else if (CompositorService.isDwl) {
                                        wsData = modelData;
                                    } else if (CompositorService.isSway) {
                                        wsData = modelData;
                                    }
                                    delegateRoot.loadedWorkspaceData = wsData;
                                    delegateRoot.loadedIsUrgent = wsData?.urgent ?? false;
                                }
                            }

                            function updateAllData() {
                                dataUpdateTimer.restart()
                            }

                            width: root.isVertical ? root.barThickness : visualWidth
                            height: root.isVertical ? visualHeight : root.barThickness

                            Rectangle {
                                id: visualContent
                                width: delegateRoot.visualWidth
                                height: delegateRoot.visualHeight
                                anchors.centerIn: parent
                                radius: Theme.cornerRadius
                                color: isActive ? Theme.primary : isUrgent ? Theme.error : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                                border.width: isUrgent && !isActive ? 2 : 0
                                border.color: isUrgent && !isActive ? Theme.error : Theme.withAlpha(Theme.error, 0)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }

                                Behavior on border.width {
                                    NumberAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.mediumDuration
                                        easing.type: Theme.emphasizedEasing
                                    }
                                }

                                // Loader for Workspace Index
                                Loader {
                                    id: indexLoader
                                    anchors.fill: parent
                                    active: !isPlaceholder
                                    sourceComponent: Item {
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: {
                                                let number=workspaceRow.workspaces[index].name;
                                                if(number !== null){
                                                    number = number.match(/\d+/);
                                                    return number[0]
                                                } else if(index!=0) {
                                                    number=workspaceRow.workspaces[index-1].name;
                                                    if(number !== null){
                                                        number = number.match(/\d+/);
                                                        return parseInt(number[0])+1
                                                    }
                                                }
                                                
                                            }
                                            color: (isActive || isUrgent) ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                                            font.pixelSize: Theme.barTextSize(barThickness)
                                            font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                                        }
                                    }
                                }
                            }

                            Component.onCompleted: updateAllData()

                            Connections {
                                target: CompositorService
                                function onSortedToplevelsChanged() { delegateRoot.updateAllData() }
                            }
                            Connections {
                                target: NiriService
                                enabled: CompositorService.isNiri
                                function onAllWorkspacesChanged() { delegateRoot.updateAllData() }
                                function onWindowUrgentChanged() { delegateRoot.updateAllData() }
                                function onWindowsChanged() { delegateRoot.updateAllData() }
                            }
                            Connections {
                                target: SettingsData
                                function onShowWorkspaceAppsChanged() { delegateRoot.updateAllData() }
                                function onWorkspaceNameIconsChanged() { delegateRoot.updateAllData() }
                            }
                        }

                    }
                }
            }
        }
    }


    Component.onCompleted: {
        if (useExtWorkspace && !DMSService.activeSubscriptions.includes("extworkspace")) {
            DMSService.addSubscription("extworkspace")
        }
    }
}
