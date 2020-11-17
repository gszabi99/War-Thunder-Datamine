local { checkJoystickThustmasterHotas } = require("scripts/controls/hotas.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local skipTutorialBitmaskId = "skip_tutorial_bitmask"

local function isTutorialComplete(tutorialName) {
  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local progress = ::get_mission_progress($"tutorial/{tutorialName}")
  ::set_mp_mode(mainGameMode)
  return progress >= 0 && progress < 3
}

local checkTutorialsList = [ //idx in this array used for local profile option skipTutorialBitmaskId
  {
    id = "fighter"
    tutorial = "tutorialB_fighter"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
  }
  {
    id = "assaulter"
    tutorial = "tutorialB_assaulter"
  }
  {
    id = "bomber"
    tutorial = "tutorialB_bomber"
  }
  {
    id = "lightTank"
    tutorial = "tutorial_tank_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTankTutorials"
    requiresFeature = "Tanks"
  }
  {
    id = "lightTank_part2"
    tutorial = "tutorial_tank_basics_arcade_part2"
    requiresFeature = "Tanks"
    isNeedAskInMainmenu = function()
    {
      return  ::is_unlocked(-1, "player_is_out_of_tank_sandbox")
              && isTutorialComplete("tutorial_tank_basics_arcade_part1")
    }
  }
  {
    id = "boat"
    tutorial = "tutorial_boat_basic_arcade"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    requiresFeature = "Ships"
  }
  {
    id = "ship"
    tutorial = "tutorial_destroyer_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    requiresFeature = "Ships"
  }
]

local reqTutorial = {
  [::ES_UNIT_TYPE_AIRCRAFT] = "tutorialB_takeoff_and_landing",
  //[::ES_UNIT_TYPE_TANK] = "",
}

local getReqTutorial = @(unitType) reqTutorial?[unitType] ?? ""

local tutorialRewardData = persist("tutorialRewardData", @() ::Watched(null))
local clearTutorialRewardData = @() tutorialRewardData(null)

local launchedTutorialQuestionsPeerSession = persist("launchedTutorialQuestionsPeerSession", @() ::Watched(0))
local setLaunchedTutorialQuestionsValue = @(newValue) launchedTutorialQuestionsPeerSession(newValue)

local function saveTutorialToCheckReward(mission) {
  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local campId = ::get_game_mode_name(::GM_TRAINING)
  local fullMissionName = mission.getStr("chapter", campId) + "/" + mission.name
  local progress = ::get_mission_progress(fullMissionName)

  local usePresetFileName = ""
  local preset = ::g_controls_presets.getCurrentPreset()
  if (preset.name.indexof("hotas4") != null
      && checkJoystickThustmasterHotas(false)
      && ! ::has_feature("DisableSwitchPresetOnTutorialForHotas4"))
    {
      usePresetFileName = preset.fileName
      ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename("dualshock4"))
    }

  tutorialRewardData({
    missionName = mission.name,
    progress = progress,
    fullMissionName = fullMissionName,
    presetFilename = usePresetFileName
  })
  ::set_mp_mode(mainGameMode)
}

local isRequireFeature = @(data, featureId) (featureId in data) && !::has_feature(data[featureId])

local function getTutorialsTblWithMissions (diff = -1, misName = null) {
  local tutorialsTbl = checkTutorialsList
    .reduce(@(res, v, idx) res
      .__update({ [v.tutorial] = {
          idx = idx
          id = v.id
          mission = null
          progress = -1
          rewardText = ""
        }
      }),
    {})

  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local campId = ::get_game_mode_name(::GM_TRAINING)
  local chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (m.name in tutorialsTbl && (misName == null || misName == m.name)) {
        local fullMissionName = $"{m?.chapter ?? campId}/{m.name}"
        local progress = ::get_mission_progress(fullMissionName)
        if (!isRequireFeature(m, "reqFeature")
          && ((diff<0 && progress == 3) || (diff>=0 && (progress==3 || progress<diff)))) // 3 == unlocked, 0-2 - completed at difficulty
            tutorialsTbl[m.name].__update({ mission = m, progress = progress })

        if (misName != null)
          break
      }

  ::set_mp_mode(mainGameMode)

  return tutorialsTbl
}

local function updateTutorialRewardText(tutorialData) {
  if (tutorialData.progress == 3) { //tutorials have reward only once
    local rBlk = ::get_pve_awards_blk()
    local dataBlk = rBlk?[::get_game_mode_name(::GM_TRAINING)]
    if (dataBlk)
      tutorialData.rewardText = ::getRewardTextByBlk(dataBlk, tutorialData.mission.name, 0, "reward", true, true)
  }
}


local function getUncompletedTutorialData(misName, diff = -1) {
  if (!::has_feature("Tutorials"))
    return null

  local tutorialData = getTutorialsTblWithMissions(diff, misName)?[misName]
  if (tutorialData?.mission == null)
    return null

  updateTutorialRewardText(tutorialData)
  return tutorialData
}

