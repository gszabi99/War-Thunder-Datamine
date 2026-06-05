from "%rGui/globals/ui_library.nut" import *

let chat = require("%rGui/hudChat.nut")
let battleLog = require("%rGui/hudBattleLog.nut")
let killLog = require("%rGui/hudKillLog.nut")
let tabs = require("%rGui/components/tabs.nut")
let { get_option_auto_show_chat } = require("chat")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let { canWriteToChat, hudLog, lastInputTime } = require("%rGui/hudChatState.nut")
let { isMultiplayer } = require("%rGui/networkState.nut")
let { isChatPlaceVisible, isVisualWeaponSelectorVisible } = require("%rGui/hud/hudPartVisibleState.nut")
let { isActionBarVisible, actionBarPos } = require("%rGui/hud/actionBarState.nut")
let { dmgIndicatorWidth } = require("%rGui/hud/dmgIndicatorState.nut")
let { isSpectatorMode } = require("%rGui/hudState.nut")
let { bw } = require("%rGui/style/screenState.nut")
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
let fastDuration = 0.2
let slowDuration = 5
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

let hideNewMessageDelay = 5
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
  ? min((actionBarPos.get()?[0] ?? sw(100)) - dmgIndicatorWidth.get() - bw.get() - hdpx(20), min(sw(20), shHud(45)))
  : min(sw(20), shHud(45)))

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