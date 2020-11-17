local unitTypes = require("scripts/unit/unitTypesList.nut")
local unitStatus = require("scripts/unit/unitStatus.nut")
local { getUnitRole, getUnitRoleIcon, getUnitItemStatusText, getUnitRarity
} = require("scripts/unit/unitInfoTexts.nut")
local { checkUnitWeapons, getWeaponsStatusName } = require("scripts/weaponry/weaponryInfo.nut")
local { getUnitShopPriceText } = require("unitCardPkg.nut")
local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")

local sectorAngle1PID = ::dagui_propid.add_name_id("sector-angle-1")

local setBool = @(obj, prop, val) obj[prop] = val ? "yes" : "no"

local function showInObj(obj, id, val) {
  local tgtObj = obj.findObject(id)
  tgtObj.show(val)
  tgtObj.enable(val)
  return tgtObj
}

local function updateProgressInObj(cell, id, progress, isPaused) {
  local obj = cell.findObject(id)
  local isVisible = progress >= 0
  obj.show(isVisible)
  if (!isVisible)
    return

  setBool(obj, "paused", isPaused)
  obj.setValue(progress)
}

local function updateSector1InObj(cell, id, angle) {
  local obj = cell.findObject(id)
  if (angle != (obj.getFinalProp(sectorAngle1PID) ?? -1).tointeger()) {
    obj.set_prop_latent(sectorAngle1PID, angle)
    obj.updateRendElem()
  }
  return obj
}

local function initCell(cell, initData) {
  local { id, posX = 0, posY = 0, position = "relative" } = initData
  cell.pos = $"{posX}w, {posY}h"
  cell.position = position

  local prevId = cell.holderId
  if (prevId == id)
    return
  cell.holderId = id
  cell.id = $"unitCell_{id}"
  local cardObj = cell.findObject(prevId)
  cardObj.id = id
  cardObj.findObject("mainActionButton").holderId = id
}

