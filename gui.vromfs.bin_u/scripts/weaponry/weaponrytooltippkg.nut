let weaponryEffects = require("%scripts/weaponry/weaponryEffects.nut")
let { getByCurBundle, canBeResearched, isModInResearch, getDiscountPath, getItemStatusTbl, getRepairCostCoef,
  isResearchableItem, countWeaponsUpgrade, getItemUpgradesList
} = require("%scripts/weaponry/itemInfo.nut")
let { isBullets, isWeaponTierAvailable, isBulletsGroupActiveByMod,
  getModificationInfo, getModificationName
} = require("%scripts/weaponry/bulletsInfo.nut")
let { addBulletsParamToDesc, buildBulletsData, addArmorPiercingToDesc } = require("%scripts/weaponry/bulletsVisual.nut")
let { TRIGGER_TYPE, CONSUMABLE_TYPES, WEAPON_TEXT_PARAMS, getPrimaryWeaponsList, isWeaponEnabled,
  addWeaponsFromBlk, getWeaponBlkParams } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponInfoText, getModItemName, getReqModsText, getFullItemCostText } = require("weaponryDescription.nut")
let { isModResearched } = require("%scripts/weaponry/modificationInfo.nut")
let { getActionItemAmountText, getActionItemModificationName } = require("%scripts/hud/hudActionBarInfo.nut")
let { getActionBarItems } = ::require_native("hudActionBar")
let { getUnitWeaponSlots, getPresetWeaponsByPath, getUnitPresets,
  getSlotWeapons } = require("%scripts/weaponry/weaponryPresets.nut")


let function updateModType(unit, mod)
{
  if ("type" in mod)
    return

  let { name } = mod
  let primaryWeaponsNames = getPrimaryWeaponsList(unit)
  foreach(modName in primaryWeaponsNames)
    if (modName == name)
    {
      mod.type <- weaponsItem.primaryWeapon
      return
    }

  mod.type <- weaponsItem.modification
  return
}

