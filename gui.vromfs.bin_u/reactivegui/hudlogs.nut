from "%rGui/globals/ui_library.nut" import *

let chat = require("hudChat.nut")
let battleLog = require("hudBattleLog.nut")
let tabs = require("components/tabs.nut")
let { get_option_auto_show_chat } = require("chat")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let { canWriteToChat, hudLog, lastInputTime } = require("hudChatState.nut")
let { isMultiplayer } = require("networkState.nut")
let { isChatPlaceVisible, isVisualWeaponSelectorVisible } = require("hud/hudPartVisibleState.nut")

let tabsList = [
  { id = "Chat", text = loc("mainmenu/chat"), content = chat }
  { id = "BattleLog", text = loc("options/_Bttl"), content = battleLog }
]
let initialTabId = tabsList[0].id

let isEnabled = Computed(@() isChatPlaceVisible.value && isMultiplayer.value)
let isInteractive = Computed(@() canWriteToChat.value || (cursorVisible.value && !isVisualWeaponSelectorVisible.value))
let isNewMessage = Watched(false)
let isFadingOut = Watched(false)
let isInited = Watched(false)
let isVisible = Computed(@() isEnabled.value && isInited.value
  && (isInteractive.value || isFadingOut.value || isNewMessage.value))

let currentTab = mkWatched(persist, "currentTab", initialTabId)
let currentLog = Computed(function(prev) {
  if (cursorVisible.value || prev == FRP_INITIAL)
    return currentTab.value

  if (canWriteToChat.value || isNewMessage.value)
    return initialTabId

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

let skipAnims = @() [slowFadeOutId, fastFadeOutId, showOutId].each(@(id) anim_skip(id))

function startAnim(animId) {
  skipAnims()
  anim_start(animId)
}

let hideNewMessageDelay = 5
function hideNewMessage() {
  isNewMessage(false)
  if (!isInteractive.value)
    startAnim(slowFadeOutId)
}


lastInputTime.subscribe(function(_) {
  skipAnims()
  isNewMessage(true)
  gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
})

hudLog.subscribe(function(_) {
  if (cursorVisible.value || hudLog.value.len() == 0
      || get_option_auto_show_chat() == 0)
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
  watch = [cursorVisible, currentTab]
  size = FLEX_H
  opacity = cursorVisible.value ? 1 : 0
  children = [
    tabs({
      tabs = tabsList
      currentTab = currentTab.value
      onChange = @(tab) currentTab.update(tab.id)
    })
  ]
  transitions = [{ prop = AnimProp.opacity, duration = fastDuration, easing = OutCubic }]
}

let logsContainer = @() {
  watch = currentLog
  size = FLEX_H
  children = tabsList.findvalue(@(tab) tab.id == currentLog.value)?.content
  animations = logsContainerAnims
}

function init() {
  isInited(true)
}

return @() {
  size = [min(sw(30), shHud(45)), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = isVisible
  children = isVisible.value ? [logsHeader, logsContainer] : []
  onAttach = function() {
    
    
    gui_scene.resetTimeout(0.1, init)
  }
  onDetach = function() {
    gui_scene.clearTimer(init)
    isInited(false)
  }
}
