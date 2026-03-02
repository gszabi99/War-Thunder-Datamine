from "%scripts/dagui_natives.nut" import get_name_by_unlock_type
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/mainConsts.nut" import SEEN
from "%scripts/utils_sa.nut" import roman_numerals, locOrStrip

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { format } = require("string")
let { number_of_set_bits, is_bit_set } = require("%sqstd/math.nut")
let { buildDateTimeStr } = require("%scripts/time.nut")
let { isLoadingBgUnlock } = require("%scripts/loading/loadingBgData.nut")
let { isBitModeType, getMainProgressCondition, getProgressBarData
} = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnlockCost, getUnlockType, isUnlockOpened, canClaimUnlockReward,
  isUnlockVisibleByTime, debugLogVisibleByTimeInfo, canClaimUnlockRewardForUnit,
  isUnlockVisible, hasSpecialMultiStageLocId } = require("%scripts/unlocks/unlocksModule.nut")
let { getDecorator, getDecoratorById } = require("%scripts/customization/decoratorGetters.nut")
let { getViewTypeByUnlockedItemType } = require("%scripts/customization/decoratorViewType.nut")
let { getPlaneBySkinId } = require("%scripts/customization/skinUtils.nut")
let { getUnlockProgressSnapshot } = require("%scripts/unlocks/unlockProgressSnapshots.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { hasActiveUnlock, getUnitListByUnlockId } = require("%scripts/unlocks/unlockMarkers.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { makeConfigStr } = require("%scripts/seen/bhvUnseen.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { decoratorTypes, getTypeByUnlockedItemType, getTypeByResourceType
} = require("%scripts/customization/decoratorBaseType.nut")
let { addTooltipTypes, getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { getWarbondPriceText } = require("%scripts/warbonds/warbondsState.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { activeUnlocks } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasksState.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")


let { buildConditionsConfig, getUnlockDesc, getFullUnlockDescByName, getUnlockMultDescByCfg,
  getUnlockMultDesc, getUnlockCondsDescByCfg, getUnlockCondsDesc, getUnlockMainCondDesc,
  getUnlockMainCondDescByCfg, getLocForBitValues, getUnlockNameText, getSubUnlockLocName,
  getUnlockLocName } = require("%scripts/unlocks/unlocksState.nut")


const MAX_STAGES_NUM = 10 
const SUB_UNLOCKS_COL_COUNT = 4


function getSubunlockCfg(conditions) {
  if (conditions.len() != 1)
    return null

  let cond = conditions[0]
  if (cond?.modeType != "char_unlocks" || cond?.values.len() != 1)
    return null

  let blk = getUnlockById(cond.values[0])
  if (blk?.hidden ?? false)
    return null

  return buildConditionsConfig(blk)
}

function getTooltipMarkupByModeType(config) {
  if (config.type == "char_unit_exist")
    return getTooltipType("UNIT").getMarkup(config.id, { showProgress = true })

  if (isBattleTask(config.id))
    return getTooltipType("BATTLE_TASK").getMarkup(config.id, { showProgress = true })

  if (activeUnlocks.get()?[config.id] != null)
    return getTooltipType("BATTLE_PASS_CHALLENGE").getMarkup(config.id, { showProgress = true })

  return getTooltipType("UNLOCK").getMarkup(config.id, { showProgress = true })
}


function findPreviewablePrize(unlockCfg) {
  if (unlockCfg.userLogId == null)
    return null

  let itemId = unlockCfg.unlockType == UNLOCKABLE_INVENTORY
    ? unlockCfg.userLogId.tointeger()
    : unlockCfg.userLogId
  let item = findItemById(itemId)
  if (item == null)
    return null

  if (item.iType == itemType.VEHICLE
      || item.iType == itemType.ATTACHABLE
      || item.iType == itemType.SKIN
      || item.iType == itemType.DECAL)
    return item

  if (item.iType == itemType.TROPHY) {
    if (item.getContent().len() != 1)
      return null

    let prize = item.getTopPrize()
    if (prize?.unit != null)
      return getAircraftByName(prize.unit)

    if (prize?.resourceType != null && prize?.resource != null) {
      let decType = getTypeByResourceType(prize.resourceType)
      return getDecorator(prize.resource, decType)
    }
  }

  return null
}

let canPreviewUnlockPrize = @(unlockCfg) findPreviewablePrize(unlockCfg)?.canPreview() ?? false
let doPreviewUnlockPrize = @(unlockCfg) findPreviewablePrize(unlockCfg)?.doPreview()


function getUnlockIconConfig(config, isForTooltip = false) {
  let iconStyle = config?.iconStyle ?? ""
  let ratio = (("descrImage" in config) && ("descrImageRatio" in config))
    ? config.descrImageRatio : 1.0
  let iconParams = config?.iconParams
  let iconConfig = config?.iconConfig
  local image = config?.descrImage ?? ""
  if (isForTooltip)
    image = config?.tooltipImage ?? image
  return { iconStyle, image, ratio, iconParams, iconConfig }
}


function getUnlockRewardsText(config) {
  let textsList = []
  if ("reward" in config)
    textsList.append(config.reward.tostring())
  if ("rewardWarbonds" in config)
    textsList.append(getWarbondPriceText(config.rewardWarbonds.wbAmount))
  return ", ".join(textsList, true)
}

function getUnlockTypeText(unlockType, id = null) {
  if (unlockType == UNLOCKABLE_AUTOCOUNTRY)
    return loc("unlocks/country")

  if (id && isBattleTask(id))
    return loc("unlocks/battletask")

  if (id && isLoadingBgUnlock(id))
    return loc("unlocks/loading_bg")

  if (unlockType == -1)
    return ""

  return loc($"unlocks/{get_name_by_unlock_type(unlockType)}")
}


function getUnlockTitle(unlockConfig, params = null) {
  local name = unlockConfig.useSubUnlockName ? getSubUnlockLocName(unlockConfig)
    : unlockConfig.locId != "" ? getUnlockLocName(unlockConfig)
    : getUnlockNameText(unlockConfig.unlockType, unlockConfig.id, params)
  if (name == "")
    name = getUnlockTypeText(unlockConfig.unlockType, unlockConfig.id)

  let hasStages = unlockConfig.stages.len() > 0
  let stage = (unlockConfig.needToAddCurStageToName && hasStages && (unlockConfig.curStage >= 0))
    ? unlockConfig.curStage + (isUnlockOpened(unlockConfig.id) ? 0 : 1)
    : 0

  return (roman_numerals?[stage] ?? "") != ""
    ? $"{name} {roman_numerals[stage]}"
    : name
}

function getUnlockChapterAndGroupText(unlockBlk) {
  let chapterAndGroupText = []
  if ("chapter" in unlockBlk)
    chapterAndGroupText.append(loc($"unlocks/chapter/{unlockBlk.chapter}"))
  if ((unlockBlk?.group ?? "") != "") {
    local locId = $"unlocks/group/{unlockBlk.group}"
    let parentUnlock = getUnlockById(unlockBlk.group)
    if (parentUnlock?.chapter == unlockBlk?.chapter)
      locId = $"{parentUnlock.id}/name"
    chapterAndGroupText.append(loc(locId))
  }
  return chapterAndGroupText.len() > 0
    ? $"({", ".join(chapterAndGroupText, true)})"
    : ""
}


function getUnlockSnapshotText(unlockCfg) {
  let snapshot = getUnlockProgressSnapshot(unlockCfg.id)
  if (!snapshot)
    return ""

  let date = buildDateTimeStr(snapshot.timeSec)
  let delta = isBitModeType(unlockCfg.type)
    ? number_of_set_bits(unlockCfg.curVal) - number_of_set_bits(snapshot.progress)
    : unlockCfg.curVal - snapshot.progress
  return colorize("darkGreen", loc("unlock/progress_snapshot", { delta = max(delta, 0), date }))
}

function getUnlockCostText(cfg) {
  if (!cfg)
    return ""

  let cost = getUnlockCost(cfg.id)
  if (cost > zero_money)
    return "".concat(
      loc("ugm/price"),
      loc("ui/colon"),
      colorize("unlockActiveColor", cost.getTextAccordingToBalance()))

  return ""
}


function getUnlockAdditionalView(unlockId) {
  let unlockBlk = getUnlockById(unlockId)
  if (!unlockBlk || !isUnlockVisible(unlockBlk))
    return {
      isProgressBarVisible = false
      isAddToFavVisible = false
    }

  let unlockConfig = buildConditionsConfig(unlockBlk)
  let unlockDesc = getUnlockMainCondDescByCfg(unlockConfig)

  return {
    unlockId
    unlockProgressDesc = $"({unlockDesc})"
    isProgressBarVisible = true
    progressBarValue = unlockConfig.getProgressBarData().value
    toFavoritesCheckboxVal = isUnlockFav(unlockId) ? "yes" : "no"
  }
}

function getUnlocksListView(config) {
  let res = []

  let namesLoc = getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
  let isBitMode = isBitModeType(config.type)
  let isInteractive = config?.isInteractive ?? true
  let isAddToFavVisible = isInteractive && !config.isOnlyInfo

  foreach (idx, unlockId in config.names) {
    let isEven = idx % 2 == 0
    if (config.type == "char_resources") {
      let decorator = getDecoratorById(unlockId)
      if (decorator && decorator.isVisible())
        res.append({
          isEven
          text = decorator.getName()
          isUnlocked = decorator.isUnlocked()
          tooltipMarkup = getTooltipType("DECORATION").getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
          isAddToFavVisible 
        }.__update(getUnlockAdditionalView(decorator.unlockId)))
    }
    else {
      let unlockBlk = getUnlockById(unlockId)
      if (!unlockBlk || !isUnlockVisible(unlockBlk))
        continue

      let unlockConfig = buildConditionsConfig(unlockBlk)
      let isUnlocked = isBitMode ? is_bit_set(config.curVal, idx) : isUnlockOpened(unlockId)
      let unlockName = namesLoc[idx]
      res.append({
        isEven
        isUnlocked
        text = unlockName
        tooltipMarkup = getTooltipMarkupByModeType(unlockConfig)
        isAddToFavVisible
      }.__update(getUnlockAdditionalView(unlockId)))
    }
  }

  return res
}


function getFullUnlockCondsDesc(conds, curVal = null, maxVal = null, params = null) {
  if (!conds)
    return ""

  let mainCond = getMainProgressCondition(conds)
  return "\n".join([
    getUnlockMainCondDesc(mainCond, curVal, maxVal, params),
    getUnlockCondsDesc(conds),
    getUnlockMultDesc(mainCond)
  ], true)
}

function getFullUnlockCondsDescInline(conds) {
  if (!conds)
    return ""

  let mainCond = getMainProgressCondition(conds)
  let mainCondText = getUnlockMainCondDesc(mainCond)
  let condsText = getUnlockCondsDesc(conds)
  return ", ".join([
    mainCondText,
    (condsText != "" ? $"({condsText})" : ""),
    getUnlockMultDesc(mainCond)
  ], true)
}

function getUnitRequireUnlockText(unit) {
  let desc = getFullUnlockDescByName(unit.reqUnlock, -1, { showValueForBitList = true })
  return "\n".concat(loc("mainmenu/needUnlock"), desc)
}

function getUnitRequireUnlockShortText(unit) {
  let unlockBlk = getUnlockById(unit.reqUnlock)
  let cfg = buildConditionsConfig(unlockBlk)
  let mainCond = getMainProgressCondition(cfg.conditions)
  return getUnlockMainCondDesc(
    mainCond, cfg.curVal, cfg.maxVal, { isProgressTextOnly = true })
}

function buildUnlockDesc(item) {
  let mainCond = getMainProgressCondition(item.conditions)
  let progressText = getUnlockMainCondDesc(mainCond, item.curVal, item.maxVal)
  item.showProgress <- progressText != ""
  return item
}

function fillUnlockManualOpenButton(cfg, obj) {
  let btnObj = obj.findObject("manual_open_button")
  if (!btnObj?.isValid())
    return

  let needShow = cfg.manualOpen && canClaimUnlockReward(cfg.id)
  btnObj.unlockId = cfg.id
  btnObj.show(needShow)
}

function getRewardText(unlockConfig, stageNum) {
  if (("stages" in unlockConfig) && (stageNum in unlockConfig.stages))
    unlockConfig = unlockConfig.stages[stageNum]

  let reward = getTblValue("reward", unlockConfig, null)
  let text = reward ? reward.tostring() : ""
  if (text != "")
    return $"{loc("challenge/reward")} <color=@activeTextColor>{text}</color>"
  return ""
}

function updateUnseenIcon(cfg, obj) {
  let unseenCfg = cfg.manualOpen && canClaimUnlockReward(cfg.id) && canClaimUnlockRewardForUnit(cfg.id)
    ? makeConfigStr(SEEN.MANUAL_UNLOCKS, cfg.id)
    : ""
  obj.findObject("unseen_icon").setValue(unseenCfg)
}

function getUnlockTypeFromConfig(unlockConfig) {
  return unlockConfig?.unlockType ?? unlockConfig?.type ?? -1
}

function updateProgress(unlockCfg, unlockObj) {
  let progressData = unlockCfg.getProgressBarData()
  let hasProgress = progressData.show && !isUnlockOpened(unlockCfg.id)

  let snapshot = getUnlockProgressSnapshot(unlockCfg.id)
  let hasSnapshot = (snapshot != null) && hasProgress
  let snapshotObj = unlockObj.findObject("progress_snapshot")
  snapshotObj.show(hasSnapshot)
  if (hasSnapshot) {
    let storedProgress = getProgressBarData(unlockCfg.type, snapshot.progress, unlockCfg.maxVal).value
    snapshotObj.setValue(min(storedProgress, progressData.value))
  }

  let progressObj = unlockObj.findObject("progress_bar")
  progressObj.show(hasProgress)
  if (hasProgress) {
    progressObj.hasSnapshot = hasSnapshot ? "yes" : "no"
    progressObj.setValue(progressData.value)
  }

  unlockObj.findObject("snapshotBtn").show(hasProgress)
}

function needShowLockIcon(cfg) {
  if (cfg.lockStyle == "none")
    return false

  if (cfg?.isTrophyLocked)
    return true

  let unlockType = getUnlockTypeFromConfig(cfg)
  let isUnlocked = isUnlockOpened(cfg.id, unlockType)
  if (isUnlocked)
    return false

  return cfg.lockStyle == "lock"
    || unlockType == UNLOCKABLE_DECAL
    || unlockType == UNLOCKABLE_PILOT
}

function updateLockStatus(cfg, obj) {
  let needLockIcon = needShowLockIcon(cfg)
  let lockObj = obj.findObject("lock_icon")
  lockObj.show(needLockIcon)
}

function getUnlockImageConfig(unlockConfig) {
  let unlockType = getUnlockTypeFromConfig(unlockConfig)
  let isUnlocked = isUnlockOpened(unlockConfig.id, unlockType)
  local iconStyle = unlockConfig?.iconStyle ?? ""
  let image = unlockConfig?.image ?? ""

  if (iconStyle == "" && image == "")
    iconStyle = "".concat(
      (isUnlocked ? "default_unlocked" : "default_locked"),
      (isUnlocked || unlockConfig.curStage < 1) ? "" : $"_stage_{unlockConfig.curStage}")

  let effect = isUnlocked || unlockConfig.lockStyle == "none" || needShowLockIcon(unlockConfig) ? ""
    : unlockConfig.lockStyle != "" ? unlockConfig.lockStyle
    : unlockType == UNLOCKABLE_MEDAL ? "darkened"
    : "desaturated"

  return {
    style = iconStyle
    image = unlockType == UNLOCKABLE_PILOT ? (unlockConfig?.descrImage ?? image) : image
    ratio = unlockConfig?.imgRatio ?? 1.0
    params = unlockConfig?.iconParams
    effect
  }
}

function fillUnlockImage(unlockConfig, unlockObj) {
  let iconObj = unlockObj.findObject("achivment_ico")
  let imgConfig = getUnlockImageConfig(unlockConfig)
  iconObj.effectType = imgConfig.effect

  if (unlockConfig?.iconData) {
    LayersIcon.replaceIconByIconData(iconObj, unlockConfig.iconData)
    return
  }

  LayersIcon.replaceIcon(
    iconObj,
    imgConfig.style,
    imgConfig.image,
    imgConfig.ratio,
    null  ,
    imgConfig.params
  )
}

function fillUnlockProgressBar(unlockConfig, unlockObj) {
  let obj = unlockObj.findObject("progress_bar")
  let data = unlockConfig.getProgressBarData()
  obj.show(data.show)
  if (!data.show)
    return

  obj.setValue(data.value)

  let markersNestObj = unlockObj.findObject("progress_markers_nest")
  if (!markersNestObj?.isValid())
    return

  let discountTooltip = []
  let unlockBlk = getUnlockById(unlockConfig.id)
  let view = { markers = [] }
  for (local i = 0; $"costGoldDiscountProgress{i}" in unlockBlk; ++i) {
    view.markers.append({
      markerText = roman_numerals[i + 1],
      markerPosition = unlockBlk[$"costGoldDiscountProgress{i}"] / unlockConfig.maxVal / 1000.0
    })

    discountTooltip.append(loc("mainmenu/unlockDiscount", {
      romanNumeral = roman_numerals[i + 1],
      discountProgress = unlockBlk[$"costGoldDiscountProgress{i}"] / 1000
      maxProgress = unlockConfig.maxVal
      cost = Cost(0, unlockBlk.costGold - unlockBlk[$"costGoldDiscountValue{i}"] * unlockBlk.costGold / 100.0)
    }))
  }

  if (view.markers.len() > 0) {
    markersNestObj.show(true)
    markersNestObj.tooltip = "\n".join(discountTooltip)
    let markup = handyman.renderCached("%gui/unlocks/unlockProgressMarkers.tpl", view)
    obj.getScene().replaceContentFromText(markersNestObj, markup, markup.len(), this)
    obj.hasMarkers = "yes"
  } else {
    markersNestObj.show(false)
    obj.hasMarkers = "no"
  }
}

function fillUnlockDescription(unlockConfig, unlockObj) {
  unlockObj.findObject("description").setValue(getUnlockDesc(unlockConfig))
  unlockObj.findObject("main_cond").setValue(getUnlockMainCondDescByCfg(unlockConfig))
  unlockObj.findObject("mult_desc").setValue(getUnlockMultDescByCfg(unlockConfig))
  unlockObj.findObject("conditions").setValue(getUnlockCondsDescByCfg(unlockConfig))

  let showUnitsBtnObj = unlockObj.findObject("show_units_btn")
  showUnitsBtnObj.show(hasActiveUnlock(unlockConfig.id, getShopDiffCode())
    && getUnitListByUnlockId(unlockConfig.id).len() > 0)
  showUnitsBtnObj.unlockId = unlockConfig.id

  let showPrizesBtnObj = unlockObj.findObject("show_prizes_btn")
  showPrizesBtnObj.show(unlockConfig?.trophyId != null)
  showPrizesBtnObj.trophyId = unlockConfig?.trophyId

  let previewPrizeBtnObj = unlockObj.findObject("preview_prize_btn")
  previewPrizeBtnObj.show(canPreviewUnlockPrize(unlockConfig))
  previewPrizeBtnObj.unlockId = unlockConfig.id
}

function getRewardCfgByUnlockCfg(unlockConfig) {
  let id = unlockConfig.id
  let unlockType = unlockConfig.unlockType
  let res = {
    rewardText = ""
    tooltipId = getTooltipType("REWARD_TOOLTIP").getTooltipId(id)
  }

  if (isInArray(unlockType, [UNLOCKABLE_DECAL, UNLOCKABLE_MEDAL, UNLOCKABLE_SKIN]))
    res.rewardText = getUnlockNameText(unlockType, id)
  else if (unlockType == UNLOCKABLE_TITLE)
    res.rewardText = format(loc("reward/title"), getUnlockNameText(unlockType, id))
  else if (unlockType == UNLOCKABLE_TROPHY) {
    let item = findItemById(id)
    if (item) {
      res.rewardText = item.getName() 
      res.tooltipId = getTooltipType("ITEM").getTooltipId(id)
    }
  }

  if (res.rewardText != "")
    res.rewardText = " ".concat(loc("challenge/reward"), colorize("activeTextColor", res.rewardText))

  let showStages = ("stages" in unlockConfig) && (unlockConfig.stages.len() > 1)
  if ((showStages && unlockConfig.curStage >= 0) || ("reward" in unlockConfig))
    res.rewardText = getRewardText(unlockConfig, unlockConfig.curStage)

  return res
}

function fillReward(unlockConfig, unlockObj) {
  let rewardObj = unlockObj.findObject("reward")
  if (!checkObj(rewardObj))
    return

  let { rewardText, tooltipId } = getRewardCfgByUnlockCfg(unlockConfig)

  let tooltipObj = rewardObj.findObject("tooltip")
  if (checkObj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  rewardObj.show(rewardText != "")
  rewardObj.setValue(rewardText)
}

function fillUnlockTitle(unlockConfig, unlockObj) {
  let title = getUnlockTitle(unlockConfig)
  unlockObj.findObject("achivment_title").setValue(title)
}

function fillUnlockPurchaseButton(unlockData, unlockObj) {
  let purchButtonObj = unlockObj.findObject("purchase_button")
  if (!checkObj(purchButtonObj))
    return

  let unlockId = unlockData.id
  purchButtonObj.unlockId = unlockId
  let isUnlocked = isUnlockOpened(unlockId)
  let haveStages = getTblValue("stages", unlockData, []).len() > 1
  let cost = getUnlockCost(unlockId)
  let canSpendGold = cost.gold == 0 || hasFeature("SpendGold")
  let isPurchaseTime = isUnlockVisibleByTime(unlockId, false)
  let canOpenManually = unlockData.manualOpen && canClaimUnlockReward(unlockId)

  let show = isPurchaseTime && canSpendGold && !haveStages && !isUnlocked
    && !canOpenManually && !cost.isZero()

  purchButtonObj.show(show)
  if (show)
    placePriceTextToButton(unlockObj, "purchase_button", loc("mainmenu/btnBuyInstantly"), cost)

  if (!show && !cost.isZero()) {
    let cantPurchase = $"UnlocksPurchase: can't purchase {unlockId}:"
    if (canOpenManually)
      log($"{cantPurchase} can open manually")
    else if (!canSpendGold)
      log($"{cantPurchase} can't spend gold")
    else if (haveStages)
      log($"{cantPurchase} has stages = {unlockData.stages.len()}")
    else if (isUnlocked)
      log($"{cantPurchase} already unlocked")
    else if (!isPurchaseTime) {
      debugLogVisibleByTimeInfo(unlockId)
      log($"{cantPurchase} not purchase time. see time before.")
    }
  }
}

function getConditionsToUnlockShowcaseById(unlockId) {
  let unlock = getUnlockById(unlockId)
  if (unlock == null)
    return ""

  let config = buildConditionsConfig(unlock)
  let subunlockCfg = getSubunlockCfg(config.conditions)
  local conds = getUnlockCondsDescByCfg(subunlockCfg ?? config)
  if (conds == "")
    conds = getUnlockMainCondDescByCfg(subunlockCfg ?? config, {})

  return conds
}

function getSubunlockTooltipMarkup(unlockCfg, subunlockId, allowActionText = "") {
  if (unlockCfg.type == "char_resources") {
    let decorator = getDecoratorById(subunlockId)
    return decorator
      ? getTooltipType("DECORATION").getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
      : ""
  }

  let hasUnlock = getUnlockById(subunlockId) != null
  return hasUnlock
    ? getTooltipType("UNLOCK").getMarkup(subunlockId, { showProgress = true, allowActionText })
    : ""
}

function fillUnlockStages(unlockConfig, unlockObj, context) {
  if (!unlockObj?.isValid())
    return
  let stagesObj = unlockObj.findObject("stages")
  if (!stagesObj?.isValid())
    return

  local textStages = ""
  let needToFillStages = unlockConfig.needToFillStages && unlockConfig.stages.len() <= MAX_STAGES_NUM
  if (needToFillStages)
    for (local i = 0; i < unlockConfig.stages.len(); i++) {
      let stage = unlockConfig.stages[i]
      let curValStage = (unlockConfig.curVal > stage.val) ? stage.val : unlockConfig.curVal
      let isUnlockedStage = curValStage >= stage.val
      textStages = "".concat(textStages, "unlocked { {parity} substrateImg {} img { background-image:t='{image}' } {tooltip} }"
        .subst({
          image = isUnlockedStage ? $"#ui/gameuiskin#stage_unlocked_{i+1}" : $"#ui/gameuiskin#stage_locked_{i+1}"
          parity = i % 2 == 0 ? "class:t='even';" : "class:t='odd';"
          tooltip = getTooltipType("UNLOCK_SHORT").getMarkup(unlockConfig.id, { stage = i })
        }))
    }

  unlockObj.getScene().replaceContentFromText(stagesObj, textStages, textStages.len(), context)
}

function getSubunlocksView(cfg, numColumns = 2, includeTooltip = false) {
  if (cfg.hideSubunlocks)
    return null
  let isBitMode = isBitModeType(cfg.type)
  let titles = getLocForBitValues(cfg.type, cfg.names, cfg.hasCustomUnlockableList)
  let subunlocks = []
  foreach (idx, title in titles) {
    let unlockId = cfg.names[idx]
    let unlockBlk = getUnlockById(unlockId)
    if (!isUnlockVisible(unlockBlk) && !(unlockBlk?.showInDesc ?? false))
      continue
    let isUnlocked = isBitMode ? is_bit_set(cfg.curVal, idx) : isUnlockOpened(unlockId)
    let tooltipMarkup = includeTooltip ? getSubunlockTooltipMarkup(cfg, unlockId) : null
    subunlocks.append({ title, isUnlocked, numColumns, tooltipMarkup })
  }
  return (subunlocks.len() > 0) ? { subunlocks } : null
}

function getUnlockStagesView(cfg) {
  let needToFillStages = cfg.needToFillStages && cfg.stages.len() <= MAX_STAGES_NUM
  if (!needToFillStages)
    return []

  let stages = []
  for (local i = 0; i < cfg.stages.len(); ++i) {
    let stage = cfg.stages[i]
    let curValStage = (cfg.curVal > stage.val) ? stage.val : cfg.curVal
    let isUnlockedStage = curValStage >= stage.val
    stages.append({
      image = isUnlockedStage
        ? $"#ui/gameuiskin#stage_unlocked_{i + 1}"
        : $"#ui/gameuiskin#stage_locked_{i + 1}"
      even = i % 2 == 0
      tooltip = getTooltipType("UNLOCK_SHORT").getMarkup(cfg.id, { stage = i })
    })
  }
  return stages
}

function canPurchaseConditionUnlock(unlock) {
  let unlockId = unlock.id
  if ((unlock?.stages ?? []).len() > 1)
    return false

  if (isUnlockOpened(unlockId))
    return false

  let cost = getUnlockCost(unlockId)
  if (cost.gold > 0 && !hasFeature("SpendGold"))
    return false

  if (cost.isZero())
    return false

  if (unlock?.manualOpen && canClaimUnlockReward(unlockId))
    return false

  return isUnlockVisibleByTime(unlockId, false)
}

function fillUnlockConditions(unlockConfig, unlockObj, context, simplified = false) {
  if (!checkObj(unlockObj))
    return

  let hiddenObj = unlockObj.findObject("hidden_block")
  if (!checkObj(hiddenObj))
    return

  let conditions = []
  if (!unlockConfig.hideSubunlocks) {
    let isBitMode = isBitModeType(unlockConfig.type)
    let names = getLocForBitValues(unlockConfig.type, unlockConfig.names, unlockConfig.hasCustomUnlockableList)
    for (local i = 0; i < names.len(); i++) {
      let unlockId = unlockConfig.names[i]
      let unlock = getUnlockById(unlockId)
      if (unlock && !isUnlockVisible(unlock) && !(unlock?.showInDesc ?? false))
        continue

      let isShowAsButton = !simplified && unlock != null && getUnlockType(unlockId) != UNLOCKABLE_STREAK && isUnlockVisible(unlock)

      this.guiScene.applyPendingChanges(true)

      let maxButtonWidth = hiddenObj.getSize()[0] / SUB_UNLOCKS_COL_COUNT
      let conditionDescription = names[i]
      let textWidth = getStringWidthPx(conditionDescription, "fontNormal", this.guiScene)
      let hasAutoscrollText = (textWidth + to_pixels("2@buttonTextPadding")) > maxButtonWidth
      local allowActionText = ""
      if (!simplified && isShowAsButton) {
        let canPurchase = canPurchaseConditionUnlock(unlock)
        allowActionText = $"{canPurchase ? loc("profile/unlockConditions/allowActionText") : ""} {loc("profile/unlockConditions/goToTheTask")}"
      }

      conditions.append({
        isUnlocked = isBitMode ? is_bit_set(unlockConfig.curVal, i) : isUnlockOpened(unlockId)
        conditionDescription
        isShowAsButton
        unlockId
        hasAutoscrollText
        isSimplified = simplified
        hasUnlockImg = ("image" in unlockConfig) && unlockConfig.image != ""
        tooltipMarkup = getSubunlockTooltipMarkup(unlockConfig, unlockId, allowActionText)
      })
    }
  }

  unlockObj.findObject("expandImg").show(conditions.len() > 0)
  let markUpData = handyman.renderCached("%gui/profile/unlockConditions.tpl", { conditions })
  unlockObj.getScene().replaceContentFromText(hiddenObj, markUpData, markUpData.len(), context)
}

function fillSimplifiedUnlockInfo(unlockBlk, unlockObj, context) {
  let isShowUnlock = unlockBlk != null && isUnlockVisible(unlockBlk)
  unlockObj.show(isShowUnlock)
  if (!isShowUnlock)
    return

  let unlockConfig = buildConditionsConfig(unlockBlk)
  let subunlockCfg = getSubunlockCfg(unlockConfig.conditions)
  buildUnlockDesc(subunlockCfg ?? unlockConfig)
  unlockObj.id = unlockConfig.id

  fillUnlockTitle(unlockConfig, unlockObj)
  fillUnlockImage(unlockConfig, unlockObj)
  fillReward(unlockConfig, unlockObj)
  updateLockStatus(unlockConfig, unlockObj)
  updateProgress(subunlockCfg ?? unlockConfig, unlockObj)
  fillUnlockConditions(subunlockCfg ?? unlockConfig, unlockObj, context, true)

  unlockObj.findObject("removeFromFavoritesBtn").unlockId = unlockBlk.id
  unlockObj.findObject("snapshotBtn").unlockId = unlockBlk.id

  let tooltipObj = unlockObj.findObject("unlock_tooltip")
  tooltipObj.tooltipId = getTooltipType("UNLOCK_SHORT").getTooltipId(unlockConfig.id, {
    showChapter = true
    showSnapshot = true
  })
}

function fillUnlockBlock(obj, config, isForTooltip = false) {
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

  let allowActionText = config?.allowActionText ?? ""
  if (allowActionText != "") {
    let aObj = obj.findObject("allow_action_text")
    aObj.setValue(allowActionText)
    showObjById("allow_action_text_block", true, obj)

    obj["transparent"] = "yes"
    obj["noPadding"] = "yes"
    obj.findObject("contentBlock")["isShow"] = "yes"
  }

  if (config.type == UNLOCKABLE_PILOT || config.type == UNLOCKABLE_FRAME) {
    let tObj = obj.findObject("award_title_text")
    tObj.setValue("title" in config ? config.title : "")
  }

  let uObj = obj.findObject("unlock_name")
  uObj.setValue(config?.name ?? "")

  let amount = config?.amount ?? 1

  if ("similarAwardNamesList" in config) {
    let maxStreak = config.similarAwardNamesList?.maxStreak ?? 1
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
      let view = getSubunlocksView(config.unlockCfg)
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

  if (config?.hideAward)
    return

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

function buildUnlockTooltipByConfig(obj, config, handler) {
  let guiScene = obj.getScene()
  guiScene.replaceContent(obj, "%gui/unlocks/unlockBlock.blk", handler)

  obj["min-width"] = "@unlockBlockWidth"

  fillUnlockBlock(obj, config, true)
}

addTooltipTypes({
  UNLOCK_SHORT = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params) {
      if (!checkObj(obj))
        return false

      let unlock = getUnlockById(unlockId)
      if (unlock == null)
        return false

      let stage = params?.stage.tointeger() ?? -1
      let config = buildConditionsConfig(unlock, stage)
      let subunlockCfg = getSubunlockCfg(config.conditions)

      obj.getScene().replaceContent(obj, "%gui/unlocks/shortTooltip.blk", handler)

      let header = getUnlockTitle(config, {needShortName = true})
      obj.findObject("header").setValue(header)

      if (params?.showChapter ?? false)
        obj.findObject("chapter").setValue(getUnlockChapterAndGroupText(unlock))

      let mainCond = getUnlockMainCondDescByCfg(subunlockCfg ?? config, { showSingleStreakCondText = true })
      let hasMainCond = mainCond != ""
      let progressData = subunlockCfg?.getProgressBarData() ?? config.getProgressBarData()
      let isUnlocked = isUnlockOpened(unlockId)
      let hasProgressBar = hasMainCond && progressData.show && !isUnlocked
      let snapshot = hasProgressBar && (params?.showSnapshot ?? false)
        ? getUnlockSnapshotText(subunlockCfg ?? config)
        : ""
      let conds = getUnlockCondsDescByCfg(subunlockCfg ?? config)
      obj.findObject("desc_text").setValue(getUnlockDesc(subunlockCfg ?? config))
      obj.findObject("mainCond").setValue(" ".join([mainCond, snapshot], true))
      obj.findObject("multDesc").setValue(getUnlockMultDescByCfg(subunlockCfg ?? config))
      obj.findObject("conds").setValue(conds)

      let hasAnyCond = hasMainCond || conds != ""
      if (hasMainCond && !isUnlocked) {
        let pObj = obj.findObject("progress")
        pObj.setValue(progressData.value)
        pObj.show(progressData.show)
      }
      else if (hasAnyCond)
        obj.findObject("challenge_complete").show(isUnlocked)

      let reward = getRewardText(config, stage)
      obj.findObject("reward").setValue(reward)


      let view = getSubunlocksView(subunlockCfg ?? config)
      if (view) {
        let markup = handyman.renderCached("%gui/unlocks/subunlocks.tpl", view)
        let nestObj = obj.findObject("subunlocks")
        nestObj.show(true)
        obj.getScene().replaceContentFromText(nestObj, markup, markup.len(), this)
      }

      return true
    }
  }
  REWARD_TOOLTIP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, _handler, unlockId, _params) {
      if (!checkObj(obj))
        return false

      let unlockBlk = unlockId && unlockId != "" && getUnlockById(unlockId)
      if (!unlockBlk)
        return false

      let config = buildConditionsConfig(unlockBlk)
      let name = config.id
      let unlockType = config.unlockType
      let decoratorType = getTypeByUnlockedItemType(unlockType)
      let guiScene = obj.getScene()
      if (decoratorType == decoratorTypes.DECALS
          || decoratorType == decoratorTypes.ATTACHABLES
          || unlockType == UNLOCKABLE_MEDAL) {
        let bgImage = format("background-image:t='%s';", config.image)
        let size = format("size:t='128, 128/%f';", config.imgRatio)
        let svgSize = format("background-svg-size:t='128, 128/%f';", config.imgRatio)

        guiScene.appendWithBlk(obj, " ".concat("img{", bgImage, size, svgSize, "}"), this)
      }
      else if (decoratorType == decoratorTypes.SKINS) {
        let unit = getAircraftByName(getPlaneBySkinId(name))
        local text = []
        if (unit)
          text.append($"{loc("reward/skin_for")} {getUnitName(unit)}")
        let viewDecoratorType = getViewTypeByUnlockedItemType(decoratorType.unlockedItemType)
        text.append(viewDecoratorType.getLocDesc(name))

        text = locOrStrip("\n".join(text, true))
        let textBlock = "textareaNoTab {smallFont:t='yes'; max-width:t='0.5@sf'; text:t='%s';}"
        guiScene.appendWithBlk(obj, format(textBlock, text), this)
      }
      else
        return false

      return true
    }
  }
})

return {
  getUnlockRewardsText
  getUnlockTypeText
  getUnlockTitle
  getFullUnlockCondsDesc
  getFullUnlockCondsDescInline
  getUnlockSnapshotText
  getUnlockCostText
  getUnitRequireUnlockText
  getUnitRequireUnlockShortText
  getUnlockIconConfig
  buildUnlockDesc
  fillUnlockManualOpenButton
  getRewardText
  updateUnseenIcon
  getUnlockTypeFromConfig
  updateProgress
  needShowLockIcon
  updateLockStatus
  getUnlockImageConfig
  fillUnlockImage
  fillUnlockProgressBar
  doPreviewUnlockPrize
  fillUnlockDescription
  fillReward
  fillUnlockTitle
  fillUnlockPurchaseButton
  getConditionsToUnlockShowcaseById
  getSubunlockCfg
  getTooltipMarkupByModeType
  getUnlocksListView
  fillUnlockConditions
  getRewardCfgByUnlockCfg
  fillUnlockStages
  getSubunlocksView
  getUnlockStagesView
  fillSimplifiedUnlockInfo
  fillUnlockBlock
  buildUnlockTooltipByConfig
}