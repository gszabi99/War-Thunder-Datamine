import "%scripts/customization/contentPreview.nut" as contentPreview
import "%scripts/shop/shopSearchCore.nut" as shopSearchCore
import "%sqStdLibs/helpers/u.nut" as u
import "%sqstd/math.nut" as stdMath
import "%scripts/time.nut" as time
from "%scripts/unit/unitInfo.nut" import get_unit_icon_by_unit, getUnitCountry, getUnitExp
from "%scripts/langUtils/harmonized.nut" import is_harmonized_unit_image_required
from "%scripts/money.nut" import Cost
from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened
from "%sqstd/platform.nut" import platformId
from "%appGlobals/clientState/platform.nut" import canSpendRealMoney
from "%scripts/weaponry/weaponryInfo.nut" import getLastWeapon, isWeaponEnabled, isWeaponVisible
from "%scripts/weaponry/bulletsInfo.nut" import getUnitLastBullets
from "%scripts/unit/unitClassType.nut" import getUnitClassTypeByExpClass
from "%scripts/weaponry/weaponryPresets.nut" import getDefaultPresetId
from "%scripts/unit/initUnitWeapons.nut" import initUnitWeapons, initWeaponryUpgrades, initUnitModifications, initUnitWeaponsContainers, getWeaponImage
from "%scripts/unit/unitWeaponryCustomPresets.nut" import getWeaponryCustomPresets
from "%scripts/unit/remainingTimeUnit.nut" import isPromUnit
from "%scripts/customization/decoratorGetters.nut" import getDecorator
from "%scripts/weaponry/modificationInfo.nut" import isModificationEnabled
from "%scripts/options/countryFlagsPreset.nut" import hasCountryIcon
from "%scripts/unit/unitParams.nut" import getFullUnitBlk
from "%scripts/unit/unitStatus.nut" import isUnitInResearch, isUnitBroken, isUnitResearched
from "%scripts/unit/unitShopInfo.nut" import isUnitGift
from "%scripts/langUtils/language.nut" import getLanguageName
from "%scripts/onlineShop/onlineShopState.nut" import searchEntitlementsByUnit
from "%scripts/options/optionsExt.nut" import get_unit_preset_img
from "%scripts/unit/unitNews.nut" import addUnitNewsId
from "%scripts/unit/unitEvents.nut" import addUnitEventId, hasUnitEvent
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial, calcBattleRatingFromRank, get_unit_blk_economic_rank_by_mode
from "string" import split_by_chars
from "%sqstd/datablock.nut" import eachBlock, eachParam
from "unitCustomization" import get_skins_for_unit
from "chard" import get_charserver_time_sec
from "blkGetters" import get_wpcost_blk, get_warpoints_blk, get_unittags_blk, get_modifications_blk, get_ranks_blk
from "%scripts/dagui_natives.nut" import rented_units_get_expired_time_sec, clan_get_unit_open_cost_gold, wp_get_repair_cost, shop_is_aircraft_purchased, remove_calculate_modification_effect_jobs, shop_is_unit_rented, shop_get_spawn_score, shop_is_player_has_unit, wp_get_cost2, is_unlocked
from "%globalScripts/unitTypeConsts.nut" import *
from "%globalScripts/unlockConsts.nut" import UNLOCKABLE_WEAPON
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import get_tomoe_unit_icon
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem
from "%scripts/unit/unitsData.nut" import getUnitPackedFieldValue, unitPackedFieldNames

let { g_difficulty } = require("%scripts/difficulty.nut")
let { isString, isArray, isTable, isFunction } = u
let { unitClassType } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")
let { isDebugModeEnabled } = require("%scripts/debugTools/dbgChecks.nut")

const MOD_TIERS_COUNT = 4


let emptyArray = freeze([])
let emptyTable = freeze({})

let toOwnTable = @(t) t.is_frozen() ? { ...t } : t
let sharedByInitOnce = {}

function makeShareKey(v) {
  let parts = []
  if (isTable(v))
    foreach (key in v.keys().sort())
      parts.append($"{key}:{makeShareKey(v[key])}")
  else if (isArray(v))
    foreach (item in v)
      parts.append(makeShareKey(item))
  else
    return $"{type(v)}{v}"
  return "".concat("{", ",".join(parts), "}")
}

