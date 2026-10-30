import "%scripts/time.nut" as time
import "%scripts/user/playerContextMenu.nut" as playerContextMenu
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/daguiUtil.nut" import enableObjsByTable, select_editbox
from "%scripts/chat/mpChatModel.nut" import onInternalMessage, getLogForBanhammer, chatSystemMessage
from "%scripts/chat/mpChatState.nut" import unblockMessageInLog, getMpChatLog, getCurrentModeId, validateCurMode, hasEnableChatMode, setModeId
  , isActiveMpChat, setActiveMpChat, getScenes, appendScene, sceneIdxPID, cleanScenesList, findSceneDataByScene
  , findSceneDataByObj, doForAllScenes, canEnableChatInput
from "%scripts/penitentiary/penaltyMessages.nut" import getDevoiceMessage
from "%scripts/chat/chatStates.nut" import isChatEnabled
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/contacts/contactsChecks.nut" import isPlayerNickInContacts
from "%scripts/contacts/contactsInfo.nut" import getPlayerFullName
from "%scripts/squads/squadState.nut" import isEqualSquadId
from "%scripts/chat/chatUtils.nut" import filterMessageText, getPlayerTag, addTextToEditbox
from "%scripts/matchingRooms/sessionLobbyMembersInfo.nut" import isPlayerDedicatedSpectator
from "%scripts/user/usersReputation.nut" import hasChatReputationFilter, getReputationBlockMessage
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%globalScripts/chatState.nut" import ReputationType
from "%sqstd/platform.nut" import isPC
from "guiMission" import get_player_army_for_hud
from "string" import format
from "replays" import is_replay_playing
from "eventbus" import eventbus_send, eventbus_subscribe
from "chat" import chat_on_text_update, chat_on_send, CHAT_MODE_ALL
from "mission" import get_mplayer_by_userid
from "scriptRespondent" import registerRespondent
from "dagor.workcycle" import defer, deferOnce
from "%globalScripts/externalPlayerListConsts.nut" import *
from "%scripts/dagui_natives.nut" import is_menu_state
from "%scripts/dagui_library.nut" import *
from "%appGlobals/missions/missionStateShared.nut" import isModeWithTeams
from "hudState" import is_hud_visible
from "gameplayBinding" import getIsInFlightMenu, isInFlight

