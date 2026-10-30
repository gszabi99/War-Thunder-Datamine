import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/tutorials/tutorialsData.nut" import tutorialRewardData, clearTutorialRewardData
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/customization/decoratorGetters.nut" import getDecoratorByResource
from "%scripts/missions/missionsUtilsModule.nut" import getMissionRewardsMarkup
from "%scripts/customization/contentPreview.nut" import canStartPreviewScene, getDecoratorDataToUse, useDecorator
from "%scripts/debriefing/debriefingFull.nut" import getMoneyFromDebriefingResult, setDebriefingResult
from "%scripts/debriefing/checkRankUpWindow.nut" import checkRankUpWindow
from "%scripts/options/countryFlagsPreset.nut" import getCountryFlagImg
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/firstChoice/firstChoice.nut" import checkUnlockedCountries
from "%scripts/unlocks/unlocksModule.nut" import isAnyAwardReceivedByModeType
from "%scripts/user/userInfoStats.nut" import getPlayerRankByCountry
from "%scripts/slotbar/crewsList.nut" import invalidateCrewsList
from "%scripts/slotbar/slotbarState.nut" import reinitAllSlotbars
from "%scripts/userLog/userlogUtils.nut" import getUserLogsList
from "%scripts/user/newbieTutorialDisplay.nut" import needShowTutorial
from "console" import register_command
from "mission" import set_game_mode, get_game_mode
from "blkGetters" import get_pve_awards_blk
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_natives.nut" import get_game_mode_name, get_mission_progress
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { reqTutorial } = require("%scripts/tutorials/tutorialsState.nut")
let safeAreaMenu = require("%scripts/options/safeAreaMenu.nut")

register_command(
  function (misName) {

    if(checkTutorialsList.filter(@(t) t.tutorial == misName).len() == 0)
      return

    let dataBlk = get_pve_awards_blk()?[get_game_mode_name(GM_TRAINING)]
    let rewardsConfig = [{
      rewardMoney = getMoneyFromDebriefingResult()
      hasRewardImage = false
      isBaseReward = true
      needVerticalAlign = true
    }]
    setDebriefingResult(null)
    return loadHandler(get_gui_handler("TutorialRewardHandler"),
      {
        rewardMarkup = getMissionRewardsMarkup(dataBlk ?? DataBlock(), misName, rewardsConfig)
        misName
        afterRewardText = dataBlk?[misName].rewardWndInfoText ?? ""
        decorator = null
      })
  },
  "ui.debug_tutorial_reward"
)

local TutorialRewardHandler = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL

  sceneBlkName = "%gui/tutorials/tutorialReward.blk"
  misName = ""
  rewardMarkup = ""
  afterRewardText = ""
  decorator = null
  decoratorUnit = null
  decoratorSlot = null

  function initScreen() {
    this.scene.findObject("award_name").setValue(loc("mainmenu/btnTutorial"))

    let descObj = this.scene.findObject("award_desc")
    descObj["text-align"] = "center"

    let msgText = colorize("activeTextColor",
      "\n".concat(loc("MISSION_SUCCESS"), loc($"missions/{this.misName}", "")))
    descObj.setValue(msgText)

    if (this.rewardMarkup != "") {
      let rewardsObj = this.scene.findObject("reward_markup")
      this.guiScene.replaceContentFromText(rewardsObj, this.rewardMarkup, this.rewardMarkup.len(), this)
      rewardsObj.show(true)
    }

    this.updateDecoratorButton()
    if (this.decorator != null) { 
      let decoratorId = this.decorator.id
      getUserLogsList({
        show = [EULT_NEW_UNLOCK]
        disableVisible = true
        checkFunc = @(userlog) decoratorId == (userlog?.body.unlockId ?? "")
      })
    }

    foreach (t in checkTutorialsList)
      if (t.tutorial == this.misName) {
        let image = getCountryFlagImg($"tutorial_{t.id}_win")
        if (image == "")
          continue

        this.scene.findObject("award_image")["background-image"] = image
        break
      }

    if (!isAnyAwardReceivedByModeType("char_versus_battles_end_count_and_rank_test"))
      this.afterRewardText = loc("award/tutorial_fighter_next_award/desc")

    let nObj = this.scene.findObject("next_award")
    if (checkObj(nObj))
      nObj.setValue(this.afterRewardText)

    this.guiScene.applyPendingChanges(false)

    let window_height = this.scene.findObject("reward_frame").getSize()[1]
    let safe_height = safeAreaMenu.getSafearea()[1] * screen_height()

    if (window_height > safe_height) {
      let award_image = this.scene.findObject("award_image")
      let image_height = award_image.getSize()[1]
      let image_new_height = image_height - (window_height - safe_height)
      let k = image_new_height / image_height
      let image_reduce_height = (image_height - image_new_height) / 2
      award_image["height"] = "{0}pw".subst(k * 0.75)
      award_image["background-position"] = "0, {0}, 0, {1}".subst(image_reduce_height, image_reduce_height)
      award_image["background-repeat"] = "part"
    }
  }

  function onOk() {
    this.goBack()
  }

  onUseDecorator = @() useDecorator(this.decorator, this.decoratorUnit, this.decoratorSlot)

  function updateDecoratorButton() {
    let canUseDecoratorInTutorial = !needShowTutorial("countryChoice", 1)
    local canUseDecorator = this.decorator != null && canUseDecoratorInTutorial && canStartPreviewScene(false)
    let obj = showObjById("btn_use_decorator", canUseDecorator, this.scene)
    if (!canUseDecorator)
      return

    let resourceType = this.decorator.decoratorType.resourceType
    let decorData = getDecoratorDataToUse(this.decorator.id, resourceType)
    canUseDecorator = decorData.decorator != null
    obj?.show(canUseDecorator)
    if (!canUseDecorator)
      return

    this.decoratorUnit = decorData.decoratorUnit
    this.decoratorSlot = decorData.decoratorSlot
    if (obj?.isValid() ?? false)
      obj.setValue(loc($"decorator/use/{resourceType}"))
  }

  function onEventHangarModelLoaded(_params = {}) {
    this.updateDecoratorButton()
  }
}

