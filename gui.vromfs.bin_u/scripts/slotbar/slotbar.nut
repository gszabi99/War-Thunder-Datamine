local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local unitStatus = require("scripts/unit/unitStatus.nut")
local { getUnitRole, getUnitRoleIcon } = require("scripts/unit/unitInfoTexts.nut")
local { getLastWeapon, getWeaponsStatusName } = require("scripts/weaponry/weaponryInfo.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

/*
if need - put commented in array above
//crew list for tests
  {
    country = "country_usa"
    crews = [
      { aircraft = "pby-5a", trained = ["pby-5a", "b_24d"] }
      { aircraft = "b_24d" }
      { }
    ]
  }
  {
    country = "country_germany"
    crews = [
      { aircraft = "fiat_cr42" }
      { aircraft = "fiat_g50_seria2" }
      { aircraft = "fiat_g50_seria7as" }
      { aircraft = "bf-109e-3" }
      { aircraft = "bf-110c-4" }
      { aircraft = "bf-109f-4" }
    ]
  }
  {
    country = "country_ussr"
    crews = [
      { aircraft = "swordfish_mk1" }
      { aircraft = "gladiator_mk2" }
    ]
  }
*/

::selected_crews <- []
::unlocked_countries <- []

::g_script_reloader.registerPersistentData("SlotbarGlobals", ::getroottable(), ["selected_crews", "unlocked_countries"])

::build_aircraft_item <- function build_aircraft_item(id, air, params = {})
{
  local res = ""
  local defaultStatus = "none"

  local showBR = ::getTblValue("showBR", params, ::has_feature("GlobalShowBattleRating"))
  local curEdiff = ("getEdiffFunc" in params) ?  params.getEdiffFunc() : ::get_current_ediff()

  if (air && !::isUnitGroup(air) && !air?.isFakeUnit)
  {
    local isLocalState        = params?.isLocalState ?? true
    local forceNotInResearch  = params?.forceNotInResearch ?? false
    local inactive            = params?.inactive ?? false
    local shopResearchMode    = params?.shopResearchMode ?? false
    local hasActions          = params?.hasActions ?? false

    local isOwn               = ::isUnitBought(air)
    local isUsable            = ::isUnitUsable(air)
    local isMounted           = ::isUnitInSlotbar(air)
    local canResearch         = ::canResearchUnit(air)
    local special             = ::isUnitSpecial(air)
    local isVehicleInResearch = ::isUnitInResearch(air) && !forceNotInResearch
    local isSquadronVehicle   = air.isSquadronVehicle()
    local isMarketableVehicle = ::canBuyUnitOnMarketplace(air)
    local unitReqExp          = ::getUnitReqExp(air)
    local unitExpGranted      = ::getUnitExp(air)
    local diffExp = isSquadronVehicle
      ? ::min(::clan_get_exp(), unitReqExp - unitExpGranted)
      : (params?.diffExp ?? 0)
    if (isSquadronVehicle && isVehicleInResearch)
      unitExpGranted += diffExp

    local isBroken            = ::isUnitBroken(air)
    local unitRarity          = ::getUnitRarity(air)
    local isLockedSquadronVehicle = isSquadronVehicle && !::is_in_clan() && diffExp <= 0

    local status = params?.status ?? defaultStatus
    if (status == defaultStatus)
    {
      local bitStatus = unitStatus.getBitStatus(air, params)
      if (bit_unit_status.locked & bitStatus)
        inactive = shopResearchMode
      else if (bit_unit_status.disabled & bitStatus)
        inactive = true

      status = ::getUnitItemStatusText(bitStatus, false)
    }

    //
    // Bottom button view
    //

    local mainButtonAction = ::show_console_buttons ? "onOpenActionsList" : (params?.mainActionFunc ?? "")
    local mainButtonText = ::show_console_buttons ? "" : (params?.mainActionText ?? "")
    local mainButtonIcon = ::show_console_buttons ? "#ui/gameuiskin#slot_menu.svg" : (params?.mainActionIcon ?? "")
    local checkTexts = mainButtonAction.len() > 0 && (mainButtonText.len() > 0 || mainButtonIcon.len() > 0)
    local checkButton = !isVehicleInResearch || ::has_feature("SpendGold")
    local bottomButtonView = {
      hasButton           = hasActions && checkTexts && checkButton
      spaceButton         = true
      mainButtonText      = mainButtonText
      mainButtonAction    = mainButtonAction
      hasMainButtonIcon   = mainButtonIcon.len()
      mainButtonIcon      = mainButtonIcon
    }

    //
    // Item buttons view
    //

    local crewId = params?.crewId ?? -1
    local showWarningIcon = params?.showWarningIcon ?? false
    local specType = params?.specType
    local rentInfo = ::get_unit_item_rent_info(air, params)
    local spareCount = isLocalState ? ::get_spare_aircrafts_count(air.name) : 0

    local hasCrewInfo = ::has_feature("CrewInfo") && crewId >= 0
    local crew = hasCrewInfo ? ::get_crew_by_id(crewId) : null

    local forceCrewInfoUnit = params?.forceCrewInfoUnit
    local unitForCrewInfo = forceCrewInfoUnit || air
    local crewLevelText = crew && unitForCrewInfo
      ? ::g_crew.getCrewLevel(crew, unitForCrewInfo, unitForCrewInfo.getCrewUnitType()).tointeger().tostring()
      : ""
    local crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unitForCrewInfo).trainedIcon

    local itemButtonsView = {
      itemButtons = {
        hasToBattleButton       = params?.toBattle ?? false
        toBattleButtonAction    = params?.toBattleButtonAction ?? "onSlotBattle"
        hasExtraInfoBlock       = params?.hasExtraInfoBlock ?? false

        hasCrewInfo             = hasCrewInfo
        crewLevel               = hasCrewInfo ? crewLevelText : ""
        crewSpecIcon            = hasCrewInfo ? crewSpecIcon : ""
        crewStatus              = hasCrewInfo ? ::get_crew_status(crew, unitForCrewInfo) : ""

        hasSpareCount           = spareCount > 0
        spareCount              = spareCount ? spareCount + ::loc("icon/spare") : ""
        specIconBlock           = showWarningIcon || specType != null
        showWarningIcon         = showWarningIcon
        hasRepairIcon           = isLocalState && isBroken
        weaponsStatus           = getWeaponsStatusName(isLocalState && isUsable ? ::checkUnitWeapons(air) : UNIT_WEAPONS_READY)
        hasRentIcon             = rentInfo.hasIcon
        hasRentProgress         = rentInfo.hasProgress
        rentProgress            = rentInfo.progress
        bonusId                 = id
      }
    }

    if (specType)
    {
      itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
      itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
    }

    //
    // Air research progress view
    //

    local showProgress = isLocalState && !isOwn && canResearch && !::is_in_flight()
      && (!isLockedSquadronVehicle || unitExpGranted > 0)
    local airResearchProgressView = {
      airResearchProgress = []
    }
    if (showProgress)
    {
      airResearchProgressView.airResearchProgress.append({
        airResearchProgressValue            = unitReqExp > 0 ? (unitExpGranted.tofloat() / unitReqExp * 1000).tointeger() : 0
        airResearchProgressType             = "new"
        airResearchProgressIsPaused         = !isVehicleInResearch || forceNotInResearch || isLockedSquadronVehicle
        airResearchProgressAbsolutePosition = false
        airResearchProgressHasPaused        = true
        airResearchProgressHasDisplay       = false
      })
      if (unitExpGranted > diffExp)
      {
        airResearchProgressView.airResearchProgress.append({
          airResearchProgressValue            = ((unitExpGranted.tofloat() - diffExp) / unitReqExp * 1000).tointeger()
          airResearchProgressType             = "old"
          airResearchProgressIsPaused         = !isVehicleInResearch || forceNotInResearch || isLockedSquadronVehicle
          airResearchProgressAbsolutePosition = true
          airResearchProgressHasPaused        = true
          airResearchProgressHasDisplay       = false
        })
      }
    }

    //
    // Res view
    //

    local priceText = ::get_unit_item_price_text(air, params)
    local progressText = showProgress ? ::get_unit_item_research_progress_text(air, params, priceText) : ""
    local checkNotification = ::g_discount.getEntitlementUnitDiscount(air.name)

    local resView = {
      slotId              = "td_" + id
      slotInactive        = inactive
      isSlotbarItem       = params?.isSlotbarItem ?? false
      isInTable           = params?.isInTable ?? true
      shopItemId          = id
      unitName            = air.name
      crewId              = crew?.id.tostring()
      premiumPatternType  = special
      shopItemType        = getUnitRole(air)
      unitClassIcon       = getUnitRoleIcon(air)
      shopStatus          = status
      unitRarity          = unitRarity
      isBroken            = isLocalState && isBroken
      shopAirImg          = ::image_for_air(air)
      isPkgDev            = air.isPkgDev
      isRecentlyReleased  = air.isRecentlyReleased()
      discountId          = id + "-discount"
      showDiscount        = isLocalState && !isOwn && (!::isUnitGift(air) || checkNotification)
      shopItemTextId      = id + "_txt"
      shopItemText        = ::get_slot_unit_name_text(air, params)
      progressText        = progressText
      progressStatus      = showProgress? ::get_unit_item_progress_status(air, params) : ""
      progressBlk         = ::handyman.renderCached("gui/slotbar/airResearchProgress", airResearchProgressView)
      showInService       = (params?.showInService ?? false) && isUsable
      isMounted           = isMounted
      priceText           = priceText
      isLongPriceText     = ::is_unit_price_text_long(priceText)
      isElite             = (isLocalState && isOwn && ::isUnitElite(air)) || (!isOwn && special)
      unitRankText        = ::get_unit_rank_text(air, crew, showBR, curEdiff)
      bottomLineText      = params?.bottomLineText
      isItemLocked        = isLocalState && !isUsable && !special && !isSquadronVehicle && !isMarketableVehicle && !::isUnitsEraUnlocked(air)
      hasTalismanIcon     = isLocalState && (special || ::shop_is_modification_enabled(air.name, "premExpMul"))
      itemButtons         = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      tooltipId           = ::g_tooltip.getIdUnit(air.name, params?.tooltipParams)
      bottomButton        = ::handyman.renderCached("gui/slotbar/slotbarItemBottomButton", bottomButtonView)
      hasHoverMenu        = hasActions
    }
    local missionRules = params?.missionRules
    local groupName = missionRules ? missionRules.getRandomUnitsGroupName(air.name) : null
    local isShowAsRandomUnit = groupName
      && (::is_respawn_screen()
        || !::is_player_unit_alive()
        || ::get_player_unit_name() != air.name)
    if (isShowAsRandomUnit)
    {
      resView.shopAirImg = missionRules.getRandomUnitsGroupIcon(groupName)
      resView.shopItemType = ""
      resView.unitClassIcon = ""
      resView.isElite = false
      resView.premiumPatternType = false
      resView.unitRarity = ""
      resView.unitRankText = ""
      resView.tooltipId = ::g_tooltip_type.RANDOM_UNIT.getTooltipId(air.name, {groupName = groupName})
    }

    res = ::handyman.renderCached("gui/slotbar/slotbarSlotSingle", resView)
  }
  else if (air && ::isUnitGroup(air)) //group of aircrafts
  {
    local groupStatus         = params?.status ?? defaultStatus
    local forceNotInResearch  = params?.forceNotInResearch ?? false
    local shopResearchMode    = params?.shopResearchMode ?? false
    local showInService       = params?.showInService ?? false
    local inactive            = params?.inactive ?? false

    local special           = false

    local nextAir = air.airsGroup[0]
    local country = nextAir.shopCountry
    local esUnitType = ::get_es_unit_type(nextAir)
    local forceUnitNameOnPlate = false

    local era = getUnitRank(nextAir)

    local isGroupUsable     = false
    local isGroupInResearch = false
    local isElite           = true
    local isPkgDev          = false
    local isRecentlyReleased = false
    local hasTalismanIcon   = false
    local talismanIncomplete = false
    local mountedUnit       = null
    local lastBoughtUnit    = null
    local firstUnboughtUnit = null
    local researchingUnit   = null
    local rentedUnit        = null
    local unitRole          = null
    local bitStatus         = 0

    local isSquadronResearchMode = params?.isSquadronResearchMode ?? false

    foreach(a in air.airsGroup)
    {
      local isInResearch = !forceNotInResearch && ::isUnitInResearch(a)
      local isUsable = ::isUnitUsable(a)

      if (isInResearch || (::canResearchUnit(a) && !researchingUnit))
      {
        researchingUnit = a
        isGroupInResearch = isInResearch
      }
      else if (isUsable)
        lastBoughtUnit = a
      else if (!firstUnboughtUnit && (::canBuyUnit(a) || ::canBuyUnitOnline(a)))
        firstUnboughtUnit = a

      if (showInService && isUsable)
      {
        if (::isUnitInSlotbar(a))
          mountedUnit = a
        isGroupUsable = true
      }

      if (a.isRented())
      {
        if (!rentedUnit || a.getRentTimeleft() <= rentedUnit.getRentTimeleft())
          rentedUnit = a
      }

      if (unitRole == null || isInResearch)
        unitRole = getUnitRole(nextAir)

      special = ::isUnitSpecial(a)
      isElite = isElite && ::isUnitElite(a)
      isPkgDev = isPkgDev || a.isPkgDev
      isRecentlyReleased = isRecentlyReleased || a.isRecentlyReleased()

      local hasTalisman = special || ::shop_is_modification_enabled(a.name, "premExpMul")
      hasTalismanIcon = hasTalismanIcon || hasTalisman
      talismanIncomplete = talismanIncomplete || !hasTalisman

      bitStatus = bitStatus | unitStatus.getBitStatus(a)
    }

    if ((shopResearchMode && !(bitStatus &
           (
             bit_unit_status.canBuy
            | bit_unit_status.inResearch
            | bit_unit_status.canResearch)
          ))
        || isSquadronResearchMode)
      {
        if (!(bitStatus & bit_unit_status.locked) || isSquadronResearchMode)
          bitStatus = bit_unit_status.disabled
        inactive = true
      }

    // Unit selection priority: 1) rented, 2) researching, 3) mounted, 4) first unbougt,
    //   5) last bought, 6) first in group.
    nextAir = rentedUnit || mountedUnit || (isGroupInResearch && researchingUnit)
      || firstUnboughtUnit || lastBoughtUnit || nextAir
    forceUnitNameOnPlate = rentedUnit != null || mountedUnit  != null
      || (isGroupInResearch && researchingUnit != null) || firstUnboughtUnit != null
    local unitForBR = rentedUnit || researchingUnit || firstUnboughtUnit || air

    //
    // Bottom button view
    //

    local bottomButtonView = {
      hasButton           = ::show_console_buttons
      spaceButton         = false
      mainButtonAction    = "onAircraftClick"
      mainButtonText      = ""
      mainButtonIcon      = "#ui/gameuiskin#slot_unfold.svg"
      hasMainButtonIcon   = true
    }

    //
    // Item buttons view
    //

    local rentInfo = ::get_unit_item_rent_info(rentedUnit, params)

    local itemButtonsView = {
      itemButtons = {
        hasRentIcon             = rentInfo.hasIcon
        hasRentProgress         = rentInfo.hasProgress
        rentProgress            = rentInfo.progress
      }
    }

    //
    // Air research progress view
    //

    local showProgress = false
    local unitExpProgressValue = 0
    if (researchingUnit)
    {
      showProgress = true
      local unitExpGranted = ::getUnitExp(researchingUnit)
      local unitReqExp = ::getUnitReqExp(researchingUnit)
      unitExpProgressValue = unitReqExp > 0 ? unitExpGranted.tofloat() / unitReqExp.tofloat() * 1000 : 0
    }

    local airResearchProgressView = {
      airResearchProgress = [{
        airResearchProgressValue            = unitExpProgressValue.tostring()
        airResearchProgressType             = ""
        airResearchProgressIsPaused         = !isGroupInResearch
        airResearchProgressAbsolutePosition = false
        airResearchProgressHasPaused        = true
        airResearchProgressHasDisplay       = true
        airResearchProgressDisplay          = showProgress
      }]
    }

    //
    // Res view
    //

    local shopAirImage = ::get_unit_preset_img(air.name)
    if (!shopAirImage)
      if (::is_tencent_unit_image_reqired(nextAir))
        shopAirImage = ::get_tomoe_unit_icon(air.name) + (air.name.indexof("_group", 0) != null ? "" : "_group")
      else
        shopAirImage = "!" + (::getTblValue("image", air) || ("#ui/unitskin#planes_group"))

    local groupSlotView = {
      slotId              = id
      unitRole            = unitRole
      unitClassIcon       = getUnitRoleIcon(nextAir)
      groupStatus         = groupStatus == defaultStatus ? ::getUnitItemStatusText(bitStatus, true) : groupStatus
      isBroken            = bitStatus & bit_unit_status.broken
      shopAirImg          = shopAirImage
      isPkgDev            = isPkgDev
      isRecentlyReleased  = isRecentlyReleased
      discountId          = id + "-discount"
      shopItemTextId      = id + "_txt"
      shopItemText        = forceUnitNameOnPlate ? "#" + nextAir.name + "_shop" : "#shop/group/" + air.name
      progressText        = showProgress ? ::get_unit_item_research_progress_text(researchingUnit, params) : ""
      progressStatus      = showProgress ? ::get_unit_item_progress_status(researchingUnit, params) : ""
      progressBlk         = ::handyman.renderCached("gui/slotbar/airResearchProgress", airResearchProgressView)
      showInService       = isGroupUsable
      priceText           = !showProgress && firstUnboughtUnit ? ::get_unit_item_price_text(firstUnboughtUnit, params) : ""
      isMounted           = mountedUnit != null
      isElite             = isElite
      unitRankText        = ::get_unit_rank_text(unitForBR, null, showBR, curEdiff)
      isItemLocked        = !::is_era_available(country, era, esUnitType)
      hasTalismanIcon     = hasTalismanIcon
      talismanIncomplete  = talismanIncomplete
      itemButtons         = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      bonusId             = id
      primaryUnitId       = nextAir.name
      tooltipId           = ::g_tooltip.getIdUnit(nextAir.name, params?.tooltipParams)
      bottomButton        = ::handyman.renderCached("gui/slotbar/slotbarItemBottomButton", bottomButtonView)
      hasFullGroupBlock   = params?.fullGroupBlock ?? true
      fullGroupBlockId    = "td_" + id
      isGroupInactive     = inactive
    }
    res = ::handyman.renderCached("gui/slotbar/slotbarSlotGroup", groupSlotView)
  }
  else if (air?.isFakeUnit)  //fake unit slot
  {
    local isReqForFakeUnit  = air?.isReqForFakeUnit ?? false
    local isLocalState      = params?.isLocalState ?? true
    local isFakeAirRankOpen = isLocalState && get_units_count_at_rank(air?.rank,
      unitTypes.getByName(air.name, false).esUnitType, air?.country, true)
    local bitStatus = isReqForFakeUnit ? bit_unit_status.disabled
      : (isFakeAirRankOpen || !isLocalState ? bit_unit_status.owned
        : bit_unit_status.locked)
    local nameForLoc = isReqForFakeUnit ? ::split(air.name, "_")?[0] : air.name
    local fakeSlotView = {
      slotId              = "td_" + id
      slotInactive        = true
      isSlotbarItem       = false
      shopItemId          = id
      unitName            = air.name
      shopAirImg          = air.image
      shopStatus          = params?.status ?? ::getUnitItemStatusText(bitStatus, true)
      unitRankText        = ::get_unit_rank_text(air, null, showBR, curEdiff)
      shopItemTextId      = id + "_txt"
      shopItemText        = ::loc(air?.nameLoc ?? $"mainmenu/type_{nameForLoc}")
      isItemDisabled      = bitStatus == bit_unit_status.disabled
      needMultiLineName   = params?.needMultiLineName
      tooltipId           = params?.tooltipId ?? ""
      bottomLineText      = params?.bottomLineText
    }
    res = ::handyman.renderCached("gui/slotbar/slotbarSlotFake", fakeSlotView)
  }
  else //empty air slot
  {
    local specType = params?.specType
    local itemButtonsView = { itemButtons = {
      specIconBlock = specType != null
    }}

    if (specType)
    {
      itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
      itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
    }

    local crewLevelInfoData = ""
    local unitForCrewInfo = params?.forceCrewInfoUnit
    if (unitForCrewInfo)
    {
      local crewId = params?.crewId ?? -1
      local crew = crewId >= 0 ? ::get_crew_by_id(crewId) : null
      if (crew)
      {
        local crewLevelText = ::g_crew.getCrewLevel(crew, unitForCrewInfo,
          unitForCrewInfo.getCrewUnitType()).tointeger().tostring()
        local crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unitForCrewInfo).trainedIcon

        local crewLevelInfoView = { itemButtons = {
          hasExtraInfoBlock = true
          hasCrewInfo       = ::has_feature("CrewInfo")
          crewLevel         = crewLevelText
          crewSpecIcon      = crewSpecIcon
        }}
        crewLevelInfoData = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", crewLevelInfoView)
      }
    }

    local emptyCost = params?.emptyCost
    local priceText = emptyCost ? emptyCost.getTextAccordingToBalance() : ""
    local emptySlotView = {
      slotId = "td_" + id,
      shopItemId = id,
      shopItemTextId = id + "_txt",
      shopItemTextValue = params?.emptyText ?? ""
      shopStatus = params?.status
      shopItemPriceText = priceText,
      crewImage = params?.crewImage
      isCrewRecruit = params?.isCrewRecruit ?? false
      itemButtons = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      isSlotbarItem = params?.isSlotbarItem ?? false
      crewLevelInfo = crewLevelInfoData
    }
    res = ::handyman.renderCached("gui/slotbar/slotbarSlotEmpty", emptySlotView)
  }

  if (params?.fullBlock ?? true)
    res = ::format("td{%s}", res)

  return res
}

