let stdMath = require("%sqstd/math.nut")
let { skipTutorialBitmaskId, checkTutorialsList, saveTutorialToCheckReward,
  launchedTutorialQuestionsPeerSession, setLaunchedTutorialQuestionsValue,
  getUncompletedTutorialData, getTutorialRewardMarkup, getSuitableUncompletedTutorialData
} = require("%scripts/tutorials/tutorialsData.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

const NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID = "statistic:new_player_tutorial_choice"

::dagui_propid.add_name_id("userInputType")

local NextTutorialHandler = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/nextTutorial.blk"

  tutorialMission = null
  rewardMarkup = ""
  checkIdx = 0
  canSkipTutorial = true

  function initScreen()
  {
    if (!tutorialMission)
      return goBack()

    let msgText = ::g_string.implode([
      ::loc("askPlayTutorial"),
      ::colorize("userlogColoredText", ::loc($"missions/{tutorialMission.name}")),
    ], "\n")

    scene.findObject("msgText").setValue(msgText)

    if (rewardMarkup != "") {
      let rewardsObj = scene.findObject("rewards")
      guiScene.replaceContentFromText(rewardsObj, rewardMarkup, rewardMarkup.len(), this)
      rewardsObj.show(true)
    }

    canSkipTutorial = true
    if (checkIdx in checkTutorialsList)
    {
      let tutorialBlock = checkTutorialsList[checkIdx]
      let image = ::get_country_flag_img("tutorial_" + tutorialBlock.id)
      if (image != "")
        scene.findObject("tutorial_image")["background-image"] = image
      if ("canSkipByFeature" in tutorialBlock)
        canSkipTutorial = ::has_feature(tutorialBlock.canSkipByFeature)
      if (!canSkipTutorial)
        canSkipTutorial = ::loadLocalByAccount("firstRunTutorial_"+tutorialMission.name, false)
    }
    foreach (name in ["skip_tutorial", "btn_close_tutorial"])
    {
      let obj = scene.findObject(name)
      if (obj)
        obj.show(canSkipTutorial)
    }
    if (canSkipTutorial)
    {
      let obj = scene.findObject("skip_tutorial")
      if (::checkObj(obj))
      {
        let skipTutorial = ::loadLocalByAccount(skipTutorialBitmaskId, 0)
        obj.setValue(stdMath.is_bit_set(skipTutorial, checkIdx))
      }
    }
  }

  function onStart(obj = null)
  {
    sendTutorialChoiceStatisticOnce("start", obj)
    saveTutorialToCheckReward(tutorialMission)
    ::saveLocalByAccount("firstRunTutorial_"+tutorialMission.name, true)
    setLaunchedTutorialQuestions()
    ::destroy_session_scripted()

    ::set_mp_mode(::GM_TRAINING)
    ::select_mission(tutorialMission, true)
    ::current_campaign_mission = tutorialMission.name
    guiScene.performDelayed(this, function(){ goForward(::gui_start_flight); })
    ::save_profile(false)
  }

  function onClose(obj = null)
  {
    if( ! canSkipTutorial)
      return;
    sendTutorialChoiceStatisticOnce("close", obj)
    setLaunchedTutorialQuestions()
    goBack()
  }

  function sendTutorialChoiceStatisticOnce(action, obj = null)
  {
    if(::loadLocalByAccount(NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID, false))
      return
    let info = {
                  action = action,
                  reminder = stdMath.is_bit_set(::loadLocalByAccount(skipTutorialBitmaskId, 0), checkIdx) ? "off" : "on"
                  missionName = tutorialMission.name
                  }
    if(obj != null)
      info["input"] <- getObjectUserInputType(obj)
    ::add_big_query_record ("new_player_tutorial_choice", ::save_to_json(info))
    ::saveLocalByAccount(NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID, true)
  }

  function onSkipTutorial(obj)
  {
    if (!obj)
      return

    local skipTutorial = ::loadLocalByAccount(skipTutorialBitmaskId, 0)
    skipTutorial = stdMath.change_bit(skipTutorial, checkIdx, obj.getValue())
    ::saveLocalByAccount(skipTutorialBitmaskId, skipTutorial)
  }

  function getObjectUserInputType(obj)
  {
    let VALID_INPUT_LIST = ["mouse", "keyboard", "gamepad"]
    let userInputType = obj?.userInputType ?? ""
    if(::isInArray(userInputType, VALID_INPUT_LIST))
      return userInputType
    return "invalid"
  }

  setLaunchedTutorialQuestions = @() setLaunchedTutorialQuestionsValue(launchedTutorialQuestionsPeerSession.value | (1 << checkIdx))
}

::gui_handlers.NextTutorialHandler <- NextTutorialHandler

let function tryOpenNextTutorialHandler(checkId, checkSkip = true) {
  local idx = -1
  local mData = null
  foreach(i, item in checkTutorialsList)
    if (item.id == checkId)
    {
      if (("requiresFeature" in item) && !::has_feature(item.requiresFeature))
        return false

      mData = getUncompletedTutorialData(item.tutorial)
      if (!mData)
        return false

      if ((launchedTutorialQuestionsPeerSession.value & (1 << i)) && checkSkip)
        return false

      idx = i
      break
    }

  if (!mData)
    return false

  if (checkSkip)
  {
    let skipTutorial = ::loadLocalByAccount(skipTutorialBitmaskId, 0)
    if (stdMath.is_bit_set(skipTutorial, idx))
      return false
  }

  ::handlersManager.loadHandler(NextTutorialHandler, {
    tutorialMission = mData.mission
    rewardMarkup = getTutorialRewardMarkup(mData)
    checkIdx = idx
  })

  return true
}

let function onOpenTutorialFromPromo(owner, params = []) {
  local tutorialId = ""
  if (::u.isString(params))
    tutorialId = params
  else if (::u.isArray(params) && params.len() > 0)
    tutorialId = params[0]

  owner.checkedNewFlight(function() {
    if (!tryOpenNextTutorialHandler(tutorialId, false))
      ::gui_start_tutorial()
  })
}

let function getTutorialData() {
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

local function getTutorialButtonText(tutorialMission = null) {
  tutorialMission = tutorialMission ?? getTutorialData()?.tutorialMission
  return tutorialMission != null
    ? ::loc("missions/" + (tutorialMission?.name ?? "") + "/short", "")
    : ::loc("mainmenu/btnTutorial")
}

addPromoAction("tutorial", @(handler, params, obj) onOpenTutorialFromPromo(handler, params))

let promoButtonId = "tutorial_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = getTutorialButtonText
  collapsedIcon = ::loc("icon/tutorial")
  updateFunctionInHandler = function() {
    let tutorialData = getTutorialData()
    let tutorialMission = tutorialData?.tutorialMission
    let tutorialId = ::getTblValue("tutorialId", tutorialData)

    let id = promoButtonId
    let actionKey = ::g_promo.getActionParamsKey(id)
    ::g_promo.setActionParamsData(actionKey, "tutorial", [tutorialId])

    local buttonObj = null
    local show = isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = ::showBtn(id, show, scene)
    else
    {
      show = tutorialMission != null && ::g_promo.getVisibilityById(id)
      buttonObj = ::showBtn(id, show, scene)
    }

    if (!show || !::checkObj(buttonObj))
      return

    ::g_promo.setButtonText(buttonObj, id, getTutorialButtonText(tutorialMission))
  }
  updateByEvents = ["HangarModelLoaded"]
})

return {
  tryOpenNextTutorialHandler = tryOpenNextTutorialHandler
}