local function updateCardStatus(obj, id, statusTbl) {
  local {
    isGroup             = false,
    unitName            = "",
    unitImage           = "",
    nameText            = "",
    unitRarity          = "",
    unitClassIcon       = "",
    unitClass           = "",
    isPkgDev            = false,
    isRecentlyReleased  = false,
    tooltipId           = "",
    hasActionsMenu      = false,

    shopStatus          = "",
    unitRankText        = "",
    isViewDisabled      = false,
    isBroken            = false,
    isLocked            = false,
    needInService       = false,
    isMounted           = false,
    isElite             = false,
    hasTalismanIcon     = false,
    isTalismanComplete  = true,
    weaponsStatus       = "",
    progressText        = "",
    progressStatus      = "",
    isResearchPaused    = false,
    researchProgressOld = -1,
    researchProgressNew = -1,
    priceText           = "",
    primaryUnitId       = "", //used for group timers
    mainButtonText      = "",
    mainButtonIcon      = "",

    discount            = 0,
    expMul              = 1.0,
    wpMul               = 1.0
  } = statusTbl
  local isLongPriceText = ::is_unit_price_text_long(priceText)

  setBool(obj, "group", isGroup)
  obj.primaryUnitId = primaryUnitId
  obj.unit_name = unitName
  obj.shopStat = shopStatus
  obj.unitRarity = unitRarity
  setBool(obj, "isPkgDev", isPkgDev)
  setBool(obj, "isBroken", isBroken)
  setBool(obj, "refuseOpenHoverMenu", !hasActionsMenu)
  setBool(obj, "isElite", isElite)
  setBool(obj, "isRecentlyReleased", isRecentlyReleased)

  obj.findObject("unitImage")["foreground-image"] = unitImage
  obj.findObject("unitTooltip").tooltipId = tooltipId
  setBool(showInObj(obj, "talisman", hasTalismanIcon), "incomplete", !isTalismanComplete)
  setBool(showInObj(obj, "inServiceMark", needInService), "mounted", isMounted)
  showInObj(obj, "weaponStatusIcon", weaponsStatus != "").weaponsStatus = weaponsStatus
  showInObj(obj, "repairIcon", isBroken)

  local nameObj = obj.findObject("nameText")
  nameObj.setValue(nameText)
  setBool(nameObj, "disabled", isViewDisabled)

  local progressObj = obj.findObject("progressText")
  progressObj.setValue(progressText)
  progressObj.progressStatus = progressStatus

  updateProgressInObj(obj, "progressOld", researchProgressOld, isResearchPaused)
  updateProgressInObj(obj, "progressNew", researchProgressNew, isResearchPaused)

  local priceObj = obj.findObject("priceText")
  priceObj.setValue(priceText)
  setBool(priceObj, "tinyFont", isLongPriceText)

  local rankObj = obj.findObject("rankText")
  rankObj.setValue(unitRankText)
  setBool(rankObj, "tinyFont", isLongPriceText)
  setBool(rankObj, "locked", isLocked)

  local classPlace = showInObj(obj, "classIconPlace", unitClassIcon != "")
  if (unitClassIcon != "") {
    local classObj = classPlace.findObject("classIcon")
    classObj.setValue(unitClassIcon)
    classObj.shopItemType = unitClass
  }

  local hasMainButton = mainButtonText != "" || mainButtonIcon != ""
  local mainBtnObj = obj.findObject("mainActionButton")
  setBool(mainBtnObj, "forceHide", !hasMainButton)
  if (hasMainButton) {
    mainBtnObj.text = mainButtonText
    showInObj(mainBtnObj, "mainActionIcon", mainButtonIcon != "")["background-image"] = mainButtonIcon
  }

  local needDiscount = discount > 0
  local discountObj = obj.findObject("unitDiscount")
  if (!needDiscount)
    discountObj.setValue("")
  else {
    discountObj.setValue($"-{discount}%")
    discountObj.tooltip = ::format(::loc("discount/buy/tooltip"), discount.tostring())
  }

  local hasBonus = expMul > 1 || wpMul > 1
  local bonusObj = showInObj(obj, "unitBonusMark", hasBonus)
  if (hasBonus) {
    bonusObj.bonusType = expMul > 1 && wpMul > 1 ? "wp_exp"
      : expMul > 1 ? "exp"
      : "wp"
    bonusObj["background-image"] = ::getBonusImage("item", ::max(expMul, wpMul), "air")
    local locEnd = isGroup ? "/group/tooltip" : "/tooltip"
    local tooltipArr = []
    if (expMul > 1)
      tooltipArr.append(::format(::loc($"bonus/expitemAircraftMul{locEnd}"), $"x{expMul}"))
    if (wpMul > 1)
      tooltipArr.append(::format(::loc($"bonus/wpitemAircraftMul{locEnd}"), $"x{wpMul}"))
    bonusObj.tooltip = "\n".join(tooltipArr, true)
  }
}

local function updateCellStatus(cell, statusTbl) {
  local { isInactive = false, isVisible = true } = statusTbl
  setBool(cell, "inactive", isInactive)
  cell.enable(isVisible)
  cell.show(isVisible)
  if (!isVisible)
    return

  local id = cell.holderId
  local cardObj = cell.findObject(id)
  updateCardStatus(cardObj, id, statusTbl)
}

local function updateCellTimedStatusImpl(cell, timedTbl) {
  local { rentProgress = -1 } = timedTbl

  local rentIcon = showInObj(cell, "rentIcon", rentProgress >= 0)
  if (rentProgress >= 0)
    updateSector1InObj(rentIcon, "rentProgress", 360 - ::round(360.0 * rentProgress).tointeger())
}

local getUnitFixedParams = function(unit, params) {
  local { tooltipParams = {} } = params
  return {
    unitName            = unit.name
    unitImage           = ::image_for_air(unit)
    nameText            = ::getUnitName(unit)
    unitRarity          = getUnitRarity(unit)
    unitClassIcon       = getUnitRoleIcon(unit)
    unitClass           = getUnitRole(unit)
    isPkgDev            = unit.isPkgDev
    isRecentlyReleased  = unit.isRecentlyReleased()
    tooltipId           = ::g_tooltip.getIdUnit(unit.name, tooltipParams)
    hasActionsMenu      = true
  }
}

