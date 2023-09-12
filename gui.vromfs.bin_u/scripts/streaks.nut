//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loading_play_voice } = require("loading")
let { is_replay_playing } = require("replays")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getMultiStageLocId } = require("%scripts/unlocks/unlocksModule.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HUD_VISIBLE_STREAKS
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")

const STREAK_LIFE_TIME = 5.0
const STREAK_FADE_OUT_TIME = 1.5
const STREAK_DELAY_TIME = 0.5
const STREAK_QUEUE_TIME_FACTOR = 3.0

enum hudStreakState {
  EMPTY
  ACTIVE
  DELAY_BETWEEN_STREAKS
}

::g_streaks <- {
  stateTimeLeft = 0
  streakQueue = []
  state = hudStreakState.EMPTY

  scene = null
}

let function updateAnimTimer() {
  let obj = ::g_streaks.getSceneObj()
  if (!obj)
    return

  let animTime = 1000 * STREAK_LIFE_TIME / ::g_streaks.getTimeMultiplier()
  obj.findObject("streak_content")["transp-time"] = animTime.tointeger().tostring()
}

::g_streaks.addStreak <- function addStreak(id, header, score) {
  if (!this.isStreaksAvailable())
    return
  if (!::get_gui_option_in_mode(USEROPT_HUD_VISIBLE_STREAKS, OPTIONS_MODE_GAMEPLAY, true)) {
    this.streakQueue.clear()
    return
  }

  this.streakQueue.append({ id = id, header = header, score = score })
  this.checkNextState()

  if (this.streakQueue.len() == 1)
    updateAnimTimer()
}

::g_streaks.isStreaksAvailable <- function isStreaksAvailable() {
  return !is_replay_playing()
}

::g_streaks.checkNextState <- function checkNextState() {
  if (this.stateTimeLeft > 0)
    return

  let wasState = this.state
  if (this.state == hudStreakState.ACTIVE) {
    this.state = hudStreakState.DELAY_BETWEEN_STREAKS
    this.stateTimeLeft = STREAK_DELAY_TIME
  }
  else if (this.state == hudStreakState.EMPTY || this.state == hudStreakState.DELAY_BETWEEN_STREAKS) {
    if (this.showNextStreak()) {
      this.state = hudStreakState.ACTIVE
      this.stateTimeLeft = STREAK_LIFE_TIME
    }
    else
      this.state = hudStreakState.EMPTY
  }

  if (wasState == this.state)
    return

  this.updateSceneObj()
  this.updatePlaceObj()
}

::g_streaks.getSceneObj <- function getSceneObj() {
  if (checkObj(this.scene))
    return this.scene

  let guiScene = get_gui_scene()
  if (!guiScene)
    return null
  let obj = guiScene["hud_streaks"]
  if (!checkObj(obj))
    return null

  this.scene = obj
  return obj
}

::g_streaks.showNextStreak <- function showNextStreak() {
  if (!this.streakQueue.len())
    return false

  let obj = this.getSceneObj()
  if (!obj)
    return false

  let guiScene = obj.getScene()
  guiScene.setUpdatesEnabled(false, false)

  let streak = this.streakQueue.remove(0)

  let contentObj = obj.findObject("streak_content")
  contentObj.show(true) //need to correct update textarea positions and sizes
  obj.findObject("streak_header").setValue(streak.header)
  obj.findObject("streak_score").setValue(streak.score)
  let config = { iconStyle = "streak_" + streak.id }
  ::set_unlock_icon_by_config(obj.findObject("streak_icon"), config)

  contentObj._blink = "yes"
  updateAnimTimer()

  guiScene.setUpdatesEnabled(true, true)
  this.updatePlaceObjHeight(contentObj.getSize()[1])

  this.streakPlaySound(streak.id)
  return true
}

::g_streaks.updateSceneObj <- function updateSceneObj() {
  let obj = this.getSceneObj()
  if (!obj)
    return

  showObjById("streak_content", this.state == hudStreakState.ACTIVE, obj)
}

::g_streaks.updatePlaceObj <- function updatePlaceObj() {
  let obj = this.getSceneObj()
  if (!obj)
    return

  let show = this.state == hudStreakState.ACTIVE
               || (this.state == hudStreakState.DELAY_BETWEEN_STREAKS && this.streakQueue.len() > 0)
  obj.animation = show ? "show" : "hide"
}

::g_streaks.updatePlaceObjHeight <- function updatePlaceObjHeight(newHeight) {
  let obj = this.getSceneObj()
  if (!obj || !newHeight)
    return

  let curHeight = to_integer_safe(obj?["height-end"], 1)
  if (curHeight == newHeight)
    return

  obj["height-end"] = newHeight.tostring()
}

::g_streaks.streakPlaySound <- function streakPlaySound(streakId) {
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

::g_streaks.getTimeMultiplier <- function getTimeMultiplier() {
  return this.streakQueue.len() > 0 ? STREAK_QUEUE_TIME_FACTOR : 1.0
}

::g_streaks.onUpdate <- function onUpdate(dt) {
  if (this.stateTimeLeft <= 0)
    return

  this.stateTimeLeft -= dt * this.getTimeMultiplier()

  if (this.stateTimeLeft <= 0)
    this.checkNextState()
}

::g_streaks.clear <- function clear() {
  this.stateTimeLeft = 0;
  this.state = hudStreakState.EMPTY
  this.streakQueue.clear()
}


///////////////////////////////////////////////////////////////////////
///////////////////Function called from code///////////////////////////
///////////////////////////////////////////////////////////////////////

::add_streak_message <- function add_streak_message(header, wp, exp, id = "") { // called from client
  let messageArr = []
  if (wp)
    messageArr.append(loc("warpoints/received/by_param", {
      sign  = "+"
      value = decimalFormat(wp)
    }))
  if (exp)
    messageArr.append(loc("exp_received/by_param", { value = decimalFormat(exp) }))

  broadcastEvent("StreakArrived", { id = id })
  ::g_streaks.addStreak(id, header, loc("ui/comma").join(messageArr, true))
}

::get_loc_for_streak <- function get_loc_for_streak(StreakNameType, name, stageparam, playerNick = "", colorId = 0) {
  let stageId = getMultiStageLocId(name, stageparam)
  let isMyStreak = StreakNameType == SNT_MY_STREAK_HEADER
  local text = ""
  if (isMyStreak)
    text = loc("streaks/" + stageId)
  else { //SNT_OTHER_STREAK_TEXT
    text = loc("streaks/" + stageId + "/other")
    if (text == "")
      text = format(loc("streaks/default/other"), loc("streaks/" + stageId))
  }

  if (stageparam)
    text = format(text, stageparam)
  if (!isMyStreak && colorId != 0)
    text = format("\x1b%03d%s\x1b %s", colorId, getPlayerName(playerNick), text)
  return text
}
