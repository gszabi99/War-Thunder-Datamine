//-file:plus-string
from "%scripts/dagui_natives.nut" import shop_get_module_exp, calculate_mod_or_weapon_effect, wp_get_repair_cost_by_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, INFO_DETAIL
let { getPresetRewardMul, getWeaponDamage } = require("%appGlobals/econWeaponUtils.nut")

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getCurrentShopDifficulty, getCurrentGameMode, getRequiredUnitTypes } = require("%scripts/gameModes/gameModeManagerState.nut")
let { format } = require("string")
let { isEqual } = require("%sqstd/underscore.nut")
let { eachBlock, isDataBlock } = require("%sqstd/datablock.nut")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let weaponryEffects = require("%scripts/weaponry/weaponryEffects.nut")
let { getByCurBundle, canBeResearched, isModInResearch, getDiscountPath, getItemStatusTbl, getRepairCostCoef,
  isResearchableItem, countWeaponsUpgrade, getItemUpgradesList
} = require("%scripts/weaponry/itemInfo.nut")
let { isBullets, isWeaponTierAvailable, isBulletsGroupActiveByMod, getBulletsNamesBySet,
  getModificationInfo, getModificationName, isBulletsWithoutTracer, getBulletsSetData
} = require("%scripts/weaponry/bulletsInfo.nut")
let { addBulletsParamToDesc, buildBulletsData, addArmorPiercingToDesc } = require("%scripts/weaponry/bulletsVisual.nut")
let { WEAPON_TYPE, TRIGGER_TYPE, CONSUMABLE_TYPES, WEAPON_TEXT_PARAMS, getPrimaryWeaponsList, isWeaponEnabled,
  addWeaponsFromBlk } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponInfoText, getModItemName, getReqModsText, getFullItemCostText } = require("weaponryDescription.nut")