local getUnitStatusTbl = function(unit, params) {
  local { shopResearchMode = false, forceNotInResearch = false, mainActionText = "",
    showBR = false, getEdiffFunc = ::get_current_ediff
  } = params

  local isOwn           = unit.isBought()
  local isUsable        = ::isUnitUsable(unit)
  local isSpecial       = ::isUnitSpecial(unit)
  local bitStatus       = unitStatus.getBitStatus(unit, params)

  local res = {
    shopStatus          = getUnitItemStatusText(bitStatus, false)
    unitRankText        = ::get_unit_rank_text(unit, null, showBR, getEdiffFunc())
    isInactive          = (bit_unit_status.disabled & bitStatus) != 0
      || (shopResearchMode && (bit_unit_status.locked & bitStatus) != 0)
    isBroken            = ::isUnitBroken(unit)
    isLocked            = !isUsable && !isSpecial && !unit.isSquadronVehicle() && !::canBuyUnitOnMarketplace(unit)
      && !::isUnitsEraUnlocked(unit)
    needInService       = isUsable
    isMounted           = isUsable && ::isUnitInSlotbar(unit)
    weaponsStatus       = getWeaponsStatusName(isUsable ? checkUnitWeapons(unit) : UNIT_WEAPONS_READY)
    isElite             = isOwn ? ::isUnitElite(unit) : isSpecial
    hasTalismanIcon     = isSpecial || ::shop_is_modification_enabled(unit.name, "premExpMul")
    priceText           = getUnitShopPriceText(unit)

    discount            = isOwn || ::isUnitGift(unit) ? 0 : ::g_discount.getUnitDiscount(unit)
    expMul              = ::wp_shop_get_aircraft_xp_rate(unit.name)
    wpMul               = ::wp_shop_get_aircraft_wp_rate(unit.name)
  }
  if (forceNotInResearch || !::isUnitInResearch(unit) || ::has_feature("SpendGold")) //it not look like good idea to calc it here
    if (::show_console_buttons)
      res.mainButtonIcon <- "#ui/gameuiskin#slot_menu.svg"
    else
      res.mainButtonText <- mainActionText
  return res
}

local function getUnitResearchStatusTbl(unit, params) {
  if (unit.isBought() || !::canResearchUnit(unit))
    return {}
  local unitReqExp = ::getUnitReqExp(unit)
  if (unitReqExp <= 0)
    return {}

  local { forceNotInResearch = false, flushExp = 0 } = params

  local isVehicleInResearch = ::isUnitInResearch(unit) && !forceNotInResearch
  local isSquadronVehicle = unit.isSquadronVehicle()
  local unitCurExp = ::getUnitExp(unit)
  local diffExp = isSquadronVehicle ? ::min(::clan_get_exp(), unitReqExp - unitCurExp) : 0
  local isLockedSquadronVehicle = isSquadronVehicle && !::is_in_clan() && diffExp <= 0
  if (isLockedSquadronVehicle && unitCurExp <= 0)
    return {}

  local unitNewExp = unitCurExp + (isVehicleInResearch ? diffExp : 0)
  local isFull = isSquadronVehicle ? diffExp > 0 && unitNewExp >= unitReqExp
    : unitCurExp + flushExp >= unitReqExp

  return {
    progressText        = isLockedSquadronVehicle ? ""
      : isSquadronVehicle ? ::Cost().setSap(unitReqExp - unitCurExp).tostring()
      : ::Cost().setRp(unitReqExp - unitCurExp).tostring()
    progressStatus      = isFull ? "researched"
      : isVehicleInResearch ? "research"
      : ""
    isResearchPaused    = !isVehicleInResearch
    researchProgressOld = (1000.0 * unitCurExp / unitReqExp).tointeger()
    researchProgressNew = (1000.0 * unitNewExp / unitReqExp).tointeger()
  }
}

local function getUnitTimedStatusTbl(unit) {
  local isRented = unit.isRented()
  return {
    rentProgress = isRented
      ? unit.getRentTimeleft().tofloat() / (::rented_units_get_last_max_full_rent_time(unit.name) || -1)
      : -1
    needUpdateByTime = isRented
  }
}

