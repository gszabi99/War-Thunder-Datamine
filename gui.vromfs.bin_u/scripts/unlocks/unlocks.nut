from "%scripts/dagui_natives.nut" import get_unlock_type
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/shop/shopCountriesList.nut" import checkCountry

let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getRegionalUnlockProgress, isRegionalUnlock } = require("%scripts/unlocks/regionalUnlocks.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { getUnlockLocName, getSubUnlockLocName, getUnlockDesc, getFullUnlockDesc, getUnlockCondsDescByCfg,
  getUnlockMultDescByCfg, getUnlockMainCondDescByCfg, getUnlockMultDesc, getIconByUnlockBlk,
  getUnlockNameText, getUnlockTypeText, getUnlockCostText, buildUnlockDesc, getUnlockableMedalImage,
  getUnlockIconConfig, getDescriptionByUnlockType
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { getMainProgressCondition, getProgressBarData, loadMainProgressCondition, isNestedUnlockMode,
  loadConditionsFromBlk, getMultipliersTable, isBitModeType, isStreak, isTimeRangeCondition
} = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockProgress } = require("unlocks")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnlockCost, getUnlockRewardCost, hasSpecialMultiStageLocId, hasMultiStageLocId,
  getMultiStageLocId, getUnlockType, isUnlockOpened,
  cloneDefaultUnlockData, isUnlockExist, checkAwardsAmountPeerSession
} = require("%scripts/unlocks/unlocksModule.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { isBattleTask, isBattleTaskDone, isBattleTaskExpired, getBattleTaskById,
  getBattleTaskNameById, getDifficultyTypeByTask
} = require("%scripts/unlocks/battleTasks.nut")
let { get_charserver_time_sec } = require("chard")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes, getTypeByUnlockedItemType, getTypeByResourceType } = require("%scripts/customization/types.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { getCrewSpTextIfNotZero } = require("%scripts/crew/crewPointsText.nut")
let { getCrewById } = require("%scripts/slotbar/slotbarState.nut")
let { shopSmokeItems, isItemdefId } = require("%scripts/items/itemsManager.nut")
let { getPlayerRankByCountry } = require("%scripts/user/userInfoStats.nut")
let { getCrewName } = require("%scripts/crew/crew.nut")
let { isStringInteger } = require("%sqstd/string.nut")
let { getRankByExp } = require("%scripts/ranks.nut")

function setImageByUnlockType(config, unlockBlk) {
  let unlockType = get_unlock_type(getTblValue("type", unlockBlk, ""))
  if (unlockType == UNLOCKABLE_MEDAL) {
    if (getTblValue("subType", unlockBlk) == "clan_season_reward") {
      let unlock = ::ClanSeasonPlaceTitle.createFromUnlockBlk(unlockBlk)
      config.iconStyle <- unlock.iconStyle()
      config.iconParams <- unlock.iconParams()
    }
    else
      config.image <- getUnlockableMedalImage(unlockBlk.id)

    return
  }
  else if (unlockBlk?.battlePassSeason != null)
    config.image = "#ui/gameuiskin#item_challenge"

  let decoratorType = getTypeByUnlockedItemType(unlockType)
  if (decoratorType != decoratorTypes.UNKNOWN && !is_in_loading_screen()) {
    let decorator = getDecorator(unlockBlk.id, decoratorType)
    config.image <- decoratorType.getImage(decorator)
    config.imgRatio <- decoratorType.getRatio(decorator)
  }
}

function setUnlockIconCfg(cfg, blk) {
  let icon = getIconByUnlockBlk(blk)
  if (icon)
    cfg.image = icon
  else
    setImageByUnlockType(cfg, blk)
}

function setRewardIconCfg(cfg, blk, unlocked) {
  if (!blk?.userLogId)
    return

  let item = ::ItemsManager.findItemById(blk.userLogId)
  if (item?.iType != itemType.TROPHY)
    return

  let content = item.getContent()
  if (content.len() > 1) {
    cfg.iconData <- item.getIcon()
    cfg.isTrophyLocked <- !unlocked
    if (!unlocked)
      cfg.trophyId <- item.id
    return
  }

  let prize = item.getTopPrize()
  if (prize?.unlock && getUnlockType(prize.unlock) ==  UNLOCKABLE_PILOT) {
    cfg.image <- $"#ui/images/avatars/{prize.unlock}.avif"
    cfg.isTrophyLocked <- !unlocked
    return
  }

  if (prize?.resourceType && prize?.resource) {
    let decType = getTypeByResourceType(prize.resourceType)
    let decorator = getDecorator(prize.resource, decType)
    let image = decType.getImage(decorator)
    if (image == "")
      return

    cfg.image <- image
    cfg.isTrophyLocked <- !unlocked
  }
}

let getEmptyConditionsConfig = @() {
  id = ""
  unlockType = -1
  locId = ""
  locDescId = ""
  locStagesDescId = ""
  locMultDescId = ""
  mulArcade = 0
  mulRealistic = 0
  mulHardcore = 0
  useSubUnlockName = false
  hideSubunlocks = false
  curVal = 0
  maxVal = 0
  stages = []
  curStage = -1
  link = ""
  forceExternalBrowser = false
  iconStyle = ""
  iconParams = null
  userLogId = null
  image = ""
  lockStyle = ""
  imgRatio = 1.0
  type = ""
  conditions = []
  hasCustomUnlockableList = false
  manualOpen = false
  isExpired = false
  needToFillStages = true
  needToAddCurStageToName = true
  useLastStageAsUnlockOpening = false
  additionalStagesDescAsItemCountLocId = ""
  additionalStagesDescAsItemCountId = 0
  additionalStagesDescAsItemCountMax = 0
  names = [] //bit progress names. better to rename it.

  showProgress = true
  getProgressBarData = function() {
    let res = getProgressBarData(this.type, this.curVal, this.maxVal)
    res.show = res.show && this.showProgress
    return res
  }
}

::build_conditions_config <- function build_conditions_config(blk, showStage = -1) {
  let id = blk.getStr("id", "")
  let config = getEmptyConditionsConfig()
  config.id = id
  config.imgRatio = blk.getReal("aspect_ratio", 1.0)
  config.userLogId = blk?.userLogId
  config.unlockType = get_unlock_type(blk?.type ?? "")
  config.locId = blk.getStr("locId", "")
  config.locDescId = blk.getStr("locDescId", "")
  config.locStagesDescId = blk.getStr("locStagesDescId", "")
  config.useSubUnlockName = blk?.useSubUnlockName ?? false
  config.hideSubunlocks = blk?.hideSubunlocks ?? false
  config.link = getLocTextFromConfig(blk, "link", "")
  config.forceExternalBrowser = blk?.forceExternalBrowser ?? false
  config.needToFillStages = blk?.needToFillStages ?? true
  config.needToAddCurStageToName = blk?.needToAddCurStageToName ?? true
  config.useLastStageAsUnlockOpening = blk?.useLastStageAsUnlockOpening ?? false
  config.additionalStagesDescAsItemCountLocId = blk?.additionalStagesDescAsItemCountLocId ?? ""
  config.additionalStagesDescAsItemCountId = blk?.additionalStagesDescAsItemCountId ?? 0
  config.additionalStagesDescAsItemCountMax = blk?.additionalStagesDescAsItemCountMax ?? 0
  config.manualOpen = blk?.manualOpen ?? false

  config.iconStyle <- blk?.iconStyle ?? config?.iconStyle
  config.image = blk?.icon ?? ""

  let unlocked = isUnlockOpened(id, config.unlockType)
  if (config.image == "")
    setRewardIconCfg(config, blk, unlocked)
  if (config.image == "" && !config?.iconData)
    setUnlockIconCfg(config, blk)
  if (config.image != "")
    config.lockStyle = blk?.lockStyle ?? "" // lock, darkened, desaturated, none

  config.desc <- getDescriptionByUnlockType(blk)

  if (blk?.isRevenueShare)
    config.isRevenueShare <- true

  if (blk?._puType)
    config._puType <- blk._puType

  foreach (mode in blk % "mode") {
    let modeType = mode?.type ?? ""
    config.type = modeType

    // Custom multiplier description and its associated parameters
    config.locMultDescId = mode?.locMultDescId ?? ""
    config.mulArcade = mode?.mulArcade ?? 0
    config.mulRealistic = mode?.mulRealistic ?? 0
    config.mulHardcore = mode?.mulHardcore ?? 0

    if (config.unlockType == UNLOCKABLE_TROPHY_PSN) {
      //do not show secondary conditions anywhere for psn trophies
      config.conditions = []
      let mainCond = loadMainProgressCondition(mode)
      if (mainCond)
        config.conditions.append(mainCond)
    }
    else
      config.conditions = loadConditionsFromBlk(mode, blk) //-param-pos

    let mainCond = getMainProgressCondition(config.conditions)

    config.hasCustomUnlockableList = getTblValue("hasCustomUnlockableList", mainCond, false)

    if (mainCond && mainCond.values
        && (mainCond.values.len() > 1 || config.hasCustomUnlockableList
        || (isNestedUnlockMode(mainCond.modeType) && isStreak(mainCond.values[0]))))
      config.names = mainCond.values //for easy support old values list

    config.maxVal = mainCond?.num ?? 1
    config.curVal = 0

    if (modeType == "rank")
      config.curVal = getPlayerRankByCountry(config.country)
    else if (isUnlockExist(id)) {
      let progress = isRegionalUnlock(id) ? getRegionalUnlockProgress(id) : getUnlockProgress(id)
      if (modeType == "char_player_exp") {
        config.maxVal = getRankByExp(progress.maxVal)
        config.curVal = getRankByExp(progress.curVal)
      }
      else {
        if (!isBattleTask(id)) {
          if (config.unlockType == UNLOCKABLE_STREAK) {
            config.minVal <- mode?.minVal ?? 0
            config.maxVal = mode?.maxVal ?? 0
            config.multiplier <- getMultipliersTable(mode)
          }
          else {
            config.maxVal = progress.maxVal
          }
        }

        config.curVal = progress.curVal
        config.curStage = (progress?.curStage ?? -1) + 1
      }
    }

    if (isBitModeType(modeType) && mainCond)
      config.curVal = ((1 << mainCond.values.len()) - 1) & config.curVal
    else if (config.curVal > config.maxVal)
      config.curVal = config.maxVal
  }

  if (!unlocked) {
    let cond = config.conditions.findvalue(@(c) isTimeRangeCondition(c.type))
    if (cond)
      config.isExpired = get_charserver_time_sec() >= cond.endTime
  }

  let haveBasicRewards = !blk?.aircraftPresentExtMoneyback
  foreach (stage in blk % "stage") {
    let sData = { val = config.type == "char_player_exp"
                          ? getRankByExp(stage.getInt("param", 1))
                          : stage.getInt("param", 1)
                  }
    if (haveBasicRewards)
      sData.reward <- getUnlockRewardCost(stage)
    config.stages.append(sData)
  }

  if (showStage >= 0 && blk?.isMultiStage) { // isMultiStage means stages are auto-generated (used only for streaks).
    config.curStage = showStage
    config.maxVal = config.stages[0].val + showStage
  }
  else if (showStage >= 0 && showStage < config.stages.len()) {
    config.curStage = showStage
    config.maxVal = config.stages[showStage].val
  }
  else if (config.useLastStageAsUnlockOpening) {
    config.maxVal = config.stages.top().val
    config.curVal = min(config.curVal, config.maxVal)
  }
  else {
    foreach (stage in config.stages)
      if ((stage.val <= config.maxVal && stage.val > config.curVal)
          || (config.curStage < 0 && stage.val == config.maxVal && stage.val == config.curVal)) {
        config.maxVal = stage.val
      }
  }

  if (!isBattleTask(id) && config.unlockType != UNLOCKABLE_STREAK
    && blk?.mode.chardType != null && blk?.mode.num != null) {
    config.maxVal = ((blk?.mode.type ?? "") == "totalMissionScore")
      ? (blk.mode.num / 1000) /*PSEUDO_FLOAT_VALUE_MUL*/ : blk.mode.num
  }

  if (haveBasicRewards) {
    let reward = getUnlockRewardCost(blk)
    if (reward > zero_money)
      config.reward <- reward
  }

  if (config.unlockType == UNLOCKABLE_WARBOND) {
    let wbAmount = blk?.amount_warbonds
    if (wbAmount) {
      config.rewardWarbonds <- {
        wbName = blk?.userLogId ?? id
        wbAmount = wbAmount
      }
    }
  }

  return config
}

::fill_unlock_block <- function fill_unlock_block(obj, config, isForTooltip = false) {
  let { iconStyle, image, ratio, iconParams, iconConfig } = getUnlockIconConfig(config, isForTooltip)
  let hasImage = iconConfig != null || iconStyle != "" || image != ""
  obj.findObject("award_image_sizer").show(hasImage)
  if (hasImage) {
    if (isForTooltip) {
      let icoSize = config?.tooltipImageSize ?? "@profileUnlockIconSize, @profileUnlockIconSize"
      obj.findObject("award_image_sizer").size = icoSize
    }

    let icoObj = obj.findObject("award_image")
    if (config?.isLocked)
      icoObj.effectType = "desaturated"

    LayersIcon.replaceIcon(icoObj, iconStyle, image, ratio, null, iconParams, iconConfig)
  }

  let tObj = obj.findObject("award_title_text")
  tObj.setValue("title" in config ? config.title : "")

  let uObj = obj.findObject("unlock_name")
  uObj.setValue(getTblValue("name", config, ""))

  let amount = getTblValue("amount", config, 1)

  if ("similarAwardNamesList" in config) {
    let maxStreak = getTblValue("maxStreak", config.similarAwardNamesList, 1)
    local repeatText = loc("streaks/rewarded_count", { count = colorize("activeTextColor", amount) })
    if (!hasSpecialMultiStageLocId(config.id, maxStreak))
      repeatText = "\n".concat(format(loc("streaks/max_streak_amount"), maxStreak.tostring()), repeatText)
    obj.findObject("mult_awards_text").setValue(repeatText)
  }

  if (config?.isUnlockDesc ?? false) {
    obj.findObject("desc_text").setValue(getUnlockDesc(config.unlockCfg))
    obj.findObject("mainCond").setValue(getUnlockMainCondDescByCfg(config.unlockCfg))
    obj.findObject("multDesc").setValue(getUnlockMultDescByCfg(config.unlockCfg))
    obj.findObject("conds").setValue(getUnlockCondsDescByCfg(config.unlockCfg))
    obj.findObject("obtain_info").setValue(config?.obtainInfo ?? "")

    if (isForTooltip) {
      let view = ::g_unlock_view.getSubunlocksView(config.unlockCfg)
      if (view) {
        let markup = handyman.renderCached("%gui/unlocks/subunlocks.tpl", view)
        let nestObj = obj.findObject("subunlocks")
        nestObj.show(true)
        obj.getScene().replaceContentFromText(nestObj, markup, markup.len(), this)
      }
    }
  }
  else if (config?.type == UNLOCKABLE_STREAK) {
    local cond = ""
    if (config?.minVal && config.maxVal)
      cond = format(loc("streaks/min_max_limit"), config.minVal, config.maxVal)
    else if (config?.minVal)
      cond = format(loc("streaks/min_limit"), config.minVal)
    else if (config.maxVal)
      cond = format(loc("streaks/max_limit"), config.maxVal)

    let desc = "\n".join([config?.desc ?? "", cond, getUnlockMultDesc(config)], true)
    obj.findObject("desc_text").setValue(desc)
  }
  else
    obj.findObject("desc_text").setValue(config?.desc ?? "")

  if (("progressBar" in config) && config.progressBar.show) {
    let pObj = obj.findObject("progress")
    pObj.setValue(config.progressBar.value)
    pObj.show(true)
  }

  if (config?.showAsTrophyContent) {
    let isUnlocked = isUnlockOpened(config?.id)
    let text = !isUnlocked ? loc("mainmenu/itemCanBeReceived")
      : "\n".concat(loc("mainmenu/itemReceived"), colorize("badTextColor", loc("mainmenu/receiveOnlyOnce")))
    obj.findObject("state").show(true)
    obj.findObject("state_text").setValue(text)
    obj.findObject("state_icon")["background-image"] = isUnlocked ? "#ui/gameuiskin#favorite" : "#ui/gameuiskin#locked.svg"
  }

  let rObj = obj.findObject("award_text")
  rObj.setValue((config?.rewardText ?? "") != ""
    ? $"{loc("challenge/reward")} {config.rewardText}"
    : "")

  let awMultObj = obj.findObject("award_multiplier")
  if (checkObj(awMultObj)) {
    let show = amount > 1
    awMultObj.show(show)
    if (show)
      awMultObj.findObject("amount_text").setValue($"x{amount}")
  }
}

::build_unlock_tooltip_by_config <- function build_unlock_tooltip_by_config(obj, config, handler) {
  let guiScene = obj.getScene()
  guiScene.replaceContent(obj, "%gui/unlocks/unlockBlock.blk", handler)

  obj["min-width"] = "@unlockBlockWidth"

  ::fill_unlock_block(obj, config, true)
}

::build_log_unlock_data <- function build_log_unlock_data(config) {
  let showLocalState = config?.showLocalState ?? true
  let showProgress   = showLocalState && (config?.showProgress ?? false)
  let needTitle      = config?.needTitle ?? true

  let res = cloneDefaultUnlockData()
  let realId = config?.unlockId ?? config?.id ?? ""
  let unlockBlk = getUnlockById(realId)

  local uType = config?.unlockType ?? config?.type ?? -1
  if (uType < 0)
    uType = unlockBlk?.type != null ? get_unlock_type(unlockBlk.type) : -1
  local stage = ("stage" in config) ? config.stage : -1
  let isMultiStage = unlockBlk?.isMultiStage ? true : false // means stages are auto-generated (used only for streaks).
  let id = config?.displayId ?? realId

  res.desc = null
  local unlockCfg = null
  if (unlockBlk) {
    unlockCfg = ::build_conditions_config(unlockBlk, stage)
    let isProgressing = showProgress
      && (stage == -1 || stage == unlockCfg.curStage)
      && unlockCfg.curVal < unlockCfg.maxVal
    let progressData = isProgressing ? unlockCfg.getProgressBarData() : null
    let haveProgress = getTblValue("show", progressData, false)
    if (haveProgress)
      res.progressBar <- progressData
    unlockCfg = buildUnlockDesc(unlockCfg)
    unlockCfg.showProgress = unlockCfg.showProgress && haveProgress
    res.link = unlockCfg.link
    res.forceExternalBrowser = unlockCfg.forceExternalBrowser
  }

  res.id = id
  res.type = uType
  res.rewardText = ""
  res.amount = getTblValue("amount", config, res.amount)

  let battleTask = getBattleTaskById(realId)
  let isTask = isBattleTask(battleTask)
  if (isTask) {
    if (needTitle)
      res.title = loc("unlocks/battletask")
    res.name = getBattleTaskNameById(battleTask)
    res.image = getDifficultyTypeByTask(battleTask).image
    if (isBattleTaskDone(battleTask))
      res.image2 <- "#ui/gameuiskin#icon_primary_ok.svg"
    else if (isBattleTaskExpired(battleTask))
      res.image2 <- "#ui/gameuiskin#icon_primary_fail.svg"
  }
  else {
    res.name = getUnlockNameText(uType, id)
    if (needTitle)
      res.title = getUnlockTypeText(uType, id)
  }

  if (config?.showAsTrophyContent)
    res.showAsTrophyContent <- true

  if (uType == UNLOCKABLE_SKIN || uType == UNLOCKABLE_ATTACHABLE || uType == UNLOCKABLE_DECAL) {
    let decoratorType = getTypeByUnlockedItemType(uType)
    res.image = decoratorType.userlogPurchaseIcon
    res.name = decoratorType.getLocName(id)

    let decorator = getDecorator(id, decoratorType)
    if (decorator && !is_in_loading_screen()) {
      res.image = decoratorType.getImage(decorator)
      res.descrImage <- res.image
      res.descrImageSize <- decoratorType.getImageSize(decorator)
      res.descrImageRatio <- decoratorType.getRatio(decorator)
    }
  }
  else if ( uType == UNLOCKABLE_MEDAL) {
    if (id != "") {
      let imagePath = getUnlockableMedalImage(id)
      res.image = imagePath
      res.descrImage <- imagePath
      res.descrImageSize <- "128, 128"
      res.tooltipImage <- getUnlockableMedalImage(id, true)
      res.tooltipImageSize <- "@profileMedalSize, @profileMedalSize"
    }
  }

  else if ( uType == UNLOCKABLE_CHALLENGE) {
    let challengeDescription = loc($"{id}/desc", "")
    if (challengeDescription && challengeDescription != "")
      res.desc = challengeDescription
    res.image = "#ui/gameuiskin#unlock_challenge"
    res.isLocked <- !isUnlockOpened(id)
  }

  else if ( uType == UNLOCKABLE_SINGLEMISSION) {
    res.image = "#ui/gameuiskin#unlock_mission"
  }

  else if ( uType == UNLOCKABLE_TITLE || uType == UNLOCKABLE_ACHIEVEMENT) {
    let challengeDescription = loc($"{id}/desc", "")
    if (challengeDescription && challengeDescription != "")
      res.desc = challengeDescription
    if (unlockBlk?.battlePassSeason != null) {
      res.descrImage <- "#ui/gameuiskin#item_challenge"
      res.descrImageSize <- "@profileMedalSize, @profileMedalSize"
      res.isLocked <- !isUnlockOpened(id)
    }
    res.image = "#ui/gameuiskin#unlock_achievement"
  }

  else if ( uType == UNLOCKABLE_TROPHY_STEAM) {
    res.image = "#ui/gameuiskin#unlock_achievement"
  }

  else if ( uType == UNLOCKABLE_PILOT) {
    if (id != "") {
      res.descrImage <- $"#ui/images/avatars/{id}.avif"
      res.descrImageSize <- "100, 100"
      res.needFrame <- true
    }
  }

  else if ( uType == UNLOCKABLE_STREAK) {
    local name = loc($"streaks/{id}")
    local desc = loc($"streaks/{id}/desc", "")
    local iconStyle = $"streak_{id}"

    if (isMultiStage && stage >= 0 && unlockBlk?.stage.param != null) {
      res.stage = stage
      local maxStreak = unlockBlk.stage.param.tointeger() + stage
      if ((config?.similarAwards.len() ?? 0) > 0) {
        checkAwardsAmountPeerSession(res, config, maxStreak, name)
        maxStreak = res.similarAwardNamesList.maxStreak
        name = loc($"streaks/{id}/multiple", name)
        desc = loc($"streaks/{id}/multiple/desc", desc)
      }
      else if (hasMultiStageLocId(id)) {
        let stageId = getMultiStageLocId(id, maxStreak)
        name = loc($"streaks/{stageId}")
        iconStyle = $"streak_{stageId}"
      }

      name = format(name, maxStreak)
      desc = format(desc, maxStreak)
    }
    else {
      if (name.indexof("%d") != null)
        name = loc($"streaks/{id}/multiple")
      if (desc.indexof("%d") != null) {
        let descValue = unlockBlk?.stage ? (unlockBlk?.stage.param ?? 0) : (unlockBlk?.mode.num ?? 0)
        if (descValue > 0)
          desc = format(desc, descValue)
        else
          desc = loc($"streaks/{id}/multiple/desc", desc)
      }
    }

    res.name = name
    res.desc = desc
    res.image = "#ui/gameuiskin#unlock_streak"
    res.iconStyle <- iconStyle
    res.minVal <- unlockCfg?.minVal ?? 0
    res.maxVal <- unlockCfg?.maxVal ?? 0
    res.multiplier <- unlockCfg?.multiplier ?? {}
  }

  else if ( uType == UNLOCKABLE_AWARD) {
    if (isTask) {}

    else if (id.contains("ship_flag_")) {
      let decoratorType = decoratorTypes.FLAGS
      res.image = decoratorType.userlogPurchaseIcon
      res.name = decoratorType.getLocName(id)
      let decorator = getDecorator(id, decoratorType)
      if (decorator) {
        res.image = decoratorType.getImage(decorator)
        res.descrImage <- res.image
        res.descrImageSize <- decoratorType.getImageSize(decorator)
        res.descrImageRatio <- decoratorType.getRatio(decorator)
      }
    }
    else {
      res.desc = loc($"award/{id}/desc", "")
      if (id == "money_back") {
        let unitName = config?.unit
        if (unitName)
          res.desc = "".concat(res.desc, (res.desc == "") ? "" : "\n",
            loc("award/money_back/unit", { unitName = getUnitName(unitName) }))
      }
      if (config?.isAerobaticSmoke) {
        res.name = shopSmokeItems.value.findvalue(@(inst) inst.id == config.unlockId)
            ?.getDescriptionTitle() ?? ""
        res.image = "#ui/gameuiskin#item_type_aerobatic_smoke.svg"
      }
    }
  }

  else if ( uType == UNLOCKABLE_AUTOCOUNTRY) {
    res.rewardText = loc("award/autocountry")
  }

  else if ( uType == UNLOCKABLE_SLOT) {
    let slotNum = getTblValue("slot", config, 0)
    res.name = (slotNum > 0)
      ? "".concat(loc("options/crewName"), slotNum)
      : loc("options/crew")
    res.desc = loc($"slot/{id}/desc", "")
    res.image = "#ui/gameuiskin#log_crew"
  }

  else if ( uType == UNLOCKABLE_DYNCAMPAIGN || uType == UNLOCKABLE_YEAR ) {
    if (unlockBlk?.mode.country)
      res.image = getCountryIcon(unlockBlk.mode.country)
  }

  else if ( uType == UNLOCKABLE_SKILLPOINTS) {
    let slotId = getTblValue("slot", config, -1)
    let crew = getCrewById(slotId)
    let crewName = crew ? getCrewName(crew) : loc("options/crew")
    let country = crew ? crew.country : config?.country ?? ""
    let skillPoints = getTblValue("sp", config, 0)
    let skillPointsStr = getCrewSpTextIfNotZero(skillPoints)

    if (checkCountry(country, "userlog EULT_*_CREW"))
      res.image2 = getCountryIcon(country)

    res.desc = "".concat(crewName, loc("unlocks/skillpoints/desc"), skillPointsStr)
    res.image = "#ui/gameuiskin#log_crew"
  }

  else if ( uType == UNLOCKABLE_TROPHY) {
    let item = ::ItemsManager.findItemById(id)
    if (item) {
      res.title = getUnlockTypeText(uType, realId)
      res.name = getUnlockNameText(uType, realId)
      res.image = item.getSmallIconName()
      res.desc = item.getDescription()
      res.rewardText = item.getName()
      let numDecals = item.getContent().filter(@(c) c?.resourceType == "decal").len()
      if (numDecals > 0)
        res.descrImageSize <- $"{0.05 * numDecals}sh, 0.05sh"
    }
  }

  else if ( uType == UNLOCKABLE_INVENTORY) {
    let itemId = isStringInteger(id) ? id.tointeger() : id
    let item = isItemdefId(itemId) ? ::ItemsManager.getItemOrRecipeBundleById(itemId) : null
    if (item) {
      res.title = getUnlockTypeText(uType, realId)
      res.name = item.getName()
      res.image = item.getSmallIconName()
      res.desc = item.getDescription()
      res.descrImageSize <- "1@smallItemHeight, 1@smallItemHeight"
    }
  }

  else if ( uType == UNLOCKABLE_WARBOND) {
    let wbAmount = config?.warbonds
    let wbStageName = config?.warbondStageName
    let wb = ::g_warbonds.findWarbond(id, wbStageName)
    if (wb != null && wbAmount != null)
      res.rewardText = wb.getPriceText(wbAmount, true, false)
  }

  else if ( uType == UNLOCKABLE_AIRCRAFT) {
    let unit = getAircraftByName(id)
    if (unit)
      res.image = unit.getUnlockImage()
  }

  if (unlockBlk?.useSubUnlockName)
    res.name = getSubUnlockLocName(unlockBlk)
  else if (unlockBlk?.locId)
    res.name = getUnlockLocName(unlockBlk)

  if ((unlockBlk?.customDescription ?? "") != "")
    res.desc = loc(unlockBlk.customDescription, "")

  if (res.desc == null) {
    let unlockDesc = unlockCfg ? getFullUnlockDesc(unlockCfg) : ""
    if (unlockDesc != "") {
      res.desc = unlockDesc
      res.isUnlockDesc <- true
      res.unlockCfg <- unlockCfg
    }
    else
      res.desc = (id != realId) ? loc($"{id}/desc", "") : ""
  }

  if (uType == UNLOCKABLE_PILOT
      && (unlockBlk?.marketplaceItemdefId || !getUnlockCost(unlockBlk.id).isZero())
      && id != "" && !isUnlockOpened(id)) {
    res.obtainInfo <- unlockBlk?.marketplaceItemdefId
      ? colorize("userlogColoredText", loc("shop/pilot/coupon/info"))
      : getUnlockCostText(unlockCfg)
    res.desc = "\n".join([res.desc, res.obtainInfo], true)
  }

  let rewards = { wp = "amount_warpoints", exp = "amount_exp", gold = "amount_gold" }
  local rewardsWasLoadedFromLog = false;
  foreach (nameInConfig, _nameInBlk in rewards) //try load rewards data from log first because
    if (nameInConfig in config) {                //award message can haven't appropriate unlock
      res[nameInConfig] = config[nameInConfig]
      rewardsWasLoadedFromLog = true;
    }
  if ("exp" in config) {
    res.frp = config.exp
    rewardsWasLoadedFromLog = true;
  }

  if ("userLogId" in config) {
    let itemId = config.userLogId
    let item = ::ItemsManager.findItemById(itemId)
    if (item)
      res.rewardText = "".concat(res.rewardText, item.getName(), "\n", item.getNameMarkup())
  }

  //check rewards and stages
  if (unlockBlk) {
    local rBlock = DataBlock()
    rewardsWasLoadedFromLog = rewardsWasLoadedFromLog || unlockBlk?.aircraftPresentExtMoneyback == true

    // stage >= 0 means there are stages.
    // isMultiStage=false means stages are hard-coded (usually used for challenges and achievements).
    // isMultiStage=true means stages are auto-generated (usually used only for streaks).
    // there are streaks with stages and isMultiStage=false and they should have own name, icon, etc
    if (stage >= 0 && !isMultiStage && uType != UNLOCKABLE_STREAK) {
      local curStage = -1
      for (local j = 0; j < unlockBlk.blockCount(); j++) {
        let sBlock = unlockBlk.getBlock(j)
        if (sBlock.getBlockName() != "stage")
          continue

        curStage++
        if (curStage == stage) {
          rBlock = sBlock
          if (unlockCfg.needToAddCurStageToName)
            res.name = $"{res.name} {get_roman_numeral(stage + 1)}"
          res.stage <- stage
          res.unlocked <- true
          res.iconStyle <- "default_unlocked"
        }
        else if (curStage > stage) {
          if (stage >= 0) {
            res.unlocked = false
            res.iconStyle <- $"default_locked_stage_{stage + 1}"
          }
          break
        }
      }
      if (curStage != stage)
        stage = -1
    }
    if (stage < 0)  //no stages
      rBlock = unlockBlk

    if (rBlock?.iconStyle)
      res.iconStyle <- rBlock.iconStyle

    if (getTblValue("descrImage", res, "") == "") {
      let icon = getIconByUnlockBlk(unlockBlk)
      if (icon)
        res.descrImage <- icon
      else if (getTblValue("iconStyle", res, "") == "")
        res.iconStyle <- !showLocalState || isUnlockOpened(id, uType) ? "default_unlocked"
          : "default_locked"
    }

    if (!rewardsWasLoadedFromLog) {
      foreach (nameInConfig, nameInBlk in rewards) {
        res[nameInConfig] = rBlock?[nameInBlk] ?? 0
        if (type(res[nameInConfig]) == "instance")
          res[nameInConfig] = res[nameInConfig].x
      }
      if (rBlock?.amount_exp)
        res.frp = (type(rBlock.amount_exp) == "instance") ? rBlock.amount_exp.x : rBlock.amount_exp
    }

    let popupImage = getLocTextFromConfig(rBlock, "popupImage", "")
    if (popupImage != "")
      res.popupImage <- popupImage
  }

  if (showLocalState) {
    let cost = Cost(getTblValue("wp", res, 0),
                        getTblValue("gold", res, 0),
                        getTblValue("frp", res, 0),
                        getTblValue("rp", res, 0))

    res.rewardText = colorize("activeTextColor", $"{res.rewardText}{cost.tostring()}")
    res.showShareBtn <- true
  }

  if ("miscMsg" in config) //for misc params from userlog
    res.miscParam <- config.miscMsg

  if ("tooltipImageSize" in config)
    res.tooltipImageSize <- config.tooltipImageSize

  return res
}