local function getSuitableUncompletedTutorialData(unit, diff = -1) {
  if (!::has_feature("Tutorials"))
    return null

  local tutorialsTbl = getTutorialsTblWithMissions(diff)
  local tutorialData = null
  if (unit?.isTank() && ::has_feature("Tanks")
    && tutorialsTbl?.tutorial_tank_basics_arcade.mission != null)
      tutorialData = tutorialsTbl.tutorial_tank_basics_arcade
  else if (unit?.isBoat() && ::has_feature("Ships")
    && tutorialsTbl?.tutorial_boat_basic_arcade.mission != null)
      tutorialData = tutorialsTbl.tutorial_boat_basic_arcade
  else if (unit?.isShip() && ::has_feature("Ships")
    && tutorialsTbl?.tutorial_destroyer_basics_arcade.mission != null)
      tutorialData = tutorialsTbl.tutorial_destroyer_basics_arcade

  if (tutorialData == null)
    foreach (tutorial in checkTutorialsList) {
      if (isRequireFeature(tutorial, "requiresFeature") || tutorialsTbl?[tutorial.tutorial].mission == null)
        continue

      tutorialData = tutorialsTbl[tutorial.tutorial]
      break
    }

  if (tutorialData == null)
    return null

  updateTutorialRewardText(tutorialData)
  return tutorialData
}

local function resetTutorialSkip() {
  ::saveLocalByAccount(skipTutorialBitmaskId, 0)
}

local reqTimeInMode = 60 //req time in mode when no need check tutorial
local function isDiffUnlocked(diff, checkUnitType) {
  //check played before
  for(local d = diff; d<3; d++)
    if (::my_stats.getTimePlayed(checkUnitType, d) >= reqTimeInMode)
      return true

  local reqName = getReqTutorial(checkUnitType)
  if (reqName == "")
    return true

  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress

  local chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (reqName == m.name) {
        local fullMissionName = m.getStr("chapter", ::get_game_mode_name(::GM_TRAINING)) + "/" + m.name
        local progress = ::get_mission_progress(fullMissionName)
        if (mainGameMode >= 0)
          ::set_mp_mode(mainGameMode)
        return (progress<3 && progress>=diff) // 3 == unlocked, 0-2 - completed at difficulty
      }
  dagor.assertf(false, "Error: Not found mission ::req_tutorial_name = " + reqName)
  ::set_mp_mode(mainGameMode)
  return true
}

local function checkDiffTutorial(diff, unitType, needMsgBox = true, cancelCb = null) {
  if (!::check_diff_pkg(diff, !needMsgBox))
    return true
  if (!::g_difficulty.getDifficultyByDiffCode(diff).needCheckTutorial)
    return false
  if (::g_squad_manager.isNotAloneOnline())
    return false

  if (isDiffUnlocked(diff, unitType))
    return false

  local reqName = getReqTutorial(unitType)
  local mData = getUncompletedTutorialData(reqName, diff)
  if (!mData)
    return false

  local msgText = ::loc((diff==2)? "msgbox/req_tutorial_for_real" : "msgbox/req_tutorial_for_hist")
  msgText += "\n\n" + format(::loc("msgbox/req_tutorial_for_mode"), ::loc("difficulty" + diff))

  msgText += "\n<color=@userlogColoredText>" + ::loc("missions/" + mData.mission.name) + "</color>"

  if(needMsgBox)
    ::scene_msg_box("req_tutorial_msgbox", null, msgText,
      [
        ["startTutorial", (@(mData, diff) function() {
          mData.mission.setStr("difficulty", ::get_option(::USEROPT_DIFFICULTY).values[diff])
          ::select_mission(mData.mission, true)
          ::current_campaign_mission = mData.mission.name
          saveTutorialToCheckReward(mData.mission)
          ::handlersManager.animatedSwitchScene(::gui_start_flight)
        })(mData, diff)],
        ["cancel", cancelCb]
      ], "cancel")
  else if(cancelCb)
    cancelCb()
  return true
}

addListenersWithoutEnv({
  SignOut = function(p) {
    clearTutorialRewardData()
    setLaunchedTutorialQuestionsValue(0)
  }
})

return {
  skipTutorialBitmaskId = skipTutorialBitmaskId
  checkTutorialsList = checkTutorialsList
  reqTutorial = reqTutorial
  clearTutorialRewardData = clearTutorialRewardData
  tutorialRewardData = tutorialRewardData
  setLaunchedTutorialQuestionsValue = setLaunchedTutorialQuestionsValue
  launchedTutorialQuestionsPeerSession = launchedTutorialQuestionsPeerSession
  saveTutorialToCheckReward = saveTutorialToCheckReward
  getUncompletedTutorialData = getUncompletedTutorialData
  getSuitableUncompletedTutorialData = getSuitableUncompletedTutorialData
  resetTutorialSkip = resetTutorialSkip
  isDiffUnlocked = isDiffUnlocked
  checkDiffTutorial = checkDiffTutorial
}