from "%rGui/globals/ui_library.nut" import *
let { subscribe, send, eventbus_subscribe, eventbus_send} = require("eventbus")
let { resetTimeout } = require("dagor.workcycle")
let extWatched = require("%rGui/globals/extWatched.nut")

let isActionBarCollapsed = Watched(false)
let isActionBarCollapsable = Watched(false)
let isCollapseBtnHidden = extWatched("isActionBarCollapseBtnHidden", false)
let isCollapseHintVisible = Watched(false)
let isActionBarVisible = Watched(false)
let actionBarPos = Watched(null)
let actionBarSize = Watched(null)
let actionBarCollapseShText = Watched("")
let collapseBtnPressedTime = Watched(0)

const HINT_SHOW_TIME = 3
const HIDE_BTN_PRESS_TIME = 1.5

function hideCollapseBtnHint() {
  isCollapseHintVisible.set(false)
}

function showCollapseBtnHint() {
  isCollapseHintVisible.set(true)
  resetTimeout(HINT_SHOW_TIME, hideCollapseBtnHint)
}

local isCollapseTimerComplete = false

function updateCollapsePressTime() {
  let progressTime = collapseBtnPressedTime.get() + 0.1 / HIDE_BTN_PRESS_TIME
  collapseBtnPressedTime.set(progressTime)
  if (progressTime <= 1)
    return

  gui_scene.clearTimer(updateCollapsePressTime)
  collapseBtnPressedTime.set(0)
  isCollapseTimerComplete = true

  let isHidden = !isCollapseBtnHidden.get()
  isCollapseBtnHidden.set(isHidden)
  eventbus_send("ActionBarCollapseBtnHidden", isHidden)

  if (!isHidden || !isActionBarCollapsed.get())
    eventbus_send("collapseActionBar")
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
      isCollapseBtnHidden.set(false)
    }
    isCollapseTimerComplete = false
  }
}

eventbus_subscribe("onCollapseActionBarBtn", onCollapseShortcutPress)
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
  isCollapseBtnHidden
  isActionBarCollapsable
  isActionBarVisible
  isCollapseHintVisible
  actionBarPos
  actionBarSize
  actionBarCollapseShText
}