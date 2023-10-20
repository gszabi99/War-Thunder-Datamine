//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getMissionRewardsMarkup } = require("%scripts/missions/missionsUtilsModule.nut")
let { get_meta_missions_info_by_chapters, select_mission } = require("guiMission")
let { set_game_mode, get_game_mode } = require("mission")
let { getUnlockRewardCostByName, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let { USEROPT_DIFFICULTY } = require("%scripts/options/optionsExtNames.nut")
let { saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { get_pve_awards_blk } = require("blkGetters")

let skipTutorialBitmaskId = "skip_tutorial_bitmask"

let checkTutorialsList = [ //idx in this array used for local profile option skipTutorialBitmaskId
  {
    id = "fighter"
    tutorial = "tutorialB_fighter"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) (unit?.isAir() ?? false) || (unit?.isHelicopter() ?? false)
    isNeedAskInMainmenu = true
    isShowInPromoBlock = true
  }
  {
    id = "assaulter"
    tutorial = "tutorialB_assaulter"
    suitableForUnit = @(unit) unit?.isAir() ?? false
    isShowInPromoBlock = true
  }
  {
    id = "bomber"
    tutorial = "tutorialB_bomber"
    suitableForUnit = @(unit) unit?.isAir() ?? false
    isShowInPromoBlock = true
  }
  {
    id = "lightTank"
    tutorial = "tutorial_tank_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTankTutorials"
    requiresFeature = "!TestTankActionTutorial"
    suitableForUnit = @(unit) unit?.isTank() ?? false
    isNeedAskInMainmenu = true
    isShowInPromoBlock = true
  }
  {
    id = "lightTank_action"
    tutorial = "tutorial_tank_action_arcade"
    canSkipByFeature = "AllowedToSkipBaseTankTutorials"
    requiresFeature = "TestTankActionTutorial"
    suitableForUnit = @(unit) unit?.isTank() ?? false
    isNeedAskInMainmenu = true
    isShowInPromoBlock = true
  }
  {
    id = "lightTank_part2"
    tutorial = "tutorial_tank_basics_arcade_part2"
    suitableForUnit = @(unit) unit?.isTank() ?? false
    isShowInPromoBlock = true
  }
  {
    id = "boat"
    tutorial = "tutorial_boat_basic_arcade"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isBoat() ?? false
    isNeedAskInMainmenu = true
    isShowInPromoBlock = true
  }
  {
    id = "ship"
    tutorial = "tutorial_destroyer_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isShip() ?? false
    isNeedAskInMainmenu = true
    isShowInPromoBlock = true
  }
  {
    id = "fighter"
    tutorial = "tutorialB_takeoff_and_landing"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isAir() ?? false
    isShowInPromoBlock = true
  }
  {
    id = "fighter"
    tutorial = "tutorial01"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isAir() ?? false
  }
  {
    id = "fighter"
    tutorial = "tutorial02"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isAir() ?? false
  }
  {
    id = "bomber"
    tutorial = "tutorial03"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isAir() ?? false
  }
  {
    id = "bomber"
    tutorial = "tutorial04"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
    suitableForUnit = @(unit) unit?.isAir() ?? false
  }
]

let reqTutorial = {
  [ES_UNIT_TYPE_AIRCRAFT] = "tutorialB_takeoff_and_landing",
  //[ES_UNIT_TYPE_TANK] = "",
}

let getReqTutorial = @(unitType) reqTutorial?[unitType] ?? ""

let tutorialRewardData = mkWatched(persist, "tutorialRewardData", null)
let clearTutorialRewardData = @() tutorialRewardData(null)

let launchedTutorialQuestionsPeerSession = mkWatched(persist, "launchedTutorialQuestionsPeerSession", 0)
let setLaunchedTutorialQuestionsValue = @(newValue) launchedTutorialQuestionsPeerSession(newValue)

let function getTutorialFirstCompletRewardData(misDataBlk, params = {}) {
  let { hasRewardImage = true, needVerticalAlign = false, highlighted = null,
    showFullReward = false, isMissionComplete = false } = params
  let res = {
    locId = "reward/tutorialFirstComplet"
    rewardMoney = Cost()
    isComplete = true
    hasReward = false
    hasRewardImage
    highlighted = false
    needVerticalAlign
    slotReward = ""
  }

  let slot = misDataBlk?.slot
  if (slot != null) {
    let isReceiveSlot = ::g_crews_list.get().findindex(@(c) c.crews.len() < slot) == null
    if (isReceiveSlot || !isMissionComplete) {
      res.isComplete = isReceiveSlot
      if (showFullReward || !isReceiveSlot) {
        res.slotReward = slot.tostring()
        res.hasReward = true
      }
    }
  }

  let oneTimeAwardUnlockId = misDataBlk?.oneTimeAwardUnlock ?? ""
  if (oneTimeAwardUnlockId == "")
    return res

  let isCompleteAwardUnlock = isUnlockOpened(oneTimeAwardUnlockId)
  if (res.hasReward && !res.isComplete && isCompleteAwardUnlock)
    return res

  if ((misDataBlk?.hideOneTimeAwardIfUnlockIsOpen ?? "") != ""
      && isUnlockOpened(misDataBlk.hideOneTimeAwardIfUnlockIsOpen)
      && !isCompleteAwardUnlock)
    return res

  let cost = getUnlockRewardCostByName(oneTimeAwardUnlockId)
  if (cost.isZero())
    return res

  res.rewardMoney = cost
  res.hasReward = true
  res.isComplete = res.isComplete && isCompleteAwardUnlock
  res.highlighted = highlighted ?? isCompleteAwardUnlock
  return res
}

let function saveTutorialToCheckReward(mission) {
  let mainGameMode = get_game_mode()
  set_game_mode(GM_TRAINING)  //req to check progress
  let campId = ::get_game_mode_name(GM_TRAINING)
  let missionName = mission.name
  let fullMissionName = $"{mission.getStr("chapter", campId)}/{missionName}"
  let progress = ::get_mission_progress(fullMissionName)
  let isComplete = progress >= 0 && progress < 3

  let rBlk = get_pve_awards_blk()
  let dataBlk = rBlk?[::get_game_mode_name(GM_TRAINING)]
  let misDataBlk = dataBlk?[missionName]
  let resource = misDataBlk?.decal
  let resourceType = "decal"
  let isResourceUnlocked = getDecoratorByResource(resource, resourceType)?.isUnlocked() ?? false

  tutorialRewardData({
    missionName
    progress
    fullMissionName
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
  set_game_mode(mainGameMode)
}

let isRequireFeature = @(data, featureId) (featureId in data) && !hasFeature(data[featureId])

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

  let mainGameMode = get_game_mode()
  set_game_mode(GM_TRAINING)  //req to check progress
  let campId = ::get_game_mode_name(GM_TRAINING)
  let chapters = get_meta_missions_info_by_chapters(GM_TRAINING)
  foreach (chapter in chapters)
    foreach (m in chapter)
      if (m.name in tutorialsTbl && (misName == null || misName == m.name)) {
        let fullMissionName = $"{m?.chapter ?? campId}/{m.name}"
        let progress = ::get_mission_progress(fullMissionName)
        if (!isRequireFeature(m, "reqFeature")
          && ((diff < 0 && progress == 3) || (diff >= 0 && (progress == 3 || progress < diff)))) // 3 == unlocked, 0-2 - completed at difficulty
            tutorialsTbl[m.name].__update({ mission = m, progress = progress })

        if (misName != null)
          break
      }

  set_game_mode(mainGameMode)

  return tutorialsTbl
}

let function getTutorialRewardMarkup(tutorialData) {
  if (tutorialData.progress != 3) //tutorials have reward only once
    return ""

  let rBlk = get_pve_awards_blk()
  let dataBlk = rBlk?[::get_game_mode_name(GM_TRAINING)]
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
  if (!hasFeature("Tutorials"))
    return null

  let tutorialData = getTutorialsTblWithMissions(diff, misName)?[misName]
  if (tutorialData?.mission == null)
    return null

  return tutorialData
}

let function getSuitableUncompletedTutorialData(unit, diff = -1) {
  if (!hasFeature("Tutorials"))
    return null

  let tutorialsTbl = getTutorialsTblWithMissions(diff)
  local tutorialData = null
  foreach (tutorial in checkTutorialsList) {
    if (isRequireFeature(tutorial, "requiresFeature")
      || tutorialsTbl?[tutorial.tutorial].mission == null
      || !(tutorial?.isShowInPromoBlock ?? false))
      continue

    if (tutorial.suitableForUnit(unit))
      return tutorialsTbl[tutorial.tutorial]

    if (tutorialData == null)
      tutorialData = tutorialsTbl[tutorial.tutorial]
  }

  return tutorialData
}

let function resetTutorialSkip() {
  saveLocalByAccount(skipTutorialBitmaskId, 0)
}

let reqTimeInMode = 60 //req time in mode when no need check tutorial
let function isDiffUnlocked(diff, checkUnitType) {
  //check played before
  for (local d = diff; d < 3; d++)
    if (::my_stats.getTimePlayed(checkUnitType, d) >= reqTimeInMode)
      return true

  let reqName = getReqTutorial(checkUnitType)
  if (reqName == "")
    return true

  let mainGameMode = get_game_mode()
  set_game_mode(GM_TRAINING)  //req to check progress

  let chapters = get_meta_missions_info_by_chapters(GM_TRAINING)
  foreach (chapter in chapters)
    foreach (m in chapter)
      if (reqName == m.name) {
        let fullMissionName = m.getStr("chapter", ::get_game_mode_name(GM_TRAINING)) + "/" + m.name
        let progress = ::get_mission_progress(fullMissionName)
        if (mainGameMode >= 0)
          set_game_mode(mainGameMode)
        return (progress < 3 && progress >= diff) // 3 == unlocked, 0-2 - completed at difficulty
      }
  assert(false, "Error: Not found mission ::req_tutorial_name = " + reqName)
  set_game_mode(mainGameMode)
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

  local msgText = loc((diff == 2) ? "msgbox/req_tutorial_for_real" : "msgbox/req_tutorial_for_hist")
  msgText += "\n\n" + format(loc("msgbox/req_tutorial_for_mode"), loc("difficulty" + diff))

  msgText += "\n<color=@userlogColoredText>" + loc("missions/" + mData.mission.name) + "</color>"

  if (needMsgBox)
    scene_msg_box("req_tutorial_msgbox", null, msgText,
      [
        ["startTutorial", function() {
          mData.mission.setStr("difficulty", ::get_option(USEROPT_DIFFICULTY).values[diff])
          select_mission(mData.mission, true)
          ::current_campaign_mission = mData.mission.name
          saveTutorialToCheckReward(mData.mission)
          handlersManager.animatedSwitchScene(::gui_start_flight)
        }],
        ["cancel", cancelCb]
      ], "cancel")
  else if (cancelCb)
    cancelCb()
  return true
}

addListenersWithoutEnv({
  SignOut = function(_p) {
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