from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loading_play_voice } = require("loading")
let { is_replay_playing } = require("replays")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getMultiStageLocId } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockIconConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HUD_VISIBLE_STREAKS
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { eventbus_subscribe } = require("eventbus")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")

const STREAK_LIFE_TIME = 5.0
const STREAK_DELAY_TIME = 0.5
const STREAK_QUEUE_TIME_FACTOR = 3.0

enum hudStreakState {
  EMPTY
  ACTIVE
  DELAY_BETWEEN_STREAKS
}

local stateTimeLeft = 0
let streakQueue = []
local streakState = hudStreakState.EMPTY
local scene = null

function clearStreaks() {
  stateTimeLeft = 0
  streakState = hudStreakState.EMPTY
  streakQueue.clear()
}

function getSceneObj() {
  if (scene?.isValid())
    return scene

  let guiScene = get_gui_scene()
  if (!guiScene)
    return null
  let obj = guiScene["hud_streaks"]
  if (!checkObj(obj))
    return null

  scene = obj
  return obj
}

function getTimeMultiplier() {
  return streakQueue.len() > 0 ? STREAK_QUEUE_TIME_FACTOR : 1.0
}

function updateAnimTimer() {
  let obj = getSceneObj()
  if (!obj)
    return

  let animTime = 1000 * STREAK_LIFE_TIME / getTimeMultiplier()
  obj.findObject("streak_content")["transp-time"] = animTime.tointeger().tostring()
}

function isStreaksAvailable() {
  return !is_replay_playing()
}

function streakPlaySound(streakId) {
  if (!hasFeature("streakVoiceovers"))
    return
  let unlockBlk = getUnlockById(streakId)
  if (!unlockBlk)
    return

  if (unlockBlk?.isAfterFlight)
    get_cur_gui_scene()?.playSound("streak_mission_complete")
  else if (unlockBlk?.sound)
    loading_play_voice(unlockBlk.sound, true)
}

function updatePlaceObjHeight(newHeight) {
  let obj = getSceneObj()
  if (!obj || !newHeight)
    return

  let curHeight = to_integer_safe(obj?["height-end"], 1)
  if (curHeight == newHeight)
    return

  obj["height-end"] = newHeight.tostring()
}

function showNextStreak() {
  if (!streakQueue.len())
    return false

  let obj = getSceneObj()
  if (!obj)
    return false

  let guiScene = obj.getScene()
  guiScene.setUpdatesEnabled(false, false)

  let streak = streakQueue.remove(0)

  let contentObj = obj.findObject("streak_content")
  contentObj.show(true) 
  obj.findObject("streak_header").setValue(streak.header)
  obj.findObject("streak_score").setValue(streak.score)
  let config = { iconStyle = $"streak_{streak.id}" }

  let { iconStyle, image, ratio, iconParams, iconConfig } = getUnlockIconConfig(config)
  LayersIcon.replaceIcon(obj.findObject("streak_icon"), iconStyle, image, ratio, null, iconParams, iconConfig)

  contentObj._blink = "yes"
  updateAnimTimer()

  guiScene.setUpdatesEnabled(true, true)
  updatePlaceObjHeight(contentObj.getSize()[1])

  streakPlaySound(streak.id)
  return true
}

function updateSceneObj() {
  let obj = getSceneObj()
  if (!obj)
    return

  showObjById("streak_content", streakState == hudStreakState.ACTIVE, obj)
}

function updatePlaceObj() {
  let obj = getSceneObj()
  if (!obj)
    return

  let show = streakState == hudStreakState.ACTIVE
    || (streakState == hudStreakState.DELAY_BETWEEN_STREAKS && streakQueue.len() > 0)
  obj.animation = show ? "show" : "hide"
}

function checkNextState() {
  if (stateTimeLeft > 0)
    return

  let wasState = streakState
  if (streakState == hudStreakState.ACTIVE) {
    streakState = hudStreakState.DELAY_BETWEEN_STREAKS
    stateTimeLeft = STREAK_DELAY_TIME
  }
  else if (streakState == hudStreakState.EMPTY || streakState == hudStreakState.DELAY_BETWEEN_STREAKS) {
    if (showNextStreak()) {
      streakState = hudStreakState.ACTIVE
      stateTimeLeft = STREAK_LIFE_TIME
    }
    else
      streakState = hudStreakState.EMPTY
  }

  if (wasState == streakState)
    return

  updateSceneObj()
  updatePlaceObj()
}

function addStreak(id, header, score) {
  if (!isStreaksAvailable())
    return
  if (!get_gui_option_in_mode(USEROPT_HUD_VISIBLE_STREAKS, OPTIONS_MODE_GAMEPLAY, true)) {
    streakQueue.clear()
    return
  }

  streakQueue.append({ id = id, header = header, score = score })
  checkNextState()

  if (streakQueue.len() == 1)
    updateAnimTimer()
}

function onUpdateStreaks(dt) {
  if (stateTimeLeft <= 0)
    return

  stateTimeLeft -= dt * getTimeMultiplier()

  if (stateTimeLeft <= 0)
    checkNextState()
}

function getLocForStreak(StreakNameType, name, stageparam, playerNick = "", colorId = 0) {
  let stageId = getMultiStageLocId(name, stageparam)
  let isMyStreak = StreakNameType == SNT_MY_STREAK_HEADER
  local text = ""
  if (isMyStreak)
    text = loc($"streaks/{stageId}")
  else { 
    text = loc($"streaks/{stageId}/other")
    if (text == "")
      text = format(loc("streaks/default/other"), loc($"streaks/{stageId}"))
  }

  if (stageparam)
    text = format(text, stageparam)
  if (!isMyStreak && colorId != 0)
    text = format("\x1b%03d%s\x1b %s", colorId, getPlayerName(playerNick), text)
  return text
}





function add_streak_message(data) { 
  let { header, wp, exp, id = "" } = data
  let messageArr = []
  if (wp)
    messageArr.append(loc("warpoints/received/by_param", {
      sign  = "+"
      value = decimalFormat(wp)
    }))
  if (exp)
    messageArr.append(loc("exp_received/by_param", { value = decimalFormat(exp) }))

  broadcastEvent("StreakArrived", { id })
  addStreak(id, header, loc("ui/comma").join(messageArr, true))
}

eventbus_subscribe("add_streak_message", @(p) add_streak_message(p))

::get_loc_for_streak <- getLocForStreak

return {
  add_streak_message
  getLocForStreak
  clearStreaks
  onUpdateStreaks
}