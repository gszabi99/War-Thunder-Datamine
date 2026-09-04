import "%rGui/hudChat.nut" as chat
import "%rGui/components/tabs.nut" as tabs
from "%rGui/ctrlsState.nut" import cursorVisible
from "%rGui/hudChatState.nut" import canWriteToChat, hudLog, lastInputTime
from "%rGui/networkState.nut" import isMultiplayer
from "%rGui/hud/hudPartVisibleState.nut" import isChatPlaceVisible, isVisualWeaponSelectorVisible
from "%rGui/hud/actionBarState.nut" import isActionBarVisible, actionBarPos
from "%rGui/hud/dmgIndicatorState.nut" import dmgIndicatorWidth
from "%rGui/hudState.nut" import isSpectatorMode
from "%rGui/style/screenState.nut" import bw
from "chat" import get_option_auto_show_chat
from "%rGui/globals/ui_library.nut" import *

let battleLog = require("%rGui/hudBattleLog.nut")
let killLog = require("%rGui/hudKillLog.nut")
let { activeOrderLogContent } = require("%rGui/activeOrder.nut")

let tabsList = [
  { id = "Chat", text = loc("mainmenu/chat"), content = chat }
  { id = "BattleLog", text = loc("options/_Bttl"), content = battleLog }
  { id = "KillLog", text = loc("battlelog/asInBattle"), content = killLog }
  { id = "Orders", text = loc("itemTypes/orders"), content = activeOrderLogContent }
]
let tabsVisibleInSpectatorOnly = ["KillLog", "Orders"]
let initialTabId = tabsList[0].id

let isEnabled = Computed(@() isChatPlaceVisible.get() && isMultiplayer.get())
let isInteractive = Computed(@() canWriteToChat.get() || (cursorVisible.get() && !isVisualWeaponSelectorVisible.get()))
let isNewMessage = Watched(false)
let isFadingOut = Watched(false)
let isInited = Watched(false)
let isVisible = Computed(@() isSpectatorMode.get() || (isEnabled.get() && isInited.get()
  && (isInteractive.get() || isFadingOut.get() || isNewMessage.get())))

let currentTab = mkWatched(persist, "currentTab", initialTabId)
let currentLog = Computed(function(prev) {
  if (cursorVisible.get() || prev == FRP_INITIAL)
    return currentTab.get()

  if (canWriteToChat.get() || isNewMessage.get())
    return initialTabId

  return prev
})

let showOutId = {}
let fastFadeOutId = {}
let slowFadeOutId = {}
const fastDuration = 0.2
const slowDuration = 5
let opacityAnim = { prop = AnimProp.opacity, easing = OutCubic }

let logsContainerAnims = [
  opacityAnim.__merge({ trigger = showOutId,     from = 0.2, to = 1, duration = fastDuration, play = true })
  opacityAnim.__merge({ trigger = fastFadeOutId, from = 1,   to = 0, duration = fastDuration,
    onEnter = @() isFadingOut.set(true), onFinish = @() isFadingOut.set(false), onAbort = @() isFadingOut.set(false) })
  opacityAnim.__merge({ trigger = fastFadeOutId, from = 0,   to = 0, duration = 1, delay = fastDuration })
  opacityAnim.__merge({ trigger = slowFadeOutId, from = 1,   to = 0, duration = slowDuration,
    onEnter = @() isFadingOut.set(true), onFinish = @() isFadingOut.set(false), onAbort = @() isFadingOut.set(false) })
  opacityAnim.__merge({ trigger = slowFadeOutId, from = 0,   to = 0, duration = 1, delay = slowDuration })
]

let skipAnims = @() [slowFadeOutId, fastFadeOutId, showOutId].each(@(id) anim_skip(id))

function startAnim(animId) {
  skipAnims()
  anim_start(animId)
}

const hideNewMessageDelay = 5
function hideNewMessage() {
  isNewMessage.set(false)
  if (!isInteractive.get())
    startAnim(slowFadeOutId)
}


lastInputTime.subscribe(function(_) {
  skipAnims()
  isNewMessage.set(true)
  gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
})

hudLog.subscribe(function(_) {
  if (cursorVisible.get() || hudLog.get().len() == 0
      || get_option_auto_show_chat() == 0)
    return

  gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
  if (isNewMessage.get())
    return

  isNewMessage.set(true)
  if (canWriteToChat.get())
    return

  startAnim(showOutId)
})

isInteractive.subscribe(function(value) {
  if (value) {
    if (isNewMessage.get()) {
      gui_scene.clearTimer(hideNewMessage)
      isNewMessage.set(false)
      return
    }
    startAnim(showOutId)
    return
  }

  if (!isNewMessage.get())
    startAnim(fastFadeOutId)
})

let logsHeader = @() {
  watch = [cursorVisible, currentTab, isSpectatorMode]
  size = FLEX_H
  opacity = cursorVisible.get() ? 1 : 0
  children = [
    tabs({
      tabs = isSpectatorMode.get() ? tabsList : tabsList.filter(@(a) !tabsVisibleInSpectatorOnly.contains(a.id))
      currentTab = currentTab.get()
      onChange = @(tab) currentTab.set(tab.id)
    })
  ]
  transitions = [{ prop = AnimProp.opacity, duration = fastDuration, easing = OutCubic }]
}

let logsContainer = @() {
  watch = currentLog
  size = FLEX_H
  children = tabsList.findvalue(@(tab) tab.id == currentLog.get())?.content
  animations = logsContainerAnims
}

function init() {
  isInited.set(true)
}

let hudLogsWidth = Computed(@() (isActionBarVisible.get() && isSpectatorMode.get())
  ? min((actionBarPos.get()?[0] ?? sw(100)) - dmgIndicatorWidth.get() - bw.get() - hdpx(20), min(sw(28), shHud(45)))
  : min(sw(28), shHud(45)))

return @() {
  size = [hudLogsWidth.get(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = [isVisible, hudLogsWidth]
  children = isVisible.get() ? [logsHeader, logsContainer] : []
  onAttach = function() {
    
    
    gui_scene.resetTimeout(0.1, init)
  }
  onDetach = function() {
    gui_scene.clearTimer(init)
    isInited.set(false)
  }
}