from "%scripts/dagui_natives.nut" import shop_get_module_exp, calculate_mod_or_weapon_effect, wp_get_repair_cost_by_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, INFO_DETAIL
from "%scripts/utils_sa.nut" import getAmountAndMaxAmountText, roman_numerals

let { getPresetRewardMul, getWeaponDamage } = require("%appGlobals/econWeaponUtils.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getCurrentShopDifficulty, getCurrentGameMode, getRequiredUnitTypes } = require("%scripts/gameModes/gameModeManagerState.nut")
let { format } = require("string")
let { utf8Capitalize } = require("%sqstd/string.nut")
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
let { addBulletsParamToDesc, buildBulletsData, addArmorPiercingToDesc, addArmorPiercingToDescForBullets
  checkBulletParamsBeforeRender
} = require("%scripts/weaponry/bulletsVisual.nut")
let { WEAPON_TYPE, TRIGGER_TYPE, CONSUMABLE_TYPES, getPrimaryWeaponsList, isWeaponEnabled,
  addWeaponsFromBlk, getWeaponExtendedInfo
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponInfoText, getModItemName, getReqModsText, getFullItemCostText, makeWeaponInfoData
} = require("weaponryDescription.nut")
let { isModResearched, isModificationEnabled, getModificationByName
} = require("%scripts/weaponry/modificationInfo.nut")
let { getActionItemAmountText, getActionItemModificationName } = require("%scripts/hud/hudActionBarInfo.nut")
let { getActionBarItems } = require("hudActionBar")
let { getUnitWeaponsByTier, getUnitWeaponsByPreset } = require("%scripts/weaponry/weaponryPresets.nut")
let { get_warpoints_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getDiscountByPath } = require("%scripts/discounts/discountUtils.nut")

let TYPES_ARMOR_PIERCING = [TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.ATGM]
const UI_BASE_REWARD_DECORATION = 10

function setWidthForWeaponsPresetTooltip(obj, descTbl) {
  obj["weaponTooltipWidth"] = descTbl?.bulletPenetrationData ? "full" : "narrow"
}

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

function getPresetWeaponsDescArray(unit, weaponInfoData, params) {
  
  let showOnlyNamesAndSpecs = params?.showOnlyNamesAndSpecs ?? false
  let presetsWeapons = []
  let presetsNames = {
    names = []
  }
  foreach(weaponBlockSet in (weaponInfoData?.resultWeaponBlocks ?? [])) {
    foreach(weapon in weaponBlockSet) {
      let weaponName = weapon.weaponName
      local presetName = loc($"weapons/{weaponName}")
      if (weapon.ammo > 1)
        presetName = "".concat(presetName, " ", format(loc("weapons/counter/right/short"), weapon.ammo))

      if (showOnlyNamesAndSpecs) {
        presetsNames.names.append({ presetName })
        continue
      }
      let presetParams = getWeaponExtendedInfo(weapon, weapon.weaponType, unit, params?.curEdiff)
      presetsWeapons.append({ presetName, presetParams })
    }
  }
  return { presetsWeapons, presetsNames }
}


function addArmorPiercingDataToDescTbl(descTbl, unit, blk, tType) {
  if (TYPES_ARMOR_PIERCING.contains(tType)) {
    let bulletsData = buildBulletsData(calculate_tank_bullet_parameters(unit.name, blk, true, false))
    addArmorPiercingToDescForBullets(bulletsData, descTbl)
  }
  if (descTbl?.bulletPenetrationData)
    descTbl.bulletPenetrationData.__update({
      title = loc("bullet_properties/armorPiercing")
  })
}

function getTierTooltipParams(weaponry, presetName, tierId) {
  let tier = weaponry.tiers?[tierId] || weaponry.tiers?[tierId.tostring()] 
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
  let weaponInfoParams = {
    weapons
    isPrimary = false
    isSingle = true
    detail = INFO_DETAIL.EXTENDED
  }
  let res = {}

  let { presetsWeapons } = getPresetWeaponsDescArray(unit, makeWeaponInfoData(unit, weaponInfoParams), params)
  if (presetsWeapons.len())
    res.presetsWeapons <- presetsWeapons

  addArmorPiercingDataToDescTbl(res, unit, blkPath, tType)
  return res
}

function getGunAmmoPerTier(weapons) {
  
  
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
  let { amountPerTier, blk, tType, ammo, isGun, presetName, tierId,
    narrowPenetrationTable = false } = params

  let isBlock = amountPerTier > 1
  let weapArr = getUnitWeaponsByTier(unit, blk, tierId)
    ?? getUnitWeaponsByPreset(unit, blk, presetName)
  let weapons = addWeaponsFromBlk({}, weapArr, unit)
  let weaponInfoParams = {
    weapons
    isPrimary = false
    detail = INFO_DETAIL.EXTENDED
  }
  let weaponInfoData = makeWeaponInfoData(unit, weaponInfoParams)
  let { presetsWeapons, presetsNames } = getPresetWeaponsDescArray(unit, weaponInfoData, params)

  local count = 1

  if (isInArray(tType, CONSUMABLE_TYPES))
    count = isBlock
      ? amountPerTier
      : count
  else if (ammo > 0)
    count = !isBlock
      ? ammo
      : isGun ? getGunAmmoPerTier(weapons) : amountPerTier

  let res = { count, presetsWeapons }

  if (presetsNames.names.len()) {
    res.presetsNames <- presetsNames
    return res
  }

  addArmorPiercingDataToDescTbl(res, unit, blk, tType)
  if (res?.bulletPenetrationData.kineticPenetration && narrowPenetrationTable)
    res.bulletPenetrationData.narrowPenetrationTable <- true
  return res
}

function getTierDescTbl(unit, params) {
  let { tooltipLang, name, addWeaponry, presetName, tierId } = params

  if (tooltipLang != null)
    return { reqText = loc(tooltipLang) }

  let weaponryDesc = getWeaponDescTbl(unit, params)

  let res = {}

  if (!!weaponryDesc?.presetsNames) {
    res.presetsNames <- weaponryDesc.presetsNames
    return res
  }

  res.__update({
    presetsWeapons = weaponryDesc.presetsWeapons
    bulletParams = weaponryDesc?.bulletParams
    bulletPenetrationData = weaponryDesc?.bulletPenetrationData
  })

  let additionalWeaponryDesc = addWeaponry
    ? getWeaponDescTbl(unit, getTierTooltipParams(addWeaponry, presetName, tierId))
    : null

  if (!additionalWeaponryDesc) {
    if (!!res.presetsWeapons?[0]) {
      let tierName = buildWeaponDescHeader(params, weaponryDesc.count)
      res.presetsWeapons[0].presetName <- tierName
    }
    return res
  }

  let isSameWeapons = loc($"weapons/{name}") == loc($"weapons/{addWeaponry.name}")
  if (!!res.presetsWeapons?[0]) {
    let weaponsCount = isSameWeapons ? weaponryDesc.count + additionalWeaponryDesc.count
      : weaponryDesc.count
    res.presetsWeapons[0].presetName <- buildWeaponDescHeader(params, weaponsCount)
  }
  if (!isSameWeapons) {
    additionalWeaponryDesc.presetName <- buildWeaponDescHeader(addWeaponry, additionalWeaponryDesc.count)
    res.presetsWeapons.append(additionalWeaponryDesc)
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
    text = $"<color=@badTextColor>{loc("worldwar/weaponry/inArmyIsDisabled")}</color>"
  else if (isEnabledByMission && !isEnabledForUnit)
    text = $"<color=@badTextColor>{loc("worldwar/weaponry/inArmyIsEnabled/weaponRequired")}</color>"
  else if (isEnabledByMission && isEnabledForUnit)
    text = $"<color=@goodTextColor>{loc("worldwar/weaponry/inArmyIsEnabled")}</color>"

  return text
}

function getBasesEstimatedDamageRewardArray(unit, item) {
  let res = {
    estimatedDamageTitle = loc("shop/estimated_damage_to_base_title")
    params = []
  }

  let reqUnitTypes = getRequiredUnitTypes(getCurrentGameMode())
  if (reqUnitTypes.len() == 0 || !reqUnitTypes.contains(ES_UNIT_TYPE_AIRCRAFT))
    return res

  
  local itemPresetList = {}

  
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
            let weaponAmount = val.getParamValue(0) * itemPresetList[key]
            customPresetWeaponTable[weaponKey] <- (customPresetWeaponTable?[weaponKey] ?? 0) + weaponAmount
            itemPresetList.rawdelete(key)
            return
          }
        })
      })
    }
  }

  let estimatedDamageToBase = getWeaponDamage(unit.name, item.name, customPresetWeaponTable)

  if (estimatedDamageToBase == 0)
    return res

  res.params.append({
    text = loc("shop/estimated_damage_to_base")
    damageValue = format("%.1f", estimatedDamageToBase)
  })

  let rewardMultiplierForBases = format("%.1f", getPresetRewardMul(unit.name, estimatedDamageToBase) * UI_BASE_REWARD_DECORATION)

  res.params.append({
    text = loc("shop/reward_multiplier_for_base")
    damageValue = rewardMultiplierForBases
  })

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

  local name = $"<color=@activeTextColor>{getModItemName(unit, item, false)}</color>"
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

  let { isBulletCard = false, hasPlayerInfo = true } = params

  if (hasPlayerInfo
    && !isWeaponTierAvailable(unit, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons) {
    let reqMods = ::getNextTierModsCount(unit, curTier - 1)
    if (reqMods > 0)
      reqText = loc("weaponry/unlockModTierReq",
                      { tier = roman_numerals[curTier], amount = reqMods })
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
    let weaponInfoParams = {
      isPrimary = false
      weaponPreset = item.name
      ediff = params?.curEdiff
      detail = params?.detail ?? INFO_DETAIL.EXTENDED
      weaponsFilterFunc = params?.weaponsFilterFunc
    }
    let weaponInfoData = makeWeaponInfoData(unit, weaponInfoParams)
    if (!params?.needDescInArrayForm)
      desc = getWeaponInfoText(unit, makeWeaponInfoData(unit, weaponInfoParams))
    else {
      let { presetsWeapons, presetsNames } = getPresetWeaponsDescArray(unit, weaponInfoData, params)
      if (presetsNames.names.len()) {
        res.presetsNames <- presetsNames
      }
      else if (presetsWeapons.len())
        res.presetsWeapons <- presetsWeapons
    }
    if ((item.rocket || item.bomb) && (params?.detail ?? INFO_DETAIL.EXTENDED) == INFO_DETAIL.EXTENDED) {
      let bulletsData = buildBulletsData(calculate_tank_bullet_parameters(unit.name, item.name, true, true))
      addArmorPiercingToDesc(bulletsData, res)
    }
    if (effect) {
      addDesc = weaponryEffects.getDesc(unit, effect, {
        curEdiff = params?.curEdiff
        needDescInArrayForm = params?.needDescInArrayForm
      })
      if (addDesc.len() && !!params?.needDescInArrayForm) {
        let changeToSpecs = {
          changeSpecTitle = loc("modifications/specs_change")
          changeSpecNotice = loc("weaponry/modsEffectsNotification")
          changeToSpecsParams = addDesc
        }
        res.changeToSpecs <- changeToSpecs
      }
      let estimatedDamageAndMultiplier = getBasesEstimatedDamageRewardArray(unit, item)
      if (estimatedDamageAndMultiplier.params.len())
        res.estimatedDamageToBases <- estimatedDamageAndMultiplier
    }
    if (!effect && updateEffectFunc)
      res.delayed = calculate_mod_or_weapon_effect(unit.name, item.name, false, this,
        updateEffectFunc, null) ?? true
  }
  else if (item.type == weaponsItem.primaryWeapon) {
    name = ""
    let weaponInfoParams = {
      isPrimary = true
      weaponPreset = item.name
      ediff = params?.curEdiff
      detail = params?.detail ?? INFO_DETAIL.EXTENDED
      weaponsFilterFunc = params?.weaponsFilterFunc
    }
    let weaponInfoData = makeWeaponInfoData(unit, weaponInfoParams)
    let weaponsList = []
    if (weaponInfoData?.resultWeaponBlocks != null) {
      foreach(weaponBlockSet in (weaponInfoData.resultWeaponBlocks)) {
        let weaponsListElement = {
          titlesAndAmmo = []
        }
        foreach(weaponId, weapon in weaponBlockSet) {
          let weaponName = weapon.weaponName
          local weaponTitle = ""
          if (isInArray(weapon.weaponType, CONSUMABLE_TYPES) || weapon.weaponType == WEAPON_TYPE.CONTAINER_ITEM)
            weaponTitle = "".concat(loc($"weapons/{weaponName}"), format(loc("weapons/counter"), weapon.ammo))
          else {
            weaponTitle = loc($"weapons/{weaponName}")
            if ((TRIGGER_TYPE.TURRETS in weapon) && weaponId == 0) {
              let turretsCount = weapon[TRIGGER_TYPE.TURRETS]
              let turretName = turretsCount > 1 ? format(loc("weapons/turret_number"), turretsCount)
                : "".concat(utf8Capitalize(loc("weapons_types/turrets")), loc("ui/colon"))
              weaponsListElement.turretName <- turretName
            }
            if (weapon.num > 1)
              weaponTitle = $"{weaponTitle}{format(loc("weapons/counter"), weapon.num)}"
            }
          weaponsListElement.titlesAndAmmo.append({
            weaponTitle
            ammo = weapon.ammo > 0 ? "".concat("(", loc("shop/ammo"), loc("ui/colon"), weapon.ammo, ")") : ""
          })
        }
        weaponsList.append(weaponsListElement)
      }
      if (weaponsList.len())
        res.weaponsList <- weaponsList
    }
    desc = getWeaponInfoText(unit, weaponInfoData)
    let upgradesList = getItemUpgradesList(item)
    if (upgradesList) {
      let upgradesCount = countWeaponsUpgrade(unit, item)
      let weaponsModifications = {
        title = ""
        modifications = []
      }
      foreach (arr in upgradesList)
        foreach (upgrade in arr) {
          if (upgrade == null)
            continue
          let mod = { modName = getModificationName(unit, upgrade) }
          if (isModificationEnabled(unit.name, upgrade))
            mod.active <- true
          weaponsModifications.modifications.append(mod)
        }
      if (weaponsModifications.modifications.len() && upgradesCount?[1]) {
        weaponsModifications.title = (loc("weaponry/weaponsUpgradeInstalled",
          { current = upgradesCount[0], total = upgradesCount[1] }))

        res.weaponsModifications <- weaponsModifications
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

    addBulletsParamToDesc(res, unit, item, isBulletCard)
    let { pairModName = null } = params
    if (pairModName != null) {
      let pairMod = getModificationByName(unit, pairModName)
      if (pairMod != null) {
        name = ""
        let pairBulletsParam = {}
        addBulletsParamToDesc(pairBulletsParam, unit, pairMod, isBulletCard)
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
    let amountText = getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount)
    if (amountText != "") {
      let color = statusTbl.amount < statusTbl.amountWarningValue ? "badTextColor" : ""
      res.amountText <- colorize(color, $"{loc("options/amount")}{loc("ui/colon")}{amountText}")

      if (isInFlight() && item.type == weaponsItem.weapon) {
        let respLeft = getCurMissionRules().getUnitWeaponRespawnsLeft(unit, item)
        if (respLeft >= 0)
          res.amountText = "".concat(res.amountText, loc("ui/colon"), loc("respawn/leftRespawns", { num = respLeft }))
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
    let discount = getDiscountByPath(getDiscountPath(unit, item, statusTbl.discountType))
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
      addDesc = "".concat(addDesc, "\n", loc("shop/avg_repair_cost"), nbsp,
        (avgCost > 0 ? "+" : ""),
        Cost(avgCost).toStringWithParams({ isWpAlwaysShown = true, isColored = false }))
  }

  if (hasPlayerInfo) {
    if (!statusTbl.amount && !needShowWWSecondaryWeapons) {
      let reqMods = getReqModsText(unit, item)
      if (reqMods != "")
        reqText = "\n".join([reqText, reqMods], true)
    }
    if (isBullets(item) && !isBulletsGroupActiveByMod(unit, item) && !isInFlight())
      reqText = "\n".join([reqText, loc("msg/weaponSelectRequired")], true)
    reqText = reqText != "" ? ($"<color=@badTextColor>{reqText}</color>") : ""

    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(unit, item)
  }
  if (reqText != "")
    res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name

  res.desc = desc
  res.addDesc <- (addDesc != "" && res?.changeToSpecs == null) ? addDesc : null

  return res
}

function updateWeaponTooltip(obj, unit, item, handler, params = {}, effect = null) {
  let self = callee()
  let descTbl = getItemDescTbl(unit, item, params, effect,
    function(effect_, ...) {
      if (checkObj(obj) && obj.isVisible())
        self(obj, unit, item, handler, params, effect_)
    })

  let markupFileName = params?.markupFileName ?? "%gui/weaponry/weaponTooltip.tpl"
  let curExp = shop_get_module_exp(unit.name, item.name)
  let is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && isModResearched(unit, item))
  let is_researching = isModInResearch(unit, item)
  let is_paused = canBeResearched(unit, item, true) && curExp > 0

  if (is_researching || is_paused || !is_researched) {
    if ((("reqExp" in item) && item.reqExp > curExp) || is_paused) {
      local expText = ""
      if (is_researching || is_paused)
        expText = "".concat(loc("currency/researchPoints/name"), loc("ui/colon"),
          colorize("activeTextColor",
            "".concat(Cost().setRp(curExp).toStringWithParams({ isRpAlwaysShown = true }),
              loc("ui/slash"), Cost().setRp(item.reqExp).tostring())))
      else
        expText = "".concat(loc("shop/required_rp"), " ", "<color=@activeTextColor>",
          Cost().setRp(item.reqExp).tostring(), "</color>")

      let diffExp = Cost().setRp(getTblValue("diffExp", params, 0)).tostring()
      if (diffExp.len())
        expText = $"{expText} (+{diffExp})"
      descTbl.expText <- expText
    }
  }
  else if (params?.hasPlayerInfo ?? true)
    descTbl.showPrice <- ("currentPrice" in descTbl) || ("noDiscountPrice" in descTbl)

  if (descTbl?.showPrice || descTbl?.amountText || descTbl?.expText)
    descTbl.showFooter <- true

  checkBulletParamsBeforeRender(descTbl)

  if (markupFileName == "%gui/weaponry/weaponsPresetTooltip.tpl")
    setWidthForWeaponsPresetTooltip(obj, descTbl)

  descTbl.hasSweepRange <- item?.hasSweepRange
  let data = handyman.renderCached(markupFileName, descTbl)
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
  setWidthForWeaponsPresetTooltip
}