local weaponryEffects = require("scripts/weaponry/weaponryEffects.nut")
local { getByCurBundle, canBeResearched, isModInResearch, getDiscountPath, getItemStatusTbl, getRepairCostCoef,
  isResearchableItem, countWeaponsUpgrade, getItemUpgradesList
} = require("scripts/weaponry/itemInfo.nut")
local { isBullets, buildPiercingData, getModificationInfo, getModificationName, addBulletsParamToDesc,
  isWeaponTierAvailable, isBulletsGroupActiveByMod
} = require("scripts/weaponry/bulletsInfo.nut")
local { TRIGGER_TYPE, CONSUMABLE_TYPES, WEAPON_TEXT_PARAMS, getPrimaryWeaponsList, isWeaponEnabled
} = require("scripts/weaponry/weaponryInfo.nut")
local { getWeaponInfoText, getModItemName, getReqModsText, getFullItemCostText } = require("weaponryDescription.nut")
local { isModResearched } = require("scripts/weaponry/modificationInfo.nut")


local function updateModType(unit, mod)
{
  if ("type" in mod)
    return

  local { name } = mod
  local primaryWeaponsNames = getPrimaryWeaponsList(unit)
  foreach(modName in primaryWeaponsNames)
    if (modName == name)
    {
      mod.type <- weaponsItem.primaryWeapon
      return
    }

  mod.type <- weaponsItem.modification
  return
}

