from "%scripts/dagui_natives.nut" import get_unlock_type
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let getShipFlags = require("%scripts/customization/shipFlags.nut")
let events = getGlobalModule("events")
let { ceil } = require("math")
let { format, split_by_chars } = require("string")
let { getUnlockProgress } = require("unlocks")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getRoleText } = require("%scripts/unit/unitInfoRoles.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { createSeasonRewardFromUnlockBlk } = require("%scripts/clans/clanSeasonPlaceTitle.nut")
let { getPlayerRankByCountry } = require("%scripts/user/userInfoStats.nut")
let { maxCountryRank, getRankByExp } = require("%scripts/ranks.nut")
let { isBattleTask, getBattleTaskNameById } = require("%scripts/unlocks/battleTasksState.nut")
let { getRegionalUnlockProgress, isRegionalUnlock } = require("%scripts/unlocks/regionalUnlocks.nut")
let { get_charserver_time_sec } = require("chard")
let { zero_money } = require("%scripts/money.nut")
let { number_of_set_bits, round_by_value } = require("%sqstd/math.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getPlaneBySkinId } = require("%scripts/customization/skinUtils.nut")
let { buildDateStrShort } = require("%scripts/time.nut")
let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { getMissionTimeText } = require("%scripts/missions/missionsText.nut")
let { season, seasonLevel, getLevelByExp } = require("%scripts/battlePass/seasonState.nut")
let { isLoadingBgUnlock, getLoadingBgName, getLoadingBgIdByUnlockId
} = require("%scripts/loading/loadingBgData.nut")
let { getRawInventoryItemAmount, getItemOrRecipeBundleById
} = require("%scripts/items/itemsManager.nut")
let { decoratorTypes, getTypeByUnlockedItemType, getTypeByResourceType
} = require("%scripts/customization/decoratorBaseType.nut")
let { getViewTypeByUnlockedItemType } = require("%scripts/customization/decoratorViewType.nut")
let { getDecorator, getDecoratorById } = require("%scripts/customization/decoratorGetters.nut")
let { isUnlockOpened, getUnlockType, isUnlockExist, getUnlockRewardCost, isUnlockComplete
} = require("%scripts/unlocks/unlocksModule.nut")
let { loadMainProgressCondition, loadConditionsFromBlk, getMainProgressCondition,
  isNestedUnlockMode, isStreak, isBitModeType, getMultipliersTable, isTimeRangeCondition,
  getProgressBarData, loadCondition, getUnlockConditions, getRangeString,
  getDiffNameByInt
} = require("%scripts/unlocks/unlocksConditions.nut")


function getUnlockableMedalImage(id, big = false) {
  return big ? $"!@ui/medals/{id}_big.ddsx" : $"!@ui/medals/{id}.ddsx"
}


let customLocTypes = ["gameModeInfoString", "missionPostfix"]


let conditionsOrder = [
  "beginDate", "endDate", "battlepassProgress", "battlepassLevel",
  "missionsWon", "mission", "char_mission_completed", "char_unlock_open_count",
  "missionType", "atLeastOneUnitsRankOnStartMission", "maxUnitsRankOnStartMission",
  "unitExists", "additional", "unitClass",
  "gameModeInfoString", "missionPostfix", "missionEnvironment", "modes", "events", "tournamentMode",
  "location", "operationMap", "weaponType", "ammoMass", "bulletCaliber", "difficulty",
  "playerUnit", "playerType", "playerExpClass", "playerUnitRank", "playerUnitMRank", "playerTag", "playerCountry",
  "offenderUnit", "offenderType", "offenderUnitRank", "offenderUnitMRank", "offenderTag", "offenderSpeed",
  "targetUnit", "targetType", "targetTag",
  "crewsUnit", "crewsUnitRank", "crewsUnitMRank", "crewsTag", "usedPlayerUnit", "lastPlayerUnit",
  "activity", "minStat", "statPlaceInSession", "statScoreInSession", "statAwardDamageInSession",
  "statKillsPlayerInSession", "statKillsAirInSession", "statKillsAirAiInSession",
  "statKillsGroundInSession", "statKillsGroundAiInSession",
  "statKillsNavalInSession", "statKillsNavalAiInSession",
  "statKillsSurfaceInSession", "statKillsSurfaceAiInSession",
  "targetIsPlayer", "eliteUnitsOnly", "noPremiumVehicles", "era", "country",
  "targets", "targetDistance", "higherBR"
]

let condWithValuesInside = [
  "atLeastOneUnitsRankOnStartMission", "eliteUnitsOnly"
]


let mapConditionUnitType = {
  aircraft          = "unit_aircraft"
  tank              = "unit_tank"
  typeLightTank     = "type_light_tank"
  typeMediumTank    = "type_medium_tank"
  typeHeavyTank     = "type_heavy_tank"
  typeSPG           = "type_tank_destroyer"
  typeSPAA          = "type_spaa"
  typeTankDestroyer = "type_tank_destroyer"
  typeFighter       = "type_fighter"
  typeDiveBomber    = "type_dive_bomber"
  typeBomber        = "type_bomber"
  typeAssault       = "type_strike_aircraft"
  typeStormovik     = "type_strike_aircraft"
  typeTransport     = "type_transport"
  typeStrikeFighter = "type_strike_fighter"
  typeDestroyer     = "type_destroyer"
  typeTorpedoBoat   = "type_torpedo_boat"
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
  isNotBegun = false
  needToFillStages = true
  needToAddCurStageToName = true
  useLastStageAsUnlockOpening = false
  additionalStagesDescAsItemCountLocId = ""
  additionalStagesDescAsItemCountId = 0
  additionalStagesDescAsItemCountMax = 0
  names = [] 

  showProgress = true
  getProgressBarData = function() {
    let res = getProgressBarData(this.type, this.curVal, this.maxVal)
    res.show = res.show && this.showProgress
    return res
  }
}


function setRewardDataCfg(cfg, blk, unlocked) {
  if (!blk?.userLogId)
    return

  let item = findItemById(blk.userLogId)
  if (item?.iType != itemType.TROPHY)
    return

  let content = item.getContent()
  let hasManyPrizes = content.len() > 1
  if (hasManyPrizes && !unlocked)
    cfg.trophyId <- item.id

  if (cfg.image != "")
    return

  if (hasManyPrizes) {
    cfg.iconData <- item.getIcon()
    cfg.isTrophyLocked <- !unlocked
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
    let viewDecoratorType = getViewTypeByUnlockedItemType(decType.unlockedItemType)

    let decorator = getDecorator(prize.resource, decType)
    let image = viewDecoratorType.getImage(decorator)
    if (image == "")
      return

    cfg.image <- image
    cfg.isTrophyLocked <- !unlocked
  }
}


function getIconByUnlockBlk(unlockBlk) {
  let unlockType = get_unlock_type(unlockBlk.type)
  let decoratorType = getTypeByUnlockedItemType(unlockType)

  if (decoratorType != decoratorTypes.UNKNOWN && !is_in_loading_screen()) {
    let decorator = getDecorator(unlockBlk.id, decoratorType)
    let viewDecoratorType = getViewTypeByUnlockedItemType(decoratorType.unlockedItemType)
    return viewDecoratorType.getImage(decorator)
  }
  if (unlockType == UNLOCKABLE_AIRCRAFT) {
    let unit = getAircraftByName(unlockBlk.id)
    if (unit)
      return unit.getUnlockImage()
  }
  else if (unlockType == UNLOCKABLE_PILOT)
    return $"#ui/images/avatars/{unlockBlk.id}.avif"

  return unlockBlk?.icon
}

function setImageByUnlockType(config, unlockBlk) {
  let unlockType = get_unlock_type(getTblValue("type", unlockBlk, ""))
  if (unlockType == UNLOCKABLE_MEDAL) {
    if (getTblValue("subType", unlockBlk) == "clan_season_reward") {
      let unlock = createSeasonRewardFromUnlockBlk(unlockBlk)
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
    let viewDecoratorType = getViewTypeByUnlockedItemType(decoratorType.unlockedItemType)
    config.image <- viewDecoratorType.getImage(decorator)
    config.imgRatio <- viewDecoratorType.getRatio(decorator)
  }
}

function setUnlockIconCfg(cfg, blk) {
  let icon = getIconByUnlockBlk(blk)
  if (icon)
    cfg.image = icon
  else
    setImageByUnlockType(cfg, blk)
}


function getDescriptionByUnlockType(unlockBlk) {
  let unlockType = get_unlock_type(unlockBlk?.type ?? "")
  if (unlockType == UNLOCKABLE_MEDAL) {
    if (unlockBlk?.subType == "clan_season_reward") {
      let unlock = createSeasonRewardFromUnlockBlk(unlockBlk)
      return unlock.desc()
    }
  }
  else if (unlockType == UNLOCKABLE_DECAL)
    return loc($"decals/{unlockBlk.id}/desc", "")

  return loc($"{unlockBlk.id}/desc", "")
}


function buildConditionsConfig(blk, showStage = -1) {
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
  setRewardDataCfg(config, blk, unlocked)
  if (config.image == "" && !config?.iconData)
    setUnlockIconCfg(config, blk)
  config.lockStyle = blk?.lockStyle ?? "" 

  config.desc <- getDescriptionByUnlockType(blk)

  if (blk?.isRevenueShare)
    config.isRevenueShare <- true

  if (blk?._puType)
    config._puType <- blk._puType

  foreach (mode in blk % "mode") {
    let modeType = mode?.type ?? ""
    config.type = modeType

    
    config.locMultDescId = mode?.locMultDescId ?? ""
    config.mulArcade = mode?.mulArcade ?? 0
    config.mulRealistic = mode?.mulRealistic ?? 0
    config.mulHardcore = mode?.mulHardcore ?? 0

    if (config.unlockType == UNLOCKABLE_TROPHY_PSN) {
      
      config.conditions = []
      let mainCond = loadMainProgressCondition(mode)
      if (mainCond)
        config.conditions.append(mainCond)
    }
    else
      config.conditions = loadConditionsFromBlk(mode, blk) 

    let mainCond = getMainProgressCondition(config.conditions)
    config.hasCustomUnlockableList = getTblValue("hasCustomUnlockableList", mainCond, false)

    if (mainCond && mainCond.values
        && (mainCond.values.len() > 1 || config.hasCustomUnlockableList
        || (isNestedUnlockMode(mainCond.modeType) && isStreak(mainCond.values[0]))))
      config.names = mainCond.values 

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
    if (cond) {
      config.isExpired = get_charserver_time_sec() >= cond.endTime
      config.isNotBegun = get_charserver_time_sec() < cond.beginTime
    }
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

  if (showStage >= 0 && blk?.isMultiStage) { 
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
      ? (blk.mode.num / 1000) : blk.mode.num
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

  if (config.unlockType == UNLOCKABLE_INVENTORY) {
    let item = getItemOrRecipeBundleById(config.userLogId.tointeger())
    config.locId = item?.getName(false) ?? ""
    config.locDescId = item?.getBaseDescription() ?? ""
    config.image = item?.getIconName() ?? ""
  }

  return config
}


function getUnlockStagesDesc(cfg) {
  if (cfg == null)
    return ""

  let hasStages = cfg.stages.len() > 1
  let hideDesc = isUnlockComplete(cfg) && !cfg.useLastStageAsUnlockOpening
  if (!hasStages || hideDesc)
    return ""

  if (cfg.locStagesDescId != "")
    return "".concat(
      loc(cfg.locStagesDescId),
      loc("ui/colon"),
      colorize("unlockActiveColor", loc($"{cfg.curStage}/{cfg.stages.len()}")))

  return loc("challenge/stage", {
    stage = colorize("unlockActiveColor", cfg.curStage + 1)
    totalStages = colorize("unlockActiveColor", cfg.stages.len())
  })
}


function getAdditionalStagesDesc(cfg) {
  if (cfg == null)
    return ""

  let itemId = cfg.additionalStagesDescAsItemCountId
  if (itemId <= 0)
    return ""

  let textId = cfg.additionalStagesDescAsItemCountLocId
  let curCount = getRawInventoryItemAmount(itemId)
  let maxCount = cfg.additionalStagesDescAsItemCountMax

  return "".concat(
    loc(textId),
    loc("ui/colon"),
    colorize("unlockActiveColor", loc($"{curCount}/{maxCount}")))
}


function getUnlockDesc(cfg) {
  let desc = [getUnlockStagesDesc(cfg), getAdditionalStagesDesc(cfg)]

  let hasDescInConds = cfg?.conditions.findindex(@(c) "typeLocIDWithoutValue" in c) != null
  if (!hasDescInConds)
    if ((cfg?.locDescId ?? "") != "") {
      let isBitMode = isBitModeType(cfg.type)
      let num = isBitMode ? number_of_set_bits(cfg.maxVal) : cfg.maxVal
      desc.append(loc(cfg.locDescId, { num }))
    }
    else if ((cfg?.desc ?? "") != "")
      desc.append(cfg.desc)

  return "\n".join(desc, true)
}


function getUnlockBeginDateText(unlock) {
  let isBlk = unlock?.mode != null
  let conds = isBlk ? getUnlockConditions(unlock.mode) : unlock?.conditions
  local timeCond = conds?.findvalue(@(c) isTimeRangeCondition(c.type))
  if (isBlk)
    timeCond = loadCondition(timeCond, unlock)
  return (timeCond?.beginTime != null)
    ? buildDateStrShort(timeCond.beginTime).replace(" ", nbsp)
    : ""
}

function getUnlockLocName(config, key = "locId") {
  let isRawBlk = (config?.mode != null)
  local num = (isRawBlk ? config.mode?.num : config?.maxVal) ?? 0
  if (num > 0)
    num = isBitModeType(isRawBlk ? config.mode.type : config.type) ? number_of_set_bits(num) : num
  local numRealistic = (isRawBlk ? config.mode?.mulRealistic : config?.conditions[0].multiplier.HistoricalBattle) ?? 1
  local numHardcore = (isRawBlk ? config.mode?.mulHardcore : config?.conditions[0].multiplier.FullRealBattles) ?? 1
  numRealistic = ceil(num.tofloat() / numRealistic)
  numHardcore = ceil(num.tofloat() / numHardcore)

  return "".join(getLocIdsArray(config?[key]).map(@(locId) locId.len() == 1 ? locId :
    loc(locId, { num, numRealistic, numHardcore, beginDate = getUnlockBeginDateText(config) })))
}


function getSubUnlockLocName(config) {
  let subUnlockBlk = getUnlockById(config?.mode.unlock ?? config?.conditions[0].values[0] ?? "")
  if (subUnlockBlk)
    return subUnlockBlk.locId ? getUnlockLocName(subUnlockBlk) : loc($"{subUnlockBlk.id}/name")
  else
    return ""
}


function getSubunlockOrUnlockName(id) {
  let unlockBlk = getUnlockById(id)
  if (unlockBlk?.useSubUnlockName)
    return getSubUnlockLocName(unlockBlk)
  if (unlockBlk?.locId)
    return getUnlockLocName(unlockBlk)
  return loc($"{id}/name")
}


function getDifficultyLocalizationText(difficulty) {
  return difficulty == "hardcore"  ? loc("difficulty2")
    : difficulty == "realistic" ? loc("difficulty1")
    : loc("difficulty0")
}


let singleAttachmentList = {
  unlockOpenCount = "unlock"
  unlockStageCount = "unlock"
}

let isCheckedBySingleAttachment = @(modeType)
  modeType in singleAttachmentList || isBitModeType(modeType)


let isFlagUnlock = @(id) id in getShipFlags()


let unlockTypeToGetShortNameFunc = {
  [UNLOCKABLE_SKIN] = @(id) getDecoratorById(id)?.getName() ?? ""
}

let unlockTypeToGetNameFunc = {
  [UNLOCKABLE_AIRCRAFT] = @(id) getUnitName(id),
  [UNLOCKABLE_SKIN] = function(id) {
    let unitName = getPlaneBySkinId(id)
    let res = getDecoratorById(id)?.getDesc() ?? ""
    return unitName != ""
      ? "".concat(res, loc("ui/parentheses/space", { text = getUnitName(unitName) }))
      : res
  },
  [UNLOCKABLE_DECAL] = @(id) loc($"decals/{id}"),
  [UNLOCKABLE_ATTACHABLE] = @(id) loc($"attachables/{id}"),
  [UNLOCKABLE_WEAPON] = @(_) "",
  [UNLOCKABLE_ACHIEVEMENT] = @(id) getSubunlockOrUnlockName(id),
  [UNLOCKABLE_CHALLENGE] = @(id) getSubunlockOrUnlockName(id),
  [UNLOCKABLE_INVENTORY] = @(id) getSubunlockOrUnlockName(id),
  [UNLOCKABLE_DIFFICULTY] = @(id) getDifficultyLocalizationText(id),
  [UNLOCKABLE_ENCYCLOPEDIA] = function(id) {
    let index = id.indexof("/")
    return (index != null)
      ? loc($"encyclopedia/{id.slice(index + 1)}")
      : loc($"encyclopedia/{id}")
  },
  [UNLOCKABLE_SINGLEMISSION] = function(id) {
    let index = id.indexof("/")
    return (index != null)
      ? loc($"missions/{id.slice(index + 1)}")
      : loc($"missions/{id}")
  },
  [UNLOCKABLE_TITLE] = @(id) loc($"title/{id}"),
  [UNLOCKABLE_PILOT] = @(id) loc($"{id}/name", ""),
  [UNLOCKABLE_STREAK] = function(id) {
    let unlockBlk = getUnlockById(id)
    if (unlockBlk?.useSubUnlockName)
      return getSubUnlockLocName(unlockBlk)
    if (unlockBlk?.locId)
      return getUnlockLocName(unlockBlk)

    let res = loc($"streaks/{id}")
    return res.indexof("%d") != null
      ? loc($"streaks/{id}/multiple")
      : res
  },
  [UNLOCKABLE_AWARD] = function(id) {
    if (isLoadingBgUnlock(id))
      return getLoadingBgName(getLoadingBgIdByUnlockId(id))
    if (isFlagUnlock(id))
      return loc($"{id}/name")
    return loc($"award/{id}")
  },
  [UNLOCKABLE_ENTITLEMENT] = @(id) getEntitlementName(getEntitlementConfig(id)),
  [UNLOCKABLE_COUNTRY] = @(id) loc(id),
  [UNLOCKABLE_AUTOCOUNTRY] = @(_) loc("award/autocountry"),
  [UNLOCKABLE_SLOT] = @(_) loc("options/crew"),
  [UNLOCKABLE_DYNCAMPAIGN] = function(id) {
    let parts = split_by_chars(id, "_")
    local countryId = (parts.len() > 1) ? $"country_{parts[parts.len() - 1]}" : null
    if (isInArray(countryId, shopCountriesList))
      parts.pop()
    else
      countryId = null

    let locId = $"dynamic/{"_".join(parts, true)}"
    return countryId
      ? "".concat(loc(locId), loc("ui/parentheses/space", { text = loc(countryId) }))
      : loc(locId)
  },
  [UNLOCKABLE_TROPHY] = function(id) {
    let unlockBlk = getUnlockById(id)
    if (unlockBlk?.locId)
      return getUnlockLocName(unlockBlk)
    let item = findItemById(id)
    return item ? item.getName(false) : loc($"item/{id}")
  },
  [UNLOCKABLE_YEAR] = @(id) (id.len() > 4) ? id.slice(id.len() - 4, id.len()) : "",
  [UNLOCKABLE_MEDAL] = function(id) {
    let unlockBlk = getUnlockById(id)
    if (getTblValue("subType", unlockBlk) == "clan_season_reward") {
      let unlock = createSeasonRewardFromUnlockBlk(unlockBlk)
      return unlock.name()
    }
  }
}



function getUnlockNameText(unlockType, id, params = null) {
  if (isBattleTask(id))
    return getBattleTaskNameById(id)

  if (unlockType == -1)
    unlockType = getUnlockType(id)

  return params?.needShortName && unlockTypeToGetShortNameFunc?[unlockType]
    ? unlockTypeToGetShortNameFunc[unlockType](id)
    : unlockTypeToGetNameFunc?[unlockType](id) ?? loc($"{id}/name")
}


function getLocForBitValues(modeType, values, hasCustomUnlockableList = false) {
  let valuesLoc = []
  if (hasCustomUnlockableList || isNestedUnlockMode(modeType))
    foreach (name in values)
      valuesLoc.append(getUnlockNameText(-1, name))
  else if (modeType == "char_unit_exist")
    foreach (name in values)
      valuesLoc.append(getUnitName(name))
  else if (modeType == "char_resources")
    foreach (id in values) {
      let decorator = getDecoratorById(id)
      valuesLoc.append(decorator?.getName?() ?? id)
    }
  else {
    local nameLocPrefix = ""
    if (modeType == "char_mission_list" || modeType == "char_mission_completed")
      nameLocPrefix = "missions/"
    else if (modeType == "char_buy_modification_list")
      nameLocPrefix = "modification/"

    foreach (name in values)
      valuesLoc.append(loc("".concat(nameLocPrefix, name)))
  }
  return valuesLoc
}


function getSingleAttachmentConditionText(condition, curValue, maxValue) {
  let modeType = getTblValue("modeType", condition)
  let locNames = getLocForBitValues(modeType, condition.values)
  let valueText = colorize("unlockActiveColor", $"\"{loc("ui/comma").join(locNames, true)}\"")
  let progress = colorize("unlockActiveColor", curValue != null
    ? $"{curValue}/{maxValue}"
    : $"{maxValue}")
  return loc($"conditions/{modeType}/single", { value = valueText, progress })
}






function getUnlockMainCondDesc(condition, curValue = null, maxValue = null, params = null) {
  let modeType = condition?.modeType
  if (!modeType)
    return ""

  let typeLocIDWithoutValue = getTblValue("typeLocIDWithoutValue", condition)
  if (typeLocIDWithoutValue)
    return loc(typeLocIDWithoutValue)

  let bitMode = isBitModeType(modeType)
  let haveModeTypeLocID = "modeTypeLocID" in condition

  if (maxValue == null)
    maxValue = getTblValue("rewardNum", condition) || getTblValue("num", condition)

  if (is_numeric(curValue)) {
    if (bitMode)
      curValue = number_of_set_bits(curValue)
    else if (is_numeric(maxValue) && curValue > maxValue) 
      curValue = maxValue
  }

  if (bitMode && is_numeric(maxValue))
    maxValue = number_of_set_bits(maxValue)

  if (isCheckedBySingleAttachment(modeType)
      && !haveModeTypeLocID
      && condition.values
      && condition.values.len() == 1
      && (!isStreak(condition.values[0]) || !!params?.showSingleStreakCondText))
    return getSingleAttachmentConditionText(condition, curValue, maxValue)

  local textId = $"conditions/{modeType}"
  let textParams = {}

  local progressText = ""
  let showValueForBitList = params?.showValueForBitList
  if (bitMode && (params?.bitListInValue || showValueForBitList)) {
    if (curValue == null || params?.showValueForBitList)
      progressText = ", ".join(getLocForBitValues(modeType, condition.values), true)

    if (is_numeric(maxValue) && maxValue != condition.values.len()) {
      textId = $"{textId}/withValue"
      textParams.value <- colorize("unlockActiveColor", maxValue)
    }
  }
  else if (modeType == "maxUnitsRankOnStartMission") {
    let valuesText = condition.values?.map(get_roman_numeral) ?? []
    progressText = "-".join(valuesText, true)
  }
  else if (modeType == "amountDamagesZone") {
    if (is_numeric(curValue) && is_numeric(maxValue)) {
      let a = round_by_value(curValue * 0.001, 0.001)
      let b = round_by_value(maxValue * 0.001, 0.001)
      progressText = $"{a}/{b}"
    }
  }
  else 
    progressText = "/".join([curValue, maxValue], true)

  if (params?.isProgressTextOnly)
    return progressText

  if (haveModeTypeLocID)
    textId = condition.modeTypeLocID

  else if (modeType == "rank" || modeType == "char_country_rank") {
    let country = getTblValue("country", condition)
    textId = country ? $"mainmenu/rank/{country}" : "mainmenu/rank"
  }
  else if (modeType == "unlockCount")
    textId = $"conditions/{getTblValue("unlockType", condition, "")}"
  else if (modeType == "char_static_progress")
    textParams.level <- loc($"crew/qualification/{getTblValue("level", condition, 0)}")
  else if (modeType == "landings" && getTblValue("carrierOnly", condition))
    textId = "conditions/carrierOnly"
  else if (getTblValue("isShip", condition)) 
    textId = "conditions/isShip"
  else if (modeType == "killedAirScore")
    textId = "conditions/statKillsAir"
  else if (modeType == "sessionsStarted")
    textId = "conditions/missionsPlayed"
  else if (modeType == "char_resources_count")
    textId = $"conditions/char_resources_count/{getTblValue("resourceType", condition, "")}"
  else if (modeType == "amountDamagesZone")
    textId = "debriefing/Damage"
  else if (modeType == "totalMissionScore")
    textId = "conditions/statScore"
  else if (modeType == "hitUnitsScore")
    textId = "expEventScore/hit"

  local res = ""

  if ("locEnding" in params)
    res = loc($"{textId}{params.locEnding}", textParams)

  if (res == "")
    res = loc(textId, textParams)

  if ("reason" in condition) {
    let reason = loc($"{textId}/{condition.reason}")
    res = $"{res} {reason}"
  }

  
  if (progressText != "" && (res != "" || maxValue != 1))
    res = $"{res}{loc("ui/colon")}{colorize("unlockActiveColor", progressText)}"

  return res
}


function getUnlockMainCondDescByCfg(cfg, params = null) {
  if (!cfg?.conditions)
    return ""

  let mainCond = getMainProgressCondition(cfg.conditions)
  if (!mainCond)
    return ""

  let hideCurVal = isUnlockComplete(cfg) && !cfg.useLastStageAsUnlockOpening
  let curVal = params?.curVal ?? (hideCurVal ? null : cfg.curVal)

  return getUnlockMainCondDesc(mainCond, curVal, cfg.maxVal, params)
}


function addValueToGroup(groupsList, group, value) {
  if (group not in groupsList)
    groupsList[group] <- []
  groupsList[group].append(value)
}


function addTextToCondTextList(condTextsList, group, valuesData, params = null) {
  local groupLocId = $"conditions/{group}"

  if (group == "battlepassLevel")
    groupLocId = "conditions/battlepassProgress"
  else if (group == "missionEnvironment")
    groupLocId = "options/time"
  else if (group == "char_unlock_open_count" && valuesData.len() == 1)
    groupLocId = loc($"conditions/{group}/single")
  local valuesText = loc("ui/comma").join(valuesData, true)
  if (valuesText != "") {
    let isExpired = group == "endDate" && params?.isExpired
    let isNotBegun = group == "beginDate" && params?.isNotBegun
    valuesText = colorize(isExpired || isNotBegun ? "red" : "unlockActiveColor", valuesText)
  }

  local text = !isInArray(group, customLocTypes)
    ? loc(groupLocId, { value = valuesText })
    : params?.customLocGroupText ?? ""

  if (!isInArray(group, condWithValuesInside))
    if (valuesText != "")
      text = $"{text}{(text.len() ? loc("ui/colon") : "")}{valuesText}"
    else
      text = ""

  condTextsList.append(text)
}


function addUniqConditionsText(groupsList, condition) {
  let condType = condition.type

  if (isTimeRangeCondition(condType)) {
    foreach (key in ["beginDate", "endDate"])
      if (key in condition)
        addValueToGroup(groupsList, key, condition[key])
    return true
  }

  if (condType == "atLeastOneUnitsRankOnStartMission") {
    let valuesTexts = condition.values?.map(get_roman_numeral) ?? []
    addValueToGroup(groupsList, condType, "-".join(valuesTexts, true))
    return true
  }

  if (condType == "eliteUnitsOnly") {
    addValueToGroup(groupsList, condType, "")
    return true
  }

  return false
}


let unitCondType = {
  playerUnit = true
  offenderUnit = true
  targetUnit = true
  crewsUnit = true
  unitExists = true
  usedInSessionUnit = true
  lastInSessionUnit = true
}

let playerCondType = {
  playerType = true
  targetType = true
  usedInSessionType = true
  lastInSessionType = true
  offenderType = true
}

let playerClassCondType = {
  playerExpClass = true
  unitClass = true
  usedInSessionClass = true
  lastInSessionClass = true
}

let playerTagCondType = {
  playerTag = true
  offenderTag = true
  crewsTag = true
  targetTag = true
  country = true
  playerCountry = true
  usedInSessionTag = true
  lastInSessionTag = true
}

let ammoCondType = {
  ammoMass = true
  bulletCaliber = true
  offenderSpeed = true
}

let rankCondType = {
  activity = true
  playerUnitRank = true
  offenderUnitRank = true
  playerUnitMRank = true
  offenderUnitMRank = true
  crewsUnitRank = true
  crewsUnitMRank = true
  minStat = true
  higherBR = true
  usedInSessionRank = true
}

let missionCondType = {
  mission = true
  char_mission_completed = true
  missionType = true
}

let eraAndRnakCondType = {
  era = true
  maxUnitsRankOnStartMission = true
}

function getUsualCondValueText(condType, v, condition) {
  if (condType in unitCondType)
    return getUnitName(v)
  if (condType in playerCondType)
    return loc($"unlockTag/{getTblValue(v, mapConditionUnitType, v)}")
  if (condType in playerClassCondType)
    return getRoleText(cutPrefix(v, "exp_", v))
  if (condType in playerTagCondType)
    return loc($"unlockTag/{v}")
  if (condType == "targetDistance")
    return format(loc($"conditions/{condition.gt ? "min" : "max"}_limit"), v.tostring())
  if (condType in ammoCondType)
    return format(loc(v.notLess ? "conditions/min_limit" : "conditions/less"), v.value.tostring())
  if (condType in rankCondType)
    return v.tostring()
  if (condType in missionCondType)
    return loc($"missions/{v}")
  if (condType == "missionEnvironment")
    return getMissionTimeText(v)
  if (condType in eraAndRnakCondType)
    return get_roman_numeral(v)
  if (condType == "events")
    return events.getNameByEconomicName(v)
  if (["offenderIsSupportGun", "offenderIsStealthBelt"].contains(condType))
    return loc(v)
  if (condType == "operationMap")
    return loc($"worldWar/map/{v}")
  if (condType == "difficulty") {
    local text = getDifficultyLocalizationText(v)
    if (!getTblValue("exact", condition, false) && v != "hardcore")
      text = $"{text} {loc("conditions/moreComplex")}"
    return text
  }
  if (condType == "battlepassProgress") {
    let reqLevel = getLevelByExp(v)
    if (condition.season != season.get())
      return $"{reqLevel}"
    let curLevelText = loc("conditions/battlepassProgress/currentLevel", { level = seasonLevel.get() })
    return reqLevel <= seasonLevel.get()
      ? $"{reqLevel} {curLevelText}"
      : $"{reqLevel} {colorize("red" ,curLevelText)}"
  }
  if (condType == "battlepassLevel") {
    if (condition.season != season.get())
      return $"{v}"
    let curLevelText = loc("conditions/battlepassProgress/currentLevel", { level = seasonLevel.get() })
    return v <= seasonLevel.get()
      ? $"{v} {curLevelText}"
      : $"{v} {colorize("red" ,curLevelText)}"
  }
  if (condType == "char_unlock_open_count")
    return loc(v)

  return condType ? loc($"{condType}/{v}") : ""
}


function addUsualConditionsText(groupsList, condition) {
  let condType = condition.type
  let group = getTblValue("locGroup", condition, condType)
  local values = condition.values
  local text = ""

  if (values == null)
    return addValueToGroup(groupsList, group, text)

  if (type(values) != "array")
    values = [values]

  values = processUnitTypeArray(values)
  foreach (v in values)
    addValueToGroup(groupsList, group, getUsualCondValueText(condType, v, condition))
}


function addDataToCustomGroup(groupsList, condType, data) {
  if (condType not in groupsList)
    groupsList[condType] <- []

  let customData = groupsList[condType]
  foreach (conditionData in customData)
    if (data.groupText == getTblValue("groupText", conditionData)) {
      conditionData.descText.append(getTblValue("descText", data)[0])
      return
    }

  groupsList[condType].append(data)
}


function addCustomConditionsTextData(groupsList, condition) {
  local values = condition.values
  if (values == null)
    return

  if (type(values) != "array")
    values = [values]

  let condType = condition.type
  let desc = []
  local group = ""

  foreach (v in values) {
    if (condType == "gameModeInfoString") {
      group = condition?.locParamName
        ? loc(condition.locParamName)
        : loc($"conditions/gameModeInfoString/{condition.name}")

      let locValuePrefix = condition?.locValuePrefix ?? "conditions/gameModeInfoString/"
      desc.append(loc($"{locValuePrefix}{v}"))
    }
    else if (condType == "missionPostfix") {
      group = loc($"conditions/{condition.locGroup}")

      let locValuePrefix = condition?.locValuePrefix ?? "options/"
      desc.append(loc($"{locValuePrefix}{v}"))
    }
  }

  addDataToCustomGroup(groupsList, condType, {
    groupText = group
    descText = [desc]
  })
}


function getUnlockCondsDesc(conditions, params = {}) {
  let descByLocGroups = {}
  let customDataByLocGroups = {}
  foreach (condition in conditions)
    if (!isInArray(condition.type, customLocTypes)) {
      if (!addUniqConditionsText(descByLocGroups, condition))
        addUsualConditionsText(descByLocGroups, condition)
    }
    else
      addCustomConditionsTextData(customDataByLocGroups, condition)

  let condTextsList = []
  foreach (group in conditionsOrder) {
    if (!isInArray(group, customLocTypes)) {
      let data = getTblValue(group, descByLocGroups)
      if (data == null || data.len() == 0)
        continue

      addTextToCondTextList(condTextsList, group, data, params)
    }
    else {
      let customData = getTblValue(group, customDataByLocGroups)
      if (customData == null || customData.len() == 0)
        continue

      foreach (condCustomData in customData)
        foreach (descText in condCustomData.descText)
          addTextToCondTextList(condTextsList, group, descText, {
            customLocGroupText = condCustomData.groupText
          }.__merge(params))
    }
  }

  return "\n".join(condTextsList, true)
}


function getUnlockCondsDescByCfg(cfg) {
  if (!cfg?.conditions)
    return ""
  return getUnlockCondsDesc(cfg.conditions, cfg)
}


function getUnlockMultDesc(condition) {
  let multiplierTable = condition?.multiplier ?? {}
  let rankMultiplierTable = condition?.rankMultiplier ?? {}
  if (multiplierTable.len() == 0 && rankMultiplierTable.len() == 0)
    return ""

  local mulText = ""

  if ((multiplierTable?.WWBattleForOwnClan ?? 1) > 1)
    return "{0}{1}{2}".subst(
      loc("conditions/mulWWBattleForOwnClan"),
      loc("ui/colon"),
      colorize("unlockActiveColor", format("x%d", multiplierTable.WWBattleForOwnClan)))

  let isMultipliersByDiff = multiplierTable?.ArcadeBattle != null
  foreach (param, num in multiplierTable) {
    if (num == 1 && isMultipliersByDiff)
      continue

    if (mulText.len() > 0)
      mulText = $"{mulText}, "

    let mulLocParam = isMultipliersByDiff
      ? loc($"clan/short{param}")
      : loc($"missions/{getDiffNameByInt(param)}_short")
    mulText = $"{mulText}{mulLocParam}{nbsp}(x{num})"
  }

  let mulRanks = []
  if (rankMultiplierTable.len() > 0) {
    local lastAddedRank = 0
    let maxRank = maxCountryRank.get()
    for (local rank = 1; rank <= maxRank; rank++) {
      let curRankMul = rankMultiplierTable[rank]
      let nextRankMul = rankMultiplierTable?[rank + 1]
      if (!curRankMul || (nextRankMul && curRankMul == nextRankMul))
        continue

      let rankText = (rank - 1 == lastAddedRank)
        ? get_roman_numeral(rank)
        : getRangeString(get_roman_numeral(lastAddedRank + 1), get_roman_numeral(rank))

      mulRanks.append($"{rankText}{nbsp}(x{curRankMul})")
      lastAddedRank = rank
    }
  }
  local mulRankText = ", ".join(mulRanks)

  mulText = mulText.len() > 0
    ? "{0}{1}{2}".subst(loc("conditions/multiplier"), loc("ui/colon"), mulText)
    : ""
  if (mulText.len() > 0 && mulRankText.len() > 0)
    mulText = $"{mulText}\n"

  mulRankText = mulRankText.len() > 0
    ? "{0}{1}{2}".subst(loc("conditions/rankMultiplier"), loc("ui/colon"), mulRankText)
    : ""

  return colorize("fadedTextColor", "{0}{1}".subst(mulText, mulRankText))
}


function getUnlockMultDescByCfg(cfg) {
  if (!cfg?.conditions)
    return ""

  if (cfg.locMultDescId != "")
    return loc(cfg.locMultDescId, {
      mulArcade = cfg.mulArcade
      mulRealistic = cfg.mulRealistic
      mulHardcore = cfg.mulHardcore
    })

  let mainCond = getMainProgressCondition(cfg.conditions)
  return getUnlockMultDesc(mainCond)
}


function getFullUnlockDesc(cfg, params = {}) {
  return "\n".join([
    getUnlockDesc(cfg),
    getUnlockMainCondDescByCfg(cfg, params),
    getUnlockCondsDescByCfg(cfg),
    getUnlockMultDescByCfg(cfg)], true)
}


function getFullUnlockDescByName(unlockName, forUnlockedStage = -1, params = {}) {
  let unlock = getUnlockById(unlockName)
  if (!unlock)
    return ""

  let config = buildConditionsConfig(unlock, forUnlockedStage)
  return getFullUnlockDesc(config, params)
}


return {
  buildConditionsConfig
  getUnlockStagesDesc
  getAdditionalStagesDesc
  getUnlockDesc
  getFullUnlockDesc
  getFullUnlockDescByName
  getUnlockMultDescByCfg
  getUnlockMultDesc
  getUnlockCondsDescByCfg
  getUnlockCondsDesc
  getUnlockMainCondDescByCfg
  getUnlockMainCondDesc
  getLocForBitValues
  getUnlockNameText
  getSubUnlockLocName
  getUnlockLocName
  getDescriptionByUnlockType
  getIconByUnlockBlk
  getUnlockableMedalImage
}
