from "%scripts/dagui_natives.nut" import shop_get_module_exp, calculate_mod_or_weapon_effect, wp_get_repair_cost_by_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, INFO_DETAIL
from "%scripts/utils_sa.nut" import getAmountAndMaxAmountText, roman_numerals

let { getPresetRewardMul, getWeaponDamage } = require("%appGlobals/econWeaponUtils.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getCurrentShopDifficulty, getCurrentGameMode, getRequiredUnitTypes, getCurrentGameModeEdiff
} = require("%scripts/gameModes/gameModeManagerState.nut")
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
  getModificationInfo, getModificationName, isBulletsWithoutTracer, getBulletsSetData, isPairBulletsGroup
} = require("%scripts/weaponry/bulletsInfo.nut")
let { addBulletsParamToDesc, buildBulletsData, addArmorPiercingToDesc, addArmorPiercingToDescForBullets
  checkBulletParamsBeforeRender
} = require("%scripts/weaponry/bulletsVisual.nut")
let { WEAPON_TYPE, TRIGGER_TYPE, CONSUMABLE_TYPES, NOT_WEAPON_TYPES,getPrimaryWeaponsList, isWeaponEnabled,
  addWeaponsFromBlk, getWeaponExtendedInfo, getWeaponNameByBlkPath
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponInfoText, getModItemName, getReqModsText, getFullItemCostText, makeWeaponInfoData
} = require("weaponryDescription.nut")
let { getPresetCompositionViewParams } = require("%scripts/weaponry/infantryWeapons.nut")
let { getUnitArmorData } = require("%scripts/weaponry/infantryArmor.nut")
let { isModResearched, isModificationEnabled, getModificationByName, getModificationBulletsGroup,
  calcHumanModEffects } = require("%scripts/weaponry/modificationInfo.nut")
let { getActionItemAmountText, getActionItemModificationName } = require("%scripts/hud/hudActionBarInfo.nut")
let { getActionBarItems } = require("hudActionBar")
let { getUnitWeaponsByTier, getUnitWeaponsByPreset } = require("%scripts/weaponry/weaponryPresets.nut")
let { get_warpoints_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getDiscountByPath } = require("%scripts/discounts/discountUtils.nut")
let UnitBulletsManager = require("%scripts/weaponry/unitBulletsManager.nut")
let { getNextTierModsCount } = require("%scripts/weaponry/modsTree.nut")


let TYPES_ARMOR_PIERCING = [TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.ATGM]
const UI_BASE_REWARD_DECORATION = 10

function setWidthForWeaponsPresetTooltip(obj, descTbl) {
  obj["weaponTooltipWidth"] = descTbl?.bulletPenetrationData ? "full" : "narrow"
}

