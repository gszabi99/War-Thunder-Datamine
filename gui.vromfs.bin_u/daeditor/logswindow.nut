import "dagor.debug" as dagorDebug
from "dagor.clipboard" import set_clipboard_text
from "%darg/ui_imports.nut" import *
from "%sqstd/ecs.nut" import *
let { LogsWindowId } = require("state.nut")
let { hasNewLogerr } = require("%daeditor/state/logsWindow.nut")
let textButton = require("components/textButton.nut")
let { isWindowVisible } = require("components/window.nut")
let { makeVertScroll } = require("%daeditor/components/scrollbar.nut")
let { mkFilteredList, rowText } = require("components/mkFilteredList.nut")

let logExpandedTexScroll = ScrollHandler()

let logList = Watched([])
let selectedLogIndex = Watched(-1)
let logCount = Computed(@() logList.get().len())
let logItems = Computed(@() logList.get().map(@(msg, idx) { idx, msg }))

const logExpandedColor = Color(15,15,15,200)

let excludeLogByText = [
  "sync creation of entity"
]

dagorDebug.register_logerr_monitor([" "], function(_tags, msg, _timestamp) {
  foreach(excludeText in excludeLogByText)
    if (msg.contains(excludeText))
      return

  if (!isWindowVisible(LogsWindowId))
    hasNewLogerr.set(true)
  logList.mutate(@(v) v.append(msg))
})

function selectedLogCopy() {
  if (selectedLogIndex.get() == -1)
    return
  set_clipboard_text(logList.get()[selectedLogIndex.get()])
}

function statusLine() {
  return {
    watch = logCount
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = FLEX_H
        text = $"{logCount.get()} errors   "
        color = Color(170,170,170)
     }
    ]
  }
}


let logsList = mkFilteredList({
  items = logItems
  selected = selectedLogIndex
  revealOnItems = false
  keyOf = @(item, _idx) item.idx
  mkRow = @(item, _row) rowText(item.msg)
  onClick = @(item, _evt) selectedLogIndex.modify(@(v) v != item.idx ? item.idx : -1)
})

function selectedLogExpanded() {
  if (selectedLogIndex.get() == -1)
    return { watch = selectedLogIndex }

  return {
    rendObj = ROBJ_SOLID
    color = logExpandedColor
    size = const [flex(), hdpx(160)]
    watch = [logList, selectedLogIndex]
    children = makeVertScroll({
      margin = hdpx(10)
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      size = FLEX_H
      text = logList.get()[selectedLogIndex.get()]
    }, { scrollHandler = logExpandedTexScroll })
  }
}

function logsRoot() {
  return {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    size = flex()
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        children = const [
          { size = const [sw(0.2), SIZE_TO_CONTENT] }
          {
            rendObj = ROBJ_TEXT
            size = FLEX_H
            margin = fsh(0.5)
            text = "Errors log"
          }
        ]
      }
      logsList
      selectedLogExpanded
      statusLine
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        halign = ALIGN_CENTER
        children = [
          textButton("Clear",  function(){
            logList.set([])
            selectedLogIndex.set(-1)
          }, {hotkeys=["^X"]})
        ]
      }
    ]
    hotkeys = [
      ["L.Ctrl !L.Alt C", { action = selectedLogCopy, ignoreConsumerCallback = true }]
    ]
  }
}
return {
  id = LogsWindowId
  content = logsRoot
  onAttach = @() hasNewLogerr.set(false)
  saveState=true
  headerText = "Log"
}
