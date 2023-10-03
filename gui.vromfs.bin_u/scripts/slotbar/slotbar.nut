//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { round } = require("math")
let { format, split_by_chars } = require("string")
let { get_game_mode } = require("mission")
let { get_max_spawns_unit_count, get_unit_wp_to_respawn } = require("guiMission")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let unitStatus = require("%scripts/unit/unitStatus.nut")
let { getUnitRole, getUnitRoleIcon, getUnitItemStatusText, getUnitRarity
} = require("%scripts/unit/unitInfoTexts.nut")
let { getLastWeapon, checkUnitWeapons, getWeaponsStatusName
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getUnitLastBullets } = require("%scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getUnitShopPriceText } = require("%scripts/shop/unitCardPkg.nut")
let { batchTrainCrew } = require("%scripts/crew/crewActions.nut")
let { isDiffUnlocked } = require("%scripts/tutorials/tutorialsData.nut")
let { RANDOM_UNIT } = require("%scripts/utils/genericTooltipTypes.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isNeedFirstCountryChoice } = require("%scripts/firstChoice/firstChoice.nut")
let { selectAvailableCrew } = require("%scripts/slotbar/slotbarState.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getReserveAircraftName } = require("%scripts/tutorials.nut")
let { stripTags } = require("%sqstd/string.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")
let { removeTextareaTags } = require("%sqDagui/daguiUtil.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let {
  getEsUnitType, isUnitsEraUnlocked, getUnitName, isUnitDefault, isUnitGift,
  isUnitGroup, canResearchUnit
} = require("%scripts/unit/unitInfo.nut")

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

//=============================  global functions  =============================

::selected_crews <- []
::unlocked_countries <- []

registerPersistentData("SlotbarGlobals", getroottable(), ["selected_crews", "unlocked_countries"])

::build_aircraft_item <- function build_aircraft_item(id, air, params = {}) {
  local res = ""
  let defaultStatus = "none"

  let showBR = getTblValue("showBR", params, hasFeature("GlobalShowBattleRating"))
  let curEdiff = ("getEdiffFunc" in params) ?  params.getEdiffFunc() : ::get_current_ediff()

  if (air && !isUnitGroup(air) && !air?.isFakeUnit) {
    let isLocalState        = params?.isLocalState ?? true
    let forceNotInResearch  = params?.forceNotInResearch ?? false
    local inactive            = params?.inactive ?? false
    let shopResearchMode    = params?.shopResearchMode ?? false
    let hasActions          = params?.hasActions ?? false

    let isOwn               = ::isUnitBought(air)
    let isUsable            = ::isUnitUsable(air)
    let isMounted           = ::isUnitInSlotbar(air)
    let canResearch         = canResearchUnit(air)
    let special             = ::isUnitSpecial(air)
    let isVehicleInResearch = ::isUnitInResearch(air) && !forceNotInResearch
    let isSquadronVehicle   = air.isSquadronVehicle()
    let isMarketableVehicle = ::canBuyUnitOnMarketplace(air)
    let unitReqExp          = ::getUnitReqExp(air)
    local unitExpGranted      = ::getUnitExp(air)
    let diffExp = isSquadronVehicle
      ? min(::clan_get_exp(), unitReqExp - unitExpGranted)
      : (params?.diffExp ?? 0)
    if (isSquadronVehicle && isVehicleInResearch)
      unitExpGranted += diffExp

    let isBroken            = ::isUnitBroken(air)
    let unitRarity          = getUnitRarity(air)
    let isLockedSquadronVehicle = isSquadronVehicle && !::is_in_clan() && diffExp <= 0

    local status = params?.status ?? defaultStatus
    if (status == defaultStatus) {
      let bitStatus = unitStatus.getBitStatus(air, params)
      if (bit_unit_status.locked & bitStatus)
        inactive = shopResearchMode
      else if (bit_unit_status.disabled & bitStatus)
        inactive = true

      status = getUnitItemStatusText(bitStatus, false)
    }

    //
    // Bottom button view
    //

    let mainButtonAction = showConsoleButtons.value ? "onOpenActionsList" : (params?.mainActionFunc ?? "")
    let mainButtonText = showConsoleButtons.value ? "" : (params?.mainActionText ?? "")
    let mainButtonIcon = showConsoleButtons.value ? "#ui/gameuiskin#slot_menu.svg" : (params?.mainActionIcon ?? "")
    let checkTexts = mainButtonAction.len() > 0 && (mainButtonText.len() > 0 || mainButtonIcon.len() > 0)
    let checkButton = !isVehicleInResearch || hasFeature("SpendGold")
    let bottomButtonView = {
      holderId            = id
      hasButton           = hasActions && checkTexts && checkButton
      mainButtonText      = mainButtonText
      mainButtonAction    = mainButtonAction
      hasMainButtonIcon   = mainButtonIcon.len()
      mainButtonIcon      = mainButtonIcon
    }

    //
    // Item buttons view
    //

    let crewId = params?.crewId ?? -1
    let showWarningIcon = params?.showWarningIcon ?? false
    let specType = params?.specType
    let rentInfo = ::get_unit_item_rent_info(air, params)
    let spareCount = isLocalState ? ::get_spare_aircrafts_count(air.name) : 0

    let hasCrewInfo = crewId >= 0
    let crew = hasCrewInfo ? ::get_crew_by_id(crewId) : null

    let forceCrewInfoUnit = params?.forceCrewInfoUnit
    let unitForCrewInfo = forceCrewInfoUnit || air
    let crewLevelText = crew && unitForCrewInfo
      ? ::g_crew.getCrewLevel(crew, unitForCrewInfo, unitForCrewInfo.getCrewUnitType()).tointeger().tostring()
      : ""
    let crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unitForCrewInfo).trainedIcon

    let itemButtonsView = {
      itemButtons = {
        hasToBattleButton       = params?.toBattle ?? false
        toBattleButtonAction    = params?.toBattleButtonAction ?? "onSlotBattle"

        specIconBlock           = showWarningIcon || specType != null
        showWarningIcon         = showWarningIcon
        hasRepairIcon           = isLocalState && isBroken
        weaponsStatus           = getWeaponsStatusName(isLocalState && isUsable ? checkUnitWeapons(air) : UNIT_WEAPONS_READY)
        hasRentIcon             = rentInfo.hasIcon
        hasRentProgress         = rentInfo.hasProgress
        rentProgress            = rentInfo.progress
      }
    }

    let extraInfoView = {
      hasExtraInfoBlock         = params?.hasExtraInfoBlock ?? false
      hasCrewInfo               = hasCrewInfo
      crewLevel                 = hasCrewInfo ? crewLevelText : ""
      crewSpecIcon              = hasCrewInfo ? crewSpecIcon : ""
      crewStatus                = hasCrewInfo ? ::get_crew_status(crew, unitForCrewInfo) : ""
      hasSpareCount             = spareCount > 0
      spareCount                = spareCount ? spareCount + loc("icon/spare") : ""
    }

    if (specType) {
      itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
      itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
    }

    //
    // Air research progress view
    //

    let showProgress = isLocalState && !isOwn && canResearch && !::is_in_flight()
      && (!isLockedSquadronVehicle || unitExpGranted > 0)
    let airResearchProgressView = {
      airResearchProgress = []
    }
    if (showProgress) {
      airResearchProgressView.airResearchProgress.append({
        airResearchProgressValue            = unitReqExp > 0 ? (unitExpGranted.tofloat() / unitReqExp * 1000).tointeger() : 0
        airResearchProgressType             = "new"
        airResearchProgressIsPaused         = !isVehicleInResearch || forceNotInResearch || isLockedSquadronVehicle
        airResearchProgressAbsolutePosition = false
        airResearchProgressHasPaused        = true
        airResearchProgressHasDisplay       = false
      })
      if (unitExpGranted > diffExp) {
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

    let priceText = ::get_unit_item_price_text(air, params)
    let progressText = showProgress ? ::get_unit_item_research_progress_text(air, params, priceText) : ""
    let checkNotification = ::g_discount.getEntitlementUnitDiscount(air.name)

    let resView = params.__merge({
      slotId              = "td_" + id
      bonusId             = id
      slotInactive        = inactive
      isSlotbarItem       = params?.isSlotbarItem ?? false
      isInTable           = params?.isInTable ?? true
      shopItemId          = id
      unitName            = air.name
      crewId              = crew?.id.tostring()
      shopItemType        = getUnitRole(air)
      unitClassIcon       = getUnitRoleIcon(air)
      shopStatus          = status
      unitRarity          = unitRarity
      isBroken            = isLocalState && isBroken
      shopAirImg          = ::image_for_air(air)
      isPkgDev            = air.isPkgDev
      isRecentlyReleased  = air.isRecentlyReleased()
      discountId          = id + "-discount"
      showDiscount        = isLocalState && !isOwn && (!isUnitGift(air) || checkNotification)
      shopItemTextId      = id + "_txt"
      shopItemText        = ::get_slot_unit_name_text(air, params)
      progressText        = progressText
      progressStatus      = showProgress ? ::get_unit_item_progress_status(air, params) : ""
      progressBlk         = handyman.renderCached("%gui/slotbar/airResearchProgress.tpl", airResearchProgressView)
      showInService       = (params?.showInService ?? false) && isUsable
      isMounted           = isMounted
      priceText           = priceText
      isLongPriceText     = ::is_unit_price_text_long(priceText)
      isElite             = (isLocalState && isOwn && ::isUnitElite(air)) || (!isOwn && special)
      unitRankText        = ::get_unit_rank_text(air, crew, showBR, curEdiff)
      bottomLineText      = params?.bottomLineText
      isItemLocked        = isLocalState && !isUsable && !special && !isSquadronVehicle && !isMarketableVehicle && !isUnitsEraUnlocked(air)
      hasTalismanIcon     = isLocalState && (special || shopIsModificationEnabled(air.name, "premExpMul"))
      itemButtons         = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", itemButtonsView)
      tooltipId           = ::g_tooltip.getIdUnit(air.name, params?.tooltipParams)
      isTooltipByHold     = showConsoleButtons.value
      bottomButton        = handyman.renderCached("%gui/slotbar/slotbarItemBottomButton.tpl", bottomButtonView)
      extraInfoBlock      = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", extraInfoView)
      refuseOpenHoverMenu = !hasActions
    })
    let missionRules = params?.missionRules
    let groupName = missionRules ? missionRules.getRandomUnitsGroupName(air.name) : null
    let isShowAsRandomUnit = groupName
      && (::is_respawn_screen()
        || !::is_player_unit_alive()
        || ::get_player_unit_name() != air.name)
    if (isShowAsRandomUnit) {
      resView.shopAirImg = missionRules.getRandomUnitsGroupIcon(groupName)
      resView.shopItemType = ""
      resView.unitClassIcon = ""
      resView.isElite = false
      resView.unitRarity = ""
      resView.unitRankText = ""
      resView.tooltipId = RANDOM_UNIT.getTooltipId(air.name, { groupName = groupName })
    }

    res = handyman.renderCached("%gui/slotbar/slotbarSlotSingle.tpl", resView)
  }
  else if (air && isUnitGroup(air)) { //group of aircrafts
    let groupStatus         = params?.status ?? defaultStatus
    let forceNotInResearch  = params?.forceNotInResearch ?? false
    let shopResearchMode    = params?.shopResearchMode ?? false
    let showInService       = params?.showInService ?? false
    local inactive            = params?.inactive ?? false

    local special           = false

    local nextAir = air.airsGroup[0]
    let country = nextAir.shopCountry
    let esUnitType = getEsUnitType(nextAir)
    local forceUnitNameOnPlate = false

    let era = nextAir?.rank ?? -1

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

    let isSquadronResearchMode = params?.isSquadronResearchMode ?? false

    foreach (a in air.airsGroup) {
      let isInResearch = !forceNotInResearch && ::isUnitInResearch(a)
      let isUsable = ::isUnitUsable(a)

      if (isInResearch || (canResearchUnit(a) && !researchingUnit)) {
        researchingUnit = a
        isGroupInResearch = isInResearch
      }
      else if (isUsable)
        lastBoughtUnit = a
      else if (!firstUnboughtUnit && (::canBuyUnit(a) || ::canBuyUnitOnline(a)))
        firstUnboughtUnit = a

      if (showInService && isUsable) {
        if (::isUnitInSlotbar(a))
          mountedUnit = a
        isGroupUsable = true
      }

      if (a.isRented()) {
        if (!rentedUnit || a.getRentTimeleft() <= rentedUnit.getRentTimeleft())
          rentedUnit = a
      }

      if (unitRole == null || isInResearch)
        unitRole = getUnitRole(nextAir)

      special = ::isUnitSpecial(a)
      isElite = isElite && ::isUnitElite(a)
      isPkgDev = isPkgDev || a.isPkgDev
      isRecentlyReleased = isRecentlyReleased || a.isRecentlyReleased()

      let hasTalisman = special || shopIsModificationEnabled(a.name, "premExpMul")
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
        || isSquadronResearchMode) {
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
    let unitForBR = rentedUnit || researchingUnit || firstUnboughtUnit || air

    //
    // Bottom button view
    //

    let bottomButtonView = {
      holderId            = id
      hasButton           = showConsoleButtons.value
      mainButtonAction    = "onAircraftClick"
      mainButtonText      = ""
      mainButtonIcon      = "#ui/gameuiskin#slot_unfold.svg"
      hasMainButtonIcon   = true
    }

    //
    // Item buttons view
    //

    let rentInfo = ::get_unit_item_rent_info(rentedUnit, params)

    let itemButtonsView = {
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
    if (researchingUnit) {
      showProgress = true
      let unitExpGranted = ::getUnitExp(researchingUnit)
      let unitReqExp = ::getUnitReqExp(researchingUnit)
      unitExpProgressValue = unitReqExp > 0 ? unitExpGranted.tofloat() / unitReqExp.tofloat() * 1000 : 0
    }

    let airResearchProgressView = {
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

    let shopAirImage = ::get_unit_preset_img(air.name)
      ?? (::is_harmonized_unit_image_reqired(nextAir)
          ? ::get_tomoe_unit_icon(air.name, !air.name.endswith("_group"))
          : "!{0}".subst(air?.image ?? "#ui/unitskin#planes_group.ddsx"))

    let groupSlotView = params.__merge({
      slotId              = id
      unitRole            = unitRole
      unitClassIcon       = getUnitRoleIcon(nextAir)
      groupStatus         = groupStatus == defaultStatus ? getUnitItemStatusText(bitStatus, true) : groupStatus
      unitRarity          = getUnitRarity(nextAir)
      isBroken            = bitStatus & bit_unit_status.broken
      shopAirImg          = shopAirImage
      isPkgDev            = isPkgDev
      isRecentlyReleased  = isRecentlyReleased
      discountId          = id + "-discount"
      shopItemTextId      = id + "_txt"
      shopItemText        = forceUnitNameOnPlate ? "#" + nextAir.name + "_shop" : "#shop/group/" + air.name
      progressText        = showProgress ? ::get_unit_item_research_progress_text(researchingUnit, params) : ""
      progressStatus      = showProgress ? ::get_unit_item_progress_status(researchingUnit, params) : ""
      progressBlk         = handyman.renderCached("%gui/slotbar/airResearchProgress.tpl", airResearchProgressView)
      showInService       = isGroupUsable
      priceText           = !showProgress && firstUnboughtUnit ? ::get_unit_item_price_text(firstUnboughtUnit, params) : ""
      isMounted           = mountedUnit != null
      isElite             = isElite
      unitRankText        = ::get_unit_rank_text(unitForBR, null, showBR, curEdiff)
      isItemLocked        = !::is_era_available(country, era, esUnitType)
      hasTalismanIcon     = hasTalismanIcon
      talismanIncomplete  = talismanIncomplete
      itemButtons         = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", itemButtonsView)
      bonusId             = id
      primaryUnitId       = nextAir.name
      tooltipId           = ::g_tooltip.getIdUnit(nextAir.name, params?.tooltipParams)
      isTooltipByHold     = showConsoleButtons.value
      bottomButton        = handyman.renderCached("%gui/slotbar/slotbarItemBottomButton.tpl", bottomButtonView)
      hasFullGroupBlock   = params?.fullGroupBlock ?? true
      fullGroupBlockId    = "td_" + id
      isGroupInactive     = inactive
    })
    res = handyman.renderCached("%gui/slotbar/slotbarSlotGroup.tpl", groupSlotView)
  }
  else if (air?.isFakeUnit) {  //fake unit slot
    let isReqForFakeUnit  = air?.isReqForFakeUnit ?? false
    let isLocalState      = params?.isLocalState ?? true
    let isFakeAirRankOpen = isLocalState && ::get_units_count_at_rank(air?.rank,
      unitTypes.getByName(air.name, false).esUnitType, air?.country, true)
    let bitStatus = isReqForFakeUnit ? bit_unit_status.disabled
      : (isFakeAirRankOpen || !isLocalState ? bit_unit_status.owned
        : bit_unit_status.locked)
    let nameForLoc = isReqForFakeUnit ? split_by_chars(air.name, "_")?[0] : air.name
    let fakeSlotView = params.__merge({
      slotId              = "td_" + id
      slotInactive        = true
      isSlotbarItem       = false
      shopItemId          = id
      unitName            = air.name
      shopAirImg          = air.image
      shopStatus          = params?.status ?? getUnitItemStatusText(bitStatus, true)
      unitRankText        = ::get_unit_rank_text(air, null, showBR, curEdiff)
      shopItemTextId      = id + "_txt"
      shopItemText        = loc(air?.nameLoc ?? $"mainmenu/type_{nameForLoc}")
      isItemDisabled      = bitStatus == bit_unit_status.disabled
      needMultiLineName   = params?.needMultiLineName
      tooltipId           = params?.tooltipId ?? ""
      isTooltipByHold     = showConsoleButtons.value
      bottomLineText      = params?.bottomLineText
      isElite             = params?.isElite
      hasTalismanIcon     = params?.hasTalismanIcon
      unitRarity          = params?.unitRarity
    })
    res = handyman.renderCached("%gui/slotbar/slotbarSlotFake.tpl", fakeSlotView)
  }
  else { //empty air slot
    let specType = params?.specType
    let itemButtonsView = { itemButtons = {
      specIconBlock = specType != null
    } }

    if (specType) {
      itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
      itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
    }

    local crewLevelInfoData = ""
    let unitForCrewInfo = params?.forceCrewInfoUnit
    if (unitForCrewInfo) {
      let crewId = params?.crewId ?? -1
      let crew = crewId >= 0 ? ::get_crew_by_id(crewId) : null
      if (crew) {
        let crewLevelText = ::g_crew.getCrewLevel(crew, unitForCrewInfo,
          unitForCrewInfo.getCrewUnitType()).tointeger().tostring()
        let crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unitForCrewInfo).trainedIcon

        let crewLevelInfoView = {
          hasExtraInfoBlock = true
          hasCrewInfo       = true
          crewLevel         = crewLevelText
          crewSpecIcon      = crewSpecIcon
        }
        crewLevelInfoData = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", crewLevelInfoView)
      }
    }

    let emptyCost = params?.emptyCost
    let priceText = emptyCost ? emptyCost.getTextAccordingToBalance() : ""
    let emptySlotView = params.__merge({
      slotId = "td_" + id,
      shopItemId = id,
      shopItemTextId = id + "_txt",
      shopItemTextValue = params?.emptyText ?? ""
      shopStatus = params?.status
      shopItemPriceText = priceText,
      crewImage = params?.crewImage
      isCrewRecruit = params?.isCrewRecruit ?? false
      itemButtons = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", itemButtonsView)
      isSlotbarItem = params?.isSlotbarItem ?? false
      extraInfoBlock = crewLevelInfoData
    })
    res = handyman.renderCached("%gui/slotbar/slotbarSlotEmpty.tpl", emptySlotView)
  }

  if (params?.fullBlock ?? true)
    res = format("unitCell{%s}", res)

  return res
}

::fill_unit_item_timers <- function fill_unit_item_timers(holderObj, unit, _params = {}) {
  if (!checkObj(holderObj) || !unit)
    return

  local rentedUnit = null
  if (isUnitGroup(unit)) {
    rentedUnit = unit.airsGroup[0]
    foreach (un in unit.airsGroup) {
      if (un.isRented())
        if (!rentedUnit || unit.getRentTimeleft() <= rentedUnit.getRentTimeleft())
          rentedUnit = un
    }
  }
  else
    rentedUnit = unit

  if (!rentedUnit || !rentedUnit.isRented())
    return

  SecondsUpdater(holderObj, function(obj, params) {
    local isActive = false

    // Unit rent time
    let isRented = rentedUnit.isRented()
    if (isRented) {
      let objRentProgress = obj.findObject("rent_progress")
      if (checkObj(objRentProgress)) {
        let totalRentTimeSec = ::rented_units_get_last_max_full_rent_time(rentedUnit.name) || -1
        let progress = 360 - round(360.0 * rentedUnit.getRentTimeleft() / totalRentTimeSec).tointeger()
        if (objRentProgress["sector-angle-1"] != progress)
          objRentProgress["sector-angle-1"] = progress

        isActive = true
      }
    }
    else { // at rent time over
      let rentInfo = ::get_unit_item_rent_info(rentedUnit, params)

      let objRentIcon = obj.findObject("rent_icon")
      if (checkObj(objRentIcon))
        objRentIcon.show(rentInfo.hasIcon)
      let objRentProgress = obj.findObject("rent_progress")
      if (checkObj(objRentProgress))
        objRentProgress.show(rentInfo.hasProgress)
    }

    return !isActive
  })
}

::get_slot_obj_id <- function get_slot_obj_id(countryId, idInCountry, isBonus = false) {
  assert(countryId != null, "Country ID is null.")
  assert(idInCountry != null, "Crew IDX is null.")
  local objId = format("slot_%s_%s", countryId.tostring(), idInCountry.tostring())
  if (isBonus)
    objId += "-bonus"
  return objId
}

::get_slot_obj <- function get_slot_obj(slotbarObj, countryId, idInCountry) {
  if (!checkObj(slotbarObj))
    return null
  let slotObj = slotbarObj.findObject(::get_slot_obj_id(countryId, idInCountry))
  return checkObj(slotObj) ? slotObj : null
}

::get_unit_item_rent_info <- function get_unit_item_rent_info(unit, params) {
  let info = {
    hasIcon     = false
    hasProgress = false
    progress    = 0
  }

  if (unit) {
    let showAsTrophyContent = getTblValue("showAsTrophyContent", params, false)
    let offerRentTimeHours  = getTblValue("offerRentTimeHours", params, 0)
    let hasProgress = unit.isRented() && !showAsTrophyContent
    let isRentOffer = showAsTrophyContent && offerRentTimeHours > 0

    info.hasIcon = hasProgress || isRentOffer
    info.hasProgress = hasProgress

    let totalRentTimeSec = hasProgress ?
      (::rented_units_get_last_max_full_rent_time(unit.name) || -1)
      : 3600
    info.progress = hasProgress ?
      (360 - round(360.0 * unit.getRentTimeleft() / totalRentTimeSec).tointeger())
      : 0
  }

  return info
}

::get_slot_unit_name_text <- function get_slot_unit_name_text(unit, params) {
  local res = getUnitName(unit)
  let missionRules = getTblValue("missionRules", params)
  let groupName = missionRules ? missionRules.getRandomUnitsGroupName(unit.name) : null
  if (groupName)
    res = missionRules.getRandomUnitsGroupLocName(groupName)
  if (missionRules && missionRules.isWorldWarUnit(unit.name))
    res = loc("icon/worldWar/colored") + res
  if (missionRules && missionRules.needLeftRespawnOnSlots) {
    let leftRespawns = missionRules.getUnitLeftRespawns(unit)
    let leftWeaponPresetsText = missionRules.getUnitLeftWeaponShortText(unit)
    local text = leftRespawns != ::RESPAWNS_UNLIMITED
      ? missionRules.isUnitAvailableBySpawnScore(unit)
        ? loc("icon/star/white")
        : leftRespawns.tostring()
      : ""

    if (leftWeaponPresetsText.len())
      text += (text.len() ? "/" : "") + leftWeaponPresetsText

    if (text.len())
      res += loc("ui/parentheses/space", { text = text })
  }
  return res
}

::is_unit_price_text_long <- @(text) ::utf8_strlen(removeTextareaTags(text)) > 13

::get_unit_item_price_text <- function get_unit_item_price_text(unit, params) {
  let isLocalState        = getTblValue("isLocalState", params, true)
  let haveRespawnCost     = getTblValue("haveRespawnCost", params, false)
  let haveSpawnDelay      = getTblValue("haveSpawnDelay", params, false)
  let curSlotIdInCountry  = getTblValue("curSlotIdInCountry", params, -1)
  let slotDelayData       = getTblValue("slotDelayData", params, null)

  local priceText = ""

  if (curSlotIdInCountry >= 0 && ::is_spare_aircraft_in_slot(curSlotIdInCountry))
    priceText += loc("spare/spare/short") + " "

  if ((haveRespawnCost || haveSpawnDelay) && getTblValue("unlocked", params, true)) {
    let spawnDelay = slotDelayData != null
      ? slotDelayData.slotDelay - ((get_time_msec() - slotDelayData.updateTime) / 1000).tointeger()
      : ::get_slot_delay(unit.name)
    if (haveSpawnDelay && spawnDelay > 0)
      priceText += time.secondsToString(spawnDelay)
    else {
      let txtList = []
      local wpToRespawn = get_unit_wp_to_respawn(unit.name)
      if (wpToRespawn > 0 && ::is_crew_available_in_session(curSlotIdInCountry, false)) {
        let sessionWpBalance = getTblValue("sessionWpBalance", params, 0)
        wpToRespawn += getTblValue("weaponPrice", params, 0)
        txtList.append(::colorTextByValues(Cost(wpToRespawn).toStringWithParams({ isWpAlwaysShown = true }),
          sessionWpBalance, wpToRespawn, true, false))
      }

      let reqUnitSpawnScore = ::shop_get_spawn_score(unit.name, getLastWeapon(unit.name), getUnitLastBullets(unit))
      let totalSpawnScore = getTblValue("totalSpawnScore", params, -1)
      if (reqUnitSpawnScore > 0 && totalSpawnScore > -1) {
        local spawnScoreText = reqUnitSpawnScore
        if (reqUnitSpawnScore > totalSpawnScore)
          spawnScoreText = "<color=@badTextColor>" + reqUnitSpawnScore + "</color>"
        txtList.append(loc("shop/spawnScore", { cost = spawnScoreText }))
      }

      if (txtList.len()) {
        local spawnCostText = ", ".join(txtList, true)
        if (priceText.len())
          spawnCostText = loc("ui/parentheses", { text = spawnCostText })
        priceText += spawnCostText
      }
    }
  }

  if (::is_in_flight()) {
    let maxSpawns = get_max_spawns_unit_count(unit.name)
    if (curSlotIdInCountry >= 0 && maxSpawns > 1) {
      let leftSpawns = maxSpawns - ::get_num_used_unit_spawns(curSlotIdInCountry)
      priceText += format("(%s/%s)", leftSpawns.tostring(), maxSpawns.tostring())
    }
  }
  else if (isLocalState && priceText == "") {
    let { overlayPrice = -1, showAsTrophyContent = false, isReceivedPrizes = false } = params
    priceText = overlayPrice >= 0 ? ::getPriceAccordingToPlayersCurrency(overlayPrice, 0, true)
      : getUnitShopPriceText(unit)

    if (priceText == "" && ::isUnitBought(unit) && showAsTrophyContent && !isReceivedPrizes)
      priceText = colorize("goodTextColor", loc("mainmenu/itemReceived"))
  }

  return priceText
}

::get_unit_item_research_progress_text <- function get_unit_item_research_progress_text(unit, _params, priceText = "") {
  if (!u.isEmpty(priceText))
    return ""
  if (!canResearchUnit(unit))
    return ""

  let unitExpReq  = ::getUnitReqExp(unit)
  let unitExpCur  = ::getUnitExp(unit)
  if (unitExpReq <= 0 || unitExpReq <= unitExpCur)
    return ""

  let isSquadronVehicle = unit?.isSquadronVehicle?() ?? false
  if (isSquadronVehicle && !::is_in_clan()
    && min(::clan_get_exp(), unitExpReq - unitExpCur) <= 0)
    return ""

  return isSquadronVehicle
    ? Cost().setSap(unitExpReq - unitExpCur).tostring()
    : Cost().setRp(unitExpReq - unitExpCur).tostring()
}

::get_unit_item_progress_status <- function get_unit_item_progress_status(unit, params) {
  let isSquadronVehicle   = unit?.isSquadronVehicle?()
  let unitExpReq          = ::getUnitReqExp(unit)
  let unitExpGranted      = ::getUnitExp(unit)
  let diffSquadronExp     = isSquadronVehicle
     ? min(::clan_get_exp(), unitExpReq - unitExpGranted)
     : 0
  let flushExp = getTblValue("flushExp", params, 0)
  let isFull = (flushExp > 0 && flushExp >= unitExpReq)
    || (diffSquadronExp > 0 && diffSquadronExp >= unitExpReq)

  let forceNotInResearch  = getTblValue("forceNotInResearch", params, false)
  let isVehicleInResearch = !forceNotInResearch && ::isUnitInResearch(unit)
    && (!isSquadronVehicle || ::is_in_clan() || diffSquadronExp > 0)

  return isFull ? "researched"
         : isVehicleInResearch ? "research"
           : ""
}

::get_unit_rank_text <- function get_unit_rank_text(unit, crew = null, showBR = false, ediff = -1) {
  let isInFlight = ::is_in_flight()
  if ((unit?.hideBrForVehicle ?? false) ||
      (isInFlight && ::g_mis_custom_state.getCurMissionRules().isWorldWar))
    return ""

  let reserveText = stripTags(loc("shop/reserve"))
  if (isUnitGroup(unit)) {
    local isReserve = false
    local rank = 0
    local minBR = 0
    local maxBR = 0
    foreach (un in unit.airsGroup) {
      isReserve = isReserve || isUnitDefault(un)
      rank = rank || un.rank
      let br = un.getBattleRating(ediff)
      minBR = !minBR ? br : min(minBR, br)
      maxBR = !maxBR ? br : max(maxBR, br)
    }
    return isReserve ? reserveText :
      showBR  ? (minBR != maxBR ? format("%.1f-%.1f", minBR, maxBR) : format("%.1f", minBR)) :
      get_roman_numeral(rank)
  }

  if (unit?.isFakeUnit)
    return unit?.isReqForFakeUnit || unit?.rank == null
      ? ""
      : format(loc("events/rank"), get_roman_numeral(unit.rank))

  let isReserve = isUnitDefault(unit)
  let isSpare = crew && isInFlight ? ::is_spare_aircraft_in_slot(crew.idInCountry) : false
  let battleRatingStr = format("%.1f", unit.getBattleRating(ediff))
  let reserveToShowStr = (battleRatingStr == "1.0") ? reserveText :
    "".join([reserveText, loc("ui/parentheses/space", { text = battleRatingStr })])

  return isReserve ?
           isSpare ? "" : reserveToShowStr :
           showBR ? battleRatingStr : get_roman_numeral(unit.rank)
}

::is_crew_locked_by_prev_battle <- function is_crew_locked_by_prev_battle(crew) {
  return ::isInMenu() && getTblValue("lockedTillSec", crew, 0) > 0
}

::isUnitUnlocked <- function isUnitUnlocked(unit, curSlotCountryId, curSlotIdInCountry, country, missionRules, needDbg = false) {
  let crew = ::g_crews_list.get()[curSlotCountryId].crews[curSlotIdInCountry]
  local unlocked = !::is_crew_locked_by_prev_battle(crew)
  if (unit) {
    unlocked = unlocked && (!country || ::is_crew_available_in_session(curSlotIdInCountry, needDbg))
    unlocked = unlocked && (::isUnitAvailableForGM(unit, get_game_mode()) || ::is_in_flight())
      && (!unit.disableFlyout || !::is_in_flight())
      && (missionRules?.isUnitEnabledBySessionRank(unit) ?? true)
    if (unlocked && !::SessionLobby.canChangeCrewUnits() && !::is_in_flight()
        && ::SessionLobby.getMaxRespawns() == 1)
      unlocked = ::SessionLobby.getMyCurUnit() == unit
  }

  return unlocked
}

::isCountryAllCrewsUnlockedInHangar <- function isCountryAllCrewsUnlockedInHangar(countryId) {
  foreach (tbl in ::g_crews_list.get())
    if (tbl.country == countryId)
      foreach (crew in tbl.crews)
        if (::is_crew_locked_by_prev_battle(crew))
          return false
  return true
}

::getBrokenSlotsCount <- function getBrokenSlotsCount(country) {
  local count = 0
  foreach (c in ::g_crews_list.get())
    if (!country || country == c.country)
      foreach (crew in c.crews)
        if (("aircraft" in crew) && crew.aircraft != "") {
          let hp = ::shop_get_aircraft_hp(crew.aircraft)
          if (hp >= 0 && hp < 1)
            count++
        }
  return count
}

::get_crew_by_id <- function get_crew_by_id(id) {
  foreach (_cId, cList in ::g_crews_list.get())
    if ("crews" in cList)
      foreach (_idx, crew in cList.crews)
       if (crew.id == id)
         return crew
  return null
}

::getCrewByAir <- function getCrewByAir(air) {
  foreach (country in ::g_crews_list.get())
    if (country.country == air.shopCountry)
      foreach (crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft == air.name)
          return crew
  return null
}

::isUnitInSlotbar <- function isUnitInSlotbar(air) {
  return ::getCrewByAir(air) != null
}

::getSlotbarUnitTypes <- function getSlotbarUnitTypes(country) {
  let res = []
  foreach (countryData in ::g_crews_list.get())
    if (countryData.country == country)
      foreach (crew in countryData.crews)
        if (("aircraft" in crew) && crew.aircraft != "") {
          let unit = getAircraftByName(crew.aircraft)
          if (unit)
            u.appendOnce(getEsUnitType(unit), res)
        }
  return res
}

::get_crews_list_by_country <- function get_crews_list_by_country(country) {
  foreach (countryData in ::g_crews_list.get())
    if (countryData.country == country)
      return countryData.crews
  return []
}

::save_selected_crews <- function save_selected_crews() {
  if (!::g_login.isLoggedIn())
    return

  let blk = DataBlock()
  foreach (cIdx, country in ::g_crews_list.get())
    blk[country.country] = getTblValue(cIdx, ::selected_crews, 0)
  saveLocalByAccount("selected_crews", blk)
}

::init_selected_crews <- function init_selected_crews(forceReload = false) {
  if (!forceReload && (!::g_crews_list.get().len() || ::selected_crews.len() == ::g_crews_list.get().len()))
    return

  let selCrewsBlk = loadLocalByAccount("selected_crews", null)
  local needSave = false

  ::selected_crews = array(::g_crews_list.get().len(), 0)
  foreach (cIdx, country in ::g_crews_list.get()) {
    let crewIdx = selCrewsBlk?[country.country] ?? 0
    if ((country?.crews[crewIdx].aircraft ?? "") != "")
      ::selected_crews[cIdx] = crewIdx
    else {
      if (!selectAvailableCrew(cIdx)) {
        let unitId = getReserveAircraftName({ country = country.country })
        if (unitId != "")
          batchTrainCrew([{
            crewId = country.crews[0].id
            airName = unitId
          }])
      }
      needSave = needSave || ::selected_crews[cIdx] != crewIdx
    }
  }
  if (needSave)
    ::save_selected_crews()
  broadcastEvent("CrewChanged")
}

::select_crew_silent_no_check <- function select_crew_silent_no_check(countryId, idInCountry) {
  if (::selected_crews[countryId] != idInCountry) {
    ::selected_crews[countryId] = idInCountry
    ::save_selected_crews()
  }
}

::select_crew <- function select_crew(countryId, idInCountry, airChanged = false) {
  ::init_selected_crews()
  if ((countryId not in ::selected_crews)
      || (::selected_crews[countryId] == idInCountry && !airChanged))
    return

  ::select_crew_silent_no_check(countryId, idInCountry)
  broadcastEvent("CrewChanged")
  ::g_squad_utils.updateMyCountryData(!::is_in_flight())
}

::getSelAircraftByCountry <- function getSelAircraftByCountry(country) {
  ::init_selected_crews()
  foreach (cIdx, c in ::g_crews_list.get())
    if (c.country == country)
      return ::g_crew.getCrewUnit(c.crews?[::selected_crews[cIdx]])
  return null
}

::get_cur_slotbar_unit <- function get_cur_slotbar_unit() {
  return ::getSelAircraftByCountry(profileCountrySq.value)
}

::is_unit_enabled_for_slotbar <- function is_unit_enabled_for_slotbar(unit, params) {
  if (!unit || unit.disableFlyout)
    return false

  local res = true
  if (params?.eventId) {
    res = false
    let event = ::events.getEvent(params.eventId)
    if (event)
      res = ::events.isUnitAllowedForEventRoom(event, getTblValue("room", params), unit)
  }
  else if (params?.availableUnits)
    res = unit.name in params.availableUnits
  else if (::SessionLobby.isInRoom() && !::is_in_flight())
    res = ::SessionLobby.isUnitAllowed(unit)
  else if (params?.roomCreationContext)
    res = params.roomCreationContext.isUnitAllowed(unit)

  if (res && params?.mainMenuSlotbar)
    res = ::game_mode_manager.isUnitAllowedForGameMode(unit)

  let missionRules = params?.missionRules
  if (res && missionRules) {
    let isAvaliableUnit = (missionRules.getUnitLeftRespawns(unit) != 0
      || missionRules.isUnitAvailableBySpawnScore(unit))
      && missionRules.isUnitEnabledByRandomGroups(unit.name)
    let isControlledUnit = !::is_respawn_screen()
      && ::is_player_unit_alive()
      && ::get_player_unit_name() == unit.name

    res = isAvaliableUnit || isControlledUnit
  }

  return res
}

::isUnitInCustomList <- function isUnitInCustomList(unit, params) {
  if (!unit)
    return false

  return params?.customUnitsList ? unit.name in params.customUnitsList : true
}

::initSlotbarTopBar <- function initSlotbarTopBar(slotbarObj, show, boxesShow = true) {
  if (!checkObj(slotbarObj))
    return

  let containerObj = slotbarObj.findObject("slotbar_buttons_place")
  let mainObj = slotbarObj.findObject("autorefill-settings")
  if (!checkObj(containerObj) || !checkObj(mainObj))
    return

  containerObj.show(show)
  mainObj.show(show)
  if (!show)
    return

  let repObj = mainObj.findObject("slots-autorepair")
  let weapObj = mainObj.findObject("slots-autoweapon")
  repObj.show(boxesShow)
  weapObj.show(boxesShow)
  if (!boxesShow)
    return

  if (checkObj(repObj))
    repObj.setValue(::get_auto_refill(0))

  if (checkObj(weapObj))
    weapObj.setValue(::get_auto_refill(1))
}

::isCountryAvailable <- function isCountryAvailable(country) {
  if (country == "country_0" || country == "")
    return true

  return isInArray(country, ::unlocked_countries) || ::is_country_available(country)
}

::unlockCountry <- function unlockCountry(country, hideInUserlog = false, reqUnlock = true) {
  if (reqUnlock)
    reqUnlockByClient(country, hideInUserlog)

  if (!isInArray(country, ::unlocked_countries))
    ::unlocked_countries.append(country)
}

::checkUnlockedCountries <- function checkUnlockedCountries() {
  let curUnlocked = []
  if (isNeedFirstCountryChoice())
    return curUnlocked

  let unlockAll = ::disable_network() || hasFeature("UnlockAllCountries") || isDiffUnlocked(1, ES_UNIT_TYPE_AIRCRAFT)
  let wasInList = ::unlocked_countries.len()
  foreach (_i, country in shopCountriesList)
    if (::is_country_available(country)) {
      if (!isInArray(country, ::unlocked_countries)) {
        ::unlocked_countries.append(country)
        curUnlocked.append(country)
      }
    }
    else if (unlockAll) {
      ::unlockCountry(country, !::g_login.isLoggedIn())
      curUnlocked.append(country)
    }
  if (wasInList != ::unlocked_countries.len())
    broadcastEvent("UnlockedCountriesUpdate")
  return curUnlocked
}

::checkUnlockedCountriesByAirs <- function checkUnlockedCountriesByAirs() { //starter packs
  local haveUnlocked = false
  foreach (air in getAllUnits())
    if (!isUnitDefault(air)
        && ::isUnitUsable(air)
        && !::isCountryAvailable(air.shopCountry)) {
      ::unlockCountry(air.shopCountry)
      haveUnlocked = true
    }
  if (haveUnlocked)
    broadcastEvent("UnlockedCountriesUpdate")
  return haveUnlocked
}