::fill_unit_item_timers <- function fill_unit_item_timers(holderObj, unit, params = {})
{
  if (!::checkObj(holderObj) || !unit)
    return

  local rentedUnit = null
  if (::isUnitGroup(unit))
  {
    rentedUnit = unit.airsGroup[0]
    foreach(u in unit.airsGroup)
    {
      if (u.isRented())
        if (!rentedUnit || u.getRentTimeleft() <= rentedUnit.getRentTimeleft())
          rentedUnit = u
    }
  }
  else
    rentedUnit = unit

  if (!rentedUnit || !rentedUnit.isRented())
    return

  SecondsUpdater(holderObj, (@(rentedUnit) function(obj, params) {
    local isActive = false

    // Unit rent time
    local isRented = rentedUnit.isRented()
    if (isRented)
    {
      local objRentProgress = obj.findObject("rent_progress")
      if (::checkObj(objRentProgress))
      {
        local totalRentTimeSec = ::rented_units_get_last_max_full_rent_time(rentedUnit.name) || -1
        local progress = 360 - ::round(360.0 * rentedUnit.getRentTimeleft() / totalRentTimeSec).tointeger()
        if (objRentProgress["sector-angle-1"] != progress)
          objRentProgress["sector-angle-1"] = progress

        isActive = true
      }
    }
    else // at rent time over
    {
      local rentInfo = ::get_unit_item_rent_info(rentedUnit, params)

      local objRentIcon = obj.findObject("rent_icon")
      if (::checkObj(objRentIcon))
        objRentIcon.show(rentInfo.hasIcon)
      local objRentProgress = obj.findObject("rent_progress")
      if (::checkObj(objRentProgress))
        objRentProgress.show(rentInfo.hasProgress)
    }

    return !isActive
  })(rentedUnit))
}

