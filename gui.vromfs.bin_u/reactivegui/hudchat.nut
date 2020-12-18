local colors = require("style/colors.nut")
local transition = require("style/hudTransition.nut")
local teamColors = require("style/teamColors.nut")
local chatBase = require("daRg/components/chat.nut")
local textInput =  require("components/textInput.nut")
local penalty = require("penitentiary/penalty.nut")
local {secondsToTimeSimpleString} = require("std/time.nut")
local state = require("hudChatState.nut")
local hudState = require("hudState.nut")
local hudLog = require("components/hudLog.nut")
local fontsState = require("style/fontsState.nut")
local hints = require("hints/hints.nut")
local JB = require("reactiveGui/control/gui_buttons.nut")

local chatLog = state.log


local function modeColor(mode) {
  local colorName = ::cross_call.mp_chat_mode.getModeColorName(mode)
  return colors.hud?[colorName] ?? teamColors.value[colorName]
}


local function sendFunc(message) {
  if (!penalty.isDevoiced()) {
    ::chat_on_send()
  } else {
    state.pushSystemMessage(penalty.getDevoiceDescriptionText())
  }
}


local chat = chatBase(chatLog, sendFunc)
state.input.subscribe(function (new_val) {
  chat.form.update(new_val)
})


local function chatInputCtor(field, send) {
  local restoreControle = function () {
    ::toggle_ingame_chat(false)
  }

  local onReturn = function () {
    send()
    restoreControle()
  }

  local onEscape = function () {
    restoreControle()
  }

  local handlers = {
    onReturn = onReturn
    onEscape = onEscape
    onChange = function (new_val) {
      ::chat_on_text_update(new_val)
    }
    onImeFinish = function onImeFinish(applied) {
      if (applied)
        onReturn()
    }
  }
  local options = {
    key = "chatInput"
    font = fontsState.get("small")
    margin = 0
    padding = [::fpx(8), ::fpx(8), 0, ::fpx(8)]
    size = flex()
    valign = ALIGN_BOTTOM
    borderRadius = 0
    valignText = ALIGN_CENTER
    textmargin = [::fpx(5) , ::fpx(8)]
    hotkeys = [
      [ $"{JB.A} | J:RT", onReturn ],
      [ $"{JB.B}", onEscape ],
    ]
    colors = {
      backGroundColor = colors.hud.hudLogBgColor
      textColor = modeColor(state.modeId.value)
    }
  }
  return textInput.hud(field, options, handlers)
}


local function getHintText() {
  local config = hints(
    ::cross_call.mp_chat_mode.getChatHint(),
    { font = fontsState.get("small")
      place = "chatHint"
    })
  return config
}


local chatHint = @() {
  rendObj = ROBJ_9RECT
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = [::fpx(8)]
  gap = { size = flex() }
  color = colors.hud.hudLogBgColor
  children = [
    getHintText
    @() {
      rendObj = ROBJ_DTEXT
      watch = state.modeId
      text = ::cross_call.mp_chat_mode.getModeNameText(state.modeId.value)
      color = modeColor(state.modeId.value)
      font = fontsState.get("normal")
    }
  ]
}


local inputField = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = state.modeId
  children = [
    chat.inputField(chatInputCtor)
  ]
}


local getMessageColor = function(message) {
  if (message.isBlocked)
    return colors.menu.chatTextBlockedColor
  if (message.isAutomatic) {
    if (::cross_call.squad_manger.isInMySquad(message.sender))
      return teamColors.value.squadColor
    else if (message.team != hudState.playerArmyForHud.value)
      return teamColors.value.teamRedColor
    else
      return teamColors.value.teamBlueColor
  }
  return modeColor(message.mode) ?? colors.white
}


local getSenderColor = function (message) {
  if (message.isMyself)
    return colors.hud.mainPlayerColor
  else if (::cross_call.isPlayerDedicatedSpectator(message.sender))
    return colors.hud.spectatorColor
  else if (message.team != hudState.playerArmyForHud.value || !::cross_call.is_mode_with_teams())
    return teamColors.value.teamRedColor
  else if (::cross_call.squad_manger.isInMySquad(message.sender))
    return teamColors.value.squadColor
  return teamColors.value.teamBlueColor
}


local messageComponent = @(message) function() {
  local text = ""
  if (message.sender == "") { //systme
    text = ::string.format(
      "<color=%d>%s</color>",
      colors.hud.chatActiveInfoColor,
      ::loc(message.text)
    )
  } else {
    text = ::string.format("%s <Color=%d>[%s] %s:</Color> <Color=%d>%s</Color>",
      secondsToTimeSimpleString(message.time),
      getSenderColor(message),
      ::cross_call.mp_chat_mode.getModeNameText(message.mode),
      ::cross_call.platform.getPlayerName(message.sender),
      getMessageColor(message),
      ::cross_call.filter_chat_message(message.text, message.isMyself)
    )
  }
  return {
    watch = [teamColors, hudState.playerArmyForHud]
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = text
    font = fontsState.get("small")
    key = message
  }
}


local inputEnabled = state.inputEnabled
local cursorVisible = hudState.cursorVisible
local chatLogVisible = keepref(::Computed(@() inputEnabled.value || cursorVisible.value))
local isVisible = ::Watched(chatLogVisible.value)
chatLogVisible.subscribe(@(v) isVisible(v))
local onInputTriggered = @(new_val) isVisible(new_val || hudState.cursorVisible.value)

local logBox = hudLog({
  visibleState = isVisible
  logComponent = chat
  messageComponent = messageComponent
  onAttach = function (elem) { state.inputEnabled.subscribe(onInputTriggered) }
  onDetach = function (elem) { state.inputEnabled.unsubscribe(onInputTriggered) }
})


local onInputToggle = function (enable) {
  if (enable)
    ::set_kb_focus(chatInputCtor)
  else
    ::set_kb_focus(null)
}

local bottomPanel = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  opacity = state.inputEnabled.value ? 1.0 : 0.0

  children = [
    inputField
    chatHint
  ]

  onAttach = function (elem) {
    state.inputEnabled.subscribe(onInputToggle)
    if (state.inputEnabled.value)
      ::gui_scene.setInterval(0.1,
        function() {
          ::gui_scene.clearTimer(callee())
          onInputToggle(true)
        })
   }
   onDetach = function (elem) {
     state.inputEnabled.unsubscribe(onInputToggle)
     ::set_kb_focus(null)
   }
   transitions = [transition()]
}


return function () {
  local children = [ logBox ]
  if (state.inputEnabled.value)
    children.append(bottomPanel)

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = ::fpx(8)
    watch = state.inputEnabled

    children = children
  }
}