let { g_chat } = require("%scripts/chat/chat.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { g_mp_chat_mode } = require("%scripts/chat/mpChatMode.nut")

enum mpChatView {
  CHAT
  BATTLE
}

const senderColor = "@chatSenderFriendColor"
const senderEnemyColor = "@chatSenderEnemyColor"
const senderMeColor = "@chatSenderMeColor"
const senderMySquadColor = "@chatSenderMySquadColor"
const senderSpectatorColor = "@chatSenderSpectatorColor"
const blockedColor = "@chatTextBlockedColor"
const voiceTeamColor = "@chatTextTeamVoiceColor"
const voiceSquadColor = "@chatTextSquadVoiceColor"
const voiceEnemyColor = "@chatTextEnemyVoiceColor"

let mpChatHandlerState = mkHardPersist("chat.mpChat")("mpChatHandlerState", {
  log_text = ""
  chatInputText = ""
})

local last_scene_idx = 0

local MP_CHAT_PARAMS = {
  selfHideInput = false     
  hiddenInput = false       
  isInSpectateMode = false  
}

function isSenderMe(message) {
  return is_replay_playing() ?
    message.sender == spectatorWatchedHero.name :
    message.isMyself
}

function isSenderInMySquad(message) {
  if (is_replay_playing()) {
    if (message?.uid == null)
      return false
    let player = get_mplayer_by_userid(message.uid)
    return isEqualSquadId(spectatorWatchedHero.squadId, player?.squadId)
  }
  return g_squad_manager.isInMySquadById(message.uid)
}

function getSenderColor(message) {
  if (isSenderMe(message))
    return senderMeColor
  if (isPlayerDedicatedSpectator(message.sender))
    return senderSpectatorColor
  if (message.team != get_player_army_for_hud() || !isModeWithTeams())
    return senderEnemyColor
  if (isSenderInMySquad(message))
    return senderMySquadColor
  return senderColor
}

function getMessageColor(message) {
  if (message.isBlocked)
    return blockedColor
  if (message.isAutomatic) {
    if (isSenderInMySquad(message))
      return voiceSquadColor
    if (message.team != get_player_army_for_hud())
      return voiceEnemyColor

    return voiceTeamColor
  }
  return g_mp_chat_mode.getModeById(message.mode).textColor
}


function formatMessageText(message, text) {
  let timeString = time.secondsToString(message.time, false)
  let userColor = getSenderColor(message)
  let msgColor = getMessageColor(message)
  let clanTag = getPlayerTag(message.sender)
  let fullName = getPlayerFullName(
    getPlayerName(message.sender),
    clanTag
  )
  message.userColor = userColor
  message.msgColor = msgColor
  message.clanTag = clanTag
  return format(
    "%s <Color=%s>[%s] <Link=PL_%s>%s:</Link></Color> <Color=%s>%s</Color>",
    timeString,
    userColor,
    g_mp_chat_mode.getModeById(message.mode).getNameText(),
    message.sender,
    fullName,
    msgColor,
    text
  )
}

function getTextFromMessage(message, isReputationFilterEnabled) {
  if (message.sender == "") {
    let timeString = time.secondsToString(message.time, false)
    return $"{timeString} <color=@chatActiveInfoColor>{loc(message.text)}</color>"
  }

  if (message.isAutomatic)
    return formatMessageText(message, message.text)

  if (!message.isMyself && isPlayerNickInContacts(message.sender, EPL_BLOCKLIST))
    return formatMessageText(message, g_chat.makeBlockedMsg(message.text))

  if (!message.isMyself && isReputationFilterEnabled
      && message.userReputation == ReputationType.REP_BAD)
    return getReputationBlockMessage()

  return formatMessageText(message, filterMessageText(message.text, message.isMyself))
}

function updateTabs(sceneData) {
  local obj = sceneData.scene.findObject("chat_tabs")
  if (checkObj(obj)) {
    if (obj.getValue() == -1)
      obj.setValue(sceneData.curTab)
    obj.show(true)
  }
  obj = sceneData.scene.findObject("chat_log_tdiv")
  if (checkObj(obj)) {
    obj.height = obj?["max-height"]
    obj.scrollType = ""
  }
}

let isVisibleChatInput = @(sceneData)
  (isActiveMpChat() || !sceneData.selfHideInput)
    && !sceneData.hiddenInput
    && isChatEnabled()
    && sceneData.curTab == mpChatView.CHAT
    && hasEnableChatMode()

function selectChatEditbox(obj) {
  if (!isInFlight() || getIsInFlightMenu())
    select_editbox(obj)
  else
    obj.select()
}

function delayedSelectChatEditbox(sceneData) {
  let obj = sceneData.scene.findObject("chat_input")
  if (!(obj?.isValid() ?? false))
    return

  defer(function() {
    if (!(obj?.isValid() ?? false))
      return

    obj.setValue(mpChatHandlerState.chatInputText)
    if (sceneData?.isInputSelected ?? true)
      selectChatEditbox(obj)
  })
}

function updateChatLog(sceneData) {
  if (sceneData.curTab != mpChatView.CHAT)
    return
  let chat_log = sceneData.scene.findObject("chat_log")
  if (chat_log)
    chat_log.setValue(mpChatHandlerState.log_text)
}

function updateAllLogs() {
  doForAllScenes(updateChatLog)
}

function updateChatInput(sceneData) {
  if (isActiveMpChat() && !sceneData.scene.isVisible())
    return

  let show = isVisibleChatInput(sceneData)
  let scene = sceneData.scene

  showObjectsByTable(scene, {
      chat_input_back           = show
      chat_input_placeholder    = !show && canEnableChatInput()
      show_chat_input_accesskey = !show && sceneData.isInSpectateMode
  })
  enableObjsByTable(scene, {
      chat_input              = show
      btn_send                = show
      chat_prompt             = show && g_mp_chat_mode.getNextMode(getCurrentModeId()) != null
      chat_mod_accesskey      = show && sceneData.isInSpectateMode
  })
  if (show && sceneData.scene.isVisible())
    delayedSelectChatEditbox(sceneData)
}

function showPlayerRClickMenu(playerName) {
  playerContextMenu.showMenu(null, null, {
    playerName = playerName
    isMPChat = true
    chatLog = getLogForBanhammer()
    canComplain = true
  })
}

function updatePrompt(sceneData) {
  let scene = sceneData.scene
  let curMode = g_mp_chat_mode.getModeById(getCurrentModeId())
  let prompt = scene.findObject("chat_prompt")
  if (prompt) {
    prompt.chatMode = curMode.name
    if ((prompt?.no_text ?? "no") != "yes")
      prompt.setValue(curMode.getNameText())
    if ("tooltip" in prompt)
      prompt.tooltip = "".concat(loc("chat/to"), loc("ui/colon"), curMode.getDescText())
  }

  let input = scene.findObject("chat_input")
  if (input)
    input.chatMode = curMode.name

  let hint = scene.findObject("chat_hint")
  if (hint)
    hint.setValue(g_mp_chat_mode.getChatHint())
}

function enableChatInput(active) {
  if (active == isActiveMpChat())
    return

  setActiveMpChat(active)
  doForAllScenes(updateChatInput)
  broadcastEvent("MpChatInputToggled", { active })
  handlersManager.updateControlsAllowMask()
}

function hideChatInput(sceneData, value) {
  if (value && isActiveMpChat())
    enableChatInput(false)

  sceneData.hiddenInput = value
  updateChatInput(sceneData)
}

function addNickToEdit(sceneData, user) {
  broadcastEvent("MpChatInputRequested", { activate = true })

  let inputObj = sceneData.scene.findObject("chat_input")
  if (!inputObj)
    return

  addTextToEditbox(inputObj,$"{user} ")
  selectChatEditbox(inputObj)
}

function onChatLink(obj, link, lclick) {
  let sceneData = findSceneDataByObj(obj)
  if ((link && link.len() < 4) || sceneData.hiddenInput)
    return

  if (link.slice(0, 3) == "PL_") {
    if (lclick) {
      if (sceneData && !sceneData?.isInSpectateMode)
        addNickToEdit(sceneData, link.slice(3))
    }
    else
      showPlayerRClickMenu(link.slice(3))
  }
  else if (g_chat.checkBlockedLink(link)) {
    mpChatHandlerState.log_text = g_chat.revealBlockedMsg(mpChatHandlerState.log_text, link)

    let pureMessage = g_chat.convertLinkToBlockedMsg(link)
    unblockMessageInLog(pureMessage)
    updateAllLogs()
  }
}

function setInputField(str) {
  doForAllScenes(function(sceneData) {
    let edit = sceneData.scene.findObject("chat_input")
    if (edit)
      edit.setValue(str)
  })
}

function checkAndPrintDevoiceMsg() {
  local devoiceMsgText = getDevoiceMessage()
  if (devoiceMsgText) {
    devoiceMsgText = $"<color=@chatInfoColor>{devoiceMsgText}</color>"
    onInternalMessage(devoiceMsgText)
    setInputField("")
  }
  return devoiceMsgText != null
}

function updateBattleLog(sceneData) {
  if (sceneData.curTab != mpChatView.BATTLE || !sceneData.scene.isVisible())
    return
  let chat_log = sceneData.scene.findObject("chat_log")
  if (checkObj(chat_log))
    chat_log.setValue(HudBattleLog.getText(0))
}

function updateContent(sceneData) {
  updateChatLog(sceneData)
  updateBattleLog(sceneData)
}

function updateAllBattleLogs() {
  doForAllScenes(updateBattleLog)
}

function clearInputChat() {
  mpChatHandlerState.chatInputText = ""
  chat_on_text_update(mpChatHandlerState.chatInputText)
}

function makeChatTextFromLog() {
  let logObj = getMpChatLog()
  let formattedLogs = []
  let isReputationFilterEnabled = hasChatReputationFilter()
  foreach (logMsg in logObj) {
    let text = getTextFromMessage(logMsg, isReputationFilterEnabled)
    if (text != "")
      formattedLogs.append(text)
  }
  mpChatHandlerState.log_text = "\n".join(formattedLogs)
  updateAllLogs()
}

let chatHandler = { 
  function onChatEntered(obj) {
    let sceneData = findSceneDataByObj(obj)
    if (!sceneData)
      return

    if (sceneData.handler && ("onEmptyChatEntered" in sceneData.handler) && obj && obj.getValue() == "")
      sceneData.handler.onEmptyChatEntered()
    else {
      this.onChatSend()
      if (sceneData.handler && ("onChatEntered" in sceneData.handler))
        sceneData.handler.onChatEntered()
    }
    enableChatInput(false)
    eventbus_send("setInputEnable", { value = false })
  }

  function onChatCancel(obj) {
    let sceneData = findSceneDataByObj(obj)
    if (sceneData && sceneData.handler && ("onChatCancel" in sceneData.handler))
      sceneData.handler.onChatCancel()
    enableChatInput(false)
    eventbus_send("setInputEnable", { value = false })
  }

  function onChatSend() {
    if (checkAndPrintDevoiceMsg())
      return
    chat_on_send()
  }

  function onChatChanged(obj) {
    mpChatHandlerState.chatInputText = obj.getValue()
    chat_on_text_update(mpChatHandlerState.chatInputText)
  }

  function onChatWrapAttempt() {
    
  }

  function onChatTabChange(obj) {
    let sceneData = findSceneDataByObj(obj)
    if (sceneData) {
      sceneData.curTab = obj.getValue()
      updateContent(sceneData)
      updateChatInput(sceneData)
    }
  }

  function onChatMode() {
    setModeId(g_mp_chat_mode.getNextMode(getCurrentModeId()) ?? CHAT_MODE_ALL)
  }

  function onShowChatInput() {
    enableChatInput(true)
  }

  function onChatLinkClick(obj, _itype, link)  { onChatLink(obj, link, isPC) }
  function onChatLinkRClick(obj, _itype, link) { onChatLink(obj, link, false) }
}

let sceneObjIds = [
  "chat_prompt_place",
  "chat_input",
  "chat_log",
  "chat_tabs"
]

function addScene(newScene, handler, params) {
  let sceneData = MP_CHAT_PARAMS.__merge(params).__update({
    idx = ++last_scene_idx
    scene = newScene
    handler = handler
    curTab = mpChatView.CHAT
  })

  let scene = sceneData.scene
  foreach (objName in sceneObjIds) {
    let obj = scene.findObject(objName)
    if (obj)
      obj.setIntProp(sceneIdxPID, sceneData.idx)
  }

  if (sceneData.selfHideInput)
    updateChatInput(sceneData)

  updateTabs(sceneData)
  updateContent(sceneData)
  updatePrompt(sceneData)
  appendScene(sceneData)
  validateCurMode()
  handlersManager.updateControlsAllowMask()
  return sceneData
}

function loadScene(obj, chatBlk, handler, params = MP_CHAT_PARAMS) {
  if (!checkObj(obj))
    return null

  cleanScenesList()
  let sceneData = findSceneDataByScene(obj)
  if (sceneData) {
    sceneData.handler = handler
    return sceneData
  }

  obj.getScene().replaceContent(obj, chatBlk, chatHandler)
  return addScene(obj, handler, params)
}

function loadGameChatToObj(obj, chatBlk, handler, p = MP_CHAT_PARAMS) {
  return loadScene(obj, chatBlk, handler, MP_CHAT_PARAMS.__merge(p))
}

function detachGameChatSceneData(sceneData) {
  sceneData.scene = null
  cleanScenesList()
  handlersManager.updateControlsAllowMask()
}

function enable_game_chat_input(data) { 
  let { value } = data
  if (value)
    broadcastEvent("MpChatInputRequested")

  if (value && !hasEnableChatMode()) {
    chatSystemMessage(loc("chat/no_chat"))
    return
  }
  if (!value || canEnableChatInput())
    enableChatInput(value)
}

eventbus_subscribe("enable_game_chat_input", @(p) enable_game_chat_input(p))

addListenersWithoutEnv({
  function ChangedCursorVisibility(_) {
    doForAllScenes(function(sceneData) {
      updateTabs(sceneData)
      updateContent(sceneData)
      updateChatInput(sceneData)
    })
  }

  function LoadingStateChange(_) {
    clearInputChat()
  }

  function MpChatInputRequested(params) {
    let activate = (params?.activate ?? false)
    if (!activate || !canEnableChatInput())
      return

    foreach (sceneData in getScenes())
      if (sceneData.curTab != mpChatView.CHAT)
        if (!sceneData.hiddenInput && checkObj(sceneData.scene) && sceneData.scene.isVisible()) {
          let obj = sceneData.scene.findObject("chat_tabs")
          if (checkObj(obj)) {
            obj.setValue(mpChatView.CHAT)
            break
          }
        }
  }

  MpChatModeChanged = @(_) doForAllScenes(updatePrompt)
  BattleLogMessage = @(_) deferOnce(updateAllBattleLogs)
  WatchedHeroSwitched = @(_) makeChatTextFromLog()
  MpChatLogUpdated = @(_) makeChatTextFromLog()
  ContactsBlockStatusUpdated = @(_) makeChatTextFromLog()
  PlayerPenaltyStatusChanged = @(_) checkAndPrintDevoiceMsg()
  MpChatInputChanged = @(p) setInputField(p.str)
})

registerRespondent("is_chat_screen_allowed", function is_chat_screen_allowed() {
  return is_hud_visible() && !is_menu_state()
})

return freeze({
  loadGameChatToObj
  detachGameChatSceneData
  hideGameChatSceneInput = hideChatInput
  getGameChatLogText = @() mpChatHandlerState.log_text
})