::get_slot_obj_id <- function get_slot_obj_id(countryId, idInCountry, isBonus = false)
{
  ::dagor.assertf(countryId != null, "Country ID is null.")
  ::dagor.assertf(idInCountry != null, "Crew IDX is null.")
  local objId = ::format("slot_%s_%s", countryId.tostring(), idInCountry.tostring())
  if (isBonus)
    objId += "-bonus"
  return objId
}

::get_slot_obj <- function get_slot_obj(slotbarObj, countryId, idInCountry)
{
  if (!::checkObj(slotbarObj))
    return null
  local slotObj = slotbarObj.findObject(get_slot_obj_id(countryId, idInCountry))
  return ::checkObj(slotObj) ? slotObj : null
}

::get_unit_item_rent_info <- function get_unit_item_rent_info(unit, params)
{
  local info = {
    hasIcon     = false
    hasProgress = false
    progress    = 0
  }

  if (unit)
  {
    local showAsTrophyContent = ::getTblValue("showAsTrophyContent", params, false)
    local offerRentTimeHours  = ::getTblValue("offerRentTimeHours", params, 0)
    local hasProgress = unit.isRented() && !showAsTrophyContent
    local isRentOffer = showAsTrophyContent && offerRentTimeHours > 0

    info.hasIcon = hasProgress || isRentOffer
    info.hasProgress = hasProgress

    local totalRentTimeSec = hasProgress ?
      (::rented_units_get_last_max_full_rent_time(unit.name) || -1)
      : 3600
    info.progress = hasProgress ?
      (360 - ::round(360.0 * unit.getRentTimeleft() / totalRentTimeSec).tointeger())
      : 0
  }

  return info
}