local function getFakeUnitStatusTbl(unit, params) {
  local { showBR = false, getEdiffFunc = ::get_current_ediff } = params

  local nameForLoc = unit?.isReqForFakeUnit ? ::split(unit.name, "_")?[0] : unit.name
  local { esUnitType } = unitTypes.getByName(unit.name, false)
  local isFakeAirRankOpen = ::get_units_count_at_rank(unit?.rank, esUnitType, unit?.country, true)
  local bitStatus = unit?.isReqForFakeUnit ? bit_unit_status.disabled
    : isFakeAirRankOpen ? bit_unit_status.owned
    : bit_unit_status.locked
  return {
    unitName             = unit.name
    unitImage            = unit.image
    nameText             = ::loc(unit?.nameLoc ?? $"mainmenu/type_{nameForLoc}")
    isInactive           = true
    shopStatus           = getUnitItemStatusText(bitStatus, true)
    unitRankText         = ::get_unit_rank_text(unit, null, showBR, getEdiffFunc())
    isViewDisabled       = bitStatus == bit_unit_status.disabled
  }
}

local function getGroupStatusTbl(group, params) {
  local { forceNotInResearch = false, shopResearchMode = false, tooltipParams = {},
    showBR = false, getEdiffFunc = ::get_current_ediff
  } = params
  local unitsList = group.airsGroup

  local isInactive         = false
  local isGroupUsable      = false
  local isGroupInResearch  = false
  local isElite            = true
  local isPkgDev           = false
  local isRecentlyReleased = false
  local hasTalismanIcon    = false
  local isTalismanComplete = true
  local bitStatus          = 0
  local expMul             = 1.0
  local wpMul              = 1.0

  local mountedUnit        = null
  local lastBoughtUnit     = null
  local firstUnboughtUnit  = null
  local researchingUnit    = null
  local rentedUnit         = null

  foreach(unit in unitsList)
  {
    local isInResearch = !forceNotInResearch && ::isUnitInResearch(unit)
    local isUsable = ::isUnitUsable(unit)

    if (isInResearch || (::canResearchUnit(unit) && !researchingUnit))
    {
      researchingUnit = unit
      isGroupInResearch = isInResearch
    }
    else if (isUsable)
      lastBoughtUnit = unit
    else if (!firstUnboughtUnit && (::canBuyUnit(unit) || ::canBuyUnitOnline(unit)))
      firstUnboughtUnit = unit

    if (isUsable)
    {
      if (::isUnitInSlotbar(unit))
        mountedUnit = unit
      isGroupUsable = true
    }

    if (unit.isRented())
    {
      if (!rentedUnit || unit.getRentTimeleft() <= rentedUnit.getRentTimeleft())
        rentedUnit = unit
    }

    bitStatus = bitStatus | unitStatus.getBitStatus(unit)
    isPkgDev = isPkgDev || unit.isPkgDev
    isRecentlyReleased = isRecentlyReleased || unit.isRecentlyReleased()
    isElite = isElite && ::isUnitElite(unit)
    local hasTalisman = ::isUnitSpecial(unit) || ::shop_is_modification_enabled(unit.name, "premExpMul")
    hasTalismanIcon = hasTalismanIcon || hasTalisman
    isTalismanComplete = isTalismanComplete && hasTalisman
    expMul = ::max(expMul, ::wp_shop_get_aircraft_xp_rate(unit.name))
    wpMul = ::max(wpMul, ::wp_shop_get_aircraft_wp_rate(unit.name))
  }

  if (shopResearchMode
      && !(bitStatus & (bit_unit_status.canBuy | bit_unit_status.inResearch | bit_unit_status.canResearch))) {
    if (!(bitStatus & bit_unit_status.locked))
      bitStatus = bit_unit_status.disabled
    isInactive = true
  }

  local primaryUnit = rentedUnit || mountedUnit || (isGroupInResearch && researchingUnit)
    || firstUnboughtUnit || lastBoughtUnit || unitsList[0]
  local needUnitNameOnPlate = rentedUnit != null || mountedUnit  != null
    || (isGroupInResearch && researchingUnit != null) || firstUnboughtUnit != null
  local unitForBR = rentedUnit || researchingUnit || firstUnboughtUnit || group

  local researchStatusTbl = researchingUnit ? getUnitResearchStatusTbl(researchingUnit, params) : {}
  local unitImage = ::get_unit_preset_img(group.name)
    ?? (::is_tencent_unit_image_reqired(primaryUnit)
        ? "".concat(::get_tomoe_unit_icon(group.name), (group.name.indexof("_group", 0) != null ? "" : "_group"))
        : "!{0}".subst(group?.image ?? "#ui/unitskin#planes_group"))

  return {
    //fixed params
    isGroup             = true
    hasActionsMenu      = true
    isPkgDev,
    isRecentlyReleased,
    mainButtonIcon      = ::show_console_buttons ? "#ui/gameuiskin#slot_unfold.svg" : "",

    //primary unit params
    primaryUnitId       = primaryUnit.name,
    unitImage,
    nameText            = needUnitNameOnPlate ? ::getUnitName(primaryUnit) : ::loc($"shop/group/{group.name}")
    unitRarity          = getUnitRarity(primaryUnit)
    unitClassIcon       = getUnitRoleIcon(primaryUnit)
    unitClass           = getUnitRole(primaryUnit)
    tooltipId           = ::g_tooltip.getIdUnit(primaryUnit.name, tooltipParams)

    //complex params
    shopStatus          = getUnitItemStatusText(bitStatus, true),
    unitRankText        = ::get_unit_rank_text(unitForBR, null, showBR, getEdiffFunc()),
    isInactive,
    isBroken            = bitStatus & bit_unit_status.broken,
    isLocked            = !::is_era_available(unitsList[0].shopCountry, unitsList[0].rank, ::get_es_unit_type(unitsList[0])),
    needInService       = isGroupUsable
    isMounted           = mountedUnit != null,
    isElite,
    hasTalismanIcon,
    isTalismanComplete,
    priceText           = firstUnboughtUnit && !researchingUnit ? getUnitShopPriceText(firstUnboughtUnit) : "",

    discount            = firstUnboughtUnit ? ::g_discount.getGroupDiscount(unitsList) : 0,
    expMul,
    wpMul,
  }.__update(researchStatusTbl)
}

