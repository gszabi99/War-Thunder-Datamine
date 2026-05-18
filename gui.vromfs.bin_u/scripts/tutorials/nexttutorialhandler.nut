from "%scripts/dagui_library.nut" import *
let { save_profile } = require("chard")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkTutorialsList, saveTutorialToCheckReward,
  launchedTutorialQuestionsPeerSession, setLaunchedTutorialQuestionsValue,
  getUncompletedTutorialData, getTutorialRewardMarkup, getSuitableUncompletedTutorialData
} = require("%scripts/tutorials/tutorialsData.nut")
let { skipTutorialBitmaskId } = require("%scripts/tutorials/tutorialsState.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let { set_game_mode } = require("mission")
let { select_mission } = require("guiMission")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { setPromoButtonText, getPromoActionParamsKey, setPromoActionsParamsData,
  getPromoVisibilityById
} = require("%scripts/promo/promo.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { guiStartTutorial, guiStartFlight
} = require("%scripts/missions/startMissionsList.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")

const NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID = "statistic:new_player_tutorial_choice"

dagui_propid_add_name_id("userInputType")


function sendTutorialChoiceStatisticOnce(action, idx, missionName, input) {
  if (loadLocalByAccount(NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID, false))
    return

  let skipMask = loadLocalByAccount(skipTutorialBitmaskId, 0)
  let info = { action, missionName, input,
    reminder = stdMath.is_bit_set(skipMask, idx) ? "off" : "on"
  }
  sendBqEvent("CLIENT_GAMEPLAY_1", "new_player_tutorial_choice", info)
  saveLocalByAccount(NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID, true)
}

let setLaunchedTutorialQuestions = @(idx)
  setLaunchedTutorialQuestionsValue(launchedTutorialQuestionsPeerSession.get() | (1 << idx))

function prepareStartTutorial(idx, mission, input) {
  sendTutorialChoiceStatisticOnce("start", idx, mission.name, input)
  saveTutorialToCheckReward(mission)
  saveLocalByAccount($"firstRunTutorial_{mission.name}", true)
  setLaunchedTutorialQuestions(idx)
  destroySessionScripted("on start tutorial")
  set_game_mode(GM_TRAINING)
  select_mission(mission, true)
  currentCampaignMission.set(mission.name)
  save_profile(false)
}

local NextTutorialHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/nextTutorial.blk"

  tutorialMission = null
  rewardMarkup = ""
  checkIdx = 0
  canSkipTutorial = true

  function initScreen() {
    if (!this.tutorialMission)
      return this.goBack()

    let msgText = "\n".join([
      loc("askPlayTutorial"),
      colorize("userlogColoredText", loc($"missions/{this.tutorialMission.name}")),
    ], true)

    this.scene.findObject("msgText").setValue(msgText)

    if (this.rewardMarkup != "") {
      let rewardsObj = this.scene.findObject("rewards")
      this.guiScene.replaceContentFromText(rewardsObj, this.rewardMarkup, this.rewardMarkup.len(), this)
      rewardsObj.show(true)
    }

    this.canSkipTutorial = true
    if (this.checkIdx in checkTutorialsList) {
      let tutorialBlock = checkTutorialsList[this.checkIdx]
      let image = getCountryFlagImg($"tutorial_{tutorialBlock.id}")
      if (image != "")
        this.scene.findObject("tutorial_image")["background-image"] = image
      if ("canSkipByFeature" in tutorialBlock)
        this.canSkipTutorial = hasFeature(tutorialBlock.canSkipByFeature)
      if (!this.canSkipTutorial)
        this.canSkipTutorial = loadLocalByAccount($"firstRunTutorial_{this.tutorialMission.name}", false)
    }
    foreach (name in ["skip_tutorial", "btn_close_tutorial"]) {
      let obj = this.scene.findObject(name)
      if (obj)
        obj.show(this.canSkipTutorial)
    }
    if (this.canSkipTutorial) {
      let obj = this.scene.findObject("skip_tutorial")
      if (checkObj(obj)) {
        let skipTutorial = loadLocalByAccount(skipTutorialBitmaskId, 0)
        obj.setValue(stdMath.is_bit_set(skipTutorial, this.checkIdx))
      }
    }
  }

  function onStart(obj = null) {
    let input = obj == null ? "" : this.getObjectUserInputType(obj)
    prepareStartTutorial(this.checkIdx, this.tutorialMission, input)
    this.guiScene.performDelayed(this, function() { this.goForward(guiStartFlight); })
  }

  function onClose(obj = null) {
    if (!this.canSkipTutorial)
      return

    let input = obj == null ? "" : this.getObjectUserInputType(obj)
    sendTutorialChoiceStatisticOnce("close", this.checkIdx, this.tutorialMission.name, input)
    setLaunchedTutorialQuestions(this.checkIdx)
    this.goBack()
  }

  function onSkipTutorial(obj) {
    if (!obj)
      return

    local skipTutorial = loadLocalByAccount(skipTutorialBitmaskId, 0)
    skipTutorial = stdMath.change_bit(skipTutorial, this.checkIdx, obj.getValue())
    saveLocalByAccount(skipTutorialBitmaskId, skipTutorial)
  }

  function getObjectUserInputType(obj) {
    let VALID_INPUT_LIST = ["mouse", "keyboard", "gamepad"]
    let userInputType = obj?.userInputType ?? ""
    if (isInArray(userInputType, VALID_INPUT_LIST))
      return userInputType
    return "invalid"
  }
}