local function updateSpareType(spare)
{
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

local function getTierDescTbl(unit, weaponry, presetName, tierId)
{
  local amountPerTier = weaponry.tiers?[tierId.tostring()].amountPerTier ?? weaponry.amountPerTier ?? 0
  local isBlock = amountPerTier > 1
  local header = ::loc($"weapons/{weaponry.name}")
  local desc = getWeaponInfoText(unit, { isPrimary = false, weaponPreset = presetName,
    detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = (@(path, blk) path == weaponry.blk) })
  if (::isInArray(weaponry.tType, CONSUMABLE_TYPES))
    header = isBlock ?
      "".concat(header, ::format(::loc("weapons/counter"), amountPerTier)) : header
  else if (weaponry.ammo > 0)
    header = "".concat(header, " (", ::loc("shop/ammo"), ::loc("ui/colon"),
      isBlock && !weaponry.isGun ? amountPerTier : weaponry.ammo, ")")

  // Need to replace header with new one contains right weapons amount calculated per tier
  local descArr = desc.split(WEAPON_TEXT_PARAMS.newLine)
  descArr[0] = header
  local res = { desc = descArr.reduce(@(a, b) "".concat(a, WEAPON_TEXT_PARAMS.newLine, b))}
  if(::isInArray(weaponry.tType, [TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.ATGM]))
    buildPiercingData({
      bullet_parameters = ::calculate_tank_bullet_parameters(unit.name, weaponry.blk, true, false),
      descTbl = res})

  if (weaponry?.addWeaponry != null)
  {
    local addDescBlock = getTierDescTbl(unit, weaponry.addWeaponry, presetName, tierId)
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

local function getReqTextWorldWarArmy(unit, item)
{
  local text = ""
  local misRules = ::g_mis_custom_state.getCurMissionRules()
  if (!misRules.needCheckWeaponsAllowed(unit))
    return text

  local isEnabledByMission = misRules.isUnitWeaponAllowed(unit, item)
  local isEnabledForUnit = isWeaponEnabled(unit, item)
  if (!isEnabledByMission)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsDisabled") + "</color>"
  else if (isEnabledByMission && !isEnabledForUnit)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled/weaponRequired") + "</color>"
  else if (isEnabledByMission && isEnabledForUnit)
    text = "<color=@goodTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled") + "</color>"

  return text
}

local function getItemDescTbl(unit, item, params = null, effect = null, updateEffectFunc = null){return null}
getItemDescTbl = function(unit, item, params = null, effect = null, updateEffectFunc = null)
{
  local res = { name = "", desc = "", delayed = false }
  local needShowWWSecondaryWeapons = item.type==weaponsItem.weapon && ::is_in_flight() &&
    ::g_mis_custom_state.getCurMissionRules().isWorldWar

  if (item.type==weaponsItem.bundle)
    return getByCurBundle(unit, item,
      function(unit, item) {
        return getItemDescTbl(unit, item, params, effect, updateEffectFunc)
      }, res)

  local name = "<color=@activeTextColor>" + getModItemName(unit, item, false) + "</color>"
  local desc = ""
  local addDesc = ""
  local reqText = ""
  local curTier = "tier" in item? item.tier : 1
  local statusTbl = getItemStatusTbl(unit, item)
  local currentPrice = statusTbl.showPrice ? getFullItemCostText(unit, item) : ""

  local hasPlayerInfo = params?.hasPlayerInfo ?? true
  if (hasPlayerInfo
    && !isWeaponTierAvailable(unit, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons)
  {
    local reqMods = ::getNextTierModsCount(unit, curTier - 1)
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

    if((item.rocket || item.bomb) &&
      (params?.detail ?? INFO_DETAIL.EXTENDED) == INFO_DETAIL.EXTENDED)
    {
      buildPiercingData({
        bullet_parameters = ::calculate_tank_bullet_parameters(unit.name, item.name, true, true),
        descTbl = res})
    }

    if (effect)
      addDesc = weaponryEffects.getDesc(unit, effect)
    if (!effect && updateEffectFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(unit.name, item.name, false, this,
        updateEffectFunc, null) ?? true
  }
  else if (item.type==weaponsItem.primaryWeapon)
  {
    name = ""
    desc = getWeaponInfoText(unit, { isPrimary = true, weaponPreset = item.name,
      detail = params?.detail ?? INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })
    local upgradesList = getItemUpgradesList(item)
    if(upgradesList)
    {
      local upgradesCount = countWeaponsUpgrade(unit, item)
      if (upgradesCount?[1])
        addDesc = "\n" + ::loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach(arr in upgradesList)
        foreach(upgrade in arr)
        {
          if(upgrade == null)
            continue
          addDesc += "\n" + (::shop_is_modification_enabled(unit.name, upgrade) ?"<color=@goodTextColor>" : "<color=@commonTextColor>") + getModificationName(unit, upgrade) + "</color>"
        }
    }
  }
  else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
  {
    if (effect)
    {
      desc = getModificationInfo(unit, item.name).desc;
      addDesc = weaponryEffects.getDesc(unit, effect);
    }
    else
    {
      local info = getModificationInfo(unit, item.name, false, false, this, updateEffectFunc)
      desc = info.desc
      res.delayed = info.delayed
    }

    addBulletsParamToDesc(res, unit, item)
  }
  else if (item.type==weaponsItem.spare)
    desc = ::loc("spare/"+item.name + "/desc")

  if (hasPlayerInfo && statusTbl.unlocked && currentPrice != "")
  {
    local amountText = ::getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount)
    if (amountText != "")
    {
      local color = statusTbl.amount < statusTbl.amountWarningValue ? "badTextColor" : ""
      res.amountText <- ::colorize(color, ::loc("options/count") + ::loc("ui/colon") + amountText)

      if (::is_in_flight() && item.type==weaponsItem.weapon)
      {
        local respLeft = ::g_mis_custom_state.getCurMissionRules().getUnitWeaponRespawnsLeft(unit, item)
        if (respLeft >= 0)
          res.amountText += ::loc("ui/colon") + ::loc("respawn/leftRespawns", { num = respLeft })
      }
    }
    if (statusTbl.showMaxAmount && statusTbl.amount < statusTbl.amountWarningValue)
      res.warningText <- ::loc("weapons/restock_advice")
  }
  else if (params?.isInHudActionBar)
  {
    local modData = ::u.search(::get_action_bar_items(),
      @(itemData) itemData?.modificationName == item.name)
    if (modData)
      res.amountText <- ::ActionBar.getModAmountText(modData, true)
  }

  if (statusTbl.discountType != "")
  {
    local discount = ::getDiscountByPath(getDiscountPath(unit, item, statusTbl.discountType))
    if (discount > 0 && statusTbl.showPrice)
    {
      local cost = "cost" in item? item.cost : 0
      local costGold = "costGold" in item? item.costGold : 0
      local priceText = ::Cost(cost, costGold).getUncoloredText()
      if (priceText != "")
        res.noDiscountPrice <- "<color=@oldPrice>" + priceText + "</color>"
      if (currentPrice != "")
        currentPrice = "<color=@goodTextColor>" + currentPrice + "</color>"
    }
  }

  local repairCostCoef = getRepairCostCoef(item)
  if (repairCostCoef)
  {
    local avgRepairMul = ::get_warpoints_blk()?.avgRepairMul ?? 1.0
    local egdCode = ::get_current_shop_difficulty().egdCode
    local rCost = ::wp_get_repair_cost_by_mode(unit.name, egdCode, false)
    local avgCost = (rCost * repairCostCoef * avgRepairMul).tointeger()
    if (avgCost)
      addDesc += "\n" + ::loc("shop/avg_repair_cost") + ::nbsp
        + (avgCost > 0? "+" : "")
        + ::Cost(avgCost).toStringWithParams({isWpAlwaysShown = true, isColored = false})
  }

  if (hasPlayerInfo)
  {
    if (!statusTbl.amount && !needShowWWSecondaryWeapons)
    {
      local reqMods = getReqModsText(unit, item)
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

local function updateWeaponTooltip(obj, unit, item, handler, params={}, effect=null){}
updateWeaponTooltip = function(obj, unit, item, handler, params={}, effect=null)
{
  local descTbl = getItemDescTbl(unit, item, params, effect,
    function(effect, ...) {
      if (::checkObj(obj) && obj.isVisible())
        updateWeaponTooltip(obj, unit, item, handler, params, effect)
    })

  local curExp = ::shop_get_module_exp(unit.name, item.name)
  local is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && isModResearched(unit, item))
  local is_researching = isModInResearch(unit, item)
  local is_paused = canBeResearched(unit, item, true) && curExp > 0

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

      local diffExp = ::Cost().setRp(::getTblValue("diffExp", params, 0)).tostring()
      if (diffExp.len())
        expText += " (+" + diffExp + ")"
      descTbl.expText <- expText
    }
  }
  else if (params?.hasPlayerInfo ?? true)
    descTbl.showPrice <- ("currentPrice" in descTbl) || ("noDiscountPrice" in descTbl)

  local data = ::handyman.renderCached(("gui/weaponry/weaponTooltip"), descTbl)
  obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
}

return {
  updateModType
  getTierDescTbl
  updateSpareType
  updateWeaponTooltip
}