::get_slot_unit_name_text <- function get_slot_unit_name_text(unit, params)
{
  local res = ::getUnitName(unit)
  local missionRules = ::getTblValue("missionRules", params)
  local groupName = missionRules ? missionRules.getRandomUnitsGroupName(unit.name) : null
  if (groupName)
    res = missionRules.getRandomUnitsGroupLocName(groupName)
  if (missionRules && missionRules.isWorldWarUnit(unit.name))
    res = ::loc("icon/worldWar/colored") + res
  if (missionRules && missionRules.needLeftRespawnOnSlots)
  {
    local leftRespawns = missionRules.getUnitLeftRespawns(unit)
    local leftWeaponPresetsText = missionRules.getUnitLeftWeaponShortText(unit)
    local text = leftRespawns != ::RESPAWNS_UNLIMITED
      ? missionRules.isUnitAvailableBySpawnScore(unit)
        ? ::loc("icon/star/white")
        : leftRespawns.tostring()
      : ""

    if (leftWeaponPresetsText.len())
      text += (text.len() ? "/" : "") + leftWeaponPresetsText

    if (text.len())
      res += ::loc("ui/parentheses/space", { text = text })
  }
  return res
}

::is_unit_price_text_long <- @(text) ::utf8_strlen(::g_dagui_utils.removeTextareaTags(text)) > 13

