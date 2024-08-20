from "%rGui/globals/ui_library.nut" import *
let { subscribe, send, eventbus_subscribe, eventbus_send} = require("eventbus")
let { resetTimeout } = require("dagor.workcycle")

let isActionBarCollapsed = Watched(false)
let isActionBarCollapsable = Watched(false)
let isCollapseBtnHided = Watched(false)
let isCollapseHintVisible = Watched(false)
let isActionBarVisible = Watched(false)
let actionBarPos = Watched(null)
let actionBarSize = Watched(null)
let actionBarCollapseShText = Watched("")
let collapseBtnPressedTime = Watched(0)

let hintShowTime = 3
let preesTimeForHideBtn = 1.5

function hideCollapseBtnHint() {
  isCollapseHintVisible.set(false)
}

function showCollapseBtnHint() {
  isCollapseHintVisible.set(true)
  resetTimeout(hintShowTime, hideCollapseBtnHint)
}

local isCollapseTimerComplete = false

function updateCollapsePressTime() {
  let progressTime = collapseBtnPressedTime.get() + 0.1 / preesTimeForHideBtn
  collapseBtnPressedTime.set(progressTime)
  if (progressTime > 1) {
    gui_scene.clearTimer(updateCollapsePressTime)
    collapseBtnPressedTime.set(0)
    isCollapseTimerComplete = true

    if (isCollapseBtnHided.get()) {
      isCollapseBtnHided.set(false)
      eventbus_send("collapseActionBar")
    } else {
      if (!isActionBarCollapsed.get())
        eventbus_send("collapseActionBar")
      isCollapseBtnHided.set(true)
    }
  }
}

function onCollapseShortcutPress(v) {
  if (!isActionBarCollapsable.get())
    return
  gui_scene.clearTimer(updateCollapsePressTime)
  collapseBtnPressedTime.set(0)
  if (v.isKeyDown) {
    gui_scene.setInterval(0.1, updateCollapsePressTime)
    hideCollapseBtnHint()
  } else {
    if (!isCollapseTimerComplete) {
      if (!isActionBarCollapsed.get())
        showCollapseBtnHint()
      eventbus_send("collapseActionBar")
      isCollapseBtnHided.set(false)
    }
    isCollapseTimerComplete = false
  }
}

eventbus_subscribe("onCollapseActionBarBtn",
  @(v) v?.isKeyDown != null ? onCollapseShortcutPress(v) : eventbus_send("collapseActionBar"))
subscribe("setIsActionBarVisible", @(v) isActionBarVisible.set(v))
subscribe("setIsActionBarCollapsed", @(v) isActionBarCollapsed.set(v))
subscribe("setActionBarState", function(params) {
  isActionBarCollapsed.set(params?.isCollapsed ?? false)
  isActionBarCollapsable.set(params?.isCollapsable ?? false)
  isActionBarVisible.set(params?.isVisible ?? false)
  actionBarPos.set(params?.pos)
  actionBarSize.set(params?.size)
  actionBarCollapseShText.set(params?.shortcutText ?? "")
})

send("getActionBarState", {})

return {
  collapseBtnPressedTime
  isActionBarCollapsed
  isCollapseBtnHided
  isActionBarCollapsable
  isActionBarVisible
  isCollapseHintVisible
  actionBarPos
  actionBarSize
  actionBarCollapseShText
}