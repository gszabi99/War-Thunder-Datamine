//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let { DECORATION, UNLOCK, REWARD_TOOLTIP, UNLOCK_SHORT
} = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnlockMainCondDescByCfg, getUnlockMultDescByCfg, getUnlockDesc, getUnlockCondsDescByCfg,
  getUnlockNameText, getLocForBitValues, getUnlockTitle } = require("%scripts/unlocks/unlocksViewModule.nut")
let { hasActiveUnlock, getUnitListByUnlockId } = require("%scripts/unlocks/unlockMarkers.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { isBitModeType, getSubunlockCfg, getProgressBarData } = require("%scripts/unlocks/unlocksConditions.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { isUnlockVisible, isUnlockVisibleByTime, getUnlockCost, debugLogVisibleByTimeInfo
} = require("%scripts/unlocks/unlocksModule.nut")
let { isUnlockReadyToOpen } = require("chard")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { makeConfigStr } = require("%scripts/seen/bhvUnseen.nut")
let { getDecoratorById } = require("%scripts/customization/decorCache.nut")
let { getUnlockProgressSnapshot } = require("%scripts/unlocks/unlockProgressSnapshots.nut")

let MAX_STAGES_NUM = 10 // limited by images gui/hud/gui_skin/unlock_icons/stage_(un)locked_N

let function getSubunlockTooltipMarkup(unlockCfg, subunlockId) {
  if (unlockCfg.type == "char_resources") {
    let decorator = getDecoratorById(subunlockId)
    return decorator
      ? DECORATION.getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
      : ""
  }

  let hasUnlock = getUnlockById(subunlockId) != null
  return hasUnlock
    ? UNLOCK.getMarkup(subunlockId, { showProgress = true })
    : ""
}

::g_unlock_view <- {
  function fillUnlockManualOpenButton(cfg, obj) {
    let btnObj = obj.findObject("manual_open_button")
    if (!btnObj?.isValid())
      return

    let needShow = cfg.manualOpen && isUnlockReadyToOpen(cfg.id)
    btnObj.unlockId = cfg.id
    btnObj.show(needShow)
  }

  function getRewardConfig(unlockConfig) {
    let id = unlockConfig.id
    let unlockType = unlockConfig.unlockType
    let res = {
      rewardText = ""
      tooltipId = REWARD_TOOLTIP.getTooltipId(id)
    }

    if (isInArray(unlockType, [UNLOCKABLE_DECAL, UNLOCKABLE_MEDAL, UNLOCKABLE_SKIN]))
      res.rewardText = getUnlockNameText(unlockType, id)
    else if (unlockType == UNLOCKABLE_TITLE)
      res.rewardText = format(loc("reward/title"), getUnlockNameText(unlockType, id))
    else if (unlockType == UNLOCKABLE_TROPHY) {
      let item = ::ItemsManager.findItemById(id, itemType.TROPHY)
      if (item) {
        res.rewardText = item.getName() // colored
        res.tooltipId = ::g_tooltip.getIdItem(id)
      }
    }

    if (res.rewardText != "")
      res.rewardText = " ".concat(loc("challenge/reward"), colorize("activeTextColor", res.rewardText))

    let showStages = ("stages" in unlockConfig) && (unlockConfig.stages.len() > 1)
    if ((showStages && unlockConfig.curStage >= 0) || ("reward" in unlockConfig))
      res.rewardText = this.getRewardText(unlockConfig, unlockConfig.curStage)

    return res
  }

  function getStagesView(cfg) {
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
        tooltip = UNLOCK_SHORT.getMarkup(cfg.id, { stage = i })
      })
    }
    return stages
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

      let isUnlocked = isBitMode ? is_bit_set(cfg.curVal, idx) : ::is_unlocked_scripted(-1, unlockId)
      let tooltipMarkup = includeTooltip ? getSubunlockTooltipMarkup(cfg, unlockId) : null
      subunlocks.append({ title, isUnlocked, numColumns, tooltipMarkup })
    }

    return (subunlocks.len() > 0) ? { subunlocks } : null
  }

  function fillSimplifiedUnlockInfo(unlockBlk, unlockObj, context) {
    let isShowUnlock = unlockBlk != null && isUnlockVisible(unlockBlk)
    unlockObj.show(isShowUnlock)
    if (!isShowUnlock)
      return

    let unlockConfig = ::build_conditions_config(unlockBlk)
    let subunlockCfg = getSubunlockCfg(unlockConfig.conditions)
    ::build_unlock_desc(subunlockCfg ?? unlockConfig)
    unlockObj.id = unlockConfig.id

    this.fillUnlockTitle(unlockConfig, unlockObj)
    this.fillUnlockImage(unlockConfig, unlockObj)
    this.fillReward(unlockConfig, unlockObj)
    this.updateLockStatus(unlockConfig, unlockObj)
    this.updateProgress(subunlockCfg ?? unlockConfig, unlockObj)
    this.fillUnlockConditions(subunlockCfg ?? unlockConfig, unlockObj, context)

    unlockObj.findObject("removeFromFavoritesBtn").unlockId = unlockBlk.id
    unlockObj.findObject("snapshotBtn").unlockId = unlockBlk.id

    let tooltipObj = unlockObj.findObject("unlock_tooltip")
    tooltipObj.tooltipId = UNLOCK_SHORT.getTooltipId(unlockConfig.id, {
      showChapter = true
      showSnapshot = true
    })
  }

  function getUnlockImageConfig(unlockConfig) {
    let unlockType = this.getUnlockType(unlockConfig)
    let isUnlocked = ::is_unlocked_scripted(unlockType, unlockConfig.id)
    local iconStyle = unlockConfig?.iconStyle ?? ""
    let image = unlockConfig?.image ?? ""

    if (iconStyle == "" && image == "")
      iconStyle = (isUnlocked ? "default_unlocked" : "default_locked") +
          ((isUnlocked || unlockConfig.curStage < 1) ? "" : "_stage_" + unlockConfig.curStage)

    let effect = isUnlocked || unlockConfig.lockStyle == "none" || this.needShowLockIcon(unlockConfig) ? ""
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
    let imgConfig = this.getUnlockImageConfig(unlockConfig)
    iconObj.effectType = imgConfig.effect

    if (unlockConfig?.iconData) {
      ::LayersIcon.replaceIconByIconData(iconObj, unlockConfig.iconData)
      return
    }

    ::LayersIcon.replaceIcon(
      iconObj,
      imgConfig.style,
      imgConfig.image,
      imgConfig.ratio,
      null /*defStyle*/ ,
      imgConfig.params
    )
  }

  function updateUnseenIcon(cfg, obj) {
    let unseenCfg = cfg.manualOpen && isUnlockReadyToOpen(cfg.id)
      ? makeConfigStr(SEEN.MANUAL_UNLOCKS, cfg.id)
      : ""
    obj.findObject("unseen_icon").setValue(unseenCfg)
  }

  function updateProgress(unlockCfg, unlockObj) {
    let progressData = unlockCfg.getProgressBarData()
    let hasProgress = progressData.show && !::is_unlocked_scripted(-1, unlockCfg.id)

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

  function updateLockStatus(cfg, obj) {
    let needLockIcon = this.needShowLockIcon(cfg)
    let lockObj = obj.findObject("lock_icon")
    lockObj.show(needLockIcon)
  }

  function needShowLockIcon(cfg) {
    if (cfg.lockStyle == "none")
      return false

    if (cfg?.isTrophyLocked)
      return true

    let unlockType = this.getUnlockType(cfg)
    let isUnlocked = ::is_unlocked_scripted(unlockType, cfg.id)
    if (isUnlocked)
      return false

    return cfg.lockStyle == "lock"
      || unlockType == UNLOCKABLE_DECAL
      || unlockType == UNLOCKABLE_PILOT
  }

  function getUnlockType(unlockConfig) {
    return unlockConfig?.unlockType ?? unlockConfig?.type ?? -1
  }
}

