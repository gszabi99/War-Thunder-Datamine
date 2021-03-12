local chat = require("hudChat.nut")
local battleLog = require("hudBattleLog.nut")
local tabs = require("components/tabs.nut")
local frp = require("frp")
local { cursorVisible } = require("hudState.nut")
local { inputEnabled, log, lastInputTime } = require("hudChatState.nut")
local { isMultiplayer } = require("networkState.nut")
local { isChatPlaceVisible } = require("hud/hudPartVisibleState.nut")

local tabsList = [
  { id = "Chat", text = ::loc("mainmenu/chat"), content = chat }
  { id = "BattleLog", text = ::loc("options/_Bttl"), content = battleLog }
]

local isEnabled = ::Computed(@() isChatPlaceVisible.value && isMultiplayer.value)
local isInteractive = ::Computed(@() inputEnabled.value || cursorVisible.value)
local isNewMessage = ::Watched(false)
local isFadingOut = ::Watched(false)
local isInited = ::Watched(false)
local isVisible = ::Computed(@() isEnabled.value && isInited.value
  && (isInteractive.value || isFadingOut.value || isNewMessage.value))

local currentTab = ::Watched(tabsList[0])
local currentLog = ::Computed(function(prev) {
  if (cursorVisible.value || prev == frp.INITIAL)
    return currentTab.value

  if (inputEnabled.value || isNewMessage.value)
    return tabsList[0]

  return prev
})

local showOutId = {}
local fastFadeOutId = {}
local slowFadeOutId = {}
local fastDuration = 0.2
local slowDuration = 5
local opacityAnim = { prop = AnimProp.opacity, easing = OutCubic }

local logsContainerAnims = [
  opacityAnim.__merge({ trigger = showOutId,     from = 0.2, to = 1, duration = fastDuration, play = true })
  opacityAnim.__merge({ trigger = fastFadeOutId, from = 1,   to = 0, duration = fastDuration,
    onEnter = @() isFadingOut(true), onFinish = @() isFadingOut(false), onAbort = @() isFadingOut(false) })
  opacityAnim.__merge({ trigger = fastFadeOutId, from = 0,   to = 0, duration = 1, delay = fastDuration })
  opacityAnim.__merge({ trigger = slowFadeOutId, from = 1,   to = 0, duration = slowDuration,
    onEnter = @() isFadingOut(true), onFinish = @() isFadingOut(false), onAbort = @() isFadingOut(false) })
  opacityAnim.__merge({ trigger = slowFadeOutId, from = 0,   to = 0, duration = 1, delay = slowDuration })
]

local function startAnim(animId) {
  [slowFadeOutId, fastFadeOutId, showOutId].each(@(id) ::anim_skip(id))
  ::anim_start(animId)
}

local hideNewMessageDelay = 5
local function hideNewMessage() {
  isNewMessage(false)
  if (!isInteractive.value)
    startAnim(slowFadeOutId)
}

// force isNewMessage state to prevent log blinking right after sending a message
lastInputTime.subscribe(function(_) {
  isNewMessage(true)
  ::gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
})

log.subscribe(function(_) {
  if (cursorVisible.value || log.value.len() == 0)
    return

  ::gui_scene.resetTimeout(hideNewMessageDelay, hideNewMessage)
  if (isNewMessage.value)
    return

  isNewMessage(true)
  if (inputEnabled.value)
    return

  startAnim(showOutId)
})

isInteractive.subscribe(function(value) {
  if (value) {
    if (isNewMessage.value) {
      ::gui_scene.clearTimer(hideNewMessage)
      isNewMessage(false)
      return
    }
    startAnim(showOutId)
    return
  }

  if (!isNewMessage.value)
    startAnim(fastFadeOutId)
})

local logsHeader = @() {
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

local logsContainer = @() {
  watch = currentLog
  size = [flex(), SIZE_TO_CONTENT]
  children = currentLog.value.content
  animations = logsContainerAnims
}

local function init() {
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
    ::gui_scene.resetTimeout(0.1, init)
  }
  onDetach = function() {
    ::gui_scene.clearTimer(init)
    isInited(false)
  }
}
