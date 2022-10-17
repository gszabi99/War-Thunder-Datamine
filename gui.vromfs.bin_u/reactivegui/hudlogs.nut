from "%rGui/globals/ui_library.nut" import *

let chat = require("hudChat.nut")
let battleLog = require("hudBattleLog.nut")
let tabs = require("components/tabs.nut")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let { canWriteToChat, hudLog, lastInputTime } = require("hudChatState.nut")
let { isMultiplayer } = require("networkState.nut")
let { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")

let tabsList = [
  { id = "Chat", text = loc("mainmenu/chat"), content = chat }
  { id = "BattleLog", text = loc("options/_Bttl"), content = battleLog }
]

let isEnabled = Computed(@() isChatPlaceVisible.value && isMultiplayer.value)
let isInteractive = Computed(@() canWriteToChat.value || cursorVisible.value)
let isNewMessage = Watched(false)
let isFadingOut = Watched(false)
let isInited = Watched(false)
let isVisible = Computed(@() isEnabled.value && isInited.value
  && (isInteractive.value || isFadingOut.value || isNewMessage.value))

let currentTab = Watched(tabsList[0])
let currentLog = Computed(function(prev) {
  if (cursorVisible.value || prev == FRP_INITIAL)
    return currentTab.value

  if (canWriteToChat.value || isNewMessage.value)
    return tabsList[0]

  return prev
})

let showOutId = {}
let fastFadeOutId = {}
let slowFadeOutId = {}
let fastDuration = 0.2
let slowDuration = 5
let opacityAnim = { prop = AnimProp.opacity, easing = OutCubic }

let logsContainerAnims = [
  opacityAnim.__merge({ trigger = showOutId,     from = 0.2, to = 1, duration = fastDuration, play = true })
  opacityAnim.__merge({ trigger = fastFadeOutId, from = 1,   to = 0, duration = fastDuration,
    onEnter = @() isFadingOut(true), onFinish = @() isFadingOut(false), onAbort = @() isFadingOut(false) })
  opacityAnim.__merge({ trigger = fastFadeOutId, from = 0,   to = 0, duration = 1, delay = fastDuration })
  opacityAnim.__merge({ trigger = slowFadeOutId, from = 1,   to = 0, duration = slowDuration,
    onEnter = @() isFadingOut(true), onFinish = @() isFadingOut(false), onAbort = @() isFadingOut(false) })
  opacityAnim.__merge({ trigger = slowFadeOutId, from = 0,   to = 0, duration = 1, delay = slowDuration })
]

let function startAnim(animId) {
  [slowFadeOutId, fastFadeOutId, showOutId].each(@(id) anim_skip(id))
  anim_start(animId)
}

let hideNewMessageDelay = 5
let function hideNewMessage() {
  isNewMessage(false)
  if (!isInteractive.value)
    startAnim(slowFadeOutId)
}

// force isNewMessage state to prevent log blinking right after sending a message
lastInputTime.subscribe(function(_) {
  isNewMessage(true)
  gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
})

hudLog.subscribe(function(_) {
  if (cursorVisible.value || hudLog.value.len() == 0)
    return

  gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
  if (isNewMessage.value)
    return

  isNewMessage(true)
  if (canWriteToChat.value)
    return

  startAnim(showOutId)
})

isInteractive.subscribe(function(value) {
  if (value) {
    if (isNewMessage.value) {
      gui_scene.clearTimer(hideNewMessage)
      isNewMessage(false)
      return
    }
    startAnim(showOutId)
    return
  }

  if (!isNewMessage.value)
    startAnim(fastFadeOutId)
})

let logsHeader = @() {
  size = [flex(), SIZE_TO_CONTENT]
  watch = [cursorVisible, currentTab]
  opacity = cursorVisible.value ? 1 : 0
  children = [
    tabs({
      tabs = tabsList
      currentTab = currentTab.value.id
      onChange = @(tab) currentTab.update(tab)
    })
  ]
  transitions = [{ prop = AnimProp.opacity, duration = fastDuration, easing = OutCubic }]
}

let logsContainer = @() {
  watch = currentLog
  size = [flex(), SIZE_TO_CONTENT]
  children = currentLog.value.content
  animations = logsContainerAnims
}

let function init() {
  isInited(true)
}

return @() {
  size = [min(sw(30), sh(53)), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = isVisible
  children = isVisible.value ? [logsHeader, logsContainer] : []
  onAttach = function() {
    // delayed init to prevent getting a wrong state just after transition from other screen
    // as cursorVisible.value remains true for some frames
    gui_scene.resetTimeout(0.1, init)
  }
  onDetach = function() {
    gui_scene.clearTimer(init)
    isInited(false)
  }
}