::get_unit_item_price_text <- function get_unit_item_price_text(unit, params)
{
  local isLocalState        = ::getTblValue("isLocalState", params, true)
  local haveRespawnCost     = ::getTblValue("haveRespawnCost", params, false)
  local haveSpawnDelay      = ::getTblValue("haveSpawnDelay", params, false)
  local curSlotIdInCountry  = ::getTblValue("curSlotIdInCountry", params, -1)
  local slotDelayData       = ::getTblValue("slotDelayData", params, null)

  local priceText = ""

  if (curSlotIdInCountry >= 0 && ::is_spare_aircraft_in_slot(curSlotIdInCountry))
    priceText += ::loc("spare/spare/short") + " "

  if ((haveRespawnCost || haveSpawnDelay) && ::getTblValue("unlocked", params, true))
  {
    local spawnDelay = slotDelayData != null
      ? slotDelayData.slotDelay - ((::dagor.getCurTime() - slotDelayData.updateTime)/1000).tointeger()
      : ::get_slot_delay(unit.name)
    if (haveSpawnDelay && spawnDelay > 0)
      priceText += time.secondsToString(spawnDelay)
    else
    {
      local txtList = []
      local wpToRespawn = ::get_unit_wp_to_respawn(unit.name)
      if (wpToRespawn > 0 && ::is_crew_available_in_session(curSlotIdInCountry, false))
      {
        local sessionWpBalance = ::getTblValue("sessionWpBalance", params, 0)
        wpToRespawn += ::getTblValue("weaponPrice", params, 0)
        txtList.append(::colorTextByValues(::Cost(wpToRespawn).toStringWithParams({isWpAlwaysShown = true}),
          sessionWpBalance, wpToRespawn, true, false))
      }

      local reqUnitSpawnScore = ::shop_get_spawn_score(unit.name, getLastWeapon(unit.name))
      local totalSpawnScore = ::getTblValue("totalSpawnScore", params, -1)
      if (reqUnitSpawnScore > 0 && totalSpawnScore > -1)
      {
        local spawnScoreText = reqUnitSpawnScore
        if (reqUnitSpawnScore > totalSpawnScore)
          spawnScoreText = "<color=@badTextColor>" + reqUnitSpawnScore + "</color>"
        txtList.append(::loc("shop/spawnScore", {cost = spawnScoreText}))
      }

      if (txtList.len())
      {
        local spawnCostText = ::g_string.implode(txtList, ", ")
        if (priceText.len())
          spawnCostText = ::loc("ui/parentheses", { text = spawnCostText })
        priceText += spawnCostText
      }
    }
  }

  if (::is_in_flight())
  {
    local maxSpawns = ::get_max_spawns_unit_count(unit.name)
    if (curSlotIdInCountry >= 0 && maxSpawns > 1)
    {
      local leftSpawns = maxSpawns - ::get_num_used_unit_spawns(curSlotIdInCountry)
      priceText += ::format("(%s/%s)", leftSpawns.tostring(), maxSpawns.tostring())
    }
  } else if (isLocalState && priceText == "")
  {
    local gift                = ::isUnitGift(unit)
    local marketable          = ::canBuyUnitOnMarketplace(unit)
    local canBuy              = ::canBuyUnit(unit)
    local isUsable            = ::isUnitUsable(unit)
    local isBought            = ::isUnitBought(unit)
    local special             = ::isUnitSpecial(unit)
    local researched          = ::isUnitResearched(unit)
    local showAsTrophyContent = ::getTblValue("showAsTrophyContent", params, false)
    local isReceivedPrizes    = ::getTblValue("isReceivedPrizes", params, false)
    local overlayPrice        = ::getTblValue("overlayPrice", params, -1)

    if (overlayPrice >= 0)
      priceText = ::getPriceAccordingToPlayersCurrency(overlayPrice, 0, true)
    else if (!isUsable && gift && !marketable)
      priceText = ::g_string.stripTags(::loc("shop/giftAir/" + unit.gift, "shop/giftAir/alpha"))
    else if (!isUsable && !marketable && (canBuy || special || (!special && researched)))
      priceText = ::getPriceAccordingToPlayersCurrency(::wp_get_cost(unit.name), ::wp_get_cost_gold(unit.name), true)
    else if (marketable)
      priceText = ::loc("currency/gc/sign/colored", "")

    if (priceText == "" && isBought && showAsTrophyContent && !isReceivedPrizes)
      priceText = ::colorize("goodTextColor", ::loc("mainmenu/itemReceived"))
  }

  return priceText
}

