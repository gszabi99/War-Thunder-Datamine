let { format } = require("string")
let { checkJoystickThustmasterHotas } = require("%scripts/controls/hotas.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getMissionRewardsMarkup } = require("%scripts/missions/missionsUtilsModule.nut")

let skipTutorialBitmaskId = "skip_tutorial_bitmask"

let checkTutorialsList = [ //idx in this array used for local profile option skipTutorialBitmaskId
  {
    id = "fighter"
    tutorial = "tutorialB_fighter"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) (unit?.isAir() ?? false) || (unit?.isHelicopter() ?? false)
    isNeedAskInMainmenu = true
  }
  {
    id = "assaulter"
    tutorial = "tutorialB_assaulter"
    suitableForUnit = @(unit) unit?.isAir() ?? false
  }
  {
    id = "bomber"
    tutorial = "tutorialB_bomber"
    suitableForUnit = @(unit) unit?.isAir() ?? false
  }
  {
    id = "lightTank"
    tutorial = "tutorial_tank_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTankTutorials"
    requiresFeature = "!TestTankActionTutorial"
    suitableForUnit = @(unit) unit?.isTank() ?? false
    isNeedAskInMainmenu = true
  }
  {
    id = "lightTank_action"
    tutorial = "tutorial_tank_action_arcade"
    canSkipByFeature = "AllowedToSkipBaseTankTutorials"
    requiresFeature = "TestTankActionTutorial"
    suitableForUnit = @(unit) unit?.isTank() ?? false
    isNeedAskInMainmenu = true
  }
  {
    id = "lightTank_part2"
    tutorial = "tutorial_tank_basics_arcade_part2"
    requiresFeature = "Tanks"
    suitableForUnit = @(unit) unit?.isTank() ?? false
  }
  {
    id = "boat"
    tutorial = "tutorial_boat_basic_arcade"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    requiresFeature = "Ships"
    suitableForUnit = @(unit) unit?.isBoat() ?? false
    isNeedAskInMainmenu = true
  }
  {
    id = "ship"
    tutorial = "tutorial_destroyer_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    requiresFeature = "Ships"
    suitableForUnit = @(unit) unit?.isShip() ?? false
    isNeedAskInMainmenu = true
  }
]

let reqTutorial = {
  [::ES_UNIT_TYPE_AIRCRAFT] = "tutorialB_takeoff_and_landing",
  //[::ES_UNIT_TYPE_TANK] = "",
}

let getReqTutorial = @(unitType) reqTutorial?[unitType] ?? ""

let tutorialRewardData = persist("tutorialRewardData", @() ::Watched(null))
let clearTutorialRewardData = @() tutorialRewardData(null)

let launchedTutorialQuestionsPeerSession = persist("launchedTutorialQuestionsPeerSession", @() ::Watched(0))
let setLaunchedTutorialQuestionsValue = @(newValue) launchedTutorialQuestionsPeerSession(newValue)

let function getTutorialFirstCompletRewardData(misDataBlk, params = {}) {
  let { hasRewardImage = true, needVerticalAlign = false, highlighted = null,
    showFullReward = false, isMissionComplete = false } = params
  let res = {
    locId = "reward/tutorialFirstComplet"
    rewardMoney = ::Cost()
    isComplete = true
    hasReward = false
    hasRewardImage
    highlighted = false
    needVerticalAlign
    slotReward = ""
  }

  let slot = misDataBlk?.slot
  if (slot != null) {
    let isRecieveSlot = ::g_crews_list.get().findindex(@(c) c.crews.len() < slot) == null
    if (isRecieveSlot || !isMissionComplete) {
      res.isComplete = isRecieveSlot
      if (showFullReward || !isRecieveSlot) {
        res.slotReward = slot.tostring()
        res.hasReward = true
      }
    }
  }

  let oneTimeAwardUnlockId = misDataBlk?.oneTimeAwardUnlock ?? ""
  if (oneTimeAwardUnlockId == "")
    return res

  let isCompleteAwardUnlock = ::is_unlocked_scripted(-1, oneTimeAwardUnlockId)
  if (res.hasReward && !res.isComplete && isCompleteAwardUnlock)
    return res

  if ((misDataBlk?.hideOneTimeAwardIfUnlockIsOpen ?? "") != ""
      && ::is_unlocked_scripted(-1, misDataBlk.hideOneTimeAwardIfUnlockIsOpen)
      && !isCompleteAwardUnlock)
    return res

  let cost = ::g_unlocks.getUnlockCost(oneTimeAwardUnlockId)
  if (cost.isZero())
    return res

  res.rewardMoney = cost
  res.hasReward = true
  res.isComplete = res.isComplete && isCompleteAwardUnlock
  res.highlighted = highlighted ?? isCompleteAwardUnlock
  return res
}

