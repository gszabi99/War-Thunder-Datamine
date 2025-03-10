from "%scripts/dagui_library.nut" import *

let { CHAT_MODE_TEAM, chat_set_mode } = require("chat")
let { eventbus_send } = require("eventbus")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let { getMaxRoomMsgAmount } = require("%scripts/chat/chatStorage.nut")
let { g_mp_chat_mode } =require("%scripts/chat/mpChatMode.nut")

let mpChatState = persist("mpChatState", @() {
  log = [],
  currentModeId = CHAT_MODE_TEAM,
  maxLogSize = 20,
  isActive = false 
})

let scenes = [] 
local hasEnableChatMode = false
local modeInited = false

let sceneIdxPID = dagui_propid_add_name_id("sceneIdx")

let setModeId = @(mpChatModeId) chat_set_mode(mpChatModeId, "")

function validateCurModeImpl() {
  if (!modeInited) {
    modeInited = true
    hasEnableChatMode = false
    
    if (g_mp_chat_mode.SQUAD.isEnabled()) {
      hasEnableChatMode = true
      setModeId(g_mp_chat_mode.SQUAD.id)
      return
    }
  }

  if (g_mp_chat_mode.getModeById(mpChatState.currentModeId).isEnabled()) {
    hasEnableChatMode = true
    return
  }

  foreach (mode in g_mp_chat_mode.types)
    if (mode.isEnabled()) {
      hasEnableChatMode = true
      setModeId(mode.id)
      return
    }
}

function validateCurMode() {
  validateCurModeImpl()
  eventbus_send("setHasEnableChatMode", { hasEnableChatMode })
}

function initMpChatStates() {
  mpChatState.maxLogSize = getMaxRoomMsgAmount()
  validateCurMode()
}

function getMpChatLog() {
  return mpChatState.log
}

function setMpChatLog(l) {
  mpChatState.log = l
}

function unblockMessageInLog(text) {
  foreach (message in mpChatState.log) {
    if (message.text == text) {
      message.isBlocked = false
      return
    }
  }
}

function addMessageToLog(message) {
  if (mpChatState.log.len() > mpChatState.maxLogSize) {
    mpChatState.log.remove(0)
  }
  mpChatState.log.append(message)
}

function onChatClear() {
  mpChatState.log.clear()
  eventbus_send("mpChatClear", {})
}

function canEnableChatInput() {
  if (!isChatEnabled() || !hasEnableChatMode)
    return false
  foreach (sceneData in scenes)
    if (!sceneData.hiddenInput && checkObj(sceneData.scene) && sceneData.scene.isVisible())
      return true
  return false
}

function getMpChatControlsAllowMask() {
  return mpChatState.isActive && canEnableChatInput()
    ? CtrlsInGui.CTRL_IN_MP_CHAT | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE | CtrlsInGui.CTRL_ALLOW_MP_CHAT
    : CtrlsInGui.CTRL_ALLOW_FULL
}

function cleanScenesList() {
  for (local i = scenes.len() - 1; i >= 0; i--)
    if (!checkObj(scenes[i].scene))
      scenes.remove(i)
}

function findSceneDataByScene(scene) {
  foreach (sceneData in scenes)
    if (checkObj(sceneData.scene) && sceneData.scene.isEqual(scene))
      return sceneData
  return null
}

function findSceneDataByObj(obj) {
  let idx = obj.getIntProp(sceneIdxPID, -1)
  foreach (i, sceneData in scenes)
    if (sceneData.idx == idx)
      if (checkObj(sceneData.scene))
        return sceneData
      else {
        scenes.remove(i)
        break
      }
  return null
}

function doForAllScenes(func) {
  for (local i = scenes.len() - 1; i >= 0; i--)
    if (checkObj(scenes[i].scene))
      func(scenes[i])
    else
      scenes.remove(i)
}

addListenersWithoutEnv({
  LoadingStateChange = @(_) modeInited = false
})

return {
  sceneIdxPID
  initMpChatStates
  getMpChatControlsAllowMask
  getMpChatLog
  setMpChatLog
  unblockMessageInLog
  addMessageToLog
  onChatClear
  getCurrentModeId = @() mpChatState.currentModeId
  setCurrentModeId = @(modeId) mpChatState.currentModeId = modeId
  getMaxLogSize = @() mpChatState.maxLogSize
  validateCurMode
  hasEnableChatMode = @() hasEnableChatMode
  setModeId
  isActiveMpChat = @() mpChatState.isActive
  setActiveMpChat = @(v) mpChatState.isActive = v
  canEnableChatInput
  appendScene = @(scene) scenes.append(scene)
  getScenes = @() scenes
  cleanScenesList
  findSceneDataByScene
  findSceneDataByObj
  doForAllScenes
}