::get_unit_item_research_progress_text <- function get_unit_item_research_progress_text(unit, params, priceText = "")
{
  if (!::u.isEmpty(priceText))
    return ""
  if (!::canResearchUnit(unit))
    return ""

  local unitExpReq  = ::getUnitReqExp(unit)
  local unitExpCur  = ::getUnitExp(unit)
  if (unitExpReq <= 0 || unitExpReq <= unitExpCur)
    return ""

  local isSquadronVehicle = unit?.isSquadronVehicle?() ?? false
  if (isSquadronVehicle && !::is_in_clan()
    && min(::clan_get_exp(), unitExpReq - unitExpCur) <= 0)
    return ""

  return isSquadronVehicle
    ? ::Cost().setSap(unitExpReq - unitExpCur).tostring()
    : ::Cost().setRp(unitExpReq - unitExpCur).tostring()
}

::get_unit_item_progress_status <- function get_unit_item_progress_status(unit, params)
{
  local isSquadronVehicle   = unit?.isSquadronVehicle?()
  local unitExpReq          = ::getUnitReqExp(unit)
  local unitExpGranted      = ::getUnitExp(unit)
  local diffSquadronExp     = isSquadronVehicle
     ? ::min(::clan_get_exp(), unitExpReq - unitExpGranted)
     : 0
  local flushExp = ::getTblValue("flushExp", params, 0)
  local isFull = (flushExp > 0 && flushExp >= unitExpReq)
    || (diffSquadronExp > 0 && diffSquadronExp >= unitExpReq)

  local forceNotInResearch  = ::getTblValue("forceNotInResearch", params, false)
  local isVehicleInResearch = !forceNotInResearch && ::isUnitInResearch(unit)
    && (!isSquadronVehicle || ::is_in_clan() || diffSquadronExp > 0)

  return isFull ? "researched"
         : isVehicleInResearch ? "research"
           : ""
}

::get_unit_rank_text <- function get_unit_rank_text(unit, crew = null, showBR = false, ediff = -1)
{
  local isInFlight = ::is_in_flight()
  if (isInFlight && ::g_mis_custom_state.getCurMissionRules().isWorldWar)
    return ""

  if (::isUnitGroup(unit))
  {
    local isReserve = false
    local rank = 0
    local minBR = 0
    local maxBR = 0
    foreach(u in unit.airsGroup)
    {
      isReserve = isReserve || ::isUnitDefault(u)
      rank = rank || u.rank
      local br = u.getBattleRating(ediff)
      minBR = !minBR ? br : ::min(minBR, br)
      maxBR = !maxBR ? br : ::max(maxBR, br)
    }
    return isReserve ? ::g_string.stripTags(::loc("shop/reserve")) :
      showBR  ? (minBR != maxBR ? ::format("%.1f-%.1f", minBR, maxBR) : ::format("%.1f", minBR)) :
      ::get_roman_numeral(rank)
  }

  if (unit?.isFakeUnit)
    return unit?.isReqForFakeUnit || unit?.rank == null
      ? ""
      : ::format(::loc("events/rank"), ::get_roman_numeral(unit.rank))

  local isReserve = ::isUnitDefault(unit)
  local isSpare = crew && isInFlight ? ::is_spare_aircraft_in_slot(crew.idInCountry) : false
  return isReserve ?
           isSpare ?
             ""
             : ::g_string.stripTags(::loc("shop/reserve"))
         : showBR ?
             ::format("%.1f", unit.getBattleRating(ediff))
             : ::get_roman_numeral(unit.rank)
}

::is_crew_locked_by_prev_battle <- function is_crew_locked_by_prev_battle(crew)
{
  return ::isInMenu() && ::getTblValue("lockedTillSec", crew, 0) > 0
}

::isUnitUnlocked <- function isUnitUnlocked(handler, unit, curSlotCountryId, curSlotIdInCountry, country = null, needDbg = false)
{
  local crew = ::g_crews_list.get()[curSlotCountryId].crews[curSlotIdInCountry]
  local unlocked = !::is_crew_locked_by_prev_battle(crew)
  if (unit)
  {
    unlocked = unlocked && (!country || ::is_crew_available_in_session(curSlotIdInCountry, needDbg))
    unlocked = unlocked && (::isUnitAvailableForGM(unit, ::get_game_mode()) || ::is_in_flight())
      && (!unit.disableFlyout || !::is_in_flight())
    if (unlocked && !::SessionLobby.canChangeCrewUnits() && !::is_in_flight()
        && ::SessionLobby.getMaxRespawns() == 1)
      unlocked = ::SessionLobby.getMyCurUnit() == unit
  }

  return unlocked
}

::isCountryAllCrewsUnlockedInHangar <- function isCountryAllCrewsUnlockedInHangar(countryId)
{
  foreach (tbl in ::g_crews_list.get())
    if (tbl.country == countryId)
      foreach (crew in tbl.crews)
        if (::is_crew_locked_by_prev_battle(crew))
          return false
  return true
}

::getBrokenSlotsCount <- function getBrokenSlotsCount(country)
{
  local count = 0
  foreach(c in ::g_crews_list.get())
    if (!country || country == c.country)
      foreach(crew in c.crews)
        if (("aircraft" in crew) && crew.aircraft!="")
        {
          local hp = shop_get_aircraft_hp(crew.aircraft)
          if (hp >= 0 && hp < 1)
            count++
        }
  return count
}