let { isModResearched, isModificationEnabled, getModificationByName
} = require("%scripts/weaponry/modificationInfo.nut")
let { getActionItemAmountText, getActionItemModificationName } = require("%scripts/hud/hudActionBarInfo.nut")
let { getActionBarItems } = require("hudActionBar")
let { getUnitWeaponsByTier, getUnitWeaponsByPreset } = require("%scripts/weaponry/weaponryPresets.nut")
let { get_warpoints_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")

let TYPES_ARMOR_PIERCING = [TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.ATGM]
const UI_BASE_REWARD_DECORATION = 10

function updateModType(unit, mod) {
  if ("type" in mod)
    return

  let { name } = mod
  let primaryWeaponsNames = getPrimaryWeaponsList(unit)
  foreach (modName in primaryWeaponsNames)
    if (modName == name) {
      mod.type <- weaponsItem.primaryWeapon
      return
    }

  mod.type <- weaponsItem.modification
  return
}

function updateSpareType(spare) {
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

function getTierTooltipParams(weaponry, presetName, tierId) {
  let tier = weaponry.tiers?[tierId] || weaponry.tiers?[tierId.tostring()] // to handle cases when we get weaponry after json stringifying/parsing
  return {
    tooltipLang   = tier?.tooltipLang
    amountPerTier = tier?.amountPerTier ?? weaponry.amountPerTier ?? 0
    name          = weaponry.name
    blk           = weaponry.blk
    tType         = weaponry.tType
    ammo          = weaponry.ammo
    isGun         = weaponry.isGun
    addWeaponry   = weaponry?.addWeaponry
    presetName
    tierId
  }
}

function getSingleWeaponDescTbl(unit, params) {
  let { blkPath, tType, presetName } = params
  let weapons = addWeaponsFromBlk({}, getUnitWeaponsByPreset(unit, blkPath, presetName), unit)
  let res = {
    desc = getWeaponInfoText(unit, {
      weapons
      isPrimary = false
      isSingle = true
      detail = INFO_DETAIL.EXTENDED
    })
  }
  if (TYPES_ARMOR_PIERCING.contains(tType)) {
    let bulletsData = buildBulletsData(calculate_tank_bullet_parameters(unit.name, blkPath, true, false))
    addArmorPiercingToDesc(bulletsData, res)
  }
  return res
}

function getGunAmmoPerTier(weapons) {
  // It works for gun on tier only.
  // The logic below works on assume the tier can have only one gun/cannon block by design.
  let trigger = (weapons?.weaponsByTypes[WEAPON_TYPE.GUNS]
    ?? weapons?.weaponsByTypes[WEAPON_TYPE.CANNON])?[0]
  if (!trigger)
    return null

  let block = trigger.weaponBlocks.values()?[0]
  return block && block.num > 0 ? block.ammo * (block?.amountPerTier ?? 1) : null
}

function buildWeaponDescHeader(params, count) {
  let { name, tType, ammo } = params

  local weaponName = loc($"weapons/{name}")
  local header = ""

  if (isInArray(tType, CONSUMABLE_TYPES))
    header = count > 1
      ? "".concat(weaponName, format(loc("weapons/counter"), count))
      : weaponName
  else if (ammo > 0)
    header = "".concat(weaponName, " (", loc("shop/ammo"), loc("ui/colon"),
      count <=1 ? ammo : count ?? "", ")")

  return header.len() > 0 ? header : weaponName
}

function getWeaponDescTbl(unit, params) {
  let { amountPerTier,
    blk, tType, ammo, isGun, presetName, tierId } = params

  let isBlock = amountPerTier > 1
  let weapArr = getUnitWeaponsByTier(unit, blk, tierId)
    ?? getUnitWeaponsByPreset(unit, blk, presetName)
  let weapons = addWeaponsFromBlk({}, weapArr, unit)
  let weaponInfoText = getWeaponInfoText(unit, {
    weapons
    isPrimary = false
    detail = INFO_DETAIL.EXTENDED
  })

  local count = 1

  if (isInArray(tType, CONSUMABLE_TYPES))
    count = isBlock
      ? amountPerTier
      : count
  else if (ammo > 0)
    count = !isBlock
      ? ammo
      : isGun ? getGunAmmoPerTier(weapons) : amountPerTier

  // Remove header with incorrect weapons amount from description
  let descArr = weaponInfoText.split(WEAPON_TEXT_PARAMS.newLine).slice(1)
  let desc = WEAPON_TEXT_PARAMS.newLine.join(descArr)
  let res = { weapons, count, desc }
  if (TYPES_ARMOR_PIERCING.contains(tType)) {
    let bulletsData = buildBulletsData(calculate_tank_bullet_parameters(unit.name, blk, true, false))
    addArmorPiercingToDesc(bulletsData, res)
  }

  return res
}

function getTierDescTbl(unit, params) {
  let { tooltipLang, name, addWeaponry, presetName, tierId } = params

  if (tooltipLang != null)
    return { desc = loc(tooltipLang) }

  let weaponryDesc = getWeaponDescTbl(unit, params)
  local additionalWeaponryDesc = addWeaponry
    ? getWeaponDescTbl(unit, getTierTooltipParams(addWeaponry, presetName, tierId))
    : null

  local res = { desc = "", bulletParams = weaponryDesc?.bulletParams }

  if (!additionalWeaponryDesc) {
    let header = buildWeaponDescHeader(params, weaponryDesc.count)
    res.desc = $"{header}\n{weaponryDesc.desc}"
    return res
  }

  if (loc($"weapons/{name}") == loc($"weapons/{addWeaponry.name}")) {
    let header = buildWeaponDescHeader(params, weaponryDesc.count + additionalWeaponryDesc.count)
    res.desc = $"{header}\n{weaponryDesc.desc}"
  } else {
    let header = buildWeaponDescHeader(params, weaponryDesc.count)
    let addHeader = buildWeaponDescHeader(params.addWeaponry, additionalWeaponryDesc.count)
    res.desc = $"{header}\n{weaponryDesc.desc}\n{addHeader}\n{additionalWeaponryDesc.desc}"
  }

  if ("bulletParams" in additionalWeaponryDesc) {
    if (!res.bulletParams)
      res.bulletParams = []
    if(!isEqual(res.bulletParams, additionalWeaponryDesc.bulletParams))
      res.bulletParams.extend(additionalWeaponryDesc.bulletParams)
  }

  return res
}

function getReqTextWorldWarArmy(unit, item) {
  local text = ""
  let misRules = getCurMissionRules()
  if (!misRules.needCheckWeaponsAllowed(unit))
    return text

  let isEnabledByMission = misRules.isUnitWeaponAllowed(unit, item)
  let isEnabledForUnit = isWeaponEnabled(unit, item)
  if (!isEnabledByMission)
    text = "<color=@badTextColor>" + loc("worldwar/weaponry/inArmyIsDisabled") + "</color>"
  else if (isEnabledByMission && !isEnabledForUnit)
    text = "<color=@badTextColor>" + loc("worldwar/weaponry/inArmyIsEnabled/weaponRequired") + "</color>"
  else if (isEnabledByMission && isEnabledForUnit)
    text = "<color=@goodTextColor>" + loc("worldwar/weaponry/inArmyIsEnabled") + "</color>"

  return text
}

function getBasesEstimatedDamageRewardText(unit, item) {
  local res = ""

  let reqUnitTypes = getRequiredUnitTypes(getCurrentGameMode())
  if (reqUnitTypes.len() == 0 || !reqUnitTypes.contains(ES_UNIT_TYPE_AIRCRAFT))
    return res

  // {<presetName> = <weaponCount>, ...} - {"fab500" = 2, "fab100_internal" = 1}
  local itemPresetList = {}

  // {<weaponName> = <weaponCount>, ...} - {"bombguns_su_fab500x" = 2, "bombguns_su_fab250x" = 1}
  local customPresetWeaponTable = {}

  if (isDataBlock(item?.weaponsBlk) && unit.hasWeaponSlots) {
    foreach (w in item.weaponsBlk % "Weapon") {
      let {preset = null} = w
      if (preset != null)
        itemPresetList[preset] <- (itemPresetList?[preset] ?? 0) + 1
    }
    let customPresets = unit.getUnitWpCostBlk()?.weapons.custom_presets
    if (isDataBlock(customPresets)) {
      eachBlock(customPresets, function(slotBlk) {
        eachBlock(slotBlk, function(val, key) {
          if (key not in itemPresetList)
            return
          local weaponKey = val.paramCount() == 0 ? "" : val.getParamName(0)
          if (weaponKey != "") {
            customPresetWeaponTable[weaponKey] <- itemPresetList[key]
          }
        })
      })
    }
  }

  let estimatedDamageToBase = getWeaponDamage(unit.name, item.name, customPresetWeaponTable)

  if (estimatedDamageToBase == 0)
    return res

  let rewardMultiplierForBases = format("%.1f", getPresetRewardMul(unit.name, estimatedDamageToBase) * UI_BASE_REWARD_DECORATION)

  res = "".concat(loc("shop/estimated_damage_to_base"), " ", estimatedDamageToBase, "\n",
    loc("shop/reward_multiplier_for_base"), " ", rewardMultiplierForBases, "\n")

  return res
}

function getItemDescTbl(unit, item, params = null, effect = null, updateEffectFunc = null) {
  let res = { name = "", desc = "", delayed = false }
  let needShowWWSecondaryWeapons = item.type == weaponsItem.weapon && isInFlight()
    && getCurMissionRules().isWorldWar

  let self = callee()
  if (item.type == weaponsItem.bundle)
    return getByCurBundle(unit, item,
      function(unit_, item_) {
        return self(unit_, item_, params, effect, updateEffectFunc)
      }, res)

  local name = "<color=@activeTextColor>" + getModItemName(unit, item, false) + "</color>"
  if (isBulletsWithoutTracer(unit, item)) {
    let noTracerText = loc("ui/parentheses/space", {
      text = $"{loc("weapon/noTracer/icon")} {loc("weapon/noTracer")}"
    })
    name = $"{name}{noTracerText}"
  }
  local desc = ""
  local addDesc = ""
  local reqText = ""
  let curTier = "tier" in item ? item.tier : 1
  let statusTbl = getItemStatusTbl(unit, item)
  local currentPrice = statusTbl.showPrice ? getFullItemCostText(unit, item) : ""

  let hasPlayerInfo = params?.hasPlayerInfo ?? true
  if (hasPlayerInfo
    && !isWeaponTierAvailable(unit, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons) {
    let reqMods = ::getNextTierModsCount(unit, curTier - 1)
    if (reqMods > 0)
      reqText = loc("weaponry/unlockModTierReq",
                      { tier = ::roman_numerals[curTier], amount = reqMods.tostring() })
    else
      reqText = loc("weaponry/unlockTier/reqPrevTiers")
    reqText = $"<color=@badTextColor>{reqText}</color>"
    res.reqText <- reqText

    if (!(params?.canDisplayInfo ?? true)) {
      res.delayed = true
      return res
    }
  }

  if (item.type == weaponsItem.weapon) {
    name = ""
    desc = getWeaponInfoText(unit, { isPrimary = false, weaponPreset = item.name,
      detail = params?.detail ?? INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })

    if ((item.rocket || item.bomb) && (params?.detail ?? INFO_DETAIL.EXTENDED) == INFO_DETAIL.EXTENDED) {
      let bulletsData = buildBulletsData(calculate_tank_bullet_parameters(unit.name, item.name, true, true))
      addArmorPiercingToDesc(bulletsData, res)
    }
    if (effect) {
      addDesc = weaponryEffects.getDesc(unit, effect, { curEdiff = params?.curEdiff })
      let estimatedDamageAndMultiplier = getBasesEstimatedDamageRewardText(unit, item)
      if (estimatedDamageAndMultiplier != "")
        addDesc = "".concat(estimatedDamageAndMultiplier, addDesc)
    }
    if (!effect && updateEffectFunc)
      res.delayed = calculate_mod_or_weapon_effect(unit.name, item.name, false, this,
        updateEffectFunc, null) ?? true
  }
  else if (item.type == weaponsItem.primaryWeapon) {
    name = ""
    desc = getWeaponInfoText(unit, { isPrimary = true, weaponPreset = item.name,
      detail = params?.detail ?? INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })
    let upgradesList = getItemUpgradesList(item)
    if (upgradesList) {
      let upgradesCount = countWeaponsUpgrade(unit, item)
      if (upgradesCount?[1])
        addDesc = "\n" + loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach (arr in upgradesList)
        foreach (upgrade in arr) {
          if (upgrade == null)
            continue
          addDesc += "\n" + (isModificationEnabled(unit.name, upgrade)
            ? "<color=@goodTextColor>"
            : "<color=@commonTextColor>")
              + getModificationName(unit, upgrade) + "</color>"
        }
    }
  }
  else if (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) {
    if (item.type == weaponsItem.modification)
      res.modificationAnimation <- item?.modificationAnimation
    if (effect) {
      desc = getModificationInfo(unit, item.name).desc
      addDesc = weaponryEffects.getDesc(unit, effect, { curEdiff = params?.curEdiff })
    }
    else {
      let info = getModificationInfo(unit, item.name, false, false, this, updateEffectFunc)
      desc = info.desc
      res.delayed = info.delayed
    }

    addBulletsParamToDesc(res, unit, item)
    let { pairModName = null } = params
    if (pairModName != null) {
      let pairMod = getModificationByName(unit, pairModName)
      if (pairMod != null) {
        name = ""
        let pairBulletsParam = {}
        addBulletsParamToDesc(pairBulletsParam, unit, pairMod)
        res.bulletAnimations.extend(pairBulletsParam.bulletAnimations)
        res.bulletActions.extend(pairBulletsParam.bulletActions )
        res.hasBulletAnimation = res.hasBulletAnimation || pairBulletsParam.hasBulletAnimation
        let set = getBulletsSetData(unit, pairModName)
        if (set != null) {
          let { annotation } = getBulletsNamesBySet(set)
          desc = $"{desc}\n{annotation}"
        }
      }
    }
  }
  else if (item.type == weaponsItem.spare) {
    desc = loc($"spare/{item.name}/desc")
    res.modificationAnimation <- item?.animation
  }

  if (hasPlayerInfo && statusTbl.unlocked && currentPrice != "") {
    let amountText = ::getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount)
    if (amountText != "") {
      let color = statusTbl.amount < statusTbl.amountWarningValue ? "badTextColor" : ""
      res.amountText <- colorize(color, loc("options/count") + loc("ui/colon") + amountText)

      if (isInFlight() && item.type == weaponsItem.weapon) {
        let respLeft = getCurMissionRules().getUnitWeaponRespawnsLeft(unit, item)
        if (respLeft >= 0)
          res.amountText += loc("ui/colon") + loc("respawn/leftRespawns", { num = respLeft })
      }
    }
    if (statusTbl.showMaxAmount && statusTbl.amount < statusTbl.amountWarningValue)
      res.warningText <- loc("weapons/restock_advice")
  }
  else if (params?.isInHudActionBar) {
    let modData = u.search(getActionBarItems(),
      @(itemData) getActionItemModificationName(itemData, unit) == item.name)
    if (modData)
      res.amountText <- getActionItemAmountText(modData, true)
  }

  let isScoreCost = isInFlight()
    && getCurMissionRules().isScoreRespawnEnabled
  if (statusTbl.discountType != "" && !isScoreCost) {
    let discount = ::getDiscountByPath(getDiscountPath(unit, item, statusTbl.discountType))
    if (discount > 0 && statusTbl.showPrice && currentPrice != "") {
      let cost = "cost" in item ? item.cost : 0
      let costGold = "costGold" in item ? item.costGold : 0
      let priceText = Cost(cost, costGold).getUncoloredText()
      if (priceText != "")
        res.noDiscountPrice <- $"<color=@oldPrice>{priceText}</color>"
      currentPrice = $"<color=@goodTextColor>{currentPrice}</color>"
    }
  }

  let repairCostCoef = getRepairCostCoef(item)
  if (repairCostCoef) {
    let avgRepairMul = get_warpoints_blk()?.avgRepairMul ?? 1.0
    let egdCode = getCurrentShopDifficulty().egdCode
    let rCost = wp_get_repair_cost_by_mode(unit.name, egdCode, false)
    let avgCost = (rCost * repairCostCoef * avgRepairMul).tointeger()
    if (avgCost)
      addDesc += "\n" + loc("shop/avg_repair_cost") + nbsp
        + (avgCost > 0 ? "+" : "")
        + Cost(avgCost).toStringWithParams({ isWpAlwaysShown = true, isColored = false })
  }

  if (hasPlayerInfo) {
    if (!statusTbl.amount && !needShowWWSecondaryWeapons) {
      let reqMods = getReqModsText(unit, item)
      if (reqMods != "")
        reqText += (reqText == "" ? "" : "\n") + reqMods
    }
    if (isBullets(item) && !isBulletsGroupActiveByMod(unit, item) && !isInFlight())
      reqText += ((reqText == "") ? "" : "\n") + loc("msg/weaponSelectRequired")
    reqText = reqText != "" ? ($"<color=@badTextColor>{reqText}</color>") : ""

    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(unit, item)
  }
  res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name
  res.desc = desc
  res.addDesc <- addDesc != "" ? addDesc : null
  return res
}

function updateWeaponTooltip(obj, unit, item, handler, params = {}, effect = null) {
  let self = callee()
  let descTbl = getItemDescTbl(unit, item, params, effect,
    function(effect_, ...) {
      if (checkObj(obj) && obj.isVisible())
        self(obj, unit, item, handler, params, effect_)
    })

  let curExp = shop_get_module_exp(unit.name, item.name)
  let is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && isModResearched(unit, item))
  let is_researching = isModInResearch(unit, item)
  let is_paused = canBeResearched(unit, item, true) && curExp > 0

  if (is_researching || is_paused || !is_researched) {
    if ((("reqExp" in item) && item.reqExp > curExp) || is_paused) {
      local expText = ""
      if (is_researching || is_paused)
        expText = loc("currency/researchPoints/name") + loc("ui/colon") +
          colorize("activeTextColor",
            Cost().setRp(curExp).toStringWithParams({ isRpAlwaysShown = true }) +
            loc("ui/slash") + Cost().setRp(item.reqExp).tostring())
      else
        expText = loc("shop/required_rp") + " " + "<color=@activeTextColor>" +
          Cost().setRp(item.reqExp).tostring() + "</color>"

      let diffExp = Cost().setRp(getTblValue("diffExp", params, 0)).tostring()
      if (diffExp.len())
        expText += " (+" + diffExp + ")"
      descTbl.expText <- expText
    }
  }
  else if (params?.hasPlayerInfo ?? true)
    descTbl.showPrice <- ("currentPrice" in descTbl) || ("noDiscountPrice" in descTbl)

  descTbl.hasSweepRange <- item?.hasSweepRange
  let data = handyman.renderCached(("%gui/weaponry/weaponTooltip.tpl"), descTbl)
  obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
}

let defaultWeaponTooltipParamKeys = [
  "detail"
  "hasPlayerInfo"
  "canDisplayInfo"
  "weaponsFilterFunc"
  "curEdiff"
  "isInHudActionBar"
  "diffExp"
  "weaponBlkPath"
  "pairModName"
]
function validateWeaponryTooltipParams(params) {
  if (params == null)
    return {}
  let res = {}
  foreach (key in defaultWeaponTooltipParamKeys)
    if (key in params)
      res[key] <- params[key]
  return res
}

return {
  updateModType
  getTierTooltipParams
  getTierDescTbl
  getSingleWeaponDescTbl
  updateSpareType
  updateWeaponTooltip
  validateWeaponryTooltipParams
}