//  g_unlock_view functions 'unlockConfig' param is unlocks data table, created through
//  build_conditions_config(unlockBlk)
//  ::build_unlock_desc(unlockConfig)

::g_unlock_view.fillUnlockConditions <- function fillUnlockConditions(unlockConfig, unlockObj, context) {
  if (! checkObj(unlockObj))
    return

  let hiddenObj = unlockObj.findObject("hidden_block")
  if (!checkObj(hiddenObj))
    return

  local hiddenContent = ""

  if (!unlockConfig.hideSubunlocks) {
    let isBitMode = isBitModeType(unlockConfig.type)
    let names = getLocForBitValues(unlockConfig.type, unlockConfig.names, unlockConfig.hasCustomUnlockableList)
    for (local i = 0; i < names.len(); i++) {
      let unlockId = unlockConfig.names[i]
      let unlock = getUnlockById(unlockId)
      if (unlock && !isUnlockVisible(unlock) && !(unlock?.showInDesc ?? false))
        continue

      let isUnlocked = isBitMode ? is_bit_set(unlockConfig.curVal, i) : ::is_unlocked_scripted(-1, unlockId)
      hiddenContent += "unlockCondition {"
      hiddenContent += format("textarea {text:t='%s' } \n %s \n",
                                ::g_string.stripTags(names[i]),
                                ("image" in unlockConfig && unlockConfig.image != "" ? "" : "unlockImg{}"))
      hiddenContent += format("unlocked:t='%s'; ", (isUnlocked ? "yes" : "no"))
      hiddenContent += getSubunlockTooltipMarkup(unlockConfig, unlockId)
      hiddenContent += "}"
    }
  }

  unlockObj.findObject("expandImg").show(hiddenContent != "")
  unlockObj.getScene().replaceContentFromText(hiddenObj, hiddenContent, hiddenContent.len(), context)
}