::getSlotItem <- function getSlotItem(countryId, idInCountry)
{
  return ::g_crews_list.get()?[countryId]?.crews?[idInCountry]
}

::getSlotAircraft <- function getSlotAircraft(countryId, idInCountry)
{
  local crew = getSlotItem(countryId, idInCountry)
  local airName = ("aircraft" in crew)? crew.aircraft : ""
  local air = getAircraftByName(airName)
  return air
}

::get_crew_by_id <- function get_crew_by_id(id)
{
  foreach(cId, cList in ::g_crews_list.get())
    if ("crews" in cList)
      foreach(idx, crew in cList.crews)
       if (crew.id==id)
         return crew
  return null
}

::getCrewByAir <- function getCrewByAir(air)
{
  foreach(country in ::g_crews_list.get())
    if (country.country == air.shopCountry)
      foreach(crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft==air.name)
          return crew
  return null
}

::isUnitInSlotbar <- function isUnitInSlotbar(air)
{
  return ::getCrewByAir(air) != null
}

::getSlotbarUnitTypes <- function getSlotbarUnitTypes(country)
{
  local res = []
  foreach(countryData in ::g_crews_list.get())
    if (countryData.country == country)
      foreach(crew in countryData.crews)
        if (("aircraft" in crew) && crew.aircraft != "")
        {
          local unit = ::getAircraftByName(crew.aircraft)
          if (unit)
            ::u.appendOnce(::get_es_unit_type(unit), res)
        }
  return res
}

::get_crews_list_by_country <- function get_crews_list_by_country(country)
{
  foreach(countryData in ::g_crews_list.get())
    if (countryData.country == country)
      return countryData.crews
  return []
}

::getAvailableCrewId <- function getAvailableCrewId(countryId)
{
  local id=-1
  local curAircraft = ::get_show_aircraft_name()
  if ((countryId in ::g_crews_list.get()) && ("crews" in ::g_crews_list.get()[countryId]))
    for(local i=0; i<::g_crews_list.get()[countryId].crews.len(); i++)
    {
      local crew = ::g_crews_list.get()[countryId].crews[i]
      if (("aircraft" in crew) && crew.aircraft!="")
      {
        if (id<0) id=i
        if (crew.aircraft==curAircraft)
        {
          id=i
          break
        }
      }
    }
  return id
}

::selectAvailableCrew <- function selectAvailableCrew(countryId)
{
  local isAnyUnitInSlotbar = false
  if ((countryId in ::g_crews_list.get()) && (countryId in ::selected_crews))
  {
    local id = getAvailableCrewId(countryId)
    isAnyUnitInSlotbar = id >= 0

    if (!isAnyUnitInSlotbar)
      id = 0

    ::selected_crews[countryId] = id
  }
  return isAnyUnitInSlotbar
}

::save_selected_crews <- function save_selected_crews()
{
  if (!::g_login.isLoggedIn())
    return

  local blk = ::DataBlock()
  foreach(cIdx, country in ::g_crews_list.get())
    blk[country.country] = ::getTblValue(cIdx, ::selected_crews, 0)
  ::saveLocalByAccount("selected_crews", blk)
}

::init_selected_crews <- function init_selected_crews(forceReload = false)
{
  if (!forceReload && (!::g_crews_list.get().len() || ::selected_crews.len() == ::g_crews_list.get().len()))
    return

  local selCrewsBlk = ::loadLocalByAccount("selected_crews", null)
  local needSave = false

  ::selected_crews = array(::g_crews_list.get().len(), 0)
  foreach(cIdx, country in ::g_crews_list.get())
  {
    local crewIdx = selCrewsBlk?[country.country] ?? 0
    if (("crews" in country)
        && (crewIdx in country.crews)
        && ("aircraft" in country.crews[crewIdx])
        && country.crews[crewIdx].aircraft != "")
          ::selected_crews[cIdx] = crewIdx
    else
    {
      if (!selectAvailableCrew(cIdx))
      {
        local requestData = [{
          crewId = country.crews[0].id
          airName = ::getReserveAircraftName({country = country.country})
        }]
        ::batch_train_crew(requestData)
      }
      needSave = true
    }
  }
  if (needSave)
    ::save_selected_crews()
  ::broadcastEvent("CrewChanged")
}

::select_crew_silent_no_check <- function select_crew_silent_no_check(countryId, idInCountry)
{
  if (::selected_crews[countryId] != idInCountry)
  {
    ::selected_crews[countryId] = idInCountry
    ::save_selected_crews()
  }
}

::select_crew <- function select_crew(countryId, idInCountry, airChanged = false)
{
  init_selected_crews()
  local air = getSlotAircraft(countryId, idInCountry)
  if (!air || (::selected_crews[countryId] == idInCountry && !airChanged))
    return

  ::select_crew_silent_no_check(countryId, idInCountry)
  ::broadcastEvent("CrewChanged")
  ::g_squad_utils.updateMyCountryData(!::is_in_flight())
}

::getSelAircraftByCountry <- function getSelAircraftByCountry(country)
{
  init_selected_crews()
  foreach(cIdx, c in ::g_crews_list.get())
    if (c.country == country)
      return getSlotAircraft(cIdx, ::selected_crews[cIdx])
  return null
}

::get_cur_slotbar_unit <- function get_cur_slotbar_unit()
{
  return getSelAircraftByCountry(::get_profile_country_sq())
}

::is_unit_enabled_for_slotbar <- function is_unit_enabled_for_slotbar(unit, params)
{
  if (!unit || unit.disableFlyout)
    return false

  local res = true
  if (params?.eventId)
  {
    res = false
    local event = ::events.getEvent(params.eventId)
    if (event)
      res = ::events.isUnitAllowedForEventRoom(event, ::getTblValue("room", params), unit)
  }
  else if (params?.availableUnits)
    res = unit.name in params.availableUnits
  else if (::SessionLobby.isInRoom() && !::is_in_flight())
    res = ::SessionLobby.isUnitAllowed(unit)
  else if (params?.roomCreationContext)
    res = params.roomCreationContext.isUnitAllowed(unit)

  if (res && params?.mainMenuSlotbar)
    res = ::game_mode_manager.isUnitAllowedForGameMode(unit)

  local missionRules = params?.missionRules
  if (res && missionRules)
  {
    local isAvaliableUnit = (missionRules.getUnitLeftRespawns(unit) != 0
      || missionRules.isUnitAvailableBySpawnScore(unit))
      && missionRules.isUnitEnabledByRandomGroups(unit.name)
    local isControlledUnit = !::is_respawn_screen()
      && ::is_player_unit_alive()
      && ::get_player_unit_name() == unit.name

    res = isAvaliableUnit || isControlledUnit
  }

  return res
}

