local platformModule = require("scripts/clientState/platform.nut")

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

g_streaks.addStreak <- function addStreak(id, header, score)
{
  if (!isStreaksAvailable())
    return
  if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.STREAKS))
  {
    streakQueue.clear()
    return
  }

  streakQueue.append({ id = id, header = header, score = score })
  checkNextState()

  if (streakQueue.len() == 1)
    updateAnimTimer()
}

g_streaks.isStreaksAvailable <- function isStreaksAvailable()
{
  return !::is_replay_playing()
}

g_streaks.checkNextState <- function checkNextState()
{
  if (stateTimeLeft > 0)
    return

  local wasState = state
  if (state == hudStreakState.ACTIVE)
  {
    state = hudStreakState.DELAY_BETWEEN_STREAKS
    stateTimeLeft = STREAK_DELAY_TIME
  }
  else if (state == hudStreakState.EMPTY || state == hudStreakState.DELAY_BETWEEN_STREAKS)
  {
    if (showNextStreak())
    {
      state = hudStreakState.ACTIVE
      stateTimeLeft = STREAK_LIFE_TIME
    } else
      state = hudStreakState.EMPTY
  }

  if (wasState == state)
    return

  updateSceneObj()
  updatePlaceObj()
}

g_streaks.getSceneObj <- function getSceneObj()
{
  if (::checkObj(scene))
    return scene

  local guiScene = ::get_gui_scene()
  if (!guiScene)
    return null
  local obj = guiScene["hud_streaks"]
  if (!::checkObj(obj))
    return null

  scene = obj
  return obj
}

g_streaks.showNextStreak <- function showNextStreak()
{
  if (!streakQueue.len())
    return false

  local obj = getSceneObj()
  if (!obj)
    return false

  local guiScene = obj.getScene()
  guiScene.setUpdatesEnabled(false, false)

  local streak = streakQueue.remove(0)

  local contentObj = obj.findObject("streak_content")
  contentObj.show(true) //need to correct update textarea positions and sizes
  obj.findObject("streak_header").setValue(streak.header)
  obj.findObject("streak_score").setValue(streak.score)
  local config = { iconStyle = "streak_" + streak.id }
  ::set_unlock_icon_by_config(obj.findObject("streak_icon"), config)

  contentObj._blink = "yes"
  updateAnimTimer()

  guiScene.setUpdatesEnabled(true, true)
  updatePlaceObjHeight(contentObj.getSize()[1])

  streakPlaySound(streak.id)
  return true
}

::updateAnimTimer <- function updateAnimTimer()
{
  local obj = getSceneObj()
  if (!obj)
    return

  local animTime = 1000 * STREAK_LIFE_TIME / getTimeMultiplier()
  obj.findObject("streak_content")["transp-time"] = animTime.tointeger().tostring()
}

g_streaks.updateSceneObj <- function updateSceneObj()
{
  local obj = getSceneObj()
  if (!obj)
    return

  ::showBtn("streak_content", state == hudStreakState.ACTIVE, obj)
}

g_streaks.updatePlaceObj <- function updatePlaceObj()
{
  local obj = getSceneObj()
  if (!obj)
    return

  local show = state == hudStreakState.ACTIVE
               || (state == hudStreakState.DELAY_BETWEEN_STREAKS && streakQueue.len() > 0)
  obj.animation = show ? "show" : "hide"
}

g_streaks.updatePlaceObjHeight <- function updatePlaceObjHeight(newHeight)
{
  local obj = getSceneObj()
  if (!obj || !newHeight)
    return

  local curHeight = ::to_integer_safe(obj?["height-end"], 1)
  if (curHeight == newHeight)
    return

  obj["height-end"] = newHeight.tostring()
}

g_streaks.streakPlaySound <- function streakPlaySound(streakId)
{
  if (!::has_feature("streakVoiceovers"))
    return
  local unlockBlk = ::g_unlocks.getUnlockById(streakId)
  if (!unlockBlk)
    return

  if (unlockBlk?.isAfterFlight)
    ::get_cur_gui_scene()?.playSound("streak_mission_complete")
  else if (unlockBlk?.sound)
    ::loading_play_voice(unlockBlk.sound, true)
}

g_streaks.getTimeMultiplier <- function getTimeMultiplier()
{
  return streakQueue.len() > 0 ? STREAK_QUEUE_TIME_FACTOR : 1.0
}

g_streaks.onUpdate <- function onUpdate(dt)
{
  if (stateTimeLeft <= 0)
    return

  stateTimeLeft -= dt * getTimeMultiplier()

  if (stateTimeLeft <= 0)
    checkNextState()
}

g_streaks.clear <- function clear()
{
  stateTimeLeft = 0;
  state = hudStreakState.EMPTY
  streakQueue.clear()
}


///////////////////////////////////////////////////////////////////////
///////////////////Function called from code///////////////////////////
///////////////////////////////////////////////////////////////////////

::add_streak_message <- function add_streak_message(header, wp, exp, id = "") // called from client
{
  local messageArr = []
  if (wp)
    messageArr.append(::loc("warpoints/received/by_param", {
      sign  = "+"
      value =::g_language.decimalFormat(wp)
    }))
  if (exp)
    messageArr.append(::loc("exp_received/by_param", { value = ::g_language.decimalFormat(exp) }))

  ::broadcastEvent("StreakArrived", { id = id })
  ::g_streaks.addStreak(id, header, ::g_string.implode(messageArr, ::loc("ui/comma")))
}

::get_loc_for_streak <- function get_loc_for_streak(StreakNameType, name, stageparam, playerNick = "", colorId = 0)
{
  local stageId = ::g_unlocks.getMultiStageId(name, stageparam)
  local isMyStreak = StreakNameType == ::SNT_MY_STREAK_HEADER
  local text = ""
  if (isMyStreak)
    text = ::loc("streaks/" + stageId)
  else //SNT_OTHER_STREAK_TEXT
  {
    text = ::loc("streaks/" + stageId + "/other")
    if (text == "")
      text = ::format(::loc("streaks/default/other"), ::loc("streaks/" + stageId))
  }

  if (stageparam)
    text = format(text, stageparam)
  if (!isMyStreak && colorId != 0)
    text = ::format("\x1b%03d%s\x1b %s", colorId, platformModule.getPlayerName(playerNick), text)
  return text
}
