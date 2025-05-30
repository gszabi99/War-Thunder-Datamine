from "%scripts/dagui_natives.nut" import get_unlock_type, get_name_by_unlock_type
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/mainConsts.nut" import SEEN
from "%scripts/utils_sa.nut" import roman_numerals, locOrStrip

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let getShipFlags = require("%scripts/customization/shipFlags.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { format, split_by_chars } = require("string")
let { ceil } = require("math")
let { number_of_set_bits, round_by_value, is_bit_set } = require("%sqstd/math.nut")
let { buildDateStrShort, buildDateTimeStr } = require("%scripts/time.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { isLoadingBgUnlock, getLoadingBgName,
  getLoadingBgIdByUnlockId } = require("%scripts/loading/loadingBgData.nut")
let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { loadCondition, isBitModeType, getMainProgressCondition, isNestedUnlockMode, isTimeRangeCondition,
  getRangeString, getUnlockConditions, getDiffNameByInt, isStreak, getProgressBarData,
  loadMainProgressCondition, loadConditionsFromBlk, getMultipliersTable
} = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnlockCost, isUnlockComplete, getUnlockType, isUnlockOpened, canClaimUnlockReward, isUnlockExist,
  isUnlockVisibleByTime, debugLogVisibleByTimeInfo, canClaimUnlockRewardForUnit, getUnlockRewardCost,
  isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getDecoratorById, getDecorator } = require("%scripts/customization/decorCache.nut")
