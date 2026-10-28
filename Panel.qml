import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CalendarMath.js" as CalendarMath

// Interactive Shift Calendar Panel
// Compact, expandable icon buttons, mouse drag marking, and Shift + Arrow range selection.
Panel {
  id: root
  moduleName: "senovo.shift-calendar"
  ipcTarget: "senovo.shift-calendar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/senovo.shift-calendar"
  readonly property string storagePath: Quickshell.env("HOME") + "/.config/omarchy/shifts.json"

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // Shifts state map: {"YYYY-MM-DD": "day"|"night"|"off"}
  property var shifts: ({})

  // Pattern settings storage
  readonly property string patternStoragePath: Quickshell.env("HOME") + "/.config/omarchy/shift-pattern.json"

  // Pattern definition: array of objects { type: "day"|"night"|"off", count: int }
  property var patternSteps: [
    { type: "day", count: 4 },
    { type: "off", count: 2 },
    { type: "night", count: 3 },
    { type: "off", count: 3 }
  ]

  property string patternAnchorDate: todayKey
  property string patternRangePreset: "restOfYear" // "restOfYear", "fullYear", "threeMonths", "sixMonths"
  property string patternStatusMsg: ""
  property bool patternStatusIsError: false

  // Date picker dialog state
  property bool datePickerOpen: false
  property int pickerYear: {
    var p = patternAnchorDate.split("-")
    return p.length > 0 ? (parseInt(p[0], 10) || today.getFullYear()) : today.getFullYear()
  }
  property int pickerMonth: {
    var p = patternAnchorDate.split("-")
    return p.length > 1 ? (Math.max(0, parseInt(p[1], 10) - 1) || today.getMonth()) : today.getMonth()
  }

  function openDatePicker() {
    var p = patternAnchorDate.split("-")
    if (p.length === 3) {
      pickerYear = parseInt(p[0], 10) || today.getFullYear()
      pickerMonth = Math.max(0, parseInt(p[1], 10) - 1)
    } else {
      pickerYear = today.getFullYear()
      pickerMonth = today.getMonth()
    }
    datePickerOpen = true
  }

  function stepPickerMonth(delta) {
    var d = new Date(Date.UTC(pickerYear, pickerMonth + delta, 1))
    pickerYear = d.getUTCFullYear()
    pickerMonth = d.getUTCMonth()
  }

  function stepPickerYear(delta) {
    pickerYear += delta
  }

  function selectPickerDate(key) {
    patternAnchorDate = key
    datePickerOpen = false
    savePatternConfig()
  }

  readonly property int patternTotalCycleDays: {
    var total = 0
    if (patternSteps && patternSteps.length) {
      for (var i = 0; i < patternSteps.length; i++) {
        total += (patternSteps[i].count || 1)
      }
    }
    return total
  }

  function loadPatternConfig(raw) {
    if (!raw || raw.trim() === "") return
    try {
      var cfg = JSON.parse(raw)
      if (cfg && typeof cfg === "object") {
        if (Array.isArray(cfg.pattern) && cfg.pattern.length > 0) {
          root.patternSteps = cfg.pattern
        }
        if (cfg.anchorDate && typeof cfg.anchorDate === "string") {
          root.patternAnchorDate = cfg.anchorDate
        }
        if (cfg.rangePreset && typeof cfg.rangePreset === "string") {
          root.patternRangePreset = cfg.rangePreset
        }
      }
    } catch (e) {
      console.warn("Shift Calendar: Failed to parse shift-pattern.json:", e)
    }
  }

  function savePatternConfig() {
    var cfg = {
      pattern: root.patternSteps,
      anchorDate: root.patternAnchorDate,
      rangePreset: root.patternRangePreset
    }
    Quickshell.execDetached([root.pluginDir + "/save-pattern.sh", JSON.stringify(cfg)])
  }

  FileView {
    id: patternWatcher
    path: root.patternStoragePath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPatternConfig(text())
    onLoadFailed: {}
    onFileChanged: reload()
  }

  function setStepType(idx, nextType) {
    var copy = []
    for (var i = 0; i < root.patternSteps.length; i++) {
      var item = { type: root.patternSteps[i].type, count: root.patternSteps[i].count }
      if (i === idx) item.type = nextType
      copy.push(item)
    }
    root.patternSteps = copy
    root.savePatternConfig()
  }

  function cycleStepType(idx) {
    var types = ["day", "off", "night"]
    var curr = root.patternSteps[idx] ? root.patternSteps[idx].type : "day"
    var nextIdx = (types.indexOf(curr) + 1) % types.length
    root.setStepType(idx, types[nextIdx])
  }

  function changeStepCount(idx, delta) {
    var copy = []
    for (var i = 0; i < root.patternSteps.length; i++) {
      var item = { type: root.patternSteps[i].type, count: root.patternSteps[i].count }
      if (i === idx) {
        var newCount = Math.max(1, Math.min(30, item.count + delta))
        item.count = newCount
      }
      copy.push(item)
    }
    root.patternSteps = copy
    root.savePatternConfig()
  }

  function removeStep(idx) {
    if (root.patternSteps.length <= 1) return
    var copy = []
    for (var i = 0; i < root.patternSteps.length; i++) {
      if (i !== idx) {
        copy.push({ type: root.patternSteps[i].type, count: root.patternSteps[i].count })
      }
    }
    root.patternSteps = copy
    root.savePatternConfig()
  }

  function addStep(type, count) {
    var copy = []
    for (var i = 0; i < root.patternSteps.length; i++) {
      copy.push({ type: root.patternSteps[i].type, count: root.patternSteps[i].count })
    }
    copy.push({ type: type || "day", count: count || 2 })
    root.patternSteps = copy
    root.savePatternConfig()
  }

  function loadPreset(name) {
    if (name === "userExample") {
      root.patternSteps = [
        { type: "day", count: 4 },
        { type: "off", count: 2 },
        { type: "night", count: 3 },
        { type: "off", count: 3 }
      ]
    } else if (name === "fourOnFourOff") {
      root.patternSteps = [
        { type: "day", count: 4 },
        { type: "off", count: 4 }
      ]
    } else if (name === "pitman") {
      root.patternSteps = [
        { type: "day", count: 2 },
        { type: "off", count: 2 },
        { type: "day", count: 3 },
        { type: "off", count: 2 },
        { type: "day", count: 2 },
        { type: "off", count: 3 }
      ]
    } else if (name === "standard") {
      root.patternSteps = [
        { type: "day", count: 5 },
        { type: "off", count: 2 }
      ]
    }
    root.savePatternConfig()
  }

  function applyCurrentPattern() {
    var startK = root.patternAnchorDate
    var endK = root.patternAnchorDate

    if (root.patternRangePreset === "restOfYear") {
      startK = root.patternAnchorDate
      endK = CalendarMath.dateKey(root.viewYear, 11, 31)
    } else if (root.patternRangePreset === "fullYear") {
      startK = CalendarMath.dateKey(root.viewYear, 0, 1)
      endK = CalendarMath.dateKey(root.viewYear, 11, 31)
    } else if (root.patternRangePreset === "threeMonths") {
      startK = root.patternAnchorDate
      endK = CalendarMath.addDays(root.patternAnchorDate, 90)
    } else if (root.patternRangePreset === "sixMonths") {
      startK = root.patternAnchorDate
      endK = CalendarMath.addDays(root.patternAnchorDate, 180)
    }

    var updated = CalendarMath.applyPattern(root.shifts, startK, endK, root.patternSteps, root.patternAnchorDate)
    root.shifts = updated
    root.flushSave()
    root.savePatternConfig()

    var count = Math.abs(CalendarMath.daysBetween(startK, endK)) + 1
    root.patternStatusMsg = strings.t("pattern.appliedSuccess").arg(count)
    root.patternStatusIsError = false
  }

  function guessPatternFromHistory() {
    var detected = CalendarMath.guessPattern(root.shifts)
    if (!detected) {
      root.patternStatusMsg = strings.t("pattern.guessNotFound")
      root.patternStatusIsError = true
      return
    }

    root.patternSteps = detected.rle
    root.patternAnchorDate = detected.anchorDate
    var pct = Math.round(detected.ratio * 100)
    root.patternStatusMsg = strings.t("pattern.guessSuccess").arg(detected.period).arg(pct).arg(detected.anchorDate)
    root.patternStatusIsError = false
    root.savePatternConfig()
  }

  function clearCurrentPatternRange() {
    var startK = root.patternAnchorDate
    var endK = root.patternAnchorDate

    if (root.patternRangePreset === "restOfYear") {
      startK = root.patternAnchorDate
      endK = CalendarMath.dateKey(root.viewYear, 11, 31)
    } else if (root.patternRangePreset === "fullYear") {
      startK = CalendarMath.dateKey(root.viewYear, 0, 1)
      endK = CalendarMath.dateKey(root.viewYear, 11, 31)
    } else if (root.patternRangePreset === "threeMonths") {
      startK = root.patternAnchorDate
      endK = CalendarMath.addDays(root.patternAnchorDate, 90)
    } else if (root.patternRangePreset === "sixMonths") {
      startK = root.patternAnchorDate
      endK = CalendarMath.addDays(root.patternAnchorDate, 180)
    }

    var range = CalendarMath.dateRange(startK, endK)
    var updated = ({})
    for (var k in root.shifts) updated[k] = root.shifts[k]
    for (var i = 0; i < range.length; i++) {
      delete updated[range[i]]
    }
    root.shifts = updated
    root.flushSave()
    root.patternStatusMsg = "Cleared " + range.length + " days"
    root.patternStatusIsError = false
  }

  function loadShifts(raw) {
    if (!raw || raw.trim() === "") return
    try {
      var parsed = JSON.parse(raw)
      if (parsed && typeof parsed === "object") {
        root.shifts = parsed
      }
    } catch (e) {
      console.warn("Shift Calendar Panel: Failed to parse shifts.json:", e)
    }
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

  Timer {
    id: saveDebounceTimer
    interval: 120
    repeat: false
    onTriggered: {
      var jsonStr = JSON.stringify(root.shifts)
      Quickshell.execDetached([root.pluginDir + "/save-shifts.sh", jsonStr])
    }
  }

  function flushSave() {
    saveDebounceTimer.stop()
    var jsonStr = JSON.stringify(root.shifts)
    Quickshell.execDetached([root.pluginDir + "/save-shifts.sh", jsonStr])
  }

  function saveShifts(data) {
    if (data) root.shifts = data
    saveDebounceTimer.restart()
  }

  function setShift(dateKey, shiftType) {
    var updated = ({})
    for (var k in root.shifts) updated[k] = root.shifts[k]
    if (!shiftType || shiftType === "none") {
      delete updated[dateKey]
    } else {
      updated[dateKey] = shiftType
    }
    root.shifts = updated
    saveDebounceTimer.restart()
  }

  function toggleDateShift(dateKey) {
    if (activeShiftTool !== "") {
      if (shifts[dateKey] === activeShiftTool) {
        setShift(dateKey, "none")
      } else {
        setShift(dateKey, activeShiftTool)
      }
    } else {
      var cur = shifts[dateKey] || ""
      if (cur === "") setShift(dateKey, "day")
      else if (cur === "day") setShift(dateKey, "night")
      else if (cur === "night") setShift(dateKey, "off")
      else setShift(dateKey, "none")
    }
  }

  // Active tool: "" (cycle mode), "day", "night", "off", "none"
  property string activeShiftTool: ""

  // View state: "month" or "year"
  property string viewMode: "month"

  property date today: new Date()
  readonly property string todayKey: CalendarMath.keyForDate(today)

  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  // Focused cursor date & range anchor for Shift + Arrow navigation
  property string focusKey: todayKey
  property string rangeAnchorKey: todayKey

  function isCellInRange(key) {
    if (!rangeAnchorKey || rangeAnchorKey === "" || rangeAnchorKey === focusKey) {
      return key === focusKey
    }
    var minK = rangeAnchorKey < focusKey ? rangeAnchorKey : focusKey
    var maxK = rangeAnchorKey < focusKey ? focusKey : rangeAnchorKey
    return key >= minK && key <= maxK
  }

  function markRangeStep(delta) {
    if (!rangeAnchorKey || rangeAnchorKey === "") rangeAnchorKey = focusKey
    var targetShift = activeShiftTool !== "" ? activeShiftTool : "day"
    var newFocus = CalendarMath.addDays(focusKey, delta)
    focusKey = newFocus

    var parts = newFocus.split("-")
    var fy = parseInt(parts[0], 10)
    var fm = parseInt(parts[1], 10) - 1
    if (fy !== viewYear || fm !== viewMonth) {
      viewYear = fy
      viewMonth = fm
    }

    var range = CalendarMath.dateRange(rangeAnchorKey, focusKey)
    var updated = ({})
    for (var k in shifts) updated[k] = shifts[k]
    for (var i = 0; i < range.length; i++) {
      if (targetShift === "none") delete updated[range[i]]
      else updated[range[i]] = targetShift
    }
    shifts = updated
    saveShifts(updated)
  }

  function moveFocus(delta) {
    var newFocus = CalendarMath.addDays(focusKey, delta)
    focusKey = newFocus
    rangeAnchorKey = newFocus

    var parts = newFocus.split("-")
    var fy = parseInt(parts[0], 10)
    var fm = parseInt(parts[1], 10) - 1
    if (fy !== viewYear || fm !== viewMonth) {
      viewYear = fy
      viewMonth = fm
    }
  }

  // Controlled wheel pacing
  property real lastPanelWheelTime: 0
  property int panelWheelAccumulator: 0

  function handlePanelWheel(delta) {
    var now = Date.now()
    if (now - lastPanelWheelTime < 280) return
    panelWheelAccumulator += delta
    if (Math.abs(panelWheelAccumulator) >= 100) {
      lastPanelWheelTime = now
      var dir = panelWheelAccumulator > 0 ? -1 : 1
      panelWheelAccumulator = 0
      if (root.viewMode === "year") root.moveYear(dir)
      else root.moveMonth(dir)
    }
  }

  readonly property var labelLocale: Qt.locale(Commons.I18n.formatLocale)
  readonly property int weekStart: labelLocale.firstDayOfWeek

  readonly property var currentMonthGrid: CalendarMath.monthGrid(viewYear, viewMonth, weekStart, todayKey)
  readonly property var yearGridList: CalendarMath.yearMonths(viewYear, weekStart, todayKey)

  // Shift counts for visible view
  readonly property var stats: CalendarMath.countShifts(
    shifts,
    viewYear,
    viewMode === "month" ? viewMonth : null
  )

  function moveMonth(delta) {
    var d = new Date(Date.UTC(viewYear, viewMonth + delta, 1))
    viewYear = d.getUTCFullYear()
    viewMonth = d.getUTCMonth()
    focusKey = CalendarMath.dateKey(viewYear, viewMonth, 1)
    rangeAnchorKey = focusKey
  }

  function moveYear(delta) {
    viewYear += delta
  }

  function goToToday() {
    today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    focusKey = todayKey
    rangeAnchorKey = todayKey
  }

  function printYearView() {
    var script = root.pluginDir + "/export-print.py"
    Quickshell.execDetached(["python3", script, String(viewYear), Commons.I18n.language])
  }

  // Panel styling
  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // Expanding icon button: compact icon by default, smoothly expands on selection!
  component ExpandingButton: Rectangle {
    id: eb
    property string iconText: ""
    property string labelText: ""
    property string tooltipText: ""
    property bool selected: false
    property color activeColor: Commons.Color.accent

    implicitWidth: selected ? (row.implicitWidth + Style.space(16)) : Style.space(32)
    implicitHeight: Style.space(28)
    radius: 6
    clip: true

    Behavior on implicitWidth {
      NumberAnimation {
        duration: Style.duration(180)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    color: selected
      ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.22)
      : (mouseArea.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent")
    border.width: selected ? 1 : (mouseArea.containsMouse ? 1 : 0)
    border.color: selected ? activeColor : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        font.pixelSize: Style.font.body
        text: eb.iconText
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        visible: eb.selected
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        color: eb.selected ? eb.activeColor : root.contentForeground
        text: eb.labelText
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: eb.clicked()
    }

    signal clicked()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent

    contentWidth: panel.fittedContentWidth(root.viewMode === "year" ? Style.space(680) : (root.viewMode === "pattern" ? Style.space(520) : Style.space(450)))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(610))

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: mainColumn.implicitHeight
      anchors.fill: parent
      blocked: true

      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.datePickerOpen) {
            root.datePickerOpen = false
            event.accepted = true
            return
          }
          root.close()
          event.accepted = true
          return
        }

        var isShift = (event.modifiers & Qt.ShiftModifier) !== 0

        if (event.key === Qt.Key_Left) {
          if (isShift) root.markRangeStep(-1)
          else root.moveFocus(-1)
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Right) {
          if (isShift) root.markRangeStep(1)
          else root.moveFocus(1)
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Up) {
          if (isShift) root.markRangeStep(-7)
          else root.moveFocus(-7)
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Down) {
          if (isShift) root.markRangeStep(7)
          else root.moveFocus(7)
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.toggleDateShift(root.focusKey)
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
          root.setShift(root.focusKey, "none")
          event.accepted = true
          return
        }
        if (event.text === "1" || event.text === "d" || event.text === "D") {
          root.activeShiftTool = (root.activeShiftTool === "day" ? "" : "day")
          event.accepted = true
          return
        }
        if (event.text === "2" || event.text === "n" || event.text === "N") {
          root.activeShiftTool = (root.activeShiftTool === "night" ? "" : "night")
          event.accepted = true
          return
        }
        if (event.text === "3" || event.text === "o" || event.text === "O") {
          root.activeShiftTool = (root.activeShiftTool === "off" ? "" : "off")
          event.accepted = true
          return
        }
        if (event.text === "c" || event.text === "C" || event.text === "x" || event.text === "X") {
          root.activeShiftTool = (root.activeShiftTool === "none" ? "" : "none")
          event.accepted = true
          return
        }
        if (event.text === "t" || event.text === "T") {
          root.goToToday()
          event.accepted = true
          return
        }
        if (event.text === "m" || event.text === "M") {
          root.viewMode = (root.viewMode === "month" ? "year" : "month")
          event.accepted = true
          return
        }
        if (event.text === "a" || event.text === "A" || event.text === "r" || event.text === "R") {
          root.viewMode = (root.viewMode === "pattern" ? "month" : "pattern")
          event.accepted = true
          return
        }
        if (root.viewMode === "pattern" && (event.text === "s" || event.text === "S")) {
          if (root.datePickerOpen) root.datePickerOpen = false
          else root.openDatePicker()
          event.accepted = true
          return
        }
        if (event.text === "p" || event.text === "P") {
          root.printYearView()
          event.accepted = true
          return
        }
      }

      WheelHandler {
        target: keyCatcher
        orientation: Qt.Vertical
        onWheel: function(event) {
          root.handlePanelWheel(event.angleDelta.y)
        }
      }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: mainColumn
          width: panelScroll.width
          spacing: Style.space(8)
          padding: Style.space(10)

          // ===== 1. TOP HEADER & NAVIGATION =====
          Item {
            width: parent.width - mainColumn.padding * 2
            height: Style.space(30)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(5)

              Button {
                visible: root.viewMode !== "pattern"
                width: Style.space(26)
                height: Style.space(26)
                text: "‹"
                tooltipText: root.viewMode === "year" ? strings.t("action.prevYear") : strings.t("action.prevMonth")
                bordered: true
                onClicked: {
                  if (root.viewMode === "year") root.moveYear(-1)
                  else root.moveMonth(-1)
                }
              }

              Button {
                visible: root.viewMode !== "pattern"
                width: Style.space(26)
                height: Style.space(26)
                text: "›"
                tooltipText: root.viewMode === "year" ? strings.t("action.nextYear") : strings.t("action.nextMonth")
                bordered: true
                onClicked: {
                  if (root.viewMode === "year") root.moveYear(1)
                  else root.moveMonth(1)
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                color: root.contentForeground
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Style.space(160))
                text: {
                  if (root.viewMode === "pattern") return strings.t("pattern.title")
                  if (root.viewMode === "year") return String(root.viewYear)
                  return root.labelLocale.standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
                }
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              ExpandingButton {
                iconText: "📅"
                labelText: strings.t("view.month")
                selected: root.viewMode === "month"
                onClicked: root.viewMode = "month"
              }

              ExpandingButton {
                iconText: "🗓️"
                labelText: strings.t("view.year")
                selected: root.viewMode === "year"
                onClicked: root.viewMode = "year"
              }

              ExpandingButton {
                iconText: "🔄"
                labelText: strings.t("view.pattern")
                selected: root.viewMode === "pattern"
                onClicked: root.viewMode = "pattern"
              }

              Button {
                width: Style.space(28)
                height: Style.space(28)
                text: "⦿"
                tooltipText: strings.t("action.today")
                bordered: true
                onClicked: root.goToToday()
              }

              Button {
                width: Style.space(28)
                height: Style.space(28)
                text: "🖨️"
                tooltipText: strings.t("action.print")
                bordered: true
                onClicked: root.printYearView()
              }
            }
          }

          // ===== 2. SHIFT TOOLBAR (EXPANDING ON SELECT) =====
          Rectangle {
            visible: root.viewMode !== "pattern"
            width: parent.width - mainColumn.padding * 2
            height: Style.space(34)
            radius: 8
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            border.width: 1

            Row {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              ExpandingButton {
                iconText: "☀️"
                labelText: strings.t("shift.day")
                activeColor: "#f59e0b"
                selected: root.activeShiftTool === "day"
                onClicked: root.activeShiftTool = (root.activeShiftTool === "day" ? "" : "day")
              }

              ExpandingButton {
                iconText: "🌙"
                labelText: strings.t("shift.night")
                activeColor: "#a78bfa"
                selected: root.activeShiftTool === "night"
                onClicked: root.activeShiftTool = (root.activeShiftTool === "night" ? "" : "night")
              }

              ExpandingButton {
                iconText: "🏖️"
                labelText: strings.t("shift.off")
                activeColor: "#10b981"
                selected: root.activeShiftTool === "off"
                onClicked: root.activeShiftTool = (root.activeShiftTool === "off" ? "" : "off")
              }

              ExpandingButton {
                iconText: "✖️"
                labelText: strings.t("shift.none")
                activeColor: Commons.Color.urgent
                selected: root.activeShiftTool === "none"
                onClicked: root.activeShiftTool = (root.activeShiftTool === "none" ? "" : "none")
              }
            }

            // Counter badges on the right
            Row {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: "#f59e0b"
                text: "☀️ " + root.stats.day
              }

              Text {
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: "#a78bfa"
                text: "🌙 " + root.stats.night
              }

              Text {
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: "#10b981"
                text: "🏖️ " + root.stats.off
              }
            }
          }

        // ===== 3. MONTH DETAILED VIEW (WITH DRAG & SELECTION) =====
        Column {
          visible: root.viewMode === "month"
          width: parent.width - mainColumn.padding * 2
          spacing: Style.space(4)

          // Weekday header row
          Row {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: 7

              Item {
                width: Math.floor((parent.width - Style.space(4) * 6) / 7)
                height: Style.space(20)

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: (index === 5 || index === 6) ? Commons.Color.urgent : root.contentForeground
                  opacity: 0.7
                  text: root.labelLocale.dayName((root.weekStart + index) % 7, Locale.ShortFormat)
                }
              }
            }
          }

          // 6 Weeks of Days with mouse drag support
          Item {
            id: monthGridContainer
            width: parent.width
            height: 6 * Style.space(34) + 5 * Style.space(4)

            Column {
              anchors.fill: parent
              spacing: Style.space(4)

              Repeater {
                model: root.currentMonthGrid

                Row {
                  id: weekRow
                  required property var modelData
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: weekRow.modelData

                    Rectangle {
                      id: dayCell
                      required property var modelData
                      width: Math.floor((weekRow.width - Style.space(4) * 6) / 7)
                      height: Style.space(34)
                      radius: 6

                      readonly property string cellShift: root.shifts[modelData.key] || ""
                      readonly property bool isFocused: modelData.key === root.focusKey
                      readonly property bool inRange: root.isCellInRange(modelData.key)

                      color: {
                        if (cellShift === "day") return Qt.rgba(0.96, 0.62, 0.04, 0.22)
                        if (cellShift === "night") return Qt.rgba(0.55, 0.36, 0.96, 0.22)
                        if (cellShift === "off") return Qt.rgba(0.06, 0.72, 0.5, 0.22)
                        return Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
                      }

                      border.width: (isFocused || inRange || modelData.isToday) ? 2 : (cellShift !== "" ? 1 : 0)
                      border.color: {
                        if (isFocused || inRange) return Commons.Color.accent
                        if (modelData.isToday) return Commons.Color.foreground
                        if (cellShift === "day") return "#f59e0b"
                        if (cellShift === "night") return "#8b5cf6"
                        if (cellShift === "off") return "#10b981"
                        return "transparent"
                      }

                      opacity: modelData.inMonth ? 1.0 : 0.35

                      Text {
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                        textFormat: Text.PlainText
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: modelData.isToday || cellShift !== "" || isFocused
                        color: root.contentForeground
                        text: String(modelData.day)
                      }

                      Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        textFormat: Text.PlainText
                        font.pixelSize: Style.font.caption
                        text: {
                          if (cellShift === "day") return "☀️"
                          if (cellShift === "night") return "🌙"
                          if (cellShift === "off") return "🏖️"
                          return ""
                        }
                      }
                    }
                  }
                }
              }
            }

            // Unified drag MouseArea
            MouseArea {
              id: monthMouseArea
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor

              property bool isDragging: false
              property string dragShiftType: ""
              property string lastKey: ""

              function cellUnder(x, y) {
                var cellW = Math.floor((width - Style.space(4) * 6) / 7)
                var cellH = Style.space(38)
                var stepX = cellW + Style.space(4)
                var stepY = cellH + Style.space(4)
                var col = Math.floor(x / stepX)
                var row = Math.floor(y / stepY)
                if (col < 0 || col >= 7 || row < 0 || row >= 6) return null
                if ((x - col * stepX) > cellW || (y - row * stepY) > cellH) return null
                if (root.currentMonthGrid && root.currentMonthGrid[row]) {
                  return root.currentMonthGrid[row][col]
                }
                return null
              }

              onPressed: function(mouse) {
                var cell = cellUnder(mouse.x, mouse.y)
                if (!cell) return
                isDragging = true
                root.focusKey = cell.key
                root.rangeAnchorKey = cell.key

                if (mouse.button === Qt.RightButton) {
                  dragShiftType = "none"
                } else {
                  if (root.activeShiftTool !== "") {
                    dragShiftType = root.activeShiftTool
                  } else {
                    var cur = root.shifts[cell.key] || ""
                    if (cur === "") dragShiftType = "day"
                    else if (cur === "day") dragShiftType = "night"
                    else if (cur === "night") dragShiftType = "off"
                    else dragShiftType = "none"
                  }
                }
                lastKey = cell.key
                root.setShift(cell.key, dragShiftType)
              }

              onPositionChanged: function(mouse) {
                if (!isDragging) return
                var cell = cellUnder(mouse.x, mouse.y)
                if (cell && cell.key !== lastKey) {
                  lastKey = cell.key
                  root.focusKey = cell.key
                  root.setShift(cell.key, dragShiftType)
                }
              }

              onReleased: {
                isDragging = false
                lastKey = ""
                root.flushSave()
              }
            }
          }
        }

        // ===== 4. 12-MONTH ANNUAL OVERVIEW GRID (4 COLS x 3 ROWS) =====
        Grid {
          visible: root.viewMode === "year"
          width: parent.width - mainColumn.padding * 2
          columns: 4
          columnSpacing: Style.space(6)
          rowSpacing: Style.space(6)

          Repeater {
            model: root.yearGridList

            Rectangle {
              id: yearMonthCard
              required property var modelData
              width: Math.floor((parent.width - Style.space(18)) / 4)
              height: Style.space(118)
              radius: 6
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
              border.width: 1

              Column {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Item {
                  width: parent.width
                  height: Style.space(16)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.contentForeground
                    text: root.labelLocale.standaloneMonthName(modelData.month, Locale.LongFormat)
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.viewMonth = modelData.month
                      root.viewMode = "month"
                    }
                  }
                }

                Repeater {
                  model: modelData.weeks

                  Row {
                    id: miniWeekRow
                    required property var modelData
                    width: parent.width
                    spacing: 2

                    Repeater {
                      model: miniWeekRow.modelData

                      Rectangle {
                        id: miniCell
                        required property var modelData
                        width: Math.floor((miniWeekRow.width - 12) / 7)
                        height: Style.space(13)
                        radius: 2

                        readonly property string miniShift: root.shifts[modelData.key] || ""

                        color: {
                          if (miniShift === "day") return Qt.rgba(0.96, 0.62, 0.04, 0.45)
                          if (miniShift === "night") return Qt.rgba(0.55, 0.36, 0.96, 0.45)
                          if (miniShift === "off") return Qt.rgba(0.06, 0.72, 0.5, 0.45)
                          return "transparent"
                        }

                        border.width: modelData.isToday ? 1 : 0
                        border.color: Commons.Color.accent
                        opacity: modelData.inMonth ? 1.0 : 0.2

                        Text {
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          font.family: root.contentFontFamily
                          font.pixelSize: 8
                          font.bold: miniShift !== "" || modelData.isToday
                          color: root.contentForeground
                          text: String(modelData.day)
                        }

                        MouseArea {
                          anchors.fill: parent
                          acceptedButtons: Qt.LeftButton | Qt.RightButton
                          cursorShape: Qt.PointingHandCursor
                          onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                              root.setShift(modelData.key, "none")
                            } else {
                              root.toggleDateShift(modelData.key)
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ===== 5. ROTATION & AUTOMATION PATTERN VIEW =====
        Column {
          visible: root.viewMode === "pattern"
          width: parent.width - Style.space(20)
          spacing: Style.space(10)

          // 1. GUESSER & AUTO-DETECT CARD
          Rectangle {
            width: parent.width
            implicitHeight: guesserRow.implicitHeight + Style.space(14)
            radius: 8
            color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.08)
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.25)
            border.width: 1

            Row {
              id: guesserRow
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: root.contentForeground
                text: "✨ " + strings.t("pattern.guessBtn")
                font.bold: true
              }

              Item {
                height: 1
                width: Math.max(8, parent.width - 320)
              }

              Button {
                anchors.verticalCenter: parent.verticalCenter
                text: "Detect Pattern"
                bordered: true
                onClicked: root.guessPatternFromHistory()
              }
            }
          }

          // Guesser feedback notification (if any)
          Rectangle {
            visible: root.patternStatusMsg !== ""
            width: parent.width
            implicitHeight: statusText.implicitHeight + Style.space(12)
            radius: 6
            color: root.patternStatusIsError
              ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.15)
              : Qt.rgba(0.06, 0.72, 0.5, 0.15)
            border.width: 1
            border.color: root.patternStatusIsError ? Commons.Color.urgent : "#10b981"

            Text {
              id: statusText
              anchors.centerIn: parent
              textFormat: Text.PlainText
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: root.patternStatusIsError ? Commons.Color.urgent : "#10b981"
              text: (root.patternStatusIsError ? "⚠️ " : "✅ ") + root.patternStatusMsg
            }
          }

          // 2. PRESETS ROW (WRAPPING FLOW)
          Flow {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: presetsLabel.implicitWidth
              height: Style.space(28)

              Text {
                id: presetsLabel
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                opacity: 0.7
                color: root.contentForeground
                text: strings.t("pattern.presets") + ":"
              }
            }

            Button {
              text: strings.t("pattern.userExample")
              bordered: true
              onClicked: root.loadPreset("userExample")
            }

            Button {
              text: strings.t("pattern.fourOnFourOff")
              bordered: true
              onClicked: root.loadPreset("fourOnFourOff")
            }

            Button {
              text: strings.t("pattern.pitman")
              bordered: true
              onClicked: root.loadPreset("pitman")
            }

            Button {
              text: strings.t("pattern.standard")
              bordered: true
              onClicked: root.loadPreset("standard")
            }
          }

          // 3. INTERACTIVE PATTERN BUILDER
          Rectangle {
            width: parent.width
            implicitHeight: builderCol.implicitHeight + Style.space(16)
            radius: 8
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            border.width: 1

            Column {
              id: builderCol
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              spacing: Style.space(8)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.contentForeground
                  text: strings.t("pattern.custom")
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  opacity: 0.7
                  color: root.contentForeground
                  text: strings.t("pattern.cycle").arg(root.patternTotalCycleDays)
                }

                Item {
                  height: 1
                  width: Math.max(8, parent.width - 320)
                }

                Button {
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("pattern.addBlock")
                  bordered: true
                  onClicked: root.addStep("day", 2)
                }
              }

              // Flow of step chips
              Flow {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.patternSteps

                  Rectangle {
                    id: stepChip
                    required property int index
                    required property var modelData
                    height: Style.space(34)
                    radius: 6
                    width: stepContent.implicitWidth + Style.space(12)

                    readonly property string stepType: modelData ? modelData.type : "day"
                    readonly property int stepCount: modelData ? modelData.count : 1

                    color: {
                      if (stepType === "day") return Qt.rgba(0.96, 0.62, 0.04, 0.2)
                      if (stepType === "night") return Qt.rgba(0.55, 0.36, 0.96, 0.2)
                      return Qt.rgba(0.06, 0.72, 0.5, 0.2)
                    }
                    border.width: 1
                    border.color: {
                      if (stepType === "day") return "#f59e0b"
                      if (stepType === "night") return "#a78bfa"
                      return "#10b981"
                    }

                    Row {
                      id: stepContent
                      anchors.centerIn: parent
                      spacing: Style.space(4)

                      // Type toggle button (Click to cycle Day -> Off -> Night)
                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(60)
                        height: Style.space(24)
                        radius: 4
                        color: Qt.rgba(0, 0, 0, 0.15)

                        Row {
                          anchors.centerIn: parent
                          spacing: 2
                          Text {
                            textFormat: Text.PlainText
                            font.pixelSize: Style.font.caption
                            text: stepType === "day" ? "☀️" : (stepType === "night" ? "🌙" : "🏖️")
                          }
                          Text {
                            textFormat: Text.PlainText
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.contentForeground
                            text: stepType === "day" ? "Day" : (stepType === "night" ? "Night" : "Off")
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.cycleStepType(stepChip.index)
                        }
                      }

                      // Minus button
                      Button {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(22)
                        height: Style.space(22)
                        text: "−"
                        onClicked: root.changeStepCount(stepChip.index, -1)
                      }

                      // Count text
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        text: stepCount + " " + strings.t("pattern.daysUnit")
                      }

                      // Plus button
                      Button {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(22)
                        height: Style.space(22)
                        text: "+"
                        onClicked: root.changeStepCount(stepChip.index, 1)
                      }

                      // Remove step button (visible if > 1 step)
                      Button {
                        visible: root.patternSteps.length > 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(22)
                        height: Style.space(22)
                        text: "✕"
                        onClicked: root.removeStep(stepChip.index)
                      }
                    }
                  }
                }
              }
            }
          }

          // 4. ANCHOR DATE SELECTION & DATE PICKER
          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.contentForeground
                text: strings.t("pattern.anchor") + ":"
              }

              Button {
                text: "📅 " + root.patternAnchorDate + (root.datePickerOpen ? " ▴" : " ▾")
                selected: root.datePickerOpen
                bordered: true
                onClicked: {
                  if (root.datePickerOpen) root.datePickerOpen = false
                  else root.openDatePicker()
                }
              }

              Button {
                text: "Use " + root.focusKey
                tooltipText: "Set start date to focused calendar day"
                bordered: true
                onClicked: {
                  root.patternAnchorDate = root.focusKey
                  root.savePatternConfig()
                }
              }

              Button {
                text: strings.t("action.today")
                bordered: true
                onClicked: {
                  root.patternAnchorDate = root.todayKey
                  root.savePatternConfig()
                }
              }
            }

            // INLINE FULL MONTH DATE SELECTION DIALOG
            Rectangle {
              id: datePickerDialog
              visible: root.datePickerOpen
              width: parent.width
              implicitHeight: pickerCol.implicitHeight + Style.space(16)
              radius: 8
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
              border.color: Commons.Color.accent
              border.width: 1

              Column {
                id: pickerCol
                anchors.centerIn: parent
                width: parent.width - Style.space(16)
                spacing: Style.space(6)

                // Header with Year / Month jumpers
                Item {
                  width: parent.width
                  height: Style.space(26)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Button {
                      width: Style.space(24)
                      height: Style.space(24)
                      text: "«"
                      tooltipText: "Previous Year"
                      bordered: true
                      onClicked: root.stepPickerYear(-1)
                    }

                    Button {
                      width: Style.space(24)
                      height: Style.space(24)
                      text: "‹"
                      tooltipText: "Previous Month"
                      bordered: true
                      onClicked: root.stepPickerMonth(-1)
                    }
                  }

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    color: root.contentForeground
                    text: root.labelLocale.standaloneMonthName(root.pickerMonth, Locale.LongFormat) + " " + root.pickerYear
                  }

                  Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Button {
                      width: Style.space(24)
                      height: Style.space(24)
                      text: "›"
                      tooltipText: "Next Month"
                      bordered: true
                      onClicked: root.stepPickerMonth(1)
                    }

                    Button {
                      width: Style.space(24)
                      height: Style.space(24)
                      text: "»"
                      tooltipText: "Next Year"
                      bordered: true
                      onClicked: root.stepPickerYear(1)
                    }
                  }
                }

                // Weekday Header
                Row {
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: 7

                    Item {
                      width: Math.floor((parent.width - Style.space(4) * 6) / 7)
                      height: Style.space(16)

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        opacity: 0.6
                        color: (index === 5 || index === 6) ? Commons.Color.urgent : root.contentForeground
                        text: root.labelLocale.dayName((root.weekStart + index) % 7, Locale.ShortFormat)
                      }
                    }
                  }
                }

                // 6x7 Month Grid
                Grid {
                  id: pickerGrid
                  width: parent.width
                  columns: 7
                  columnSpacing: Style.space(4)
                  rowSpacing: Style.space(4)

                  readonly property var pickerWeeks: CalendarMath.monthGrid(root.pickerYear, root.pickerMonth, root.weekStart, root.todayKey)

                  Repeater {
                    model: 42

                    Rectangle {
                      id: pickerCell
                      required property int index
                      width: Math.floor((pickerGrid.width - Style.space(4) * 6) / 7)
                      height: Style.space(24)
                      radius: 4

                      readonly property int weekIdx: Math.floor(index / 7)
                      readonly property int dayIdx: index % 7
                      readonly property var dayObj: (pickerGrid.pickerWeeks && pickerGrid.pickerWeeks[weekIdx])
                        ? pickerGrid.pickerWeeks[weekIdx][dayIdx]
                        : null

                      readonly property bool isSelected: dayObj && dayObj.key === root.patternAnchorDate
                      readonly property bool isCurrentMonth: dayObj && dayObj.inMonth

                      color: isSelected
                        ? Commons.Color.accent
                        : (pickerMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1) : "transparent")

                      border.width: (dayObj && dayObj.isToday && !isSelected) ? 1 : 0
                      border.color: Commons.Color.accent
                      opacity: isCurrentMonth ? 1.0 : 0.3

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: isSelected || (dayObj && dayObj.isToday)
                        color: isSelected ? "#000000" : root.contentForeground
                        text: dayObj ? String(dayObj.day) : ""
                      }

                      MouseArea {
                        id: pickerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (pickerCell.dayObj) {
                            root.selectPickerDate(pickerCell.dayObj.key)
                          }
                        }
                      }
                    }
                  }
                }

                // Quick shortcuts row & Done
                Item {
                  width: parent.width
                  height: Style.space(26)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Button {
                      text: strings.t("pattern.firstOfMonth")
                      bordered: true
                      onClicked: root.selectPickerDate(CalendarMath.dateKey(root.pickerYear, root.pickerMonth, 1))
                    }

                    Button {
                      text: strings.t("pattern.jan1")
                      bordered: true
                      onClicked: root.selectPickerDate(CalendarMath.dateKey(root.pickerYear, 0, 1))
                    }
                  }

                  Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: strings.t("pattern.done")
                    selected: true
                    bordered: true
                    onClicked: root.datePickerOpen = false
                  }
                }
              }
            }
          }

          // 5. TARGET RANGE PRESET SELECTOR (WRAPPING FLOW)
          Flow {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: rangeLabel.implicitWidth
              height: Style.space(28)

              Text {
                id: rangeLabel
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                opacity: 0.7
                color: root.contentForeground
                text: strings.t("pattern.range") + ":"
              }
            }

            Button {
              text: strings.t("pattern.range.restOfYear")
              selected: root.patternRangePreset === "restOfYear"
              bordered: true
              onClicked: {
                root.patternRangePreset = "restOfYear"
                root.savePatternConfig()
              }
            }

            Button {
              text: strings.t("pattern.range.fullYear").arg(root.viewYear)
              selected: root.patternRangePreset === "fullYear"
              bordered: true
              onClicked: {
                root.patternRangePreset = "fullYear"
                root.savePatternConfig()
              }
            }

            Button {
              text: strings.t("pattern.range.threeMonths")
              selected: root.patternRangePreset === "threeMonths"
              bordered: true
              onClicked: {
                root.patternRangePreset = "threeMonths"
                root.savePatternConfig()
              }
            }

            Button {
              text: strings.t("pattern.range.sixMonths")
              selected: root.patternRangePreset === "sixMonths"
              bordered: true
              onClicked: {
                root.patternRangePreset = "sixMonths"
                root.savePatternConfig()
              }
            }
          }

          // 6. ACTION BUTTONS (APPLY & CLEAR)
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(12)

            Button {
              text: "▶ " + strings.t("pattern.applyBtn")
              selected: true
              bordered: true
              onClicked: root.applyCurrentPattern()
            }

            Button {
              text: "✖ " + strings.t("pattern.clearBtn")
              bordered: true
              onClicked: root.clearCurrentPatternRange()
            }
          }
        }

        // ===== 6. FOOTER STATS & HINT =====
        Item {
          width: parent.width - mainColumn.padding * 2
          height: Style.space(22)

          Text {
            anchors.left: parent.left
            anchors.right: footerStatsText.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            opacity: 0.6
            color: root.contentForeground
            elide: Text.ElideRight
            text: root.viewMode === "pattern"
              ? "Pick start date and target range, then click Apply"
              : "Drag or Shift+Arrows to mark • Right-click to erase"
          }

          Text {
            id: footerStatsText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.contentForeground
            text: strings.t("stats.total").arg(root.stats.total)
          }
        }
      }
    }
  }
}
}