local function getGroupTimedStatusTbl(group) {
  local unit = null
  local rentLeft = 0
  foreach(u in group.airsGroup)
    if (u.isRented() && (!unit || rentLeft >= u.getRentTimeleft()))
    {
      unit = u
      rentLeft = u.getRentTimeleft()
    }

  return {
    rentProgress = unit ? rentLeft / (::rented_units_get_last_max_full_rent_time(unit.name) || -1) : -1
    needUpdateByTime = unit != null
  }
}

local getStatusTbl = @(unitOrGroup, params) unitOrGroup == null ? { isVisible = false }
  : ::isUnitGroup(unitOrGroup) ? getGroupStatusTbl(unitOrGroup, params)
  : unitOrGroup?.isFakeUnit ? getFakeUnitStatusTbl(unitOrGroup, params)
  : getUnitStatusTbl(unitOrGroup, params)
      .__update(getUnitResearchStatusTbl(unitOrGroup, params))
      .__update(getUnitFixedParams(unitOrGroup, params))

local getTimedStatusTbl = @(unitOrGroup, params) unitOrGroup == null ? {}
  : ::isUnitGroup(unitOrGroup) ? getGroupTimedStatusTbl(unitOrGroup)
  : unitOrGroup?.isFakeUnit ? {}
  : getUnitTimedStatusTbl(unitOrGroup)

local function updateCellTimedStatus(cell, getTimedStatus) {
  local timedStatus = getTimedStatus()
  updateCellTimedStatusImpl(cell, timedStatus)
  if (!timedStatus?.needUpdateByTime)
    return

  local cardObj = cell.findObject(cell.holderId)
  SecondsUpdater(cardObj, function(obj, _) {
    timedStatus = getTimedStatus()
    updateCellTimedStatusImpl(cell, timedStatus) //cell is valid while cardObj is valid
    return !timedStatus?.needUpdateByTime
  })
}

return {
  getStatusTbl = getStatusTbl
  getTimedStatusTbl = getTimedStatusTbl
  updateCellStatus = updateCellStatus
  updateCellTimedStatus = updateCellTimedStatus
  initCell = initCell
}