let function saveTutorialToCheckReward(mission) {
  let mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  let campId = ::get_game_mode_name(::GM_TRAINING)
  let missionName = mission.name
  let fullMissionName = $"{mission.getStr("chapter", campId)}/{missionName}"
  let progress = ::get_mission_progress(fullMissionName)
  let isComplete = progress >= 0 && progress < 3

  local presetFilename = ""
  let preset = ::g_controls_presets.getCurrentPresetInfo()
  if (preset.name.indexof("hotas4") != null
      && checkJoystickThustmasterHotas(false)
      && ! ::has_feature("DisableSwitchPresetOnTutorialForHotas4"))
    {
      presetFilename = preset.fileName
      ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename("dualshock4"))
    }

  let rBlk = ::get_pve_awards_blk()
  let dataBlk = rBlk?[::get_game_mode_name(::GM_TRAINING)]
  let misDataBlk = dataBlk?[missionName]
  let resource = misDataBlk?.decal
  let resourceType = "decal"
  let isResourceUnlocked = ::g_decorator.getDecoratorByResource(resource, resourceType)?.isUnlocked() ?? false

  tutorialRewardData({
    missionName
    progress
    fullMissionName
    presetFilename
    firstCompletRewardData = getTutorialFirstCompletRewardData(misDataBlk, {
      highlighted = true
      hasRewardImage = false
      needVerticalAlign = true
      isMissionComplete = isComplete
    })
    resource
    resourceType
    isResourceUnlocked
  })
  ::set_mp_mode(mainGameMode)
}

let isRequireFeature = @(data, featureId) (featureId in data) && !::has_feature(data[featureId])

let function getTutorialsTblWithMissions (diff = -1, misName = null) {
  let tutorialsTbl = checkTutorialsList
    .reduce(@(res, v, idx) res
      .__update({ [v.tutorial] = {
          idx = idx
          id = v.id
          mission = null
          progress = -1
        }
      }),
    {})

  let mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  let campId = ::get_game_mode_name(::GM_TRAINING)
  let chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (m.name in tutorialsTbl && (misName == null || misName == m.name)) {
        let fullMissionName = $"{m?.chapter ?? campId}/{m.name}"
        let progress = ::get_mission_progress(fullMissionName)
        if (!isRequireFeature(m, "reqFeature")
          && ((diff<0 && progress == 3) || (diff>=0 && (progress==3 || progress<diff)))) // 3 == unlocked, 0-2 - completed at difficulty
            tutorialsTbl[m.name].__update({ mission = m, progress = progress })

        if (misName != null)
          break
      }

  ::set_mp_mode(mainGameMode)

  return tutorialsTbl
}

let function getTutorialRewardMarkup(tutorialData) {
  if (tutorialData.progress != 3) //tutorials have reward only once
    return ""

  let rBlk = ::get_pve_awards_blk()
  let dataBlk = rBlk?[::get_game_mode_name(::GM_TRAINING)]
  if (dataBlk == null)
    return ""

  let params = {
    highlighted = true
    hasRewardImage = false
    needVerticalAlign = true
  }
  let rewardsConfig = [params.__merge({ isBaseReward = true })]
  let firstCompletRewardData = getTutorialFirstCompletRewardData(dataBlk?[tutorialData.mission.name], params)
  if (firstCompletRewardData.hasReward && !firstCompletRewardData.isComplete)
    rewardsConfig.append(firstCompletRewardData)

  return getMissionRewardsMarkup(dataBlk, tutorialData.mission.name, rewardsConfig)
}

let function getUncompletedTutorialData(misName, diff = -1) {
  if (!::has_feature("Tutorials"))
    return null

  let tutorialData = getTutorialsTblWithMissions(diff, misName)?[misName]
  if (tutorialData?.mission == null)
    return null

  return tutorialData
}

let function getSuitableUncompletedTutorialData(unit, diff = -1) {
  if (!::has_feature("Tutorials"))
    return null

  let tutorialsTbl = getTutorialsTblWithMissions(diff)
  local tutorialData = null
  foreach (tutorial in checkTutorialsList) {
    if (isRequireFeature(tutorial, "requiresFeature") || tutorialsTbl?[tutorial.tutorial].mission == null)
      continue

    if (tutorial.suitableForUnit(unit))
      return tutorialsTbl[tutorial.tutorial]

    if (tutorialData == null)
      tutorialData = tutorialsTbl[tutorial.tutorial]
  }

  return tutorialData
}

let function resetTutorialSkip() {
  ::saveLocalByAccount(skipTutorialBitmaskId, 0)
}

let reqTimeInMode = 60 //req time in mode when no need check tutorial
let function isDiffUnlocked(diff, checkUnitType) {
  //check played before
  for(local d = diff; d<3; d++)
    if (::my_stats.getTimePlayed(checkUnitType, d) >= reqTimeInMode)
      return true

  let reqName = getReqTutorial(checkUnitType)
  if (reqName == "")
    return true

  let mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress

  let chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (reqName == m.name) {
        let fullMissionName = m.getStr("chapter", ::get_game_mode_name(::GM_TRAINING)) + "/" + m.name
        let progress = ::get_mission_progress(fullMissionName)
        if (mainGameMode >= 0)
          ::set_mp_mode(mainGameMode)
        return (progress<3 && progress>=diff) // 3 == unlocked, 0-2 - completed at difficulty
      }
  ::dagor.assertf(false, "Error: Not found mission ::req_tutorial_name = " + reqName)
  ::set_mp_mode(mainGameMode)
  return true
}

let function checkDiffTutorial(diff, unitType, needMsgBox = true, cancelCb = null) {
  if (!::check_diff_pkg(diff, !needMsgBox))
    return true
  if (!::g_difficulty.getDifficultyByDiffCode(diff).needCheckTutorial)
    return false
  if (::g_squad_manager.isNotAloneOnline())
    return false

  if (isDiffUnlocked(diff, unitType))
    return false

  let reqName = getReqTutorial(unitType)
  let mData = getUncompletedTutorialData(reqName, diff)
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
  getTutorialFirstCompletRewardData
  getTutorialRewardMarkup
}