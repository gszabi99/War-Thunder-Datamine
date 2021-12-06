local colors = require("style/colors.nut")
local teamColors = require("style/teamColors.nut")
local textInput =  require("components/textInput.nut")
local penalty = require("penitentiary/penalty.nut")
local {secondsToTimeSimpleString} = require("std/time.nut")
local state = require("hudChatState.nut")
local hudState = require("hudState.nut")
local hudLog = require("components/hudLog.nut")
local fontsState = require("style/fontsState.nut")
local hints = require("hints/hints.nut")
local JB = require("reactiveGui/control/gui_buttons.nut")

local scrollableData = require("daRg/components/scrollableData.nut")


local function makeInputField(form_state, send_function) {
  local function send () {
    send_function(form_state.value)
    form_state.update("")
  }
  return function (text_input_ctor) {
    return text_input_ctor(form_state, send)
  }
}


local function chatBase(log_state, send_message_fn) {
  local chatMessageState = Watched("")
  local logInstance = scrollableData.make(log_state)

  return {
    form = chatMessageState
    state = log_state
    inputField = makeInputField(chatMessageState, send_message_fn)
    data = logInstance.data
    scrollHandler = logInstance.scrollHandler
  }
}


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
    imeOpenJoyBtn = $"{JB.A}"
    hotkeys = [
      [ $"{JB.B}", onEscape ],
    ]
    colors = {
      backGroundColor = colors.hud.hudLogBgColor
      textColor = modeColor(state.modeId.value)
    }

    onReturn
    onEscape
    onChange = @(new_val) ::chat_on_text_update(new_val)
    function onImeFinish(applied) {
      if (applied)
        onReturn()
    }
  }
  return textInput.hud(field, options)
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
      message.isAutomatic
        ? message.text
        : ::cross_call.filter_chat_message(message.text, message.isMyself)
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

local logBox = hudLog({
  logComponent = chat
  messageComponent = messageComponent
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

  children = [
    inputField
    chatHint
  ]

  onAttach = function (elem) {
    state.inputChatVisible(true)
    state.inputEnabled.subscribe(onInputToggle)
    if (state.inputEnabled.value)
      ::gui_scene.setInterval(0.1,
        function() {
          ::gui_scene.clearTimer(callee())
          onInputToggle(true)
        })
   }
   onDetach = function (elem) {
     state.inputChatVisible(false)
     state.inputEnabled.unsubscribe(onInputToggle)
     ::set_kb_focus(null)
   }
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