function isSameValue(a, b) {
  let t = type(a)
  if (t != type(b))
    return false
  if (t == "float")
    return a == b && (a != 0 || $"{a}" == $"{b}")
  if (t != "table" && t != "array")
    return a == b
  if (a.len() != b.len())
    return false
  foreach (key, item in a)
    if ((t == "table" && key not in b) || !isSameValue(item, b[key]))
      return false
  return true
}

function deepFreeze(v) {
  if (isTable(v))
    foreach (key in v.keys())
      v[key] = deepFreeze(v[key])
  else if (isArray(v))
    for (local i = 0; i < v.len(); i++)
      v[i] = deepFreeze(v[i])
  else
    return v
  return freeze(v)
}

function shareValue(sharedValues, value) {
  if (value.is_frozen())
    return value
  let key = makeShareKey(value)
  if (key not in sharedValues)
    sharedValues[key] <- []
  let candidates = sharedValues[key]
  let found = candidates.findvalue(@(c) isSameValue(c, value))
  if (found != null)
    return found
  let res = deepFreeze(value)
  candidates.append(res)
  return res
}

function buildWeaponsList(unitName, weaponsBlk) {
  let res = []
  eachBlock(weaponsBlk, function(presetBlk, presetName) {
    if (presetName == "custom_presets" || (presetBlk?.isWeaponForCustomSlot ?? false))
      return
    let tags = []
    eachParam(presetBlk?.tags, function(value, tag) {
      if (value == true)
        tags.append(tag)
    })
    let weapon = {
      name = presetName
      isUnlocked = is_unlocked(UNLOCKABLE_WEAPON, $"{unitName}/{presetName}")
      tags = tags.len() ? tags : emptyArray
      type = weaponsItem.weapon
    }
    let cost = wp_get_cost2(unitName, presetName)
    if (cost >= 0)
      weapon.cost <- cost
    res.append(weapon)
  })
  return res.len() ? res : emptyArray
}

let unitIntParams = [ "costGold", "rank", "reqExp",
  "repairCost", "repairTimeHrsArcade", "repairTimeHrsHistorical", "repairTimeHrsSimulation",
  "train2Cost", "train3Cost_gold", "train3Cost_exp",
  "gunnersCount", "bulletsIconParam"
]

let rareFieldDefaults = freeze({
  isPkgDev = false
  giftParam = null 
  shopEvent = null 
  premPackAir = false
  repairCost = 0
  hasDepthCharge = false
  futureReqAir = null
  futureReqAirDesc = null
  fakeReqUnits = null 
  reqFeature = null 
  reqUnlock = null 
  isCrossPromo = false
  crossPromoBanner = null
  customImage = null 
  customClassIco = null 
  customTooltipImage = null 
  modifications = null 
  previewSkinId = null 
  isToStringForDebug = true
  
  modificatorsRequestTime = -1
  modificators = null 
  modificatorsBase = null 
  minChars = null 
  maxChars = null 
  primaryWeaponMods = null 
  secondaryWeaponMods = null 
  bulGroups = -1
  bulModsGroups = -1
  researchType = null
  marketplaceItemdefId = null
  defaultWeaponPreset = null
  disableFlyout = false
  hideBrForVehicle = false
  showShortestUnitInfo = false 
  nvdSights = null 
  defaultBeltParam = null
  endResearchDate = null
  slaveUnits = null
  masterUnit = null
  _endRecentlyReleasedTime = null
  _isRecentlyReleased = null
  _operatorCountry = null
})