register_gui_handler("TutorialRewardHandler", TutorialRewardHandler)

function tryOpenTutorialRewardHandler() {
  if (tutorialRewardData.get() == null)
    return false

  let mainGameMode = get_game_mode()
  set_game_mode(GM_TRAINING)  
  let progress = get_mission_progress(tutorialRewardData.get().fullMissionName)
  set_game_mode(mainGameMode)

  let decorator = getDecoratorByResource(
    tutorialRewardData.get().resource,
    tutorialRewardData.get().resourceType)
  let hasDecoratorUnlocked = !tutorialRewardData.get().isResourceUnlocked && (decorator?.isUnlocked() ?? false)

  local newCountries = null
  if (progress != tutorialRewardData.get().progress || hasDecoratorUnlocked) {
    let misName = tutorialRewardData.get().missionName

    if ((tutorialRewardData.get().progress >= 3 && progress >= 0 && progress < 3) || hasDecoratorUnlocked) {
      let rBlk = get_pve_awards_blk()
      let dataBlk = rBlk?[get_game_mode_name(GM_TRAINING)]
      let miscText = dataBlk?[misName].rewardWndInfoText ?? ""
      let firstCompletRewardData = tutorialRewardData.get().firstCompletRewardData
      let hasSlotReward = firstCompletRewardData.slotReward != ""
      if (hasSlotReward) {
        invalidateCrewsList()
        reinitAllSlotbars()
      }

      let reward = getMoneyFromDebriefingResult()
      let rewardsConfig = [{
        rewardMoney = reward
        hasRewardImage = false
        isBaseReward = true
        needVerticalAlign = true
      }]
      setDebriefingResult(null)
      if (firstCompletRewardData.hasReward && !firstCompletRewardData.isComplete)
        rewardsConfig.append(firstCompletRewardData)

      loadHandler(TutorialRewardHandler, {
        misName = misName
        decorator = decorator
        rewardMarkup = getMissionRewardsMarkup(dataBlk ?? DataBlock(), misName, rewardsConfig)
        afterRewardText = loc(miscText)
      })
    }

    if (u.search(reqTutorial, @(val) val == misName) != null) {
      newCountries = checkUnlockedCountries()
      foreach (c in newCountries)
        checkRankUpWindow(c, -1, getPlayerRankByCountry(c))
    }
  }

  clearTutorialRewardData()
  return newCountries && newCountries.len() > 0 
}

return freeze({
  tryOpenTutorialRewardHandler = tryOpenTutorialRewardHandler
})