let { getPlaneBySkinId } = require("%scripts/customization/skinUtils.nut")
let { cutPrefix, stripTags } = require("%sqstd/string.nut")
let { getLocIdsArray } = require("%scripts/langUtils/localization.nut")
let { getUnlockProgressSnapshot } = require("%scripts/unlocks/unlockProgressSnapshots.nut")
let { season, seasonLevel, getLevelByExp } = require("%scripts/battlePass/seasonState.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getRoleText } = require("%scripts/unit/unitInfoRoles.nut")
let { getMissionTimeText } = require("%scripts/missions/missionsText.nut")
let { hasActiveUnlock, getUnitListByUnlockId } = require("%scripts/unlocks/unlockMarkers.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { makeConfigStr } = require("%scripts/seen/bhvUnseen.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { getTypeByUnlockedItemType, decoratorTypes, getTypeByResourceType
} = require("%scripts/customization/types.nut")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { addTooltipTypes, getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { MAX_COUNTRY_RANK, getRankByExp } = require("%scripts/ranks.nut")
let { getWarbondPriceText } = require("%scripts/warbonds/warbondsState.nut")
let { findItemById, getRawInventoryItemAmount, getItemOrRecipeBundleById } = require("%scripts/items/itemsManager.nut")
let { getRegionalUnlockProgress, isRegionalUnlock } = require("%scripts/unlocks/regionalUnlocks.nut")
let { getPlayerRankByCountry } = require("%scripts/user/userInfoStats.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { getUnlockProgress } = require("unlocks")
let { get_charserver_time_sec } = require("chard")
let { activeUnlocks } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { isBattleTask, getBattleTaskNameById } = require("%scripts/unlocks/battleTasks.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")

const MAX_STAGES_NUM = 10 
const SUB_UNLOCKS_COL_COUNT = 4

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
  names = [] 

  showProgress = true
  getProgressBarData = function() {
    let res = getProgressBarData(this.type, this.curVal, this.maxVal)
    res.show = res.show && this.showProgress
    return res
  }
}

function getUnlockableMedalImage(id, big = false) {
  return big ? $"!@ui/medals/{id}_big.ddsx" : $"!@ui/medals/{id}.ddsx"
}

function setRewardIconCfg(cfg, blk, unlocked) {
  if (!blk?.userLogId)
    return

  let item = findItemById(blk.userLogId)
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

function getDescriptionByUnlockType(unlockBlk) {
  let unlockType = get_unlock_type(unlockBlk?.type ?? "")
  if (unlockType == UNLOCKABLE_MEDAL) {
    if (unlockBlk?.subType == "clan_season_reward") {
      let unlock = ::ClanSeasonPlaceTitle.createFromUnlockBlk(unlockBlk)
      return unlock.desc()
    }
  }
  else if (unlockType == UNLOCKABLE_DECAL)
    return loc($"decals/{unlockBlk.id}/desc", "")

  return loc($"{unlockBlk.id}/desc", "")
}

function getIconByUnlockBlk(unlockBlk) {
  let unlockType = get_unlock_type(unlockBlk.type)
  let decoratorType = getTypeByUnlockedItemType(unlockType)
  if (decoratorType != decoratorTypes.UNKNOWN && !is_in_loading_screen()) {
    let decorator = getDecorator(unlockBlk.id, decoratorType)
    return decoratorType.getImage(decorator)
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
  if (config.image == "")
    setRewardIconCfg(config, blk, unlocked)
  if (config.image == "" && !config?.iconData)
    setUnlockIconCfg(config, blk)
  if (config.image != "")
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
      ? (blk.mode.num / 1000)  : blk.mode.num
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

  if (activeUnlocks.value?[config.id] != null)
    return getTooltipType("BATTLE_PASS_CHALLENGE").getMarkup(config.id, { showProgress = true })

  return getTooltipType("UNLOCK").getMarkup(config.id, { showProgress = true })
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

function getDifficultyLocalizationText(difficulty) {
  return difficulty == "hardcore"  ? loc("difficulty2")
    : difficulty == "realistic" ? loc("difficulty1")
    : loc("difficulty0")
}

function isFlagUnlock(id) {
  return id in getShipFlags()
}

function getSubunlockOrUnlockName(id) {
  let unlockBlk = getUnlockById(id)
  if (unlockBlk?.useSubUnlockName)
    return getSubUnlockLocName(unlockBlk)
  if (unlockBlk?.locId)
    return getUnlockLocName(unlockBlk)
  return loc($"{id}/name")
}

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
      let unlock = ::ClanSeasonPlaceTitle.createFromUnlockBlk(unlockBlk)
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
  return $"{name} {roman_numerals[stage]}"
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
    valuesText = colorize(isExpired ? "red" : "unlockActiveColor", valuesText)
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
    if (condition.season != season.value)
      return $"{reqLevel}"
    let curLevelText = loc("conditions/battlepassProgress/currentLevel", { level = seasonLevel.value })
    return reqLevel <= seasonLevel.value
      ? $"{reqLevel} {curLevelText}"
      : $"{reqLevel} {colorize("red" ,curLevelText)}"
  }
  if (condType == "battlepassLevel") {
    if (condition.season != season.value)
      return $"{v}"
    let curLevelText = loc("conditions/battlepassProgress/currentLevel", { level = seasonLevel.value })
    return v <= seasonLevel.value
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


function getUnlockCondsDesc(conditions, isExpired = false) {
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

      addTextToCondTextList(condTextsList, group, data, { isExpired })
    }
    else {
      let customData = getTblValue(group, customDataByLocGroups)
      if (customData == null || customData.len() == 0)
        continue

      foreach (condCustomData in customData)
        foreach (descText in condCustomData.descText)
          addTextToCondTextList(condTextsList, group, descText, {
            customLocGroupText = condCustomData.groupText
            isExpired
          })
    }
  }

  return "\n".join(condTextsList, true)
}

function getUnlockCondsDescByCfg(cfg) {
  if (!cfg?.conditions)
    return ""
  return getUnlockCondsDesc(cfg.conditions, cfg.isExpired)
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

let singleAttachmentList = {
  unlockOpenCount = "unlock"
  unlockStageCount = "unlock"
}

function isCheckedBySingleAttachment(modeType) {
  return modeType in singleAttachmentList || isBitModeType(modeType)
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
    for (local rank = 1; rank <= MAX_COUNTRY_RANK; rank++) {
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
      let conditionDescription = stripTags(names[i])
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

addTooltipTypes({
  UNLOCK = { 
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params) {
      if (!checkObj(obj))
        return false

      let config = ::build_log_unlock_data(params.__merge({ id = unlockId }))

      if (config.type == -1)
        return false

      ::build_unlock_tooltip_by_config(obj, config, handler)
      return true
    }
  }

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
        text.append(decoratorType.getLocDesc(name))

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
  getUnlockLocName
  getUnlockTitle
  getSubUnlockLocName
  getUnlockNameText
  getLocForBitValues
  getUnlockableMedalImage
  getIconByUnlockBlk
  getFullUnlockDesc
  getFullUnlockDescByName
  getFullUnlockCondsDesc
  getFullUnlockCondsDescInline
  getUnlockDesc
  getDescriptionByUnlockType
  getUnlockMainCondDesc
  getUnlockMainCondDescByCfg
  getUnlockCondsDesc
  getUnlockCondsDescByCfg
  getUnlockMultDesc
  getUnlockMultDescByCfg
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
  buildConditionsConfig
  getSubunlockCfg
  getTooltipMarkupByModeType
  getUnlocksListView
  fillUnlockConditions
  getRewardCfgByUnlockCfg
  fillUnlockStages
  getSubunlocksView
  getUnlockStagesView
  fillSimplifiedUnlockInfo
}