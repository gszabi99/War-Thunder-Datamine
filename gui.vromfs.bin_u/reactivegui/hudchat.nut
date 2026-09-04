import "%rGui/globals/extWatched.nut" as extWatched
import "%rGui/style/teamColors.nut" as teamColors
import "%rGui/components/hudLog.nut" as hudLog
import "%rGui/hints/hints.nut" as hints
import "string" as string
from "%globalScripts/chatState.nut" import ReputationType
from "%rGui/options/options.nut" import isChatReputationFilterEnabled
from "%appGlobals/missions/missionStateShared.nut" import isModeWithTeams
from "%sqstd/time.nut" import secondsToTimeSimpleString
from "chat" import chat_on_text_update, toggle_ingame_chat, chat_on_send, CHAT_MODE_ALL, CHAT_MODE_TEAM, CHAT_MODE_SQUAD, CHAT_MODE_PRIVATE
from "%rGui/globals/ui_library.nut" import *

let colors = require("%rGui/style/colors.nut")
let textInput =  require("%rGui/components/textInput.nut")
let penalty = require("%rGui/penitentiary/penalty.nut")
let state = require("%rGui/hudChatState.nut")
let hudState = require("%rGui/hudState.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let JB = require("%rGui/control/gui_buttons.nut")

let scrollableData = require("%rGui/components/scrollableData.nut")


let mpChatHint = extWatched("mpChatHint", "")

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
    send_function(form_state.get())
    form_state.set("")
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
    : colors.hud?[colorId] ?? teamColors.get()[colorId]
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
    size = FLEX
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
      textColor = modeColor(state.modeId.get())
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

let getHintText = @() {
  watch = mpChatHint
  children = hints(
    mpChatHint.get() ?? "",
    { font = fontsState.get("small")
      place = "chatHint"
    }.__update(shadow))
}


let chatHint = @() {
  rendObj = ROBJ_9RECT
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  padding = const [hdpx(4), hdpx(8)]
  gap = { size = FLEX }
  color = colors.hud.hudLogBgColor
  children = [
    getHintText
    @() {
      rendObj = ROBJ_TEXT
      watch = state.modeId
      text = getModeNameText(state.modeId.get())
      color = modeColor(state.modeId.get())
      font = fontsState.get("normal")
    }.__update(shadow)
  ]
}


let inputField = @() {
  size = FLEX_H
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
    if (message?.isSquadMember ?? false)
      return teamColors.get().squadColor
    else if (message.team != hudState.playerArmyForHud.get())
      return teamColors.get().teamRedColor
    else
      return teamColors.get().teamBlueColor
  }
  return modeColor(message.mode) ?? colors.white
}


let getSenderColor = function (message) {
  if (message.isMyself)
    return colors.hud.mainPlayerColor
  else if (message?.isSenderSpectator ?? false)
    return colors.hud.spectatorColor
  else if (message.team != hudState.playerArmyForHud.get() || !isModeWithTeams())
    return teamColors.get().teamRedColor
  else if (message?.isSquadMember ?? false)
    return teamColors.get().squadColor
  return teamColors.get().teamBlueColor
}


let messageComponent = @(message) function() {
  local text = ""
  if (message.sender == "") { 
    text = string.format(
      "%s <color=%d>%s</color>",
      secondsToTimeSimpleString(message.time),
      colors.hud.chatActiveInfoColor,
      loc(message.text)
    )
  }
  else {
    local resText = ""
    if (message.isAutomatic)
      resText = message.text
    else if (message.userReputation == ReputationType.REP_BAD && isChatReputationFilterEnabled.get())
      resText = loc("chat/blokedByChatRules")
    else
      resText = message?.filteredText ?? message.text

    text = string.format("%s <Color=%d>[%s] %s:</Color> <Color=%d>%s</Color>",
      secondsToTimeSimpleString(message.time),
      getSenderColor(message),
      getModeNameText(message.mode),
      message.fullName,
      getMessageColor(message),
      resText
    )
  }
  return {
    watch = [teamColors, hudState.playerArmyForHud, isChatReputationFilterEnabled]
    size = FLEX_H
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    lineSpacing = hdpx(2)
    hangingIndent = hdpx(8)
    text = text
    font = fontsState.get("small")
    color = colors.hud.chatTextAllColor
    key = message
    colorTable = teamColors.get()
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
  size = FLEX_H
  flow = FLOW_VERTICAL

  children = [
    inputField
    chatHint
  ]

  onAttach = function() {
    state.inputChatVisible.set(true)
    state.canWriteToChat.subscribe(onInputToggle)
    onInputToggle(true)
   }
   onDetach = function() {
     state.inputChatVisible.set(false)
     state.canWriteToChat.unsubscribe(onInputToggle)
     capture_kb_focus(null)
   }
}


return function () {
  let children = [ logBox ]
  if (state.canWriteToChat.get())
    children.append(bottomPanel)

  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = fpx(8)
    watch = state.canWriteToChat

    children = children
  }
}
