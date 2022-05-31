let { checkTutorialsList, reqTutorial, tutorialRewardData, clearTutorialRewardData
} = require("%scripts/tutorials/tutorialsData.nut")
let { getMissionRewardsMarkup } = require("%scripts/missions/missionsUtilsModule.nut")
let { canStartPreviewScene, getDecoratorDataToUse, useDecorator } = require("%scripts/customization/contentPreview.nut")
let { getMoneyFromDebriefingResult } = require("%scripts/debriefing/debriefingFull.nut")
let { checkRankUpWindow } = require("%scripts/debriefing/rankUpModal.nut")

local TutorialRewardHandler = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"

  misName = ""
  rewardMarkup = ""
  afterRewardText = ""
  decorator = null
  decoratorUnit = null
  decoratorSlot = null

  function initScreen() {
    scene.findObject("award_name").setValue(::loc("mainmenu/btnTutorial"))

    let descObj = scene.findObject("award_desc")
    descObj["text-align"] = "center"

    let msgText = ::colorize("activeTextColor", ::loc("MISSION_SUCCESS") + "\n" + ::loc("missions/" + misName, ""))
    descObj.setValue(msgText)

    if (rewardMarkup != "") {
      let rewardsObj = scene.findObject("reward_markup")
      guiScene.replaceContentFromText(rewardsObj, rewardMarkup, rewardMarkup.len(), this)
      rewardsObj.show(true)
    }

    updateDecoratorButton()
    if (decorator != null) { //Not show new unlock window
      let decoratorId = decorator.id
      ::getUserLogsList({
        show = [::EULT_NEW_UNLOCK]
        disableVisible = true
        checkFunc = @(userlog) decoratorId == (userlog?.body.unlockId ?? "")
      })
    }

    foreach(t in checkTutorialsList)
      if (t.tutorial == misName)
      {
        let image = ::get_country_flag_img("tutorial_" + t.id + "_win")
        if (image == "")
          continue

        scene.findObject("award_image")["background-image"] = image
        break
      }

    if (!::is_any_award_received_by_mode_type("char_versus_battles_end_count_and_rank_test"))
      afterRewardText = ::loc("award/tutorial_fighter_next_award/desc")

    let nObj = scene.findObject("next_award")
    if (::checkObj(nObj))
      nObj.setValue(afterRewardText)
  }

  function onOk() {
    goBack()
  }

  onUseDecorator = @() useDecorator(decorator, decoratorUnit, decoratorSlot)

  function updateDecoratorButton() {
    local canUseDecorator = decorator != null && canStartPreviewScene(false)
    let obj = showSceneBtn("btn_use_decorator", canUseDecorator)
    if (!canUseDecorator)
      return

    let resourceType = decorator.decoratorType.resourceType
    let decorData = getDecoratorDataToUse(decorator.id, resourceType)
    canUseDecorator = decorData.decorator != null
    obj?.show(canUseDecorator)
    if (!canUseDecorator)
      return

    decoratorUnit = decorData.decoratorUnit
    decoratorSlot = decorData.decoratorSlot
    if (obj?.isValid ?? false)
      obj.setValue(::loc($"decorator/use/{resourceType}"))
  }

  function onEventHangarModelLoaded(params = {}) {
    updateDecoratorButton()
  }

  function onUnitActivate() {}
}

::gui_handlers.TutorialRewardHandler <- TutorialRewardHandler

let function tryOpenTutorialRewardHandler() {
  if (tutorialRewardData.value == null)
    return false

  let mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  let progress = ::get_mission_progress(tutorialRewardData.value.fullMissionName)
  ::set_mp_mode(mainGameMode)

  if (tutorialRewardData.value.presetFilename != "")
    ::apply_joy_preset_xchange(tutorialRewardData.value.presetFilename)

  let decorator = ::g_decorator.getDecoratorByResource(
    tutorialRewardData.value.resource,
    tutorialRewardData.value.resourceType)
  let hasDecoratorUnlocked = !tutorialRewardData.value.isResourceUnlocked && (decorator?.isUnlocked() ?? false)

  local newCountries = null
  if (progress!=tutorialRewardData.value.progress || hasDecoratorUnlocked)
  {
    let misName = tutorialRewardData.value.missionName

    if ((tutorialRewardData.value.progress>=3 && progress>=0 && progress<3) || hasDecoratorUnlocked)
    {
      let rBlk = ::get_pve_awards_blk()
      let dataBlk = rBlk?[::get_game_mode_name(::GM_TRAINING)]
      let miscText = dataBlk?[misName].rewardWndInfoText ?? ""
      let firstCompletRewardData = tutorialRewardData.value.firstCompletRewardData
      let hasSlotReward = firstCompletRewardData.slotReward != ""
      if (hasSlotReward)
      {
        ::g_crews_list.invalidate()
        ::reinitAllSlotbars()
      }

      let reward = getMoneyFromDebriefingResult()
      let rewardsConfig = [{
        rewardMoney = reward
        hasRewardImage = false
        isBaseReward = true
        needVerticalAlign = true
      }]

      if (firstCompletRewardData.hasReward && !firstCompletRewardData.isComplete)
        rewardsConfig.append(firstCompletRewardData)

      ::gui_start_modal_wnd(::gui_handlers.TutorialRewardHandler,
      {
        misName = misName
        decorator = decorator
        rewardMarkup = getMissionRewardsMarkup(dataBlk ?? ::DataBlock(), misName, rewardsConfig)
        afterRewardText = ::loc(miscText)
      })
    }

    if (::u.search(reqTutorial, @(val) val == misName) != null)
    {
      newCountries = checkUnlockedCountries()
      foreach(c in newCountries)
        checkRankUpWindow(c, -1, ::get_player_rank_by_country(c))
    }
  }

  clearTutorialRewardData()
  return newCountries && newCountries.len() > 0 //is new countries unlocked by tutorial?
}

return {
  tryOpenTutorialRewardHandler = tryOpenTutorialRewardHandler
}