::g_unlock_view.fillUnlockProgressBar <- function fillUnlockProgressBar(unlockConfig, unlockObj) {
  let obj = unlockObj.findObject("progress_bar")
  let data = unlockConfig.getProgressBarData()
  obj.show(data.show)
  if (data.show)
    obj.setValue(data.value)
}

::g_unlock_view.fillUnlockDescription <- function fillUnlockDescription(unlockConfig, unlockObj) {
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
}

::g_unlock_view.fillReward <- function fillReward(unlockConfig, unlockObj) {
  let rewardObj = unlockObj.findObject("reward")
  if (!checkObj(rewardObj))
    return

  let { rewardText, tooltipId } = this.getRewardConfig(unlockConfig)

  let tooltipObj = rewardObj.findObject("tooltip")
  if (checkObj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  rewardObj.show(rewardText != "")
  rewardObj.setValue(rewardText)
}

::g_unlock_view.fillStages <- function fillStages(unlockConfig, unlockObj, context) {
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
      textStages += "unlocked { {parity} substrateImg {} img { background-image:t='{image}' } {tooltip} }"
        .subst({
          image = isUnlockedStage ? $"#ui/gameuiskin#stage_unlocked_{i+1}" : $"#ui/gameuiskin#stage_locked_{i+1}"
          parity = i % 2 == 0 ? "class:t='even';" : "class:t='odd';"
          tooltip = UNLOCK_SHORT.getMarkup(unlockConfig.id, { stage = i })
        })
    }

  unlockObj.getScene().replaceContentFromText(stagesObj, textStages, textStages.len(), context)
}

::g_unlock_view.fillUnlockTitle <- function fillUnlockTitle(unlockConfig, unlockObj) {
  let title = getUnlockTitle(unlockConfig)
  unlockObj.findObject("achivment_title").setValue(title)
}

::g_unlock_view.getRewardText <- function getRewardText(unlockConfig, stageNum) {
  if (("stages" in unlockConfig) && (stageNum in unlockConfig.stages))
    unlockConfig = unlockConfig.stages[stageNum]

  let reward = getTblValue("reward", unlockConfig, null)
  let text = reward ? reward.tostring() : ""
  if (text != "")
    return loc("challenge/reward") + " " + "<color=@activeTextColor>" + text + "</color>"
  return ""
}

::g_unlock_view.fillUnlockFav <- function fillUnlockFav(unlockId, unlockObj) {
  let checkboxFavorites = unlockObj.findObject("checkbox_favorites")
  if (! checkObj(checkboxFavorites))
    return
  checkboxFavorites.unlockId = unlockId
  ::g_unlock_view.fillUnlockFavCheckbox(checkboxFavorites)
}

::g_unlock_view.fillUnlockFavCheckbox <- function fillUnlockFavCheckbox(obj) {
  let isUnlockInFavorites = isUnlockFav(obj.unlockId)
  obj.setValue(isUnlockInFavorites)
  obj.tooltip = isUnlockInFavorites
    ? loc("mainmenu/UnlockAchievementsRemoveFromFavorite/hint")
    : loc("mainmenu/UnlockAchievementsToFavorite/hint")
}

::g_unlock_view.fillUnlockPurchaseButton <- function fillUnlockPurchaseButton(unlockData, unlockObj) {
  let purchButtonObj = unlockObj.findObject("purchase_button")
  if (!checkObj(purchButtonObj))
    return

  let unlockId = unlockData.id
  purchButtonObj.unlockId = unlockId
  let isUnlocked = ::is_unlocked_scripted(-1, unlockId)
  let haveStages = getTblValue("stages", unlockData, []).len() > 1
  let cost = getUnlockCost(unlockId)
  let canSpendGold = cost.gold == 0 || hasFeature("SpendGold")
  let isPurchaseTime = isUnlockVisibleByTime(unlockId, false)
  let canOpenManually = unlockData.manualOpen && isUnlockReadyToOpen(unlockId)

  let show = isPurchaseTime && canSpendGold && !haveStages && !isUnlocked
    && !canOpenManually && !cost.isZero()

  purchButtonObj.show(show)
  if (show)
    placePriceTextToButton(unlockObj, "purchase_button", loc("mainmenu/btnBuy"), cost)

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