::isUnitInCustomList <- function isUnitInCustomList(unit, params)
{
  if (!unit)
    return false

  return params?.customUnitsList ? unit.name in params.customUnitsList : true
}

::getSelSlotsTable <- function getSelSlotsTable()
{
  init_selected_crews()
  local slots = {}
  foreach(cIdx, country in ::g_crews_list.get())
  {
    local air = getSlotAircraft(cIdx, ::selected_crews[cIdx])
    if (!air)
    {
      dagor.debug("selected crews = ")
      debugTableData(::selected_crews)
      dagor.debug("crews list = ")
      debugTableData(::g_crews_list.get())
//      dagor.assertf(false, "Incorrect selected_crews list on getSelSlotsTable")
      selectAvailableCrew(cIdx)
    }
    slots[country.country] <- ::selected_crews[cIdx]
  }
  return slots
}

::getSelAirsTable <- function getSelAirsTable()
{
  init_selected_crews()
  local airs = {}
  foreach(cIdx, country in ::g_crews_list.get())
  {
    local air = getSlotAircraft(cIdx, ::selected_crews[cIdx])
    airs[country.country] <- air? air.name : ""
  }
  return airs
}

::initSlotbarTopBar <- function initSlotbarTopBar(slotbarObj, show)
{
  if (!::checkObj(slotbarObj))
    return

  local containerObj = slotbarObj.findObject("slotbar_buttons_place")
  local mainObj = slotbarObj.findObject("autorefill-settings")
  if (!::check_obj(containerObj) || !::check_obj(mainObj))
    return

  containerObj.show(show)
  mainObj.show(show)
  if (!show)
    return

  local obj = mainObj.findObject("slots-autorepair")
  if (::checkObj(obj))
    obj.setValue(::get_auto_refill(0))

  obj = mainObj.findObject("slots-autoweapon")
  if (::checkObj(obj))
    obj.setValue(::get_auto_refill(1))
}

::set_autorefill_by_obj <- function set_autorefill_by_obj(obj)
{
  if (::slotbar_oninit || !obj) return
  local mode = -1
  if (obj.id == "slots-autorepair") mode = 0
  else if (obj.id == "slots-autoweapon") mode = 1

  if (mode>=0)
  {
    local value = obj.getValue()
    set_auto_refill(mode, value)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)

    ::slotbar_oninit = true
    ::broadcastEvent("AutorefillChanged", { id = obj.id, value = value })
    ::slotbar_oninit = false
  }
}

::isCountryAvailable <- function isCountryAvailable(country)
{
  if (country=="country_0" || country=="")
    return true

  return ::isInArray(country, ::unlocked_countries) || ::is_country_available(country)
}

::is_country_visible <- function is_country_visible(country)
{
  if (country == "country_china")
    return ::has_feature("CountryChina")
  return true
}

::unlockCountry <- function unlockCountry(country, hideInUserlog = false, reqUnlock = true)
{
  if (reqUnlock)
    ::req_unlock_by_client(country, hideInUserlog)

  if (!::isInArray(country, ::unlocked_countries))
    ::unlocked_countries.append(country)
}

::checkUnlockedCountries <- function checkUnlockedCountries()
{
  local curUnlocked = []
  if (::is_need_first_country_choice())
    return curUnlocked

  local unlockAll = ::isDiffUnlocked(1, ::ES_UNIT_TYPE_AIRCRAFT) || ::disable_network() || ::has_feature("UnlockAllCountries")
  local wasInList = ::unlocked_countries.len()
  foreach(i, country in ::shopCountriesList)
    if (::is_country_available(country))
    {
      if (!::isInArray(country, ::unlocked_countries))
      {
        ::unlocked_countries.append(country)
        curUnlocked.append(country)
      }
    }
    else if (unlockAll)
    {
      unlockCountry(country, !::g_login.isLoggedIn())
      curUnlocked.append(country)
    }
  if (wasInList != ::unlocked_countries.len())
    ::broadcastEvent("UnlockedCountriesUpdate")
  return curUnlocked
}

::checkUnlockedCountriesByAirs <- function checkUnlockedCountriesByAirs() //starter packs
{
  local haveUnlocked = false
  foreach(air in ::all_units)
    if (!::isUnitDefault(air)
        && ::isUnitUsable(air)
        && !::isCountryAvailable(air.shopCountry))
    {
      unlockCountry(air.shopCountry)
      haveUnlocked = true
    }
  if (haveUnlocked)
    ::broadcastEvent("UnlockedCountriesUpdate")
  return haveUnlocked
}

::gotTanksInSlots <- function gotTanksInSlots(checkCountryId=null, checkUnitId=null)
{
  foreach(country in ::g_crews_list.get())
    if (::isCountryAvailable(country.country) && (!checkCountryId || checkCountryId == country.country))
      foreach(crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft != "" && (!checkUnitId || checkUnitId == crew.aircraft) && ::isTank(::getAircraftByName(crew.aircraft)))
          return true
  return false
}

::tanksDriveGamemodeRestrictionMsgBox <- function tanksDriveGamemodeRestrictionMsgBox(featureName, curCountry=null, curUnit=null, msg=null)
{
  if (::has_feature(featureName) || !::gotTanksInSlots(curCountry, curUnit))
    return false

  msg = msg || "cbt_tanks/forbidden/tank_access"
  msg = ::loc(msg) + "\n" + ::loc("cbt_tanks/supported_game_modes") + "\n" + ::loc("cbt_tanks/temporary_restriction_release")
  ::showInfoMsgBox(msg, "cbt_tanks_forbidden")
  return true
}
