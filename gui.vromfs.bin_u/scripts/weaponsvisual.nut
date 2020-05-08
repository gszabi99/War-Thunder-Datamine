local weaponryEffects = ::require("scripts/weaponry/weaponryEffects.nut")
local stdMath = require("std/math.nut")
local { isResearchableItem,
        isModInResearch,
        canBeResearched,
        getItemUpgradesList,
        getByCurBundle,
        getItemStatusTbl,
        getRepairCostCoef,
        countWeaponsUpgrade,
        getDiscountPath } = require("scripts/weaponry/itemInfo.nut")
local { isBullets,
        isWeaponTierAvailable,
        getModificationInfo,
        getModificationName,
        addBulletsParamToDesc,
        isBulletsGroupActiveByMod } = require("scripts/weaponry/bulletsInfo.nut")
local { WEAPON_TYPE } = require("scripts/weaponry/weaponryInfo.nut")
local { getWeaponInfoText,
        getWeaponNameText,
        getBulletsCountText } = require("scripts/weaponry/weaponryVisual.nut")

/*
  weaponVisual API

    createItem(id, item, type, holderObj, handler, params)  - creates base visual item, but not update it.
               params <- { posX, posY }
    createBundle(itemsList, itemsType, subType, holderObj, handler)  - creates items bundle
                 params <- { posX, posY, createItemFunc, maxItemsInColumn, subType }
*/

::dagui_propid.add_name_id("_iconBulletName")

::weaponVisual <- {}

weaponVisual.updateItemBulletsSlider <- function updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
{
  local show = bulGroup != null && bulletsManager != null && bulletsManager.canChangeBulletsCount()
  local holderObj = ::showBtn("bullets_amount_choice_block", show, itemObj)
  if (!show || !holderObj)
    return

  local guns = bulGroup.guns
  local maxVal = bulGroup.maxBulletsCount
  local curVal = bulGroup.bulletsCount
  local unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)

  local textObj = holderObj.findObject("bulletsCountText")
  if (::check_obj(textObj))
    textObj.setValue(getBulletsCountText(curVal, maxVal, unallocated, guns))

  local btnDec = holderObj.findObject("buttonDec")
  if (::checkObj(btnDec))
    btnDec.bulletsLimit = curVal != 0? "no" : "yes"

  local btnIncr = holderObj.findObject("buttonInc")
  if (::checkObj(btnIncr))
    btnIncr.bulletsLimit = (curVal != maxVal && unallocated != 0)? "no" : "yes"

  local slidObj = holderObj.findObject("bulletsSlider")
  if (::checkObj(slidObj))
  {
    slidObj.max = maxVal.tostring()
    slidObj.setValue(curVal)
  }
  local invSlidObj = holderObj.findObject("invisBulletsSlider")
  if (::checkObj(invSlidObj))
  {
    invSlidObj.groupIdx = bulGroup.groupIndex
    invSlidObj.max = maxVal.tostring()
    if (invSlidObj.getValue() != curVal)
      invSlidObj.setValue(curVal)
  }
}

weaponVisual.getItemName <- function getItemName(air, item, limitedName = true)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(air, item, limitedName)
}

weaponVisual.getItemImage <- function getItemImage(air, item)
{
  if (!isBullets(item))
  {
    if (item.type==weaponsItem.bundle)
      return getByCurBundle(air, item, getItemImage)

    if("image" in item && item.image != "")
      return item.image
    if (item.type==weaponsItem.primaryWeapon && ("weaponMod" in item) && item.weaponMod)
      return getItemImage(air, item.weaponMod)
  }
  return ""
}

//include spawn score cost
weaponVisual.getFullItemCostText <- function getFullItemCostText(unit, item)
{
  local res = ""
  local wType = ::g_weaponry_types.getUpgradeTypeByItem(item)
  local misRules = ::g_mis_custom_state.getCurMissionRules()

  if (!::is_in_flight() || misRules.isWarpointsRespawnEnabled)
    res = wType.getCost(unit, item).tostring()

  if (::is_in_flight() && misRules.isScoreRespawnEnabled)
  {
    local scoreCostText = wType.getScoreCostText(unit, item)
    if (scoreCostText.len())
      res += (res.len() ? ", " : "") + scoreCostText
  }
  return res
}