function setInternalPadingForWeaponsPresetTooltip(descTbl) {
  if (descTbl?.presetsWeapons == null)
    return

  foreach(preset in descTbl.presetsWeapons) {
    if ((preset?.presetParams ?? []).len() == 0)
      preset.noInternalPadding <- true
  }
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

function getPresetWeaponsDescArrayForHuman(unit, item, ediff) {
  let presetsWeapons = []
  let { compositionIcons } = getPresetCompositionViewParams(unit, item, ediff)
  if (!compositionIcons.len())
    return presetsWeapons

  foreach(idx, soldierIcons in compositionIcons) {
    let presetName = "".concat(loc("infantry/squad/member"), $"{idx + 1}", soldierIcons.disabledSoldier
      ? loc("ui/parentheses/space", {
          text = " ".concat(loc("infantry/squad/member_inactive"), loc("ui/mdash"), loc("infantry/squad/member_inactive_advice"))
        })
      : "")
    let presetParamsWithImg = []
    foreach (weapon in soldierIcons.icons) {
      presetParamsWithImg.append({
        weaponNameStr = loc($"weapons/{weapon.weaponName}")
        itemImg = weapon.itemImg
        isDisabled = soldierIcons.disabledSoldier
      })
    }
    presetsWeapons.append({ presetName, presetParamsWithImg, hasPresetParamsWithImg = true })
  }
  return presetsWeapons
}


function reqEffectsGeneration(unit) {
  if (unit.isHuman())
    return false
  return true
}


function getPresetWeaponsDescArray(unit, weaponInfoData, params) {
  
  let { showOnlyNamesAndSpecs = false } = params
  let presetsWeapons = []
  let presetsNames = {
    names = []
  }
  foreach(weaponBlockSet in (weaponInfoData?.resultWeaponBlocks ?? [])) {
    foreach(weapon in weaponBlockSet) {
      let weaponName = weapon.weaponName
      local presetName = loc($"weapons/{weaponName}")
      if ([WEAPON_TYPE.GUNS, WEAPON_TYPE.CANNON].contains(weapon.weaponType)) {
        if (weapon.num > 1)
          presetName = " ".concat(presetName, format(loc("weapons/counter/right/short"), weapon.num))
        let ammoAmountString = "".concat(loc("shop/ammo"), loc("ui/colon"), weapon.ammo)
        presetName = "".concat(presetName, loc("ui/parentheses/space", { text = ammoAmountString }))
      }
      else if (weapon.ammo > 1)
        presetName = "".concat(presetName, " ", format(loc("weapons/counter/right/short"), weapon.ammo))

      if (showOnlyNamesAndSpecs) {
        presetsNames.names.append({ presetName })
        continue
      }
      let presetParams = getWeaponExtendedInfo(weapon, unit, {
        weaponType = weapon.weaponType
        ediff = params?.curEdiff
      })
      presetsWeapons.append({ presetName, presetParams })
    }
  }
  return { presetsWeapons, presetsNames }
}


function addArmorPiercingDataToDescTbl(descTbl, unit, blk, tType, weaponInfoData) {
  if (TYPES_ARMOR_PIERCING.contains(tType)) {
    let bulletsSet = {
      explosiveType = weaponInfoData?.resultWeaponBlocks[0][0].explosiveType ?? 0
      explosiveMass = weaponInfoData?.resultWeaponBlocks[0][0].explosiveMass ?? 0
      cumulativeDamage = weaponInfoData?.resultWeaponBlocks[0][0].cumulativeDamage ?? 0
    }
    let bulletsData = buildBulletsData(calculate_tank_bullet_parameters(unit.name, blk, true, false), bulletsSet)
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

  let weaponInfoData = makeWeaponInfoData(unit, weaponInfoParams)
  let { presetsWeapons } = getPresetWeaponsDescArray(unit, weaponInfoData, params)
  if (presetsWeapons.len())
    res.presetsWeapons <- presetsWeapons

  addArmorPiercingDataToDescTbl(res, unit, blkPath, tType, weaponInfoData)
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
  if (NOT_WEAPON_TYPES.contains(tType))
    return weaponName

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

  addArmorPiercingDataToDescTbl(res, unit, blk, tType, weaponInfoData)
  if (res?.bulletPenetrationData.kineticPenetration && narrowPenetrationTable)
    res.bulletPenetrationData.narrowPenetrationTable <- true
  return res
}

function getTierDescTbl(unit, params) {
  let { tooltipLang, name, addWeaponry, presetName, tierId, isGun = false } = params

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

  
  let needAddPresetNameAnTheEnd = weaponryDesc.presetsWeapons.len() == 0

  if (!additionalWeaponryDesc) {
    let tierName = buildWeaponDescHeader(params, weaponryDesc.count)
    if (!!res.presetsWeapons?[0] && !isGun)
      res.presetsWeapons[0].presetName <- tierName
    else if (needAddPresetNameAnTheEnd)
      res.presetsWeapons.append({ presetName = tierName, noInternalPadding = true })
    return res
  }

  let isSameWeapons = loc($"weapons/{name}") == loc($"weapons/{addWeaponry.name}")
  let weaponsCount = isSameWeapons ? weaponryDesc.count + additionalWeaponryDesc.count
    : weaponryDesc.count

  let resPresetName = buildWeaponDescHeader(params, weaponsCount)
  if (!!res.presetsWeapons?[0])
    res.presetsWeapons[0].presetName <- resPresetName

  if (!isSameWeapons) {
    res.presetsWeapons.append({
      presetName = buildWeaponDescHeader(addWeaponry, additionalWeaponryDesc.count)
      presetParams = additionalWeaponryDesc?.presetsWeapons[0].presetParams ?? []
    })
  }

  if (needAddPresetNameAnTheEnd)
    res.presetsWeapons.append({ presetName = resPresetName })

  if ("bulletParams" in additionalWeaponryDesc) {
    if (!res.bulletParams)
      res.bulletParams = []
    if(!isEqual(res.bulletParams, additionalWeaponryDesc.bulletParams))
      res.bulletParams.extend(additionalWeaponryDesc.bulletParams)
  }

  setInternalPadingForWeaponsPresetTooltip(res)

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
    damageValue = estimatedDamageToBase
  })

  let rewardMultiplierForBases = format("%.1f", getPresetRewardMul(unit.name, estimatedDamageToBase) * UI_BASE_REWARD_DECORATION)

  res.params.append({
    text = loc("shop/reward_multiplier_for_base")
    damageValue = rewardMultiplierForBases
  })

  return res
}

