from "%scripts/dagui_natives.nut" import get_player_army_for_hud, is_menu_state, is_cursor_visible_in_gui
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_mode_with_teams
from "hudState" import is_hud_visible
from "gameplayBinding" import getIsInFlightMenu, isInFlight

let { isPC } = require("%sqstd/platform.nut")
let { g_chat } = require("%scripts/chat/chat.nut")
let { HudBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { enableObjsByTable, select_editbox } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let { onInternalMessage, getLogForBanhammer, chatSystemMessage
} = require("%scripts/chat/mpChatModel.nut")
let { unblockMessageInLog, getMpChatLog, getCurrentModeId, getMaxLogSize,
  validateCurMode, hasEnableChatMode, setModeId, isActiveMpChat, setActiveMpChat,
  getScenes, appendScene, sceneIdxPID, cleanScenesList, findSceneDataByScene,
  findSceneDataByObj, doForAllScenes, canEnableChatInput
} = require("%scripts/chat/mpChatState.nut")
let { getDevoiceMessage } = require("%scripts/penitentiary/penaltyMessages.nut")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let spectatorWatchedHero = require("%scripts/replays/spectatorWatchedHero.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let { is_replay_playing } = require("replays")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { chat_on_text_update, toggle_ingame_chat, chat_on_send, CHAT_MODE_ALL
} = require("chat")
let { get_mplayers_list, GET_MPLAYERS_LIST, get_mplayer_by_userid } = require("mission")
let { USEROPT_AUTO_SHOW_CHAT } = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { registerRespondent } = require("scriptRespondent")
let { defer } = require("dagor.workcycle")
let { g_mp_chat_mode } =require("%scripts/chat/mpChatMode.nut")
let { clanUserTable } = require("%scripts/contacts/contactsManager.nut")
let { isPlayerNickInContacts } = require("%scripts/contacts/contactsChecks.nut")
let { getPlayerFullName } = require("%scripts/contacts/contactsInfo.nut")
let { isEqualSquadId } = require("%scripts/squads/squadState.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { filterMessageText, getPlayerTag } = require("%scripts/chat/chatUtils.nut")
let { isPlayerDedicatedSpectator } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { hasChatReputationFilter, getReputationBlockMessage } = require("%scripts/user/usersReputation.nut")
let { ReputationType } = require("%globalScripts/chatState.nut")

enum mpChatView {
  CHAT
  BATTLE
}

const CHAT_WINDOW_APPEAR_TIME = 0.125
const CHAT_WINDOW_VISIBLE_TIME = 10.0
const CHAT_WINDOW_DISAPPEAR_TIME = 3.0

const senderColor = "@chatSenderFriendColor"
const senderEnemyColor = "@chatSenderEnemyColor"
const senderMeColor = "@chatSenderMeColor"
const senderMySquadColor = "@chatSenderMySquadColor"
const senderSpectatorColor = "@chatSenderSpectatorColor"
const blockedColor = "@chatTextBlockedColor"
const voiceTeamColor = "@chatTextTeamVoiceColor"
const voiceSquadColor = "@chatTextSquadVoiceColor"
const voiceEnemyColor = "@chatTextEnemyVoiceColor"

let mpChatHandlerState = persist("mpChatHandlerState", @() {
  log_text = ""
  chatInputText = ""
})

local last_scene_idx = 0
local isMouseCursorVisible = is_cursor_visible_in_gui()
local visibleTime = 0

local MP_CHAT_PARAMS = {
  selfHideInput = false     
  hiddenInput = false       
  selfHideLog = false       
  isInSpectateMode = false  
  selectInputIfFocusLost = false
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
  if (message.team != get_player_army_for_hud() || !is_mode_with_teams())
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

function isVisibleWithCursor(sceneData) {
  if (!isMouseCursorVisible)
    return false
  let parentObj = sceneData.handler?.scene
  return (parentObj?.isValid() ?? false) && parentObj.isVisible()
}

function updateChatScene(sceneData, dt) {
  if (!sceneData.selfHideLog)
    return

  let isHudVisible = is_hud_visible()
  local transparency = sceneData.transparency
  if (!isHudVisible)
    transparency = 0
  else if (!isActiveMpChat()) {
    if (visibleTime > 0)
      visibleTime -= dt
    else
      transparency -= dt / CHAT_WINDOW_DISAPPEAR_TIME
  }
  else
    transparency += dt / CHAT_WINDOW_APPEAR_TIME
  transparency = clamp(transparency, 0.0, 1.0)

  let transValue = (isHudVisible && isVisibleWithCursor(sceneData)) ? 100 :
    (100.0 * (3.0 - 2.0 * transparency) * transparency * transparency).tointeger()

  let obj = sceneData.scene.findObject("chat_log_tdiv")
  if (checkObj(obj)) {
    obj.transparent = transValue
    sceneData.scene.findObject("chat_log").transparent = transValue
  }

  sceneData.transparency = transparency
}

function updateTabs(sceneData) {
  let visible = !sceneData.selfHideLog || isVisibleWithCursor(sceneData)

  local obj = sceneData.scene.findObject("chat_tabs")
  if (checkObj(obj)) {
    if (obj.getValue() == -1)
      obj.setValue(sceneData.curTab)
    obj.show(visible)
  }
  obj = sceneData.scene.findObject("chat_log_tdiv")
  if (checkObj(obj)) {
    obj.height = visible ? obj?["max-height"] : null
    obj.scrollType = visible ? "" : "hidden"
  }
}

function getCurView(sceneData) {
  return (!sceneData.selfHideLog || isVisibleWithCursor(sceneData)) ? sceneData.curTab : mpChatView.CHAT
}

let isVisibleChatInput = @(sceneData)
  (isActiveMpChat() || !sceneData.selfHideInput)
    && !sceneData.hiddenInput
    && isChatEnabled()
    && getCurView(sceneData) == mpChatView.CHAT
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

function selectChatInputWhenFocusLost(sceneData) {
  if (!sceneData.selectInputIfFocusLost || !sceneData.scene.isVisible()
      || !isVisibleChatInput(sceneData))
    return

  delayedSelectChatEditbox(sceneData)
}

function updateChatLog(sceneData) {
  if (getCurView(sceneData) != mpChatView.CHAT)
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
      chat_mod_accesskey      = show && (sceneData.isInSpectateMode || !is_hud_visible)
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
    if (getTblValue("no_text", prompt, "no") != "yes")
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
  if (active)
    visibleTime = CHAT_WINDOW_VISIBLE_TIME

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

  ::add_text_to_editbox(inputObj,$"{user} ")
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
  if (getCurView(sceneData) != mpChatView.BATTLE)
    return
  let limit = (!sceneData.selfHideLog || isVisibleWithCursor(sceneData)) ? 0 : getMaxLogSize()
  let chat_log = sceneData.scene.findObject("chat_log")
  if (checkObj(chat_log))
    chat_log.setValue(HudBattleLog.getText(0, limit))
}

function updateContent(sceneData) {
  updateChatLog(sceneData)
  updateBattleLog(sceneData)
}

function clearInputChat() {
  mpChatHandlerState.chatInputText = ""
  chat_on_text_update(mpChatHandlerState.chatInputText)
}

function afterLogFormat() {
  updateAllLogs()
  let autoShowOpt = get_option(USEROPT_AUTO_SHOW_CHAT)
  if (autoShowOpt.value) {
    doForAllScenes(function(sceneData) {
      if (!sceneData.scene.isVisible())
        return
      sceneData.transparency = 1.0
      updateChatScene(sceneData, 0.0)
    })
  }
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
  afterLogFormat()
}

let chatHandler = { 
  function onUpdate(obj, dt) {
    let sceneData = findSceneDataByObj(obj)
    if (sceneData)
      updateChatScene(sceneData, dt)
  }

  function onChatIngameRequestActivate(_obj = null) {
    toggle_ingame_chat(true)
  }

  function onChatIngameRequestCancel(_obj = null) {
    toggle_ingame_chat(false)
  }

  function onChatIngameRequestEnter(obj) {
    let editboxObj = checkObj(obj) ? obj.getParent().findObject("chat_input") : null
    if (checkObj(editboxObj) && editboxObj?["on_activate"] == "onChatEntered")
      this.onChatEntered(editboxObj)
  }

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

  function onChatEndEdit() {
    doForAllScenes(selectChatInputWhenFocusLost)
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
    transparency = 0.0
    curTab = mpChatView.CHAT
  })

  let scene = sceneData.scene
  foreach (objName in sceneObjIds) {
    let obj = scene.findObject(objName)
    if (obj)
      obj.setIntProp(sceneIdxPID, sceneData.idx)
  }

  let timerObj = scene.findObject("chat_update")
  if (timerObj && (sceneData?.selfHideInput || sceneData?.selfHideLog)) {
    timerObj.setIntProp(sceneIdxPID, sceneData.idx)
    timerObj.setUserData(chatHandler)
    updateChatScene(sceneData, 0.0)
    updateChatInput(sceneData)
  }

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

::add_text_to_editbox <- function add_text_to_editbox(obj, text) {
  let value = obj.getValue()
  let pos = obj.getIntProp(dagui_propid_get_name_id(":behaviour_edit_position_pos"), -1)
  if (pos > 0 && pos < value.len()) 
    obj.setValue("".concat(value.slice(0, pos), text, value.slice(pos)))
  else
    obj.setValue($"{value}{text}")
}

::add_tags_for_mp_players <- function add_tags_for_mp_players() {
  let tbl = get_mplayers_list(GET_MPLAYERS_LIST, true)
  if (!tbl)
    return

  let res = {}
  foreach (block in tbl)
    if (!block.isBot)
      res[block.name] <- block?.clanTag ?? ""

  if (res.len() > 0)
    clanUserTable.mutate(@(v) v.__update(res))
}

addListenersWithoutEnv({
  function ChangedCursorVisibility(_) {
    isMouseCursorVisible = is_cursor_visible_in_gui()

    doForAllScenes(function(sceneData) {
      updateTabs(sceneData)
      updateContent(sceneData)
      updateChatInput(sceneData)
      updateChatScene(sceneData, 0.0)
    })
  }

  function LoadingStateChange(_) {
    clearInputChat()
  }

  function MpChatInputRequested(params) {
    let activate = getTblValue("activate", params, false)
    if (!activate || !canEnableChatInput())
      return

    foreach (sceneData in getScenes())
      if (getCurView(sceneData) != mpChatView.CHAT)
        if (!sceneData.hiddenInput && checkObj(sceneData.scene) && sceneData.scene.isVisible()) {
          let obj = sceneData.scene.findObject("chat_tabs")
          if (checkObj(obj)) {
            obj.setValue(mpChatView.CHAT)
            break
          }
        }
  }

  MpChatModeChanged = @(_) doForAllScenes(updatePrompt)
  BattleLogMessage = @(_) doForAllScenes(updateBattleLog)
  WatchedHeroSwitched = @(_) makeChatTextFromLog()
  MpChatLogUpdated = @(_) makeChatTextFromLog()
  ContactsBlockStatusUpdated = @(_) makeChatTextFromLog()
  PlayerPenaltyStatusChanged = @(_) checkAndPrintDevoiceMsg()
  MpChatInputChanged = @(p) setInputField(p.str)
})

registerRespondent("is_chat_screen_allowed", function is_chat_screen_allowed() {
  return is_hud_visible() && !is_menu_state()
})

return {
  loadGameChatToObj
  detachGameChatSceneData
  hideGameChatSceneInput = hideChatInput
  getGameChatLogText = @() mpChatHandlerState.log_text
}
