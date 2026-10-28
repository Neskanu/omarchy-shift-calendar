import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CalendarMath.js" as CalendarMath

// Shift Calendar Bar Widget
// Displays today's scheduled work shift (Day, Night, Off) or calendar icon.
// Left-click opens the interactive calendar popup.
// Right-click or mouse-wheel smoothly cycles today's shift with debounced pacing.
BarWidget {
  id: root
  moduleName: "senovo.shift-calendar"

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/senovo.shift-calendar"
  readonly property string storagePath: Quickshell.env("HOME") + "/.config/omarchy/shifts.json"

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  property var shifts: ({})
  property date today: new Date()
  readonly property string todayKey: CalendarMath.keyForDate(today)
  readonly property string todayShift: shifts && shifts[todayKey] ? String(shifts[todayKey]) : ""

  readonly property color fg: bar ? bar.barForeground : Commons.Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property int size: Style.font.bodySmall

  function loadShifts(raw) {
    if (!raw || raw.trim() === "") return
    try {
      var parsed = JSON.parse(raw)
      if (parsed && typeof parsed === "object") {
        root.shifts = parsed
      }
    } catch (e) {
      console.warn("Shift Calendar BarWidget: Failed to parse shifts.json:", e)
    }
  }

  // Smooth option cycling with pacing
  property int wheelAccumulator: 0
  property real lastWheelTime: 0

  function cycleShiftDirection(dir) {
    var options = ["", "day", "night", "off"]
    var idx = options.indexOf(root.todayShift)
    if (idx === -1) idx = 0
    var nextIdx = (idx + dir + options.length) % options.length
    var nextShift = options[nextIdx]

    var updated = ({})
    for (var k in root.shifts) updated[k] = root.shifts[k]
    if (nextShift === "") delete updated[root.todayKey]
    else updated[root.todayKey] = nextShift

    root.shifts = updated
    Quickshell.execDetached([root.pluginDir + "/save-shifts.sh", JSON.stringify(updated)])
  }

  function handleWheel(delta) {
    var now = Date.now()
    if (now - lastWheelTime < 280) return

    wheelAccumulator += delta
    if (Math.abs(wheelAccumulator) >= 100) {
      lastWheelTime = now
      var dir = wheelAccumulator > 0 ? 1 : -1
      wheelAccumulator = 0
      cycleShiftDirection(dir)
    }
  }

  function cycleTodayShift() {
    cycleShiftDirection(1)
  }

  FileView {
    id: shiftsWatcher
    path: root.storagePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadShifts(text())
    onLoadFailed: {}
    onFileChanged: reload()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.today = date
  }

  // Popup panel delegation
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() {
    if (panelLoader.item) {
      panelLoader.item.toggle()
    }
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  readonly property string buttonText: {
    if (root.vertical) {
      if (root.todayShift === "day") return "☀️"
      if (root.todayShift === "night") return "🌙"
      if (root.todayShift === "off") return "🏖️"
      return "󰸗"
    }
    if (root.todayShift === "day") return "☀️ " + String(root.today.getDate())
    if (root.todayShift === "night") return "🌙 " + String(root.today.getDate())
    if (root.todayShift === "off") return "🏖️ " + String(root.today.getDate())
    return "󰸗 " + String(root.today.getDate())
  }

  readonly property color labelColor: {
    if (root.todayShift === "day") return "#f59e0b"
    if (root.todayShift === "night") return "#a78bfa"
    if (root.todayShift === "off") return "#10b981"
    return root.fg
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: {
    root.injectPanel()
    Qt.callLater(root.injectPanel)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Error) {
        console.error("Shift Calendar: Panel failed to load:", sourceComponent ? sourceComponent.errorString() : "unknown error")
      }
    }
  }

  ShellIpc {
    target: "senovo.shift-calendar"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.buttonText
    foreground: root.labelColor
    horizontalMargin: 8.5
    verticalPadding: 6

    tooltipText: {
      if (root.todayShift === "day") return strings.t("tooltip.day")
      if (root.todayShift === "night") return strings.t("tooltip.night")
      if (root.todayShift === "off") return strings.t("tooltip.off")
      return strings.t("tooltip.open")
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.cycleTodayShift()
      } else {
        root.togglePanel()
      }
    }

    onWheelMoved: function(delta) {
      root.handleWheel(delta)
    }
  }
}
