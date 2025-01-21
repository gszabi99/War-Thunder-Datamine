from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")
let string = require("string")
let colors = require("style/colors.nut")
let teamColors = require("style/teamColors.nut")
let textInput =  require("components/textInput.nut")
let penalty = require("penitentiary/penalty.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let state = require("hudChatState.nut")
let hudState = require("hudState.nut")
let hudLog = require("components/hudLog.nut")
let fontsState = require("style/fontsState.nut")
let hints = require("hints/hints.nut")
let JB = require("%rGui/control/gui_buttons.nut")
let { chat_on_text_update, toggle_ingame_chat, chat_on_send,
  CHAT_MODE_ALL, CHAT_MODE_TEAM, CHAT_MODE_SQUAD, CHAT_MODE_PRIVATE
} = require("chat")
let scrollableData = require("components/scrollableData.nut")

let chatModeConfig = {
  [CHAT_MODE_ALL] = {
    name = "all"
    colorId = "chatTextAllColor"
  },
  [CHAT_MODE_TEAM] = {
    name = "team"
    colorId = "chatTextTeamColor"
  },
  [CHAT_MODE_SQUAD] = {
    name = "squad"
    colorId = "chatTextSquadColor"
  },
  [CHAT_MODE_PRIVATE] = {
    name = "private"
    textColor = "chatTextPrivateColor"
  }
}

function makeInputField(form_state, send_function) {
  function send () {
    send_function(form_state.value)
    form_state.update("")
  }
  return function (text_input_ctor) {
    return text_input_ctor(form_state, send)
  }
}


function chatBase(log_state, send_message_fn) {
  let chatMessageState = Watched("")
  let logInstance = scrollableData.make(log_state)

  return {
    form = chatMessageState
    state = log_state
    inputField = makeInputField(chatMessageState, send_message_fn)
    data = logInstance.data
    scrollHandler = logInstance.scrollHandler
  }
}


let chatLog = state.hudLog


function modeColor(mode) {
  let colorId = chatModeConfig?[mode].colorId
  return colorId == null ? colors.white
    : colors.hud?[colorId] ?? teamColors.value[colorId]
}

function getModeNameText(mode) {
  let name = chatModeConfig?[mode].name
  return name == null ? "" : loc($"chat/{name}")
}

function sendFunc(_message) {
  if (!penalty.isDevoiced()) {
    chat_on_send()
  }
  else {
    state.pushSystemMessage(penalty.getDevoiceDescriptionText())
  }
}


let chat = chatBase(chatLog, sendFunc)
state.input.subscribe(function (new_val) {
  chat.form.update(new_val)
})


function chatInputCtor(field, send) {
  let restoreControle = function () {
    toggle_ingame_chat(false)
  }

  let onReturn = function () {
    send()
    restoreControle()
  }

  let onEscape = function () {
    restoreControle()
  }

  let options = {
    key = "chatInput"
    font = fontsState.get("small")
    margin = 0
    padding = [fpx(8), fpx(8), 0, fpx(8)]
    size = flex()
    valign = ALIGN_BOTTOM
    borderRadius = 0
    valignText = ALIGN_CENTER
    textmargin = [fpx(5),  fpx(8)]
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
    onChange = @(new_val) chat_on_text_update(new_val)
    function onImeFinish(applied) {
      if (applied)
        onReturn()
    }
  }
  return textInput.hud(field, options)
}

let shadow = {
  fontFx = FFT_SHADOW
  fontFxColor = 0xFF000000
  fontFxFactor = 20
  fontFxOffsX = hdpx(1)
  fontFxOffsY = hdpx(1)
}

function getHintText() {
  let config = hints(
    cross_call.mp_chat_mode.getChatHint() ?? "",
    { font = fontsState.get("small")
      place = "chatHint"
    }.__update(shadow))
  return config
}


let chatHint = @() {
  rendObj = ROBJ_9RECT
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = [hdpx(4), hdpx(8)]
  gap = { size = flex() }
  color = colors.hud.hudLogBgColor
  children = [
    getHintText
    @() {
      rendObj = ROBJ_TEXT
      watch = state.modeId
      text = getModeNameText(state.modeId.value)
      color = modeColor(state.modeId.value)
      font = fontsState.get("normal")
    }.__update(shadow)
  ]
}


let inputField = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = state.modeId
  children = [
    chat.inputField(chatInputCtor)
  ]
}


let getMessageColor = function(message) {
  if (message.isBlocked)
    return colors.menu.chatTextBlockedColor
  if (message.isAutomatic) {
    if (cross_call.squad_manger.isInMySquadById(message.uid))
      return teamColors.value.squadColor
    else if (message.team != hudState.playerArmyForHud.value)
      return teamColors.value.teamRedColor
    else
      return teamColors.value.teamBlueColor
  }
  return modeColor(message.mode) ?? colors.white
}


let getSenderColor = function (message) {
  if (message.isMyself)
    return colors.hud.mainPlayerColor
  else if (cross_call.isPlayerDedicatedSpectator(message.sender))
    return colors.hud.spectatorColor
  else if (message.team != hudState.playerArmyForHud.value || !cross_call.is_mode_with_teams())
    return teamColors.value.teamRedColor
  else if (cross_call.squad_manger.isInMySquadById(message.uid))
    return teamColors.value.squadColor
  return teamColors.value.teamBlueColor
}


let messageComponent = @(message) function() {
  local text = ""
  if (message.sender == "") { //system
    text = string.format(
      "%s <color=%d>%s</color>",
      secondsToTimeSimpleString(message.time),
      colors.hud.chatActiveInfoColor,
      loc(message.text)
    )
  }
  else {
    text = string.format("%s <Color=%d>[%s] %s:</Color> <Color=%d>%s</Color>",
      secondsToTimeSimpleString(message.time),
      getSenderColor(message),
      getModeNameText(message.mode),
      message.fullName,
      getMessageColor(message),
      message.isAutomatic
        ? message.text
        : cross_call.filter_chat_message(message.text, message.isMyself) ?? message.text
    )
  }
  return {
    watch = [teamColors, hudState.playerArmyForHud]
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    lineSpacing = hdpx(2)
    hangingIndent = hdpx(8)
    text = text
    font = fontsState.get("small")
    color = colors.hud.chatTextAllColor
    key = message
    colorTable = teamColors.value
  }
}

let logBox = hudLog({
  logComponent = chat
  messageComponent = messageComponent
})

let onInputToggle = function (enable) {
  if (enable)
    capture_kb_focus(chat.form)
  else
    capture_kb_focus(null)
}

let bottomPanel = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL

  children = [
    inputField
    chatHint
  ]

  onAttach = function() {
    state.inputChatVisible(true)
    state.canWriteToChat.subscribe(onInputToggle)
    onInputToggle(true)
   }
   onDetach = function() {
     state.inputChatVisible(false)
     state.canWriteToChat.unsubscribe(onInputToggle)
     capture_kb_focus(null)
   }
}


return function () {
  let children = [ logBox ]
  if (state.canWriteToChat.value)
    children.append(bottomPanel)

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = fpx(8)
    watch = state.canWriteToChat

    children = children
  }
}