let function updateSpareType(spare)
{
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

let function getTierTooltipParams(weaponry, presetName, tierId)
{
  let tier = weaponry.tiers?[tierId]
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

let function getTierDescTbl(unit, params) {
  let {tooltipLang, amountPerTier, name,
    blk, tType, ammo, isGun, addWeaponry, presetName, tierId } = params
  if (tooltipLang != null)
    return { desc = ::loc(tooltipLang) }

  local header = ::loc($"weapons/{name}")
  let isBlock = amountPerTier > 1

  let unitBlk = ::get_full_unit_blk(unit.name)
  local weaponsArr = []
  if (unit.hasWeaponSlots) {
    let slots = getUnitWeaponSlots(unitBlk)
    weaponsArr = getSlotWeapons(slots.findvalue(@(s) s?.tier == tierId)).filter(
      @(w) getWeaponBlkParams(w.blk, {}).weaponBlkPath == blk)
  }
  else
    weaponsArr = getPresetWeaponsByPath(unitBlk,
      getUnitPresets(unitBlk).findvalue(@(p) p.name == presetName).blk).filter(@(w) w.blk == blk)

  let weapons = addWeaponsFromBlk({}, weaponsArr ?? [], unit)
  let desc = getWeaponInfoText(unit, {
    weapons
    isPrimary = false
    detail = INFO_DETAIL.EXTENDED
  })

  if (::isInArray(tType, CONSUMABLE_TYPES))
    header = isBlock ?
      "".concat(header, ::format(::loc("weapons/counter"), amountPerTier)) : header
  else if (ammo > 0)
    header = "".concat(header, " (", ::loc("shop/ammo"), ::loc("ui/colon"),
      isBlock && !isGun ? amountPerTier : ammo, ")")

  // Need to replace header with new one contains right weapons amount calculated per tier
  let descArr = desc.split(WEAPON_TEXT_PARAMS.newLine)
  descArr[0] = header
  let res = { desc = descArr.reduce(@(a, b) "".concat(a, WEAPON_TEXT_PARAMS.newLine, b))}
  if(::isInArray(tType, [TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.ATGM])) {
    let bulletsData = buildBulletsData(::calculate_tank_bullet_parameters(unit.name, blk, true, false))
    addArmorPiercingToDesc(bulletsData, res)
  }

  if (addWeaponry != null)
  {
    let addDescBlock = getTierDescTbl(unit, getTierTooltipParams(addWeaponry, presetName, tierId))
    res.desc = $"{res.desc}\n{addDescBlock.desc}"
    if ("bulletParams" in addDescBlock)
    {
      if (!("bulletParams" in res))
        res.bulletParams <- []
      res.bulletParams.extend(addDescBlock.bulletParams)
    }
  }
  return res
}

let function getReqTextWorldWarArmy(unit, item)
{
  local text = ""
  let misRules = ::g_mis_custom_state.getCurMissionRules()
  if (!misRules.needCheckWeaponsAllowed(unit))
    return text

  let isEnabledByMission = misRules.isUnitWeaponAllowed(unit, item)
  let isEnabledForUnit = isWeaponEnabled(unit, item)
  if (!isEnabledByMission)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsDisabled") + "</color>"
  else if (isEnabledByMission && !isEnabledForUnit)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled/weaponRequired") + "</color>"
  else if (isEnabledByMission && isEnabledForUnit)
    text = "<color=@goodTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled") + "</color>"

  return text
}

let function getItemDescTbl(unit, item, params = null, effect = null, updateEffectFunc = null)
{
  let res = { name = "", desc = "", delayed = false }
  let needShowWWSecondaryWeapons = item.type==weaponsItem.weapon && ::is_in_flight() &&
    ::g_mis_custom_state.getCurMissionRules().isWorldWar

  let self = callee()
  if (item.type==weaponsItem.bundle)
    return getByCurBundle(unit, item,
      function(unit, item) {
        return self(unit, item, params, effect, updateEffectFunc)
      }, res)

  local name = "<color=@activeTextColor>" + getModItemName(unit, item, false) + "</color>"
  local desc = ""
  local addDesc = ""
  local reqText = ""
  let curTier = "tier" in item? item.tier : 1
  let statusTbl = getItemStatusTbl(unit, item)
  local currentPrice = statusTbl.showPrice ? getFullItemCostText(unit, item) : ""

  let hasPlayerInfo = params?.hasPlayerInfo ?? true
  if (hasPlayerInfo
    && !isWeaponTierAvailable(unit, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons)
  {
    let reqMods = ::getNextTierModsCount(unit, curTier - 1)
    if(reqMods > 0)
      reqText = ::loc("weaponry/unlockModTierReq",
                      { tier = ::roman_numerals[curTier], amount = reqMods.tostring() })
    else
      reqText = ::loc("weaponry/unlockTier/reqPrevTiers")
    reqText = "<color=@badTextColor>" + reqText + "</color>"
    res.reqText <- reqText

    if(!(params?.canDisplayInfo ?? true))
    {
      res.delayed = true
      return res
    }
  }

  if (item.type==weaponsItem.weapon)
  {
    name = ""
    desc = getWeaponInfoText(unit, { isPrimary = false, weaponPreset = item.name,
      detail = params?.detail ?? INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })

    if((item.rocket || item.bomb) && (params?.detail ?? INFO_DETAIL.EXTENDED) == INFO_DETAIL.EXTENDED)
    {
      let bulletsData = buildBulletsData(::calculate_tank_bullet_parameters(unit.name, item.name, true, true))
      addArmorPiercingToDesc(bulletsData, res)
    }

    if (effect)
      addDesc = weaponryEffects.getDesc(unit, effect, {curEdiff = params?.curEdiff})
    if (!effect && updateEffectFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(unit.name, item.name, false, this,
        updateEffectFunc, null) ?? true
  }
  else if (item.type==weaponsItem.primaryWeapon)
  {
    name = ""
    desc = getWeaponInfoText(unit, { isPrimary = true, weaponPreset = item.name,
      detail = params?.detail ?? INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })
    let upgradesList = getItemUpgradesList(item)
    if(upgradesList)
    {
      let upgradesCount = countWeaponsUpgrade(unit, item)
      if (upgradesCount?[1])
        addDesc = "\n" + ::loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach(arr in upgradesList)
        foreach(upgrade in arr)
        {
          if(upgrade == null)
            continue
          addDesc += "\n" + (::shop_is_modification_enabled(unit.name, upgrade)
            ? "<color=@goodTextColor>"
            : "<color=@commonTextColor>")
              + getModificationName(unit, upgrade) + "</color>"
        }
    }
  }
  else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
  {
    if (effect)
    {
      desc = getModificationInfo(unit, item.name).desc
      addDesc = weaponryEffects.getDesc(unit, effect, {curEdiff = params?.curEdiff})
    }
    else
    {
      let info = getModificationInfo(unit, item.name, false, false, this, updateEffectFunc)
      desc = info.desc
      res.delayed = info.delayed
    }

    addBulletsParamToDesc(res, unit, item)
  }
  else if (item.type==weaponsItem.spare)
    desc = ::loc("spare/"+item.name + "/desc")

  if (hasPlayerInfo && statusTbl.unlocked && currentPrice != "")
  {
    let amountText = ::getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount)
    if (amountText != "")
    {
      let color = statusTbl.amount < statusTbl.amountWarningValue ? "badTextColor" : ""
      res.amountText <- ::colorize(color, ::loc("options/count") + ::loc("ui/colon") + amountText)

      if (::is_in_flight() && item.type==weaponsItem.weapon)
      {
        let respLeft = ::g_mis_custom_state.getCurMissionRules().getUnitWeaponRespawnsLeft(unit, item)
        if (respLeft >= 0)
          res.amountText += ::loc("ui/colon") + ::loc("respawn/leftRespawns", { num = respLeft })
      }
    }
    if (statusTbl.showMaxAmount && statusTbl.amount < statusTbl.amountWarningValue)
      res.warningText <- ::loc("weapons/restock_advice")
  }
  else if (params?.isInHudActionBar)
  {
    let modData = ::u.search(getActionBarItems(),
      @(itemData) getActionItemModificationName(itemData, unit) == item.name)
    if (modData)
      res.amountText <- getActionItemAmountText(modData, true)
  }

  let isScoreCost = ::is_in_flight()
    && ::g_mis_custom_state.getCurMissionRules().isScoreRespawnEnabled
  if (statusTbl.discountType != "" && !isScoreCost)
  {
    let discount = ::getDiscountByPath(getDiscountPath(unit, item, statusTbl.discountType))
    if (discount > 0 && statusTbl.showPrice && currentPrice != "")
    {
      let cost = "cost" in item? item.cost : 0
      let costGold = "costGold" in item? item.costGold : 0
      let priceText = ::Cost(cost, costGold).getUncoloredText()
      if (priceText != "")
        res.noDiscountPrice <- "<color=@oldPrice>" + priceText + "</color>"
      currentPrice = "<color=@goodTextColor>" + currentPrice + "</color>"
    }
  }

  let repairCostCoef = getRepairCostCoef(item)
  if (repairCostCoef)
  {
    let avgRepairMul = ::get_warpoints_blk()?.avgRepairMul ?? 1.0
    let egdCode = ::get_current_shop_difficulty().egdCode
    let rCost = ::wp_get_repair_cost_by_mode(unit.name, egdCode, false)
    let avgCost = (rCost * repairCostCoef * avgRepairMul).tointeger()
    if (avgCost)
      addDesc += "\n" + ::loc("shop/avg_repair_cost") + ::nbsp
        + (avgCost > 0? "+" : "")
        + ::Cost(avgCost).toStringWithParams({isWpAlwaysShown = true, isColored = false})
  }

  if (hasPlayerInfo)
  {
    if (!statusTbl.amount && !needShowWWSecondaryWeapons)
    {
      let reqMods = getReqModsText(unit, item)
      if(reqMods != "")
        reqText += (reqText==""? "" : "\n") + reqMods
    }
    if (isBullets(item) && !isBulletsGroupActiveByMod(unit, item) && !::is_in_flight())
      reqText += ((reqText=="")?"":"\n") + ::loc("msg/weaponSelectRequired")
    reqText = reqText!=""? ("<color=@badTextColor>" + reqText + "</color>") : ""

    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(unit, item)
  }
  res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name
  res.desc = desc
  res.addDesc <- addDesc
  return res
}

let function updateWeaponTooltip(obj, unit, item, handler, params={}, effect=null)
{
  let self = callee()
  let descTbl = getItemDescTbl(unit, item, params, effect,
    function(effect, ...) {
      if (::checkObj(obj) && obj.isVisible())
        self(obj, unit, item, handler, params, effect)
    })

  let curExp = ::shop_get_module_exp(unit.name, item.name)
  let is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && isModResearched(unit, item))
  let is_researching = isModInResearch(unit, item)
  let is_paused = canBeResearched(unit, item, true) && curExp > 0

  if (is_researching || is_paused || !is_researched)
  {
    if ((("reqExp" in item) && item.reqExp > curExp) || is_paused)
    {
      local expText = ""
      if (is_researching || is_paused)
        expText = ::loc("currency/researchPoints/name") + ::loc("ui/colon") +
          ::colorize("activeTextColor",
            ::Cost().setRp(curExp).toStringWithParams({isRpAlwaysShown = true}) +
            ::loc("ui/slash") + ::Cost().setRp(item.reqExp).tostring())
      else
        expText = ::loc("shop/required_rp") + " " + "<color=@activeTextColor>" +
          ::Cost().setRp(item.reqExp).tostring() + "</color>"

      let diffExp = ::Cost().setRp(::getTblValue("diffExp", params, 0)).tostring()
      if (diffExp.len())
        expText += " (+" + diffExp + ")"
      descTbl.expText <- expText
    }
  }
  else if (params?.hasPlayerInfo ?? true)
    descTbl.showPrice <- ("currentPrice" in descTbl) || ("noDiscountPrice" in descTbl)

  let data = ::handyman.renderCached(("%gui/weaponry/weaponTooltip"), descTbl)
  obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
}

return {
  updateModType
  getTierTooltipParams
  getTierDescTbl
  updateSpareType
  updateWeaponTooltip
}