local Unit = class {
   name = ""
   rank = 0
   shopCountry = ""
   isInited = false 

   expClass = unitClassType.UNKNOWN
   unitType = unitTypes.INVALID
   esUnitType = ES_UNIT_TYPE_INVALID

   cost = 0
   costGold = 0
   reqExp = 0
   expMul = 1.0
   gift = null 
   event = null 
   repairTimeHrsArcade = 0
   repairTimeHrsHistorical = 0
   repairTimeHrsSimulation = 0
   freeRepairs = 0
   trainCost = 0
   train2Cost = 0
   train3Cost_gold = 0
   train3Cost_exp = 0
   gunnersCount = 0

   isInShop = false
   reqAir = null 
   group = null 
   showOnlyWhenBought = false
   showOnlyWhenAvailableForPurchase = false
   showOnlyWhenResearch = false
   showOnlyIfPlayerHasUnlock = null 
   hideForLangs = null 
   hideFeature = null 

   tags = null 
   weapons = null 
   skins = null 
   skinsBlocks = null 
   weaponUpgrades = null 
   spare = null 
   needBuyToOpenNextInTier = null 

   commonWeaponImage = "#ui/gameuiskin#weapon"
   primaryBullets = null 
   secondaryBullets = null 
   bulletsIconParam = 0

   testFlight = ""

   bulletsSets = null 
   shopReq = true 
   hasWeaponSlots = false
   weaponsContainers = null
   bulletsIconParams = null

   isWeaponsInited = false
   rareFields = null

  function _get(key) {
    if (unitPackedFieldNames.contains(key))
      return getUnitPackedFieldValue(this.name, key)
    if (key not in rareFieldDefaults)
      throw null
    let fields = this.rareFields
    return fields != null && key in fields ? fields[key] : rareFieldDefaults[key]
  }

  function _set(key, value) {
    if (key not in rareFieldDefaults)
      throw null
    let def = rareFieldDefaults[key]
    let fields = this.rareFields
    if (type(value) == type(def) && value == def)
      fields?.$rawdelete(key)
    else if (fields == null)
      this.rareFields = { [key] = value }
    else
      fields[key] <- value
  }

  getRareFieldNames = @() rareFieldDefaults.keys()

  
  constructor(unitTbl, sharedValues = null) {
    
    foreach (key, value in unitTbl)
      if (!unitPackedFieldNames.contains(key) && key in this)
        this[key] = value

    foreach (key in ["tags", "skins", "weaponUpgrades", "needBuyToOpenNextInTier"])
      if (!isArray(this[key]) || this[key].len() == 0)
        this[key] = emptyArray
    foreach (key in ["primaryBullets", "secondaryBullets", "bulletsSets", "skinsBlocks", "weaponsContainers"])
      if (!isTable(this[key]) || this[key].len() == 0)
        this[key] = emptyTable
    if (sharedValues != null)
      this.tags = shareValue(sharedValues, this.tags)
  }

  function setFromUnit(unit) {
    foreach (key, value in unit)
      if (!isFunction(value)
        && !unitPackedFieldNames.contains(key)
        && (key in this)
        && !isFunction(this[key])
      )
        this[key] = value
    if (this.rareFields != null)
      this.rareFields = { ...this.rareFields }
    this.expClass = getUnitClassTypeByExpClass(this.expClass.getExpClass())
    return this
  }

  function initOnce() {
    if (this.isInited)
      return null
    this.isInited = true

    let warpoints = get_warpoints_blk()
    let uWpCost = this.getUnitWpCostBlk()

    let expClassStr = uWpCost?.unitClass
    this.expClass = getUnitClassTypeByExpClass(expClassStr)
    this.esUnitType = this.expClass.unitTypeCode
    this.unitType = unitTypes.getByEsUnitType(this.esUnitType)

    foreach (p in unitIntParams)
      this[p] = uWpCost?[p] ?? 0

    this.bulletsIconParams         = uWpCost?.bulletsIconParams
    this.cost                      = uWpCost?.value ?? 0
    this.freeRepairs               = uWpCost?.freeRepairs ?? warpoints?.freeRepairs ?? 0
    this.expMul                    = uWpCost?.expMul ?? 1.0
    this.shopCountry               = uWpCost?.country ?? ""
    this.trainCost                 = uWpCost?.trainCost ?? warpoints?.trainCostByRank[$"rank{this.rank}"] ?? 0
    this.gift                      = uWpCost?.gift
    this.giftParam                 = uWpCost?.giftParam
    this.event                     = uWpCost?.event
    this.premPackAir               = uWpCost?.premPackAir ?? false
    this.hasDepthCharge            = uWpCost?.hasDepthCharge ?? false
    this.commonWeaponImage         = uWpCost?.commonWeaponImage ?? this.commonWeaponImage
    this.customClassIco            = uWpCost?.customClassIco
    this.customTooltipImage        = uWpCost?.customTooltipImage
    this.isPkgDev                  = is_dev_version() && (uWpCost?.pkgDev ?? false)
    this.researchType              = uWpCost?.researchType
    this.hideBrForVehicle          = this.tags.contains("hideBrForVehicle")
    this.showShortestUnitInfo      = this.tags.contains("showShortestUnitInfo")
    this.hasWeaponSlots            = uWpCost?.hasWeaponSlots ?? false
    this.defaultBeltParam          = uWpCost?.defaultBeltParam
    this.reqAir                    = uWpCost?.reqAir

    if (uWpCost?.spare != null) {
      let spareBlk = get_modifications_blk()?.modifications.spare

      let spare = {
        name = "spare"
        type = weaponsItem.spare
        cost = uWpCost?.spare.value ?? 0
        image = getWeaponImage(this.esUnitType, spareBlk, uWpCost?.spare)
        animation = spareBlk && (spareBlk % "animationByUnit")
          .findvalue((@(anim) anim.unitType == this.esUnitType).bindenv(this))?.src
      }
      if (uWpCost?.spare.costGold != null)
        spare.costGold <- uWpCost.spare.costGold
      this.spare = shareValue(sharedByInitOnce, spare)
    }

    let needBuyToOpenNextInTier = [...this.needBuyToOpenNextInTier]
    for (local i = 1; i <= MOD_TIERS_COUNT; i++)
      needBuyToOpenNextInTier.append(uWpCost?[$"needBuyToOpenNextInTier{i}"] ?? 0)
    this.needBuyToOpenNextInTier = shareValue(sharedByInitOnce, needBuyToOpenNextInTier)

    this.customImage = uWpCost?.customImage ?? get_unit_preset_img(this.name)
    if (!this.customImage && is_harmonized_unit_image_required(this))
      this.customImage = get_tomoe_unit_icon(this.name)
    if (this.customImage && !isInArray(this.customImage.slice(0, 1), ["#", "!"]))
      this.customImage = get_unit_icon_by_unit(this, this.customImage)
    shopSearchCore.cacheUnitSearchTokens(this)
    return
  }

  function hasPlatformFromBlkStr(blk, fieldName, defValue = false, separator = "; ") {
    let listStr = blk?[fieldName]
    if (!isString(listStr))
      return defValue
    return split_by_chars(listStr, separator).contains(platformId)
  }

  function applyShopBlk(shopUnitBlk, unitGroupName = null) {
    this.isInShop = true

    if (shopUnitBlk?.newsLabelId) {
      addUnitNewsId(this.name, shopUnitBlk.newsLabelId)
      if (unitGroupName != null)
        addUnitNewsId(unitGroupName, shopUnitBlk.newsLabelId)
    }

    if (shopUnitBlk?.eventLabelId) {
      addUnitEventId(this.name, shopUnitBlk.eventLabelId)
      if (unitGroupName != null)
        addUnitEventId(unitGroupName, shopUnitBlk.eventLabelId)
    }

    this.shopEvent = shopUnitBlk?.event

    if (shopUnitBlk?.slaveUnit)
      this.slaveUnits = [shopUnitBlk?.slaveUnit]

    this.futureReqAir = shopUnitBlk?.futureReqAir
    this.futureReqAirDesc = shopUnitBlk?.futureReqAirDesc
    this.group = unitGroupName
    if ("fakeReqUnitType" in shopUnitBlk)
      this.fakeReqUnits = shopUnitBlk % "fakeReqUnitType"

    this.showOnlyWhenAvailableForPurchase = shopUnitBlk?.showOnlyWhenAvailableForPurchase ?? false

    let isVisibleUnbought = !shopUnitBlk?.showOnlyWhenBought
      && this.hasPlatformFromBlkStr(shopUnitBlk, "showByPlatform", true)
      && !this.hasPlatformFromBlkStr(shopUnitBlk, "hideByPlatform", false)

    this.showOnlyWhenBought = !isVisibleUnbought
    this.showOnlyWhenResearch = shopUnitBlk?.showOnlyWhenResearch ?? false
    this.isCrossPromo = !!shopUnitBlk?.isCrossPromo
    this.crossPromoBanner = shopUnitBlk?.crossPromoBanner

    if (isVisibleUnbought && isString(shopUnitBlk?.hideForLangs))
      this.hideForLangs = split_by_chars(shopUnitBlk?.hideForLangs, "; ")

    foreach (key in ["reqFeature", "hideFeature", "showOnlyIfPlayerHasUnlock", "reqUnlock"])
      if ((shopUnitBlk?[key] ?? "") != "")
        this[key] = shopUnitBlk[key]

    this.gift = shopUnitBlk?.gift 
    this.giftParam = shopUnitBlk?.giftParam
    this.marketplaceItemdefId = shopUnitBlk?.marketplaceItemdefId
    this.disableFlyout = shopUnitBlk?.disableFlyout ?? false
    this.endResearchDate = shopUnitBlk?.endResearchDate
  }

  isAir                 = @() this.esUnitType == ES_UNIT_TYPE_AIRCRAFT
  isTank                = @() this.esUnitType == ES_UNIT_TYPE_TANK
  isShip                = @() this.esUnitType == ES_UNIT_TYPE_SHIP
  isBoat                = @() this.esUnitType == ES_UNIT_TYPE_BOAT
  isShipOrBoat          = @() this.esUnitType == ES_UNIT_TYPE_SHIP || this.esUnitType == ES_UNIT_TYPE_BOAT
  isSubmarine           = @() this.esUnitType == ES_UNIT_TYPE_SHIP && this.tags.indexof("submarine") != null
  isHelicopter          = @() this.esUnitType == ES_UNIT_TYPE_HELICOPTER
  isHuman               = @() this.esUnitType == ES_UNIT_TYPE_HUMAN
  



  getUnitWpCostBlk      = @() get_wpcost_blk()?[this.name]
  isUsable              = @() shop_is_player_has_unit(this.name)
  isRented              = @() shop_is_unit_rented(this.name)
  isBroken              = @() isUnitBroken(this)
  isResearched          = @() isUnitResearched(this)
  isInResearch          = @() isUnitInResearch(this)
  getRentTimeleft       = @() rented_units_get_expired_time_sec(this.name)
  getRepairCost         = @() Cost(wp_get_repair_cost(this.name))
  getCrewTotalCount     = @() max(this.getUnitWpCostBlk()?.crewTotalCount ?? 1, 1)
  getCrewUnitType       = @() this.unitType.crewUnitType
  getExp                = @() getUnitExp(this)

  function isBought() {
    if (this.masterUnit != null)
      return shop_is_aircraft_purchased(this.masterUnit)
    return shop_is_aircraft_purchased(this.name)
  }

  function isUsableSlaveUnit() {
    if (this.masterUnit == null)
      return false
    return shop_is_player_has_unit(this.masterUnit)
  }

  function getEndRecentlyReleasedTime() {
    if (this._endRecentlyReleasedTime != null)
      return this._endRecentlyReleasedTime

    this._endRecentlyReleasedTime = -1
    let releaseDate = get_unittags_blk()?[this.name].releaseDate
    if (releaseDate == null)
      return this._endRecentlyReleasedTime

    let recentlyReleasedUnitsDays = get_ranks_blk()?.recentlyReleasedUnitConsideredNewDays ?? 0
    if (recentlyReleasedUnitsDays == 0)
      return this._endRecentlyReleasedTime

    this._endRecentlyReleasedTime = time.getTimestampFromStringUtc(releaseDate)
      + time.daysToSeconds(recentlyReleasedUnitsDays)
    return this._endRecentlyReleasedTime
  }

  function isRecentlyReleased() {
    if (this._isRecentlyReleased != null)
      return this._isRecentlyReleased

    this._isRecentlyReleased = this.getEndRecentlyReleasedTime() > get_charserver_time_sec()
    return this._isRecentlyReleased
  }

  function getOperatorCountry() {
    if (this._operatorCountry)
      return this._operatorCountry
    local res = get_unittags_blk()?[this.name].operatorCountry ?? ""
    this._operatorCountry = res != "" && hasCountryIcon(res) ? res : this.shopCountry
    return this._operatorCountry
  }

  function getEconomicRank(ediff) {
    return get_unit_blk_economic_rank_by_mode(this.getUnitWpCostBlk(), ediff)
  }

  function getBattleRating(ediff) {
    let mrank = this.getEconomicRank(ediff)
    return calcBattleRatingFromRank(mrank)
  }

  function getCostRepairPerMin(diff) {
    let wp = this.getUnitWpCostBlk()?[$"repairCostPerMin{diff.getEgdName()}"]
    return wp ? Cost(wp) : null
  }

  function getWpRewardMulList(difficulty = g_difficulty.ARCADE) {
    let warpoints = get_warpoints_blk()
    let uWpCost = this.getUnitWpCostBlk()
    let mode = difficulty.getEgdName()

    let isSpecial = isUnitSpecial(this)
    let premPart = isSpecial ? warpoints?.rewardMulVisual.premRewardMulVisualPart ?? 0.5 : 0.0
    let mul = (uWpCost?[$"rewardMul{mode}"] ?? 1.0) *
      (warpoints?.rewardMulVisual?[$"rewardMulVisual{mode}"] ?? 1.0)
    let timedAward = uWpCost?[$"timedAward{mode}"] ?? 0

    return {
      wpMul   = stdMath.round_by_value(mul * (1.0 - premPart), isSpecial ? 0.05 : 0.1)
      wpTimed = timedAward * (1.0 - premPart)
      premMul = stdMath.round_by_value(1.0 / (1.0 - premPart), 0.1)
    }
  }

  function _tostring() {
    return $"Unit( {this.name} )"
  }

  function canAssignToCrew(country) {
    return getUnitCountry(this) == country && this.canUseByPlayer()
  }

  function canUseByPlayer() {
    return this.isUsable() && this.isVisibleInShop() && this.unitType.isAvailable()
  }

  function isVisibleInShop() {
    if (!this.isInShop || !this.unitType.isVisibleInShop())
      return false
    if (isDebugModeEnabled.status || this.isUsable())
      return true
    if (this.showOnlyWhenBought)
      return false
    if (this.hideForLangs && this.hideForLangs.indexof(getLanguageName()) != null)
      return false
    if (this.showOnlyIfPlayerHasUnlock && !isUnlockOpened(this.showOnlyIfPlayerHasUnlock))
      return false
    if (this.showOnlyWhenResearch && !this.isInResearch() && this.getExp() <= 0)
      return false
    if (this.hideFeature != null && hasFeature(this.hideFeature))
      return false
    if (isUnitGift(this) && !canSpendRealMoney() && !hasUnitEvent(this.name))
      return false
    if (this.showOnlyWhenAvailableForPurchase)
      return isPromUnit(this.name)

    return true
  }

  
  
  

  function resetSkins() {
    this.skins = emptyArray
    this.skinsBlocks = emptyTable
  }

  function getSkins() {
    if (this.skins.len() == 0)
      this.skins = get_skins_for_unit(this.name) 
    return this.skins
  }

  function getSkinBlockById(skinId) {
    this.updateSkinBlocks()
    return this.skinsBlocks?[skinId]
  }

  function updateSkinBlocks() {
    if (this.skinsBlocks.len()) 
      return
    let skinsBlocks = {}
    foreach (skin in this.getSkins())
      skinsBlocks[skin.name] <- skin
    this.skinsBlocks = skinsBlocks
  }

  function getPreviewSkinId() {
    if (!this.previewSkinId) {
      this.previewSkinId = ""
      foreach (skin in this.getSkins())
        if (getDecorator($"{this.name}/{skin.name}", decoratorTypes.SKINS)?.blk?.useByDefault)
          this.previewSkinId = skin.name
    }
    return this.previewSkinId
  }

  getSpawnScore = @(weaponName = null) shop_get_spawn_score(this.name, weaponName || getLastWeapon(this.name), getUnitLastBullets(this), { addWeaponMul = false, addBulletMul = false })

  function getMinimumSpawnScore() {
    local res = -1
    foreach (weapon in this.getWeapons())
      if (isWeaponVisible(this, weapon) && isWeaponEnabled(this, weapon)) {
        let spawnScore = this.getSpawnScore(weapon.name)
        if (res < 0 || res > spawnScore)
          res = spawnScore
      }
    return max(res, 0)
  }

  function invalidateModificators() {
    if (this.modificatorsRequestTime > 0) {
      remove_calculate_modification_effect_jobs()
      this.modificatorsRequestTime = -1
    }
    this.modificators = null
  }

  function addBulletsSet(setId, bulletsSet) {
    this.bulletsSets = toOwnTable(this.bulletsSets)
    this.bulletsSets[setId] <- bulletsSet
  }

  function setPrimaryBullets(weaponName, bulletsMask) {
    this.primaryBullets = toOwnTable(this.primaryBullets)
    this.primaryBullets[weaponName] <- bulletsMask
  }

  function setSecondaryBullets(weaponName, bulletsMask) {
    this.secondaryBullets = toOwnTable(this.secondaryBullets)
    this.secondaryBullets[weaponName] <- bulletsMask
  }

  function canPreview() {
    return this.isInShop
  }

  function doPreview() {
    if (this.canPreview())
      contentPreview.showUnitSkin(this.name)
  }

  isDepthChargeAvailable = @() this.hasDepthCharge || isModificationEnabled(this.name, "ship_depth_charge")

  function getNVDSights(modName) {
    if (!this.isTank())
      return []

    this.initNVDSightsOnce()
    return this.nvdSights?[modName] ?? []
  }

  function initNVDSightsOnce() {
    if (this.nvdSights)
      return

    this.nvdSights = {}
    eachBlock(getFullUnitBlk(this.name)?.modifications, function(mode, modeName) {
      if (mode?.effects.nightVision != null) {
        this.nvdSights[modeName] <- []
        eachBlock(
          mode.effects.nightVision,
          @(part, name) this.nvdSights[modeName].append({ name, resolution = part.resolution?.x ?? 0 }),
          this) 
      }
    }, this)
  }

  function getDefaultWeapon() {
    if (this.defaultWeaponPreset)
      return this.defaultWeaponPreset

    let unitBlk = getFullUnitBlk(this.name)
    if (!unitBlk)
      return null

    this.defaultWeaponPreset = getDefaultPresetId(unitBlk)
    return this.defaultWeaponPreset
  }

  function getEntitlements() {
    if (this.gift == null)
      return []

    return searchEntitlementsByUnit(this.name)
  }

  function isSlave() {
    return this.masterUnit != null
  }

  function getUnlockImage() {
    if (this.isAir())
      return "#ui/gameuiskin#blueprint_items_aircraft"
    if (this.isTank())
      return "#ui/gameuiskin#blueprint_items_tank"
    if (this.isShipOrBoat())
      return "#ui/gameuiskin#blueprint_items_ship"

    return "#ui/gameuiskin#blueprint_items_aircraft"
  }

  isSquadronVehicle       = @() this.researchType == "clanVehicle"
  getOpenCost             = @() Cost(0, clan_get_unit_open_cost_gold(this.name))

  function initWeaponsOnce() {
    if (this.isWeaponsInited)
      return

    let uWpCost = this.getUnitWpCostBlk()
    this.weapons = buildWeaponsList(this.name, uWpCost?.weapons)
    if (uWpCost?.weapons != null) {
      if (this.hasWeaponSlots) {
        this.weaponsContainers = toOwnTable(this.weaponsContainers)
        initUnitWeaponsContainers(this.weaponsContainers, uWpCost.weapons)
      }
      initUnitWeapons(this, this.weapons, uWpCost.weapons) 
      initWeaponryUpgrades(this, uWpCost)
    }

    this.isWeaponsInited = true
  }

  function getWeapons() {
    this.initWeaponsOnce()
    if (!this.hasWeaponSlots || !hasFeature("WeaponryCustomPresets"))
      return this.weapons

    return [].extend(this.weapons, getWeaponryCustomPresets(this))
  }

  function getModifications() {
    if (this.modifications != null)
      return this.modifications

    this.modifications = []
    let uWpCost = this.getUnitWpCostBlk()
    let errorsTextArray = initUnitModifications(this.modifications,
      uWpCost?.modifications ?? getFullUnitBlk(this.name)?.modifications, this.esUnitType)

    if (errorsTextArray.len() > 0)
      logerr("\n".join(errorsTextArray))

    return this.modifications
  }

  isEmpty =@() !this.name.len()
  _typeof = @() "Unit"
}

Unit.isEqual <- function(other) {
  return other instanceof Unit && this.name == other.name
}

return Unit