function getReqModificationsTip(unit, modName, descriptionLocId = "") {
  let mod = getModificationByName(unit, modName)
  if (mod?.reqModification == null)
    return ""
  local reqText = ""
  foreach (reqModification in mod.reqModification) {
    let reqName = getModificationName(unit, reqModification)
    reqText = reqText == "" ? reqName : ", ".concat(reqText, reqName)
  }

  return descriptionLocId == "" || reqText == ""
    ? reqText
    : " ".concat(loc(descriptionLocId), reqText)
}

function getTipForBullet(unit, item) {
  let bulletsManager = UnitBulletsManager(unit, {isForcedAvailable = true})
  let bulGroup = bulletsManager.getBulletGroupBySelectedMod(item)
  let bullets = bulGroup?.bullets
  if (!bullets)
    return ""
  local enabledBulletsCount = 0
  local disabledBullet = null
  for (local i = 0; i < bullets.items.len(); i++)
    if (bullets.items[i]?.enabled)
      enabledBulletsCount += 1
    else
      disabledBullet = bullets.values?[i]

  if (enabledBulletsCount > 1 || disabledBullet == null)
    return ""

  return getReqModificationsTip(unit, disabledBullet, "tooltip/bulletTapesReq")
}

function getTipForCountermeasures(unit, item) {
  let bulletsManager = UnitBulletsManager(unit)
  let bulGroup = bulletsManager.getBulletGroupBySelectedMod(item)
  let bullets = bulGroup?.bullets
  if (!bullets || !isPairBulletsGroup(bullets) || bullets?.items[1].enabled == true)
    return ""
  return getReqModificationsTip(unit, bullets.values[1], "tooltip/flaresChaffsRatioReq")
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

  let { isBulletCard = false, hasPlayerInfo = true, isPurchaseInfoHidden = false } = params

  if (hasPlayerInfo
    && !isWeaponTierAvailable(unit, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons) {
    let reqMods = getNextTierModsCount(unit, curTier - 1)
    if (isPurchaseInfoHidden)
      reqText = loc("msgbox/notAvailbleMod")
    else if (reqMods > 0)
      reqText = loc("weaponry/unlockModTierReq", {
        tier = roman_numerals[curTier], amount = reqMods
      })
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
    else if (unit.isHuman()) {
      let ediff = params?.curEdiff ?? getCurrentGameModeEdiff()
      res.presetsWeapons <- getPresetWeaponsDescArrayForHuman(unit, item, ediff)
      res.presetCompositionHint <- loc("weaponry/presetCompositionHint")
    }
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
          desc = annotation
        }
      }
    }

    if (effect) {
      let modInfo = getModificationInfo(unit, item.name).desc
      if (modInfo.len())
        desc = $"{modInfo}\n{desc}"
      addDesc = weaponryEffects.getDesc(unit, effect, { curEdiff = params?.curEdiff })
    }
    else if (reqEffectsGeneration(unit)) {
      let info = getModificationInfo(unit, item.name, {
        isShortDesc = false
        isLimitedName = false
        obj = this
        itemDescrRewriteFunc = updateEffectFunc
        needAddName = name == ""
      })
      if (info.len())
        desc = $"{info.desc}\n{desc}"
      res.delayed = info.delayed
    }
    else {
      desc = "{0}\n{1}".subst(loc($"modification/{item.name}/desc", ""), desc)
      addDesc = weaponryEffects.getDescForHuman(calcHumanModEffects(unit, item, "ecsGunModTemplate"))
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
    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(unit, item)
    else {
      let isBulletItem = isBullets(item)
      if (isBulletItem && statusTbl.unlocked) {
        let bulletGroupName = getModificationBulletsGroup(item.name)
        let isCountermeasures = bulletGroupName?.indexof(WEAPON_TYPE.COUNTERMEASURES) != null
        if (isCountermeasures) {
          let tip = getTipForCountermeasures(unit, item)
          if (tip != "")
            res.topReqBlock <- tip
        } else if (item?.isDefaultForGroup != null) {
          let tip = getTipForBullet(unit, item)
          if (tip != "")
            reqText = reqText != "" ? "\n".concat(reqText, tip) : tip
        }
      }
      if (!statusTbl.unlocked) {
        if (isPurchaseInfoHidden)
          reqText = $"<color=@badTextColor>{loc("msgbox/notAvailbleMod")}</color>"
        else {
          let reqMods = getReqModsText(unit, item)
          if (reqMods != "")
            reqText = "\n".join([reqText, reqMods], true)
          reqText = reqText != "" ? ($"<color=@badTextColor>{reqText}</color>") : ""
        }
      }
      if (isBulletItem && !isBulletsGroupActiveByMod(unit, item) && !isInFlight()) {
        let bulletSet = getBulletsSetData(unit, item.name)
        if (bulletSet) {
          let weaponName = getWeaponNameByBlkPath(bulletSet.weaponBlkName)
          let weaponLoc = $"weapons/{weaponName}"
          let reqLocId = (bulletSet?.isBulletBelt ?? true) ? "tooltip/bulletBeltSelectRequired" : "tooltip/shellSelectRequired"
          let weaponSelectRequiredText = $"<color=@badTextColor>{loc(reqLocId)} {loc(weaponLoc)}</color>"
          reqText = "\n".join([reqText, weaponSelectRequiredText], true)
        }
      }
    }
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
  let {
    markupFileName = "%gui/weaponry/weaponTooltip.tpl"
    checkItemBeforeGetDescFn = null
    isPurchaseInfoHidden = false
  } = params

  let self = callee()
  let descTbl = getItemDescTbl(unit, item, params, effect,
    function(effect_, ...) {
      if (checkObj(obj) && obj.isVisible()) {
        let itemAndEffectToPass = checkItemBeforeGetDescFn ? checkItemBeforeGetDescFn(item, effect_)
          : { item , effect = effect_ }

        if (itemAndEffectToPass.item)
          self(obj, unit, itemAndEffectToPass.item, handler, params, itemAndEffectToPass.effect)
      }
    })

  let curExp = shop_get_module_exp(unit.name, item.name)
  let is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && isModResearched(unit, item))
  let is_researching = isModInResearch(unit, item)
  let is_paused = canBeResearched(unit, item, true) && curExp > 0
  let hasPurchaseInfo = !isPurchaseInfoHidden && (is_researching || is_paused || !is_researched)

  if (hasPurchaseInfo) {
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


function getInfantryWeaponParamToDesc(weaponName) {
  let descTbl = {
    name = colorize("activeTextColor", loc($"weapons/{weaponName}"))
    desc = loc($"weapons/{weaponName}/desc")
  }
  return descTbl
}

function getArmorDescArrayElement(partName, partThickness, partMaterial, isMainPart = false) {
  let armorPartName = !partName ? ""
    : isMainPart ? loc($"armorSegment/{partName}/name")
    : " ".concat(loc("ui/ndash"), loc($"armorSegment/{partName}/name"))
  return {
    armorPartName
    partThickness
    partMaterial
    isMainPart
  }
}

function getArmorDescArray(armorData) {
  let res = []

  if (armorData?.helmet)
    res.append(
      getArmorDescArrayElement(
        "helmet"
        " ".concat(armorData.helmet?.item__armorAmount, loc("measureUnits/mm"))
        loc($"armor_meterial/{armorData.helmet?.item__armorMaterialName}")
        true
      )
    )
  if (armorData.body?.complex) {
    res.append(getArmorDescArrayElement("body", null, null, true))
    foreach(subPart in armorData.body.complex) {
      let { subPartName, subPartData } = subPart
      let { item__armorAmount = null, item__armorMaterialName = null } = subPartData
      if (!item__armorAmount || !item__armorMaterialName)
        continue
      res.append(
        getArmorDescArrayElement(
          subPartName
          " ".concat(item__armorAmount, loc("measureUnits/mm"))
          loc($"armor_meterial/{item__armorMaterialName}")
        )
      )
    }
  }
  return res
}

function getInfantryArmorParamToDesc(unitName, armorName) {
  let descTbl = {
    name = colorize("activeTextColor", loc($"modification/{armorName}"))
  }
  let unit = getAircraftByName(unitName)
  if (!unit)
    return descTbl
  let armorData = getUnitArmorData(unit)?.findvalue(@(a) a.name == armorName)
  if (!armorData)
    return descTbl
  let armorDescArray = getArmorDescArray(armorData.armorData)
  if (!armorDescArray.len())
    return descTbl

  
  armorDescArray.insert(0, getArmorDescArrayElement(
    null
    loc("armor_meterial/thickness_rha")
    loc("armor_meterial/material")
  ).__merge({ isHeaderRow = true }))

  descTbl.showArmorDesc <- true
  descTbl.armorDescArray <- armorDescArray
  descTbl.armorWeight <- " ".concat(armorData.armorWeight, loc("measureUnits/kg"))
  descTbl.armorWeightText <- loc("armor_parameters/weight")
  return descTbl
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
  "isPurchaseInfoHidden"
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
  getInfantryWeaponParamToDesc
  getInfantryArmorParamToDesc
}