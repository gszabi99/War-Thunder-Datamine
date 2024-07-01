//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { format } = require("string")
let { is_bit_set } = require("%sqstd/math.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnlockNameText, getLocForBitValues, buildUnlockDesc, fillUnlockImage,
  updateLockStatus, updateProgress, fillReward, fillUnlockTitle, getRewardText
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { isBitModeType, getSubunlockCfg } = require("%scripts/unlocks/unlocksConditions.nut")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getDecoratorById } = require("%scripts/customization/decorCache.nut")
let { stripTags } = require("%sqstd/string.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")

let MAX_STAGES_NUM = 10 // limited by images gui/hud/gui_skin/unlock_icons/stage_(un)locked_N

function getSubunlockTooltipMarkup(unlockCfg, subunlockId) {
  if (unlockCfg.type == "char_resources") {
    let decorator = getDecoratorById(subunlockId)
    return decorator
      ? getTooltipType("DECORATION").getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
      : ""
  }

  let hasUnlock = getUnlockById(subunlockId) != null
  return hasUnlock
    ? getTooltipType("UNLOCK").getMarkup(subunlockId, { showProgress = true })
    : ""
}

//  g_unlock_view functions 'unlockConfig' param is unlocks data table, created through
//  build_conditions_config(unlockBlk)
//  buildUnlockDesc(unlockConfig)

::g_unlock_view <- {
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
        tooltip = getTooltipType("UNLOCK_SHORT").getMarkup(cfg.id, { stage = i })
      })
    }
    return stages
  }

  function fillUnlockConditions(unlockConfig, unlockObj, context) {
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

        let isUnlocked = isBitMode ? is_bit_set(unlockConfig.curVal, i) : isUnlockOpened(unlockId)
        hiddenContent += "unlockCondition {"
        hiddenContent += format("textarea {text:t='%s' } \n %s \n", stripTags(names[i]),
          ("image" in unlockConfig && unlockConfig.image != "" ? "" : "unlockImg{}"))
        hiddenContent += format("unlocked:t='%s'; ", (isUnlocked ? "yes" : "no"))
        hiddenContent += getSubunlockTooltipMarkup(unlockConfig, unlockId)
        hiddenContent += "}"
      }
    }

    unlockObj.findObject("expandImg").show(hiddenContent != "")
    unlockObj.getScene().replaceContentFromText(hiddenObj, hiddenContent, hiddenContent.len(), context)
  }

  function fillSimplifiedUnlockInfo(unlockBlk, unlockObj, context) {
    let isShowUnlock = unlockBlk != null && isUnlockVisible(unlockBlk)
    unlockObj.show(isShowUnlock)
    if (!isShowUnlock)
      return

    let unlockConfig = ::build_conditions_config(unlockBlk)
    let subunlockCfg = getSubunlockCfg(unlockConfig.conditions)
    buildUnlockDesc(subunlockCfg ?? unlockConfig)
    unlockObj.id = unlockConfig.id

    fillUnlockTitle(unlockConfig, unlockObj)
    fillUnlockImage(unlockConfig, unlockObj)
    fillReward(unlockConfig, unlockObj)
    updateLockStatus(unlockConfig, unlockObj)
    updateProgress(subunlockCfg ?? unlockConfig, unlockObj)
    this.fillUnlockConditions(subunlockCfg ?? unlockConfig, unlockObj, context)

    unlockObj.findObject("removeFromFavoritesBtn").unlockId = unlockBlk.id
    unlockObj.findObject("snapshotBtn").unlockId = unlockBlk.id

    let tooltipObj = unlockObj.findObject("unlock_tooltip")
    tooltipObj.tooltipId = getTooltipType("UNLOCK_SHORT").getTooltipId(unlockConfig.id, {
      showChapter = true
      showSnapshot = true
    })
  }

  function fillStages(unlockConfig, unlockObj, context) {
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
            tooltip = getTooltipType("UNLOCK_SHORT").getMarkup(unlockConfig.id, { stage = i })
          })
      }

    unlockObj.getScene().replaceContentFromText(stagesObj, textStages, textStages.len(), context)
  }

  function getRewardConfig(unlockConfig) {
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
      let item = findItemById(id, itemType.TROPHY)
      if (item) {
        res.rewardText = item.getName() // colored
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
}