gui_handlers.NextTutorialHandler <- NextTutorialHandler


function autoRunTutorial(idx, mission) {
  prepareStartTutorial(idx, mission, "autostart")
  guiStartFlight()
}

let cantRunNextTutorial = @(checkSkip = true) (checkSkip && hasFeature("BattleAutoStart"))
  || !(topMenuHandler.get()?.isSceneActive() ?? false)

function getSuitableTutorialData(checkId, checkSkip = true) {
  local idx = -1
  local mData = null
  foreach (i, item in checkTutorialsList)
    if (item.id == checkId) {
      if (("requiresFeature" in item) && !hasFeature(item.requiresFeature))
        break

      if ((launchedTutorialQuestionsPeerSession.get() & (1 << i)) && checkSkip)
        break

      mData = getUncompletedTutorialData(item.tutorial)
      if (mData == null)
        break

      idx = i
      break
    }
  return { idx, mData }
}

let isTutorialIdxSkiped = @(idx, checkSkip = true)
  checkSkip ? stdMath.is_bit_set(loadLocalByAccount(skipTutorialBitmaskId, 0), idx) : false

function tryOpenNextTutorialHandler(checkId, checkSkip = true, hasDialog = true) {
  if (cantRunNextTutorial())
    return false

  let { idx = -1, mData = null } = getSuitableTutorialData(checkId, checkSkip)
  if (mData == null)
    return false

  if (isTutorialIdxSkiped(idx, checkSkip))
    return false

  if (hasDialog)
    handlersManager.loadHandler(NextTutorialHandler, {
      tutorialMission = mData.mission
      rewardMarkup = getTutorialRewardMarkup(mData)
      checkIdx = idx
    })
  else
    autoRunTutorial(idx, mData.mission)

  return true
}

function onOpenTutorialFromPromo(owner, params = []) {
  local tutorialId = ""
  if (u.isString(params))
    tutorialId = params
  else if (u.isArray(params) && params.len() > 0)
    tutorialId = params[0]

  owner.checkedNewFlight(function() {
    if (!tryOpenNextTutorialHandler(tutorialId, false))
      guiStartTutorial()
  })
}

function getTutorialData() {
  let curUnit = getShowedUnit()
  let {
    mission = null,
    id = ""
  } = getSuitableUncompletedTutorialData(curUnit, 0)

  return {
    tutorialMission = mission
    tutorialId = id
  }
}

function getTutorialButtonText(tutorialMission = null) {
  tutorialMission = tutorialMission ?? getTutorialData()?.tutorialMission
  return tutorialMission != null
    ? loc($"missions/{tutorialMission?.name ?? ""}/short", "")
    : loc("mainmenu/btnTutorial")
}

addPromoAction("tutorial", @(handler, params, _obj) onOpenTutorialFromPromo(handler, params))

let promoButtonId = "tutorial_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = getTutorialButtonText
  collapsedIconLocKey = "icon/tutorial"
  updateFunctionInHandler = function() {
    let tutorialData = getTutorialData()
    let tutorialMission = tutorialData?.tutorialMission
    let tutorialId = getTblValue("tutorialId", tutorialData)

    let id = promoButtonId
    let actionKey = getPromoActionParamsKey(id)
    setPromoActionsParamsData(actionKey, "tutorial", [tutorialId])

    local buttonObj = null
    local show = this.isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = showObjById(id, show, this.scene)
    else {
      show = tutorialMission != null && getPromoVisibilityById(id)
      buttonObj = showObjById(id, show, this.scene)
    }

    if (!show || !checkObj(buttonObj))
      return

    setPromoButtonText(buttonObj, id, getTutorialButtonText(tutorialMission))
  }
  updateByEvents = ["HangarModelLoaded"]
})

return {
  tryOpenNextTutorialHandler
}