weaponVisual.getReqModsText <- function getReqModsText(air, item)
{
  local reqText = ""
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(air.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getWeaponNameText(air.name, false, req, ", ")
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(air.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getModificationName(air, req)
  return reqText
}

weaponVisual.getItemDescTbl <- function getItemDescTbl(air, item, params = null, effect = null, updateEffectFunc = null)
{
  local res = { name = "", desc = "", delayed = false }
  local needShowWWSecondaryWeapons = item.type==weaponsItem.weapon && ::is_in_flight() &&
    ::g_mis_custom_state.getCurMissionRules().isWorldWar

  if (item.type==weaponsItem.bundle)
    return getByCurBundle(air, item,
      function(air, item) {
        return getItemDescTbl(air, item, params, effect, updateEffectFunc)
      }, res)

  local name = "<color=@activeTextColor>" + getItemName(air, item, false) + "</color>"
  local desc = ""
  local addDesc = ""
  local reqText = ""
  local curTier = "tier" in item? item.tier : 1
  local statusTbl = getItemStatusTbl(air, item)
  local currentPrice = statusTbl.showPrice? getFullItemCostText(air, item) : ""

  local hasPlayerInfo = params?.hasPlayerInfo ?? true
  if (hasPlayerInfo
    && !isWeaponTierAvailable(air, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons)
  {
    local reqMods = ::getNextTierModsCount(air, curTier - 1)
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
    desc = getWeaponInfoText(air, { isPrimary = false, weaponPreset = item.name,
      detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })

    if(item.rocket || item.bomb)
    {
      buildPiercingData(air.name,
        ::calculate_tank_bullet_parameters(air.name, item.name, true, true), res)
    }

    if (effect)
      addDesc = weaponryEffects.getDesc(air, effect)
    if (!effect && updateEffectFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(air.name, item.name, false, this, updateEffectFunc, null) ?? true
  }
  else if (item.type==weaponsItem.primaryWeapon)
  {
    name = ""
    desc = getWeaponInfoText(air, { isPrimary = true, weaponPreset = item.name,
      detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })
    local upgradesList = getItemUpgradesList(item)
    if(upgradesList)
    {
      local upgradesCount = countWeaponsUpgrade(air, item)
      if (upgradesCount?[1])
        addDesc = "\n" + ::loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach(arr in upgradesList)
        foreach(upgrade in arr)
        {
          if(upgrade == null)
            continue
          addDesc += "\n" + (::shop_is_modification_enabled(air.name, upgrade) ? "<color=@goodTextColor>" : "<color=@commonTextColor>") + getModificationName(air, upgrade) + "</color>"
        }
    }
  }
  else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
  {
    if (effect)
    {
      desc = getModificationInfo(air, item.name).desc;
      addDesc = weaponryEffects.getDesc(air, effect);
    }
    else
    {
      local info = getModificationInfo(air, item.name, false, false, this, updateEffectFunc)
      desc = info.desc
      res.delayed = info.delayed
    }

    addBulletsParamToDesc(res, air, item)
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
        local respLeft = ::g_mis_custom_state.getCurMissionRules().getUnitWeaponRespawnsLeft(air, item)
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
    local discount = ::getDiscountByPath(getDiscountPath(air, item, statusTbl.discountType))
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
    local rCost = ::wp_get_repair_cost_by_mode(air.name, egdCode, false)
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
      local reqMods = getReqModsText(air, item)
      if(reqMods != "")
        reqText += (reqText==""? "" : "\n") + reqMods
    }
    if (isBullets(item) && !isBulletsGroupActiveByMod(air, item))
      reqText += ((reqText=="")?"":"\n") + ::loc("msg/weaponSelectRequired")
    reqText = reqText!=""? ("<color=@badTextColor>" + reqText + "</color>") : ""

    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(air, item)
  }
  res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name
  res.desc = desc
  res.addDesc <- addDesc
  return res
}

weaponVisual.buildPiercingData <- function buildPiercingData(unit, bullet_parameters, descTbl, bulletsSet = null, needAdditionalInfo = false)
{
  local param = { armorPiercing = array(0, null) , armorPiercingDist = array(0, null)}
  local needAddParams = bullet_parameters.len() == 1

  local isSmokeShell = bulletsSet?.weaponType == WEAPON_TYPE.GUNS && bulletsSet?.bullets?[0] == "smoke_tank"
  local isSmokeGenerator = isSmokeShell || bulletsSet?.weaponType == WEAPON_TYPE.SMOKE
  local isCountermeasure = isSmokeGenerator || bulletsSet?.weaponType == WEAPON_TYPE.FLARES

  if (isCountermeasure)
  {
    local whitelistParams = [ "bulletType" ]
    if (isSmokeShell)
      whitelistParams.append("mass", "speed", "weaponBlkPath")
    local filteredBulletParameters = []
    foreach (_params in bullet_parameters)
    {
      local params = _params ? {} : null
      if (_params)
      {
        foreach (key in whitelistParams)
          if (key in _params)
            params[key] <- _params[key]

        params.armorPiercing     <- []
        params.armorPiercingDist <- []
      }
      filteredBulletParameters.append(params)
    }
    bullet_parameters = filteredBulletParameters
  }

  foreach (bullet_params in bullet_parameters)
  {
    if (!bullet_params)
      continue

    if (bullet_params?.bulletType != "aam")
    {
      if (param.armorPiercingDist.len() < bullet_params.armorPiercingDist.len())
      {
        param.armorPiercing.resize(bullet_params.armorPiercingDist.len());
        param.armorPiercingDist = bullet_params.armorPiercingDist;
      }
      foreach(ind, d in param.armorPiercingDist)
      {
        for (local i = 0; i < bullet_params.armorPiercingDist.len(); i++)
        {
          local armor = null;
          local idist = bullet_params.armorPiercingDist[i].tointeger()
          if (typeof(bullet_params.armorPiercing[i]) != "table")
            continue

          if (d == idist || (d < idist && !i))
            armor = ::u.map(bullet_params.armorPiercing[i], @(f) stdMath.round(f).tointeger())
          else if (d < idist && i)
          {
            local prevDist = bullet_params.armorPiercingDist[i-1].tointeger()
            if (d > prevDist)
              armor = ::u.tablesCombine(bullet_params.armorPiercing[i-1], bullet_params.armorPiercing[i],
                        (@(d, prevDist, idist) function(prev, next) {
                          return (prev + (next - prev) * (d - prevDist.tointeger()) / (idist - prevDist)).tointeger()
                        })(d, prevDist, idist), 0)
          }
          if (armor == null)
            continue

          param.armorPiercing[ind] = (!param.armorPiercing[ind]) ? armor
                                    : ::u.tablesCombine(param.armorPiercing[ind], armor, ::max)
        }
      }
    }

    if (!needAddParams)
      continue

    foreach(p in ["mass", "speed", "fuseDelayDist", "explodeTreshold", "operatedDist", "machMax", "endSpeed", "maxSpeed", "rangeBand0", "rangeBand1"])
      param[p] <- ::getTblValue(p, bullet_params, 0)

    foreach(p in ["reloadTimes", "autoAiming", "weaponBlkPath"])
    {
      if(p in bullet_params)
        param[p] <- bullet_params[p]
    }

    if(bulletsSet)
    {
      foreach(p in ["caliber", "explosiveType", "explosiveMass",
        "proximityFuseArmDistance", "proximityFuseRadius" ])
      if (p in bulletsSet)
        param[p] <- bulletsSet[p]

      if (isSmokeGenerator)
        foreach(p in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
          if (p in bulletsSet)
            param[p] <- bulletsSet[p]
    }

    param.bulletType <- ::getTblValue("bulletType", bullet_params, "")
    param.ricochetPreset <- bullet_params?.ricochetPreset
  }

  descTbl.bulletParams <- []
  local p = []
  local addProp = function(arr, text, value)
  {
    arr.append({
      text = text
      value = value
    })
  }
  if (needAdditionalInfo && "mass" in param)
  {
    if (param.caliber > 0)
      addProp(p, ::loc("bullet_properties/caliber"),
                stdMath.round_by_value(param.caliber, ::isCaliberCannon(param.caliber) ? 1 : 0.01) + " " + ::loc("measureUnits/mm"))
    if (param.mass > 0)
      addProp(p, ::loc("bullet_properties/mass"),
                ::g_measure_type.getTypeByName("kg", true).getMeasureUnitsText(param.mass))
    if (param.speed > 0)
      addProp(p, ::loc("bullet_properties/speed"),
                 ::format("%.0f %s", param.speed, ::loc("measureUnits/metersPerSecond_climbSpeed")))

    local maxSpeed = param?.maxSpeed ?? param?.endSpeed ?? 0
    if (param?.machMax)
      addProp(p, "".concat(::loc("rocket/maxSpeed"), ::format("%.1f %s", param.machMax, ::loc("measureUnits/machNumber"))))
    else if (maxSpeed)
      addProp(p, ::loc("rocket/maxSpeed"), ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed))

    if ("autoAiming" in param)
    {
      local aimingTypeLocId = "guidanceSystemType/" + (param.autoAiming ? "semiAuto" : "handAim")
      addProp(p, ::loc("guidanceSystemType/header"), ::loc(aimingTypeLocId))
    }

    local operatedDist = ::getTblValue("operatedDist", param, 0)
    if (operatedDist)
      addProp(p, ::loc("firingRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(operatedDist))

    local explosiveType = ::getTblValue("explosiveType", param)
    if (explosiveType)
      addProp(p, ::loc("bullet_properties/explosiveType"), ::loc("explosiveType/" + explosiveType))
    local explosiveMass = ::getTblValue("explosiveMass", param)
    if (explosiveMass)
      addProp(p, ::loc("bullet_properties/explosiveMass"),
        ::g_dmg_model.getMeasuredExplosionText(explosiveMass))

    if (explosiveType && explosiveMass)
    {
      local tntEqText = ::g_dmg_model.getTntEquivalentText(explosiveType, explosiveMass)
      if (tntEqText.len())
        addProp(p, ::loc("bullet_properties/explosiveMassInTNTEquivalent"), tntEqText)
    }

    local fuseDelayDist = stdMath.roundToDigits(param.fuseDelayDist, 2)
    if (fuseDelayDist)
      addProp(p, ::loc("bullet_properties/fuseDelayDist"),
                 fuseDelayDist + " " + ::loc("measureUnits/meters_alt"))
    local explodeTreshold = stdMath.roundToDigits(param.explodeTreshold, 2)
    if (explodeTreshold)
      addProp(p, ::loc("bullet_properties/explodeTreshold"),
                 explodeTreshold + " " + ::loc("measureUnits/mm"))
    local rangeBand0 = ::getTblValue("rangeBand0", param)
    if (rangeBand0)
      addProp(p, ::loc("missile/seekerRange/rearAspect"), ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeBand0))
    local rangeBand1 = ::getTblValue("rangeBand1", param)
    if (rangeBand1)
      addProp(p, ::loc("missile/seekerRange/allAspect"), ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeBand1))

    local proximityFuseArmDistance = stdMath.round(param?.proximityFuseArmDistance ?? 0)
    if (proximityFuseArmDistance)
      addProp(p, ::loc("torpedo/armingDistance"),
        proximityFuseArmDistance + " " + ::loc("measureUnits/meters_alt"))
    local proximityFuseRadius = stdMath.round(param?.proximityFuseRadius ?? 0)
    if (proximityFuseRadius)
      addProp(p, ::loc("bullet_properties/proximityFuze/triggerRadius"),
        proximityFuseRadius + " " + ::loc("measureUnits/meters_alt"))

    local ricochetData = !isCountermeasure && ::g_dmg_model.getRicochetData(param?.ricochetPreset)
    if (ricochetData)
      foreach(item in ricochetData.angleProbabilityMap)
        addProp(p, ::loc("bullet_properties/angleByProbability",
                         { probability = stdMath.roundToDigits(100.0 * item.probability, 2) }),
                   stdMath.roundToDigits(item.angle, 2) + ::loc("measureUnits/deg"))

    if ("reloadTimes" in param)
    {
      local currentDiffficulty = ::is_in_flight() ? ::get_mission_difficulty_int()
        : ::get_current_shop_difficulty().diffCode
      local reloadTime = param.reloadTimes[currentDiffficulty]
      if(reloadTime > 0)
        addProp(p, ::colorize("badTextColor", ::loc("bullet_properties/cooldown")),
                   ::colorize("badTextColor", stdMath.roundToDigits(reloadTime, 2) + " " + ::loc("measureUnits/seconds")))
    }

    if ("smokeShellRad" in param)
      addProp(p, ::loc("bullet_properties/smokeShellRad"),
                 stdMath.roundToDigits(param.smokeShellRad, 2) + " " + ::loc("measureUnits/meters_alt"))

    if ("smokeActivateTime" in param)
      addProp(p, ::loc("bullet_properties/smokeActivateTime"),
                 stdMath.roundToDigits(param.smokeActivateTime, 2) + " " + ::loc("measureUnits/seconds"))

    if ("smokeTime" in param)
      addProp(p, ::loc("bullet_properties/smokeTime"),
                 stdMath.roundToDigits(param.smokeTime, 2) + " " + ::loc("measureUnits/seconds"))

    local bTypeDesc = ::loc(param.bulletType, "")
    if (bTypeDesc != "")
      descTbl.bulletsDesc <- bTypeDesc
  }
  descTbl.bulletParams.append({ props = p })

  local bulletName = ""
  if("weaponBlkPath" in param)
    bulletName = ::loc("weapons/{0}".subst(::get_weapon_name_by_blk_path(param.weaponBlkPath)))

  local apData = getArmorPiercingViewData(param.armorPiercing, param.armorPiercingDist)
  if (apData)
  {
    local header = ::loc("bullet_properties/armorPiercing")
      + (::u.isEmpty(bulletName) ? "" : ( ": " + bulletName))
      + "\n" + ::format("(%s / %s)", ::loc("distance"), ::loc("bullet_properties/hitAngle"))
    descTbl.bulletParams.append({ props = apData, header = header })
  }
}

weaponVisual.getArmorPiercingViewData <- function getArmorPiercingViewData(armorPiercing, dist)
{
  local res = null
  if (armorPiercing.len() <= 0)
    return res

  local angles = null
  foreach(ind, armorTbl in armorPiercing)
  {
    if (armorTbl == null)
      continue
    if (!angles)
    {
      res = []
      angles = ::u.keys(armorTbl)
      angles.sort(@(a,b) a <=> b)
      local headRow = {
        text = ""
        values = ::u.map(angles, function(v) { return { value = v + ::loc("measureUnits/deg") } })
      }
      res.append(headRow)
    }

    local row = {
      text = dist[ind] + ::loc("measureUnits/meters_alt")
      values = []
    }
    foreach(angle in angles)
      row.values.append({ value = ::getTblValue(angle, armorTbl, 0) + ::loc("measureUnits/mm") })
    res.append(row)
  }
  return res
}

weaponVisual.updateModType <- function updateModType(unit, mod)
{
  if ("type" in mod)
    return

  local name = mod.name
  local primaryWeaponsNames = ::getPrimaryWeaponsList(unit)
  foreach(modName in primaryWeaponsNames)
    if (modName == name)
    {
      mod.type <- weaponsItem.primaryWeapon
      return
    }

  mod.type <- weaponsItem.modification
  return
}

weaponVisual.updateSpareType <- function updateSpareType(spare)
{
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

weaponVisual.updateWeaponTooltip <- function updateWeaponTooltip(obj, air, item, handler, params={}, effect=null)
{
  local descTbl = getItemDescTbl(air, item, params, effect,
    function(effect, ...) {
      if (::checkObj(obj) && obj.isVisible())
        ::weaponVisual.updateWeaponTooltip(obj, air, item, handler, params, effect)
    })

  local curExp = ::shop_get_module_exp(air.name, item.name)
  local is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && ::isModResearched(air, item))
  local is_researching = isModInResearch(air, item)
  local is_paused = canBeResearched(air, item, true) && curExp > 0

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

weaponVisual.getReqTextWorldWarArmy <- function getReqTextWorldWarArmy(unit, item)
{
  local text = ""
  local misRules = ::g_mis_custom_state.getCurMissionRules()
  if (!misRules.needCheckWeaponsAllowed(unit))
    return text

  local isEnabledByMission = misRules.isUnitWeaponAllowed(unit, item)
  local isEnabledForUnit = ::is_weapon_enabled(unit, item)
  if (!isEnabledByMission)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsDisabled") + "</color>"
  else if (isEnabledByMission && !isEnabledForUnit)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled/weaponRequired") + "</color>"
  else if (isEnabledByMission && isEnabledForUnit)
    text = "<color=@goodTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled") + "</color>"

  return text
}

weaponVisual.getStatusIcon <- function getStatusIcon(unit, item)
{
  local misRules = ::g_mis_custom_state.getCurMissionRules()
  if (item.type==weaponsItem.weapon
    && ::is_in_flight()
    && misRules.isWorldWar
    && misRules.needCheckWeaponsAllowed(unit)
    && misRules.isUnitWeaponAllowed(unit, item))
    return "#ui/gameuiskin#ww_icon.svg"

  return ""
}
