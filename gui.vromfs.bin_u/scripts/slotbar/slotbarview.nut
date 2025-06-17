from "%scripts/dagui_natives.nut" import clan_get_exp, get_spare_aircrafts_count, get_slot_delay, shop_get_spawn_score, is_era_available, rented_units_get_last_max_full_rent_time, utf8_strlen, is_respawn_screen, is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/misCustomRules/ruleConsts.nut" import RESPAWNS_UNLIMITED
from "%scripts/utils_sa.nut" import colorTextByValues, get_tomoe_unit_icon
from "%scripts/clans/clanState.nut" import is_in_clan
from "guiRespawn" import getNumUsedUnitSpawns

let { get_player_unit_name, is_player_unit_alive } = require("unit")
let { is_harmonized_unit_image_required } = require("%scripts/langUtils/harmonized.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { format, split_by_chars } = require("string")
let { round, floor } = require("math")
let { isInFlight } = require("gameplayBinding")
let { shopIsModificationEnabled } = require("chardResearch")
let { get_max_spawns_unit_count, get_unit_wp_to_respawn } = require("guiMission")
let { get_time_msec } = require("dagor.time")
let time = require("%scripts/time.nut")
let { stripTags } = require("%sqstd/string.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { removeTextareaTags, toPixels } = require("%sqDagui/daguiUtil.nut")
let { Cost } = require("%scripts/money.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getUnitName,
  bit_unit_status, getUnitReqExp,
  getUnitExp, image_for_air
} = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canBuyUnit, isUnitGift, isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { getTooltipType, addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnitItemStatusText, getUnitRarity, getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRole, getUnitRoleIcon } = require("%scripts/unit/unitInfoRoles.nut")
let { isUnitElite, isUnitDefault, canResearchUnit, isUnitUsable,
  isUnitInResearch, isUnitsEraUnlocked, isUnitGroup, isUnitBroken,
} = require("%scripts/unit/unitStatus.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { getBitStatus } = require("%scripts/unit/unitBitStatus.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getLastWeapon, checkUnitWeapons, getWeaponsStatusName
} = require("%scripts/weaponry/weaponryInfo.nut")
let { getUnitLastBullets } = require("%scripts/weaponry/bulletsInfo.nut")
let { isCrewAvailableInSession, isSpareAircraftInSlot, isRespawnWithUniversalSpare, isUnitDisabledByMatching
} = require("%scripts/respawn/respawnState.nut")
let { getUnitShopPriceText } = require("%scripts/shop/unitCardPkg.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getCrewById } = require("%scripts/slotbar/crewsList.nut")
let { getCurrentGameModeEdiff, isUnitAllowedForGameMode
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getCrewLevel, getCrewStatus, isCrewMaxLevel, isCrewNeedUnseenIcon } = require("%scripts/crew/crew.nut")
let { getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { getCrewSpText } = require("%scripts/crew/crewPointsText.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { get_game_mode } = require("mission")
let { debug_dump_stack } = require("dagor.debug")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { get_units_count_at_rank } = require("%scripts/shop/shopCountryInfo.nut")
let { getRoomEvent, isUnitAllowedForRoom } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { get_unit_preset_img } = require("%scripts/options/optionsExt.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getEntitlementUnitDiscount } = require("%scripts/discounts/discountsState.nut")
let { canBuyUnitOnMarketplace } = require("%scripts/unit/canBuyUnitOnMarketplace.nut")

const DEFAULT_STATUS = "none"

function getUnitSlotRentInfo(unit, params) {
  let info = {
    hasIcon     = false
    hasProgress = false
    progress    = 0
  }

  if (unit == null)
    return info

  let { showAsTrophyContent = false, offerRentTimeHours = 0 } = params
  let hasProgress = unit.isRented() && !showAsTrophyContent
  let isRentOffer = showAsTrophyContent && offerRentTimeHours > 0

  info.hasIcon = hasProgress || isRentOffer
  info.hasProgress = hasProgress

  if (!hasProgress)
    return info

  let totalRentTimeSec = (rented_units_get_last_max_full_rent_time(unit.name) || -1)
  info.progress = (360 - round(360.0 * unit.getRentTimeleft() / totalRentTimeSec).tointeger())

  return info
}

function getSlotUnitNameText(unit, params) {
  local res = getUnitName(unit)
  let { missionRules = null, showAdditionExtraInfo = false } = params
  let groupName = missionRules ? missionRules.getRandomUnitsGroupName(unit.name) : null
  if (groupName)
    res = missionRules.getRandomUnitsGroupLocName(groupName)
  if (missionRules == null)
    return res

  if (missionRules.isWorldWarUnit(unit.name))
    res = $"{loc("icon/worldWar/colored")}{res}"

  if (!missionRules.needLeftRespawnOnSlots || showAdditionExtraInfo)
    return res

  let leftRespawns = missionRules.getUnitLeftRespawns(unit)
  let leftWeaponPresetsText = missionRules.getUnitLeftWeaponShortText(unit)
  let textArray = []
  if (leftRespawns != RESPAWNS_UNLIMITED) {
    if (missionRules.isUnitAvailableBySpawnScore(unit))
      textArray.append(loc("icon/star/white"))
    else
      textArray.append(leftRespawns.tostring())
  }

  if (leftWeaponPresetsText.len())
    textArray.append(leftWeaponPresetsText)

  if (textArray.len() > 0)
    res = "".concat(res, loc("ui/parentheses/space", { text = "/".join(textArray, true) }))
  return res
}

function getUnitSlotPriceText(unit, params) {
  let { isLocalState = true, haveRespawnCost = false, haveSpawnDelay = false,
    slotDelayData = null, unlocked = true, sessionWpBalance = 0, weaponPrice = 0,
    totalSpawnScore = -1, overlayPrice = -1, showAsTrophyContent = false,
    isReceivedPrizes = false, crew = null, missionRules = null
  } = params

  local priceText = ""
  if ((haveRespawnCost || haveSpawnDelay || missionRules?.isRageTokensRespawnEnabled) && unlocked) {
    let spawnDelay = slotDelayData != null
      ? slotDelayData.slotDelay - ((get_time_msec() - slotDelayData.updateTime) / 1000).tointeger()
      : get_slot_delay(unit.name)
    if (haveSpawnDelay && spawnDelay > 0)
      priceText = $"{priceText}{time.secondsToString(spawnDelay)}"
    else {
      let txtList = []
      local wpToRespawn = get_unit_wp_to_respawn(unit.name)
      if (wpToRespawn > 0 && crew != null && isCrewAvailableInSession(crew, unit)) {
        wpToRespawn += weaponPrice
        txtList.append(colorTextByValues(Cost(wpToRespawn).toStringWithParams({ isWpAlwaysShown = true }),
          sessionWpBalance, wpToRespawn, true, false))
      }

      let reqUnitSpawnScore = shop_get_spawn_score(unit.name, getLastWeapon(unit.name), getUnitLastBullets(unit))
      if (reqUnitSpawnScore > 0 && totalSpawnScore > -1) {
        local spawnScoreText = loc("shop/spawnScore", { cost = reqUnitSpawnScore })
        if (reqUnitSpawnScore > totalSpawnScore)
          txtList.append(colorize("badTextColor", spawnScoreText))
        else
          txtList.append(spawnScoreText)
      }

      let reqUnitSpawnRageTokens = missionRules?.getUnitSpawnRageTokens(unit) ?? 0
      if (reqUnitSpawnRageTokens > 0) {
        local spawnRageTokensText = reqUnitSpawnRageTokens
        if (reqUnitSpawnRageTokens > missionRules.getSpawnRageTokens())
          spawnRageTokensText = $"<color=@badTextColor>{reqUnitSpawnRageTokens}</color>"
        txtList.append(loc("shop/rageTokens", { cost = spawnRageTokensText }))
      }

      if (txtList.len()) {
        local spawnCostText = ", ".join(txtList, true)
        if (priceText.len())
          spawnCostText = loc("ui/parentheses", { text = spawnCostText })
        priceText = $"{priceText}{spawnCostText}"
      }
    }
  }

  if (!isInFlight() && isLocalState && priceText == "") {
    priceText = overlayPrice >= 0 ? Cost(overlayPrice).getTextAccordingToBalance()
      : getUnitShopPriceText(unit)

    if (priceText == "" && isUnitBought(unit) && showAsTrophyContent && !isReceivedPrizes)
      priceText = colorize("goodTextColor", loc("mainmenu/itemReceived"))
  }

  return priceText.replace(" ", nbsp)
}

function getUnitSlotResearchProgressText(unit, priceText = "") {
  if (priceText != "")
    return ""
  if (!canResearchUnit(unit))
    return ""

  let unitExpReq  = getUnitReqExp(unit)
  let unitExpCur  = getUnitExp(unit)
  if (unitExpReq <= 0 || unitExpReq <= unitExpCur)
    return ""

  let isSquadronVehicle = unit?.isSquadronVehicle?() ?? false
  if (isSquadronVehicle && !is_in_clan()
    && min(clan_get_exp(), unitExpReq - unitExpCur) <= 0)
    return ""

  return isSquadronVehicle
    ? Cost().setSap(unitExpReq - unitExpCur).tostring()
    : Cost().setRp(unitExpReq - unitExpCur).tostring()
}

function getUnitSlotProgressStatus(unit, params) {
  let { flushExp = 0, forceNotInResearch = false } = params
  let isSquadronVehicle   = unit?.isSquadronVehicle?()
  let unitExpReq          = getUnitReqExp(unit)
  let unitExpGranted      = getUnitExp(unit)
  let diffSquadronExp     = isSquadronVehicle
     ? min(clan_get_exp(), unitExpReq - unitExpGranted)
     : 0
  let isFull = (flushExp > 0 && flushExp >= unitExpReq)
    || (diffSquadronExp > 0 && diffSquadronExp >= unitExpReq)

  let isVehicleInResearch = !forceNotInResearch && isUnitInResearch(unit)
    && (!isSquadronVehicle || is_in_clan() || diffSquadronExp > 0)

  return isFull ? "researched"
    : isVehicleInResearch ? "research"
    : ""
}

function getUnitSlotRankText(unit, crew = null, showBR = false, ediff = -1) {
  if ((unit?.hideBrForVehicle ?? false) || (isInFlight() && getCurMissionRules().isWorldWar))
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
  let isSpare = crew && isInFlight() ? isSpareAircraftInSlot(crew.idInCountry) : false
  let battleRatingStr = format("%.1f", unit.getBattleRating(ediff))
  let reserveToShowStr = (battleRatingStr == "1.0") ? reserveText :
    "".join([reserveText, loc("ui/parentheses/space", { text = battleRatingStr })])

  return isReserve
    ? (isSpare ? "" : reserveToShowStr)
    : (showBR ? battleRatingStr : get_roman_numeral(unit.rank))
}

let isUnitPriceTextLong = @(text) utf8_strlen(removeTextareaTags(text)) > 13

function getSpareCountText(spareCount, crew, unit, missionRules) {
  let hasSpare = spareCount > 0
  if (!isInFlight())
    return hasSpare ? $"{spareCount}{loc("icon/spare")}" : ""

  let isSpareAllowedInMission = (missionRules == null || missionRules.isAllowSpareInMission())
    && get_game_mode() == GM_DOMINATION
  if (!isSpareAllowedInMission)
    return ""
  if (!crew)
    return ""
  if (isRespawnWithUniversalSpare(crew, unit))
    return loc("icon/universalSpare")
  if (!hasSpare)
    return ""

  let isSpareInSlot = isSpareAircraftInSlot(crew.idInCountry)
  if (isSpareInSlot && isCrewAvailableInSession(crew, unit))
    return $"{spareCount}{loc("icon/universalSpare")}"
  if (!isSpareInSlot)
    return $"{spareCount}{loc("icon/spare")}"
  return ""
}

function calcUnitSlotMissionInfoTextsWidth(priceText, addHistoricalRespawnsText,
    addRespawnsText, spareText) {
  let res = {
    priceWidth = "fw"
    addHistoricalRespawnsWidth = "fw"
    addRespawnsWidth = "fw"
  }
  local countVisibleBlocks = 1
    + (addHistoricalRespawnsText != "" ? 1 : 0)
    + (addRespawnsText != "" ? 1 : 0)
    + (spareText != "" ? 1 : 0)

  if (countVisibleBlocks <= 2)
    return res

  let guiScene = get_cur_gui_scene()
  let gapWidth = toPixels(guiScene, "1@sf/@pf")
  local fullInfoWidth = toPixels(guiScene, "@slot_width") + gapWidth * countVisibleBlocks
  let texts = [{ text = priceText, widthId = "priceWidth" },
    { text = addHistoricalRespawnsText, widthId = "addHistoricalRespawnsWidth" },
    { text = addRespawnsText, widthId = "addRespawnsWidth" }]
  foreach (value in texts) {
    let { text, widthId } = value
    if (text == "")
      continue
    if (countVisibleBlocks == 1)
      continue
    let partWidth = (fullInfoWidth / countVisibleBlocks - 0.5).tointeger()
    let textWidth = max(
      getStringWidthPx(removeTextareaTags(text), "fontSmall", guiScene) + 2*gapWidth,
      partWidth)
    fullInfoWidth = fullInfoWidth - textWidth
    countVisibleBlocks = countVisibleBlocks - 1
    res[widthId] <- textWidth
  }
  return res
}

function getSpareCountHintText(spareCount, crew, unit, missionRules) {
  let hasSpare = spareCount > 0
  if (!isInFlight())
    return ""
  let isSpareAllowedInMission = missionRules == null || missionRules.isAllowSpareInMission()
  if (!isSpareAllowedInMission)
    return ""
  if (crew && isRespawnWithUniversalSpare(crew, unit))
    return $"{loc("icon/universalSpare")}{loc("ui/minus")}{loc("mission_hint/spare/universal_spawn")}"
  if (crew && isSpareAircraftInSlot(crew.idInCountry))
    return hasSpare
      ? $"{spareCount}{loc("icon/universalSpare")}{loc("ui/minus")}{loc("mission_hint/spare/spawn")}"
      : loc("icon/universalSpare")
  if (hasSpare)
    return $"{spareCount}{loc("icon/spare")}{loc("ui/minus")}{loc("mission_hint/spare")}"
  return ""
}

function getUnitSlotPriceHintText(unit, params) {
  let { haveRespawnCost = false, haveSpawnDelay = false,
    slotDelayData = null, unlocked = true, sessionWpBalance = 0, weaponPrice = 0,
    totalSpawnScore = -1, crew = null
  } = params

  if (!unlocked || !(haveRespawnCost || haveSpawnDelay))
    return ""

  let spawnDelay = slotDelayData != null
    ? slotDelayData.slotDelay - ((get_time_msec() - slotDelayData.updateTime) / 1000).tointeger()
    : get_slot_delay(unit.name)
  if (haveSpawnDelay && spawnDelay > 0)
    return ""

  local wpToRespawn = get_unit_wp_to_respawn(unit.name)
  if (wpToRespawn > 0 && crew != null && isCrewAvailableInSession(crew, unit)) {
    wpToRespawn += weaponPrice
    let wpToRespawnText = colorTextByValues(Cost(wpToRespawn).toStringWithParams({ isWpAlwaysShown = true }),
      sessionWpBalance, wpToRespawn, true, false)
    return $"{wpToRespawnText}{loc("ui/minus")}{loc("mission_hint/cost_sl")}"
  }

  let reqUnitSpawnScore = shop_get_spawn_score(unit.name, getLastWeapon(unit.name), getUnitLastBullets(unit))
  if (reqUnitSpawnScore > 0 && totalSpawnScore > -1) {
    local reqSpawnScoreText = loc("shop/spawnScore", { cost = reqUnitSpawnScore })
    let totalSpawnScoreText = loc("shop/spawnScore", { cost = totalSpawnScore })
    if (reqUnitSpawnScore > totalSpawnScore)
      reqSpawnScoreText = colorize("badTextColor", reqSpawnScoreText)
    return $"{reqSpawnScoreText}{loc("ui/minus")}{loc("mission_hint/cost_sp", { current_cost_sp = totalSpawnScoreText})}"
  }

  return ""
}

function buildFakeSlot(id, unit, params) {
  let { isLocalState = true, showBR = hasFeature("GlobalShowBattleRating") } = params
  let curEdiff = params?.getEdiffFunc() ?? getCurrentGameModeEdiff()
  let { isReqForFakeUnit = false } = unit
  let isFakeAirRankOpen = isLocalState && get_units_count_at_rank(unit?.rank,
    unitTypes.getByName(unit.name, false).esUnitType, unit?.country, true)
  let bitStatus = isReqForFakeUnit ? bit_unit_status.disabled
    : isFakeAirRankOpen || !isLocalState ? bit_unit_status.owned
    : bit_unit_status.locked
  let nameForLoc = isReqForFakeUnit ? split_by_chars(unit.name, "_")?[0] : unit.name
  let fakeSlotView = params.__merge({
    slotId              = $"td_{id}"
    slotInactive        = true
    isSlotbarItem       = false
    shopItemId          = id
    unitName            = unit.name
    shopAirImg          = unit.image
    shopStatus          = params?.status ?? getUnitItemStatusText(bitStatus, true)
    unitRankText        = getUnitSlotRankText(unit, null, showBR, curEdiff)
    shopItemTextId      = $"{id}_txt"
    shopItemText        = loc(unit?.nameLoc ?? $"mainmenu/type_{nameForLoc}")
    isItemDisabled      = bitStatus == bit_unit_status.disabled
    tooltipId           = params?.tooltipId ?? ""
    isTooltipByHold     = showConsoleButtons.value
  })
  return handyman.renderCached("%gui/slotbar/slotbarSlotFake.tpl", fakeSlotView)
}

function buildEmptySlot(id, _unit, params) {
  let { specType = null, forceCrewInfoUnit = null, emptyCost = null,
    crewId = -1, hasActions = false, hasCrewHint = false, isShowDragAndDropIcon = false } = params
  let itemButtons = specType == null ? { specIconBlock = false }
    : {
      specIconBlock = true
      specTypeIcon = specType.trainedIcon
      specTypeTooltip = specType.getName()
    }

  local crewLevelInfoData = ""
  let crew = crewId >= 0 ? getCrewById(crewId) : null
  let hasCrew = crew != null
  if (forceCrewInfoUnit != null && hasCrew) {
    let crewLevelText = getCrewLevel(crew, forceCrewInfoUnit,
      forceCrewInfoUnit.getCrewUnitType()).tointeger().tostring()
    let crewSpecIcon = getSpecTypeByCrewAndUnit(crew, forceCrewInfoUnit).trainedIcon

    let crewLevelInfoView = {
      hasExtraInfoBlock = true
      hasCrewInfo       = true
      crewNum           = $"{crew.idInCountry + 1}"
      crewLevel         = crewLevelText
      crewSpecIcon      = crewSpecIcon
      isEmptySlot       = "yes"
      crewId
      forcedUnit        = forceCrewInfoUnit.name
    }
    crewLevelInfoData = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", crewLevelInfoView)
  }
  else if (hasCrew) {
    crewLevelInfoData = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", {
      hasExtraInfoBlock = true
      hasCrewIdTextInfo = true
      hasActions
      hasCrewHint
      crewNum = $"{crew.idInCountry + 1}"
      isEmptySlot = "yes"
      crewNumWithTitle = $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}"
      crewPoints = getCrewSpText(crew?.skillPoints ?? 0)
      crewId = crewId.tostring()
      crewIdInCountry = crew?.idInCountry
      needCurPoints = true
    })
  }

  let priceText = emptyCost ? emptyCost.getTextAccordingToBalance() : ""
  let emptySlotView = params.__merge({
    slotId = $"td_{id}"
    shopItemId = id
    shopItemTextId = $"{id}_txt"
    shopItemTextValue = params?.emptyText ?? ""
    shopStatus = params?.status
    shopItemPriceText = priceText
    itemButtons = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", { itemButtons })
    extraInfoBlock = crewLevelInfoData
    crewNumWithTitle = hasCrew ? $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}" : "No crew"
    crewId = crewId.tostring()
    isShowDragAndDropIcon
    dragAndDropIconHint = isShowDragAndDropIcon ? loc("slotbar/dragUnitHint") : null
  })

  return handyman.renderCached("%gui/slotbar/slotbarSlotEmpty.tpl", emptySlotView)
}

function buildGroupSlot(id, unit, params) {
  let { showBR = hasFeature("GlobalShowBattleRating"),
    status = DEFAULT_STATUS, forceNotInResearch =false, shopResearchMode = false,
    showInService = false, isSquadronResearchMode = false, tooltipParams = null
  } = params
  local inactive = params?.inactive ?? false

  let curEdiff = params?.getEdiffFunc() ?? getCurrentGameModeEdiff()
  local special = false

  local nextAir = unit.airsGroup[0]
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
  local firstUnboughtUnit = null
  local researchingUnit   = null
  local rentedUnit        = null
  local unitRole          = null
  local bitStatus         = 0

  foreach (a in unit.airsGroup) {
    let isInResearch = !forceNotInResearch && isUnitInResearch(a)
    let isUsable = isUnitUsable(a)

    if (isInResearch || (canResearchUnit(a) && !researchingUnit)) {
      researchingUnit = a
      isGroupInResearch = isInResearch
    }
    else if (!isUsable && !firstUnboughtUnit && (canBuyUnit(a) || ::canBuyUnitOnline(a)))
      firstUnboughtUnit = a

    if (showInService && isUsable) {
      if (isUnitInSlotbar(a))
        mountedUnit = a
      isGroupUsable = true
    }

    if (a.isRented()) {
      if (!rentedUnit || a.getRentTimeleft() <= rentedUnit.getRentTimeleft())
        rentedUnit = a
    }

    if (unitRole == null || isInResearch)
      unitRole = getUnitRole(nextAir)
    special = isUnitSpecial(a)
    isElite = isElite && isUnitElite(a)
    isPkgDev = isPkgDev || a.isPkgDev
    isRecentlyReleased = isRecentlyReleased || a.isRecentlyReleased()

    let hasTalisman = special || shopIsModificationEnabled(a.name, "premExpMul")
    hasTalismanIcon = hasTalismanIcon || hasTalisman
    talismanIncomplete = talismanIncomplete || !hasTalisman

    bitStatus = bitStatus | getBitStatus(a)
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

  
  
  nextAir = rentedUnit || mountedUnit || (isGroupInResearch && researchingUnit)
    || firstUnboughtUnit || nextAir
  forceUnitNameOnPlate = rentedUnit != null || mountedUnit  != null
    || (isGroupInResearch && researchingUnit != null) || firstUnboughtUnit != null
  let unitForBR = rentedUnit || researchingUnit || firstUnboughtUnit || unit

  
  
  

  let bottomButtonView = {
    holderId            = id
    hasButton           = showConsoleButtons.value
    mainButtonAction    = "onAircraftClick"
    mainButtonText      = ""
    mainButtonIcon      = "#ui/gameuiskin#slot_unfold.svg"
    hasMainButtonIcon   = true
  }

  
  
  

  let rentInfo = getUnitSlotRentInfo(rentedUnit, params)

  let itemButtonsView = {
    itemButtons = {
      hasRentIcon             = rentInfo.hasIcon
      hasRentProgress         = rentInfo.hasProgress
      rentProgress            = rentInfo.progress
    }
  }

  
  
  

  local showProgress = false
  local unitExpProgressValue = 0
  if (researchingUnit) {
    showProgress = true
    let unitExpGranted = getUnitExp(researchingUnit)
    let unitReqExp = getUnitReqExp(researchingUnit)
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

  
  
  

  let shopAirImage = get_unit_preset_img(unit.name)
    ?? (is_harmonized_unit_image_required(nextAir)
        ? get_tomoe_unit_icon(unit.name, !unit.name.endswith("_group"))
        : "!{0}".subst(unit?.image ?? "#ui/unitskin#planes_group.ddsx"))
  let groupSlotView = params.__merge({
    slotId              = id
    unitRole            = unitRole
    unitClassIcon       = getUnitRoleIcon(nextAir)
    groupStatus         = status == DEFAULT_STATUS ? getUnitItemStatusText(bitStatus, true) : status
    unitRarity          = getUnitRarity(nextAir)
    isBroken            = bitStatus & bit_unit_status.broken
    shopAirImg          = shopAirImage
    isPkgDev            = isPkgDev
    isRecentlyReleased  = isRecentlyReleased
    discountId          = $"{id}-discount"
    shopItemTextId      = $"{id}_txt"
    shopItemText        = forceUnitNameOnPlate ? $"#{nextAir.name}_shop" : $"#shop/group/{unit.name}"
    progressText        = showProgress ? getUnitSlotResearchProgressText(researchingUnit) : ""
    progressStatus      = showProgress ? getUnitSlotProgressStatus(researchingUnit, params) : ""
    progressBlk         = handyman.renderCached("%gui/slotbar/airResearchProgress.tpl", airResearchProgressView)
    showInService       = isGroupUsable
    priceText           = !showProgress && firstUnboughtUnit ? getUnitSlotPriceText(firstUnboughtUnit, params) : ""
    isMounted           = mountedUnit != null
    isElite             = isElite
    unitRankText        = getUnitSlotRankText(unitForBR, null, showBR, curEdiff)
    isItemLocked        = !is_era_available(country, era, esUnitType)
    hasTalismanIcon     = hasTalismanIcon
    talismanIncomplete  = talismanIncomplete
    itemButtons         = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", itemButtonsView)
    bonusId             = id
    primaryUnitId       = nextAir.name
    tooltipId           = getTooltipType("UNIT").getTooltipId(nextAir.name, tooltipParams)
    isTooltipByHold     = showConsoleButtons.value
    bottomButton        = handyman.renderCached("%gui/slotbar/slotbarItemBottomButton.tpl", bottomButtonView)
    hasFullGroupBlock   = params?.fullGroupBlock ?? true
    fullGroupBlockId    = $"td_{id}"
    isGroupInactive     = inactive
  })

  return handyman.renderCached("%gui/slotbar/slotbarSlotGroup.tpl", groupSlotView)
}

function buildCommonUnitSlot(id, unit, params) {
  let { isLocalState = true, showBR = hasFeature("GlobalShowBattleRating"),
    forceNotInResearch = false, shopResearchMode = false, hasActions = false,
    forceCrewInfoUnit = null, crewId = -1, showWarningIcon = false, specType = null,
    missionRules = null, bottomLineText = null, isSlotbarItem = false, isInTable = true,
    showInService = false, hasExtraInfoBlock = false, hasExtraInfoBlockTop = false,
    toBattle = false, toBattleButtonAction = "onSlotBattle", hasCrewHint = false,
    showAdditionExtraInfo = false, showCrewUnseenIcon = false, showCrewInfoTranslucent = false
  } = params
  local { inactive = false, status = DEFAULT_STATUS, tooltipParams = null } = params
  let curEdiff = params?.getEdiffFunc() ?? getCurrentGameModeEdiff()

  let isOwn               = isUnitBought(unit)
  let isUsable            = isUnitUsable(unit)
  let isMounted           = isUnitInSlotbar(unit)
  let canResearch         = canResearchUnit(unit)
  let special             = isUnitSpecial(unit)
  let isVehicleInResearch = isUnitInResearch(unit) && !forceNotInResearch
  let isSquadronVehicle   = unit.isSquadronVehicle()
  let isMarketableVehicle = canBuyUnitOnMarketplace(unit)
  let unitReqExp          = getUnitReqExp(unit)
  local unitExpGranted      = getUnitExp(unit)
  let diffExp = isSquadronVehicle
    ? min(clan_get_exp(), unitReqExp - unitExpGranted)
    : (params?.diffExp ?? 0)
  if (isSquadronVehicle && isVehicleInResearch)
    unitExpGranted += diffExp

  let isBroken            = isUnitBroken(unit)
  let unitRarity          = getUnitRarity(unit)
  let isLockedSquadronVehicle = isSquadronVehicle && !is_in_clan() && diffExp <= 0

  if (status == DEFAULT_STATUS) {
    let bitStatus = getBitStatus(unit, params)
    if (bit_unit_status.locked & bitStatus)
      inactive = shopResearchMode
    else if (bit_unit_status.disabled & bitStatus)
      inactive = true

    status = getUnitItemStatusText(bitStatus, false)
  }

  
  
  

  let rentInfo = getUnitSlotRentInfo(unit, params)

  let itemButtonsView = {
    itemButtons = {
      hasToBattleButton       = toBattle
      toBattleButtonAction
      hasExtraInfoBlockTop
      specIconBlock           = showWarningIcon || specType != null
      showWarningIcon         = showWarningIcon
      hasRepairIcon           = isLocalState && isBroken
      weaponsStatus           = getWeaponsStatusName(isLocalState && isUsable ? checkUnitWeapons(unit) : UNIT_WEAPONS_READY)
      hasRentIcon             = rentInfo.hasIcon
      hasRentProgress         = rentInfo.hasProgress
      rentProgress            = rentInfo.progress
    }
  }

  let hasCrewInfo = crewId >= 0
  let crew = hasCrewInfo ? getCrewById(crewId) : null
  let unitForCrewInfo = forceCrewInfoUnit || unit

  let crewLevelText = (crew && unitForCrewInfo)
    ? getCrewLevel(crew, unitForCrewInfo, unitForCrewInfo.getCrewUnitType()).tointeger().tostring()
    : ""
  let isMaxLevel = (crew && unitForCrewInfo)
    ? isCrewMaxLevel(crew, unitForCrewInfo, crew.country, unitForCrewInfo.getCrewUnitType())
    : ""
  local crewLevelTextFull = ""
  if (isMaxLevel && crewLevelText != "") {
    let maxLevelTxt = colorize("@commonTextColor",
      loc("ui/parentheses/space", { text = loc("options/quality_max") }))
    crewLevelTextFull = $"{crewLevelText}{maxLevelTxt}"
  }

  let crewSpec = getSpecTypeByCrewAndUnit(crew, unitForCrewInfo)
  let hasUnit = !(crew?.isEmpty ?? false)
  let needCurPoints = (crew != null) && !isMaxLevel

  local extraInfoViewBottom = {}
  if (hasExtraInfoBlock && hasCrewInfo) {
    extraInfoViewBottom = {
      hasExtraInfoBlock
      hasCrewInfo
      hasUnit
      needCurPoints
      hasActions
      hasCrewHint
      showAdditionExtraInfo
      crewLevel = crewLevelText
      crewLevelFull = crewLevelTextFull
      crewSpecIcon = crewSpec.trainedIcon
      crewStatus = getCrewStatus(crew, unitForCrewInfo)
      hasCrewUnseenIcon = showCrewUnseenIcon && isCrewNeedUnseenIcon(crew, unitForCrewInfo) ? "yes" : "no"
      crewNum = $"{crew.idInCountry + 1}"
      crewNumWithTitle = $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}"
      crewPoints = (hasUnit && needCurPoints) ? getCrewSpText(crew?.skillPoints ?? 0) : ""
      crewId
      crewIdInCountry = crew?.idInCountry
      isEmptySlot = "no"
    }

    tooltipParams = tooltipParams ?? {}
    tooltipParams = tooltipParams.__merge({ needCrewInfo = false })
  }

  let priceText = getUnitSlotPriceText(unit, params.__merge({crew}))

  local additionalRespawns = ""
  local armyLocName = ""
  if (showAdditionExtraInfo && missionRules?.needLeftRespawnOnSlots == true) {
    let unitTypeName = unit.unitType.typeName
    local unitTypeIcon = unit.unitType.fontIcon
    if (unitTypeName == "BOAT")
      unitTypeIcon = unitTypes.SHIP.fontIcon
    else if (unitTypeName == "HELICOPTER")
      unitTypeIcon = unitTypes.AIRCRAFT.fontIcon
    let respawnsLeft = missionRules.getUnitLeftRespawns(unit)
    let respawnsInitial = missionRules?.getUnitInitialRespawns(unit) ?? 0
    if (respawnsInitial > 0)
      additionalRespawns = $"{unitTypeIcon}{respawnsLeft}/{respawnsInitial}"
    if (additionalRespawns != "" && respawnsLeft == 0)
      additionalRespawns = colorize("badTextColor", additionalRespawns)
    if (additionalRespawns != "")
      armyLocName = (unitTypeName == "SHIP" || unitTypeName == "BOAT") ? loc("mainmenu/fleet")
        : (unitTypeName == "HELICOPTER") ? loc("mainmenu/aviation")
        : unit.unitType.getArmyLocName()
  }

  local additionalHistoricalRespawns = ""
  local leftHistoricalSpawns = 0
  local unitClassIcoColor = "@commonTextColor"
  if (crew && isInFlight()) {
    let maxSpawns = get_max_spawns_unit_count(unit.name)
    if (crew.idInCountry >= 0 && maxSpawns > 1) {
      let numSpawns = getNumUsedUnitSpawns(crew.idInCountry)
      leftHistoricalSpawns = maxSpawns - numSpawns
      additionalHistoricalRespawns = $"{leftHistoricalSpawns}/{maxSpawns}"
      if (leftHistoricalSpawns == 0) {
        additionalHistoricalRespawns = colorize("badTextColor", additionalHistoricalRespawns)
        unitClassIcoColor = "@badTextColor"
      }
    }
  }

  let hasPriceText = showAdditionExtraInfo && priceText != ""
  let spareCount = isLocalState ? get_spare_aircrafts_count(unit.name) : 0
  let spareText = leftHistoricalSpawns == 0
    ? getSpareCountText(spareCount, crew, unit, missionRules)
    : ""
  let hasSpareInfo = spareText != ""
  let hasAdditionalRespawns = additionalRespawns != ""
  let hasAdditionalHistoricalRespawns = additionalHistoricalRespawns != "" && !hasSpareInfo

  let spareHintText = hasSpareInfo ? getSpareCountHintText(spareCount, crew, unit, missionRules) : ""
  let priceHintText = hasPriceText ? getUnitSlotPriceHintText(unit, params.__merge({crew})) : ""
  let additionalHistoricalRespawnsHintText = hasAdditionalHistoricalRespawns
    ? $"{additionalHistoricalRespawns}{loc("ui/minus")}{loc("mission_hint/spawns_per_battle", { unit_name = getUnitName(unit.name)})}"
    : ""
  let additionalRespawnsHintText = hasAdditionalRespawns
    ? $"{additionalRespawns}{loc("ui/minus")}{loc("mission_hint/spawns_per_unit", {army = armyLocName})}"
    : ""

  let isUnitDisabled = isInFlight() && crew && isUnitDisabledByMatching(crew.idInCountry)
  let extraInfoTopView = !isUnitDisabled ? {
    showAdditionExtraInfo
    spareHintText
    priceHintText
    additionalRespawnsHintText
    additionalHistoricalRespawnsHintText
    hasExtraInfoBlockTop
    hasPriceText
    hasAdditionalHistoricalRespawns
    additionalHistoricalRespawns
    addHistoricalRespawnsWidth = "fw"
    hasAdditionalRespawns
    additionalRespawns
    addRespawnsWidth = "fw"
    unitClassIco = getUnitClassIco(unit.name)
    unitClassIcoColor
    priceText
    priceWidth = "fw"
    hasSpareInfo
    spareCount = spareText
    hasPriceSeparator = hasPriceText && hasAdditionalHistoricalRespawns
    hasAdditionalRespawnsSeparator = hasAdditionalRespawns
      && (hasPriceText || hasAdditionalHistoricalRespawns)
    hasSpareSeparator = hasSpareInfo
      && (hasPriceText || hasAdditionalRespawns || hasAdditionalHistoricalRespawns)
    hasExtraInfo = hasPriceText || hasAdditionalRespawns || hasSpareInfo || hasAdditionalHistoricalRespawns
  } : {
    hasExtraInfo = false
    hasExtraInfoBlockTop
  }

  if (hasPriceText && hasSpareInfo && hasAdditionalRespawns && hasAdditionalHistoricalRespawns) {
    let roomEvent = getRoomEvent()
    let economicName = roomEvent != null ? getEventEconomicName(roomEvent) : null  
    let unitName = unit.name 
    debug_dump_stack()
    logerr("[SLOTBAR] unit slot missiton block has 4 blocks")
  }

  if (hasPriceText && !isUnitDisabled)
    extraInfoTopView.__update(
      calcUnitSlotMissionInfoTextsWidth(priceText, additionalRespawns,
        hasAdditionalHistoricalRespawns ? additionalHistoricalRespawns : "",
        spareText))

  if (specType) {
    itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
    itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
  }

  
  
  

  let showProgress = isLocalState && !isOwn && canResearch && !isInFlight()
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

  
  
  

  let progressText = showProgress ? getUnitSlotResearchProgressText(unit, priceText) : ""
  let checkNotification = getEntitlementUnitDiscount(unit.name)

  let resView = params.__merge({
    slotId              = $"td_{id}"
    bonusId             = id
    slotInactive        = inactive
    isSlotbarItem
    isInTable
    shopItemId          = id
    unitName            = unit.name
    crewId              = crew?.id.tostring()
    shopItemType        = getUnitRole(unit)
    unitClassIcon       = getUnitRoleIcon(unit)
    shopStatus          = status
    unitRarity          = unitRarity
    isBroken            = isLocalState && isBroken
    shopAirImg          = image_for_air(unit)
    isPkgDev            = unit.isPkgDev
    isRecentlyReleased  = unit.isRecentlyReleased()
    discountId          = $"{id}-discount"
    showDiscount        = isLocalState && !isOwn && (!isUnitGift(unit) || checkNotification)
    shopItemTextId      = $"{id}_txt"
    shopItemText        = getSlotUnitNameText(unit, params)
    progressText        = progressText
    progressStatus      = showProgress ? getUnitSlotProgressStatus(unit, params) : ""
    progressBlk         = handyman.renderCached("%gui/slotbar/airResearchProgress.tpl", airResearchProgressView)
    showInService       = showInService && isUsable
    isMounted           = isMounted
    priceText           = showAdditionExtraInfo ? "" : priceText
    isLongPriceText     = isUnitPriceTextLong(priceText)
    isElite             = (isLocalState && isOwn && isUnitElite(unit)) || (!isOwn && special)
    unitRankText        = getUnitSlotRankText(unit, crew, showBR, curEdiff)
    bottomLineText
    isItemLocked        = isLocalState && !isUsable && !special && !isSquadronVehicle && !isMarketableVehicle && !isUnitsEraUnlocked(unit)
    hasTalismanIcon     = isLocalState && (special || shopIsModificationEnabled(unit.name, "premExpMul"))
    itemButtons         = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", itemButtonsView)
    tooltipId           = getTooltipType("UNIT").getTooltipId(unit.name, tooltipParams)
    isTooltipByHold     = showConsoleButtons.value
    extraInfoBlock      = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", extraInfoViewBottom)
    extraInfoBlockTop   = handyman.renderCached("%gui/slotbar/slotExtraInfoBlockTop.tpl", extraInfoTopView)
    refuseOpenHoverMenu = !hasActions ? "yes" : "no"
    crewNumWithTitle    = hasCrewInfo ? $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}" : ""
    crewInfoTranslucent = showCrewInfoTranslucent ? "yes" : "no"
    hasContextCursor    = hasActions
  })
  let groupName = missionRules ? missionRules.getRandomUnitsGroupName(unit.name) : null
  let isShowAsRandomUnit = groupName
    && (is_respawn_screen()
      || !is_player_unit_alive()
      || get_player_unit_name() != unit.name)
  if (isShowAsRandomUnit) {
    resView.shopAirImg = missionRules.getRandomUnitsGroupIcon(groupName)
    resView.shopItemType = ""
    resView.unitClassIcon = ""
    resView.isElite = false
    resView.unitRarity = ""
    resView.unitRankText = ""
    resView.tooltipId = getTooltipType("RANDOM_UNIT").getTooltipId(unit.name, { groupName = groupName })
  }

  return handyman.renderCached("%gui/slotbar/slotbarSlotSingle.tpl", resView)
}

function buildUnitSlot(id, unit, params = {}) {
  let res = unit == null ? buildEmptySlot(id, unit, params)
    : isUnitGroup(unit) ? buildGroupSlot(id, unit, params)
    : unit?.isFakeUnit ? buildFakeSlot(id, unit, params)
    : buildCommonUnitSlot(id, unit, params)

  return (params?.fullBlock ?? true) ? format("unitCell{%s}", res) : res
}

function fillUnitSlotTimers(holderObj, unit) {
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

    
    let isRented = rentedUnit.isRented()
    if (isRented) {
      let objRentProgress = obj.findObject("rent_progress")
      if (checkObj(objRentProgress)) {
        let totalRentTimeSec = rented_units_get_last_max_full_rent_time(rentedUnit.name) || -1
        let progress = 360 - round(360.0 * rentedUnit.getRentTimeleft() / totalRentTimeSec).tointeger()
        if (objRentProgress["sector-angle-1"] != progress)
          objRentProgress["sector-angle-1"] = progress

        isActive = true
      }
    }
    else { 
      let rentInfo = getUnitSlotRentInfo(rentedUnit, params)

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

function getSlotObjId(countryId, idInCountry) {
  assert(countryId != null, "Country ID is null.")
  assert(idInCountry != null, "Crew IDX is null.")
  return $"slot_{countryId}_{idInCountry}"
}

function getSlotObj(slotbarObj, countryId, idInCountry) {
  if (!checkObj(slotbarObj))
    return null
  let slotObj = slotbarObj.findObject(getSlotObjId(countryId, idInCountry))
  return checkObj(slotObj) ? slotObj : null
}

function isUnitEnabledForSlotbar(unit, params) {
  if (!unit || unit.disableFlyout)
    return false

  local res = true
  let { eventId = null, room = null, availableUnits = null,
    roomCreationContext = null, mainMenuSlotbar = null, missionRules = null
  } = params

  if (eventId != null) {
    res = false
    let event = events.getEvent(eventId)
    if (event)
      res = events.isUnitAllowedForEventRoom(event, room, unit)
  }
  else if (availableUnits != null)
    res = unit.name in availableUnits
  else if (isInSessionRoom.get() && !isInFlight())
    res = isUnitAllowedForRoom(unit)
  else if (roomCreationContext != null)
    res = roomCreationContext.isUnitAllowed(unit)

  if (!res)
    return res

  res = !mainMenuSlotbar || isUnitAllowedForGameMode(unit)
  if (!res || missionRules == null)
    return res

  let isAvaliableUnit = (missionRules.getUnitLeftRespawns(unit) != 0
    || missionRules.isUnitAvailableBySpawnScore(unit))
    && missionRules.isUnitEnabledByRandomGroups(unit.name)
  let isControlledUnit = !is_respawn_screen()
    && is_player_unit_alive()
    && get_player_unit_name() == unit.name

  return isAvaliableUnit || isControlledUnit
}

addTooltipTypes({
  UNIT = { 
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params) {
      let actionsList = handlersManager.findHandlerClassInScene(gui_handlers.ActionsList)
      if (actionsList && actionsList?.params.needCloseTooltips) {
        let transparentDirection = to_integer_safe(actionsList?.scene["_transp-direction"], 0, false)
        if (transparentDirection > -1) {
          if (!showConsoleButtons.value || (is_mouse_last_time_used() && !params?.isOpenByHoldBtn))
            return false
          actionsList.close()
        }
      }

      if (!checkObj(obj))
        return false
      let unit = getAircraftByName(id)
      if (!unit)
        return false
      let guiScene = obj.getScene()
      guiScene.setUpdatesEnabled(false, false)
      guiScene.replaceContent(obj, "%gui/airTooltip.blk", handler)
      let contentObj = obj.findObject("air_info_tooltip")
      ::showAirInfo(unit, true, contentObj, handler, params)
      guiScene.setUpdatesEnabled(true, true)

      let flagCard = contentObj.findObject("aircraft-countryImg")
      let rhInPixels = toPixels(obj.getScene(), "1@rh")
      if (obj.getSize()[1] < rhInPixels) {
        if (flagCard?.isValid()) {
          flagCard.show(false)
        }
        return true
      }

      let unitImgObj = contentObj.findObject("aircraft-image-nest")
      if (!unitImgObj?.isValid())
        return true

      let unitImageHeightBeforeFit = unitImgObj.getSize()[1]
      let isVisibleUnitImg = unitImageHeightBeforeFit - (obj.getSize()[1] - rhInPixels) >= 0.5*unitImageHeightBeforeFit
      if (isVisibleUnitImg) {
        contentObj.height = "1@rh - 2@framePadding"
        unitImgObj.height = "fh"
        if (flagCard?.isValid()) {
          flagCard.show(false)
        }
      } else {
        unitImgObj.show(isVisibleUnitImg)
      }
      return true
    }
    onEventUnitModsRecount = function(eventParams, obj, handler, id, params) {
      if (id == getTblValue("name", getTblValue("unit", eventParams)))
        this.fillTooltip(obj, handler, id, params)
    }
    onEventSecondWeaponModsUpdated = function(eventParams, obj, handler, id, params) {
      if (id == getTblValue("name", getTblValue("unit", eventParams)))
        this.fillTooltip(obj, handler, id, params)
    }
  }

  UNIT_GROUP = {
    isCustomTooltipFill = true
    getTooltipId = function(group, params = null) {
      return this._buildId({ units = group?.units.keys(), name = group?.name }, params)
    }
    fillTooltip = function(obj, handler, group, _params) {
      if (!checkObj(obj))
        return false

      let name = loc("ui/quotes", { text = loc(group.name) })
      let list = []
      foreach (str in group.units) {
        let unit = getAircraftByName(str)
        if (!unit)
          continue

        list.append({
          unitName = getUnitName(str)
          icon = getUnitClassIco(str)
          shopItemType = getUnitRole(unit)
        })
      }

      let columns = []
      let unitsInArmyRowsMax = max(floor(list.len() / 2).tointeger(), 3)
      let hasMultipleColumns = list.len() > unitsInArmyRowsMax
      if (!hasMultipleColumns)
        columns.append({ groupList = list })
      else {
        columns.append({ groupList = list.slice(0, unitsInArmyRowsMax), isFirst = true })
        columns.append({ groupList = list.slice(unitsInArmyRowsMax) })
      }

      let data = handyman.renderCached("%gui/tooltips/unitGroupTooltip.tpl", {
        title = $"{loc("unitsGroup/groupContains", { name = name})}{loc("ui/colon")}",
        hasMultipleColumns = hasMultipleColumns,
        columns = columns
      })
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  RANDOM_UNIT = { 
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!checkObj(obj))
        return false
      let groupName = params?.groupName
      let missionRules = getCurMissionRules()
      if (!groupName || !missionRules)
        return false

      let unitsList = missionRules.getRandomUnitsList(groupName)
      let unitsView = []
      local unit
      foreach (unitName in unitsList) {
        unit = getAircraftByName(unitName)
        if (!unit)
          unitsView.append({ name = unitName })
        else
          unitsView.append({
            name = getUnitName(unit)
            unitClassIcon = getUnitClassIco(unit.name)
            shopItemType = getUnitRole(unit)
            tooltipId = getTooltipType("UNIT").getTooltipId(unit.name, { needShopInfo = true })
          })
      }

      let tooltipParams = {
        groupName = loc("respawn/randomUnitsGroup/description",
          { groupName = colorize("activeTextColor", missionRules.getRandomUnitsGroupLocName(groupName)) })
        rankGroup = loc("ui/colon").concat(loc("shop/age"),
          colorize("activeTextColor", missionRules.getRandomUnitsGroupLocRank(groupName)))
        battleRatingGroup = loc("ui/colon").concat(loc("shop/battle_rating"),
          colorize("activeTextColor", missionRules.getRandomUnitsGroupLocBattleRating(groupName)))
        units = unitsView
      }
      let data = handyman.renderCached("%gui/tooltips/randomUnitTooltip.tpl", tooltipParams)

      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

function getSlotCrewHint(crew, unit, params) {
  let hasUnit = unit != null
  let crewSpec = hasUnit
    ? getSpecTypeByCrewAndUnit(crew, unit)
    : null

  let isMaxLevel = (crew && unit)
    ? isCrewMaxLevel(crew, unit, crew.country, unit.getCrewUnitType())
    : ""
  let needCurPoints = (crew != null) && !isMaxLevel
  let crewLevelText = (crew && unit)
    ? getCrewLevel(crew, unit, unit.getCrewUnitType()).tointeger().tostring()
    : ""

  let data = {
    hasUnit
    crewNumWithTitle = $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}"
    crewLevel = crewLevelText
    crewSpecializationLabel = hasUnit ? $"{loc("crew/trained")}{loc("ui/colon")}" : ""
    crewSpecializationIcon = hasUnit ? crewSpec?.trainedIcon : ""
    crewSpecialization = hasUnit ? crewSpec?.getName() : ""
    needCurPoints
    crewPoints = (hasUnit && needCurPoints) ? getCrewSpText(crew?.skillPoints ?? 0) : ""
  }
  data.__update(params)

  return handyman.renderCached("%gui/slotbar/slotCrewInfo.tpl", data)
}

return {
  buildUnitSlot
  fillUnitSlotTimers
  getSlotObjId
  getSlotObj
  getSlotUnitNameText
  isUnitPriceTextLong
  getUnitSlotPriceText
  getUnitSlotPriceHintText
  getUnitSlotRankText
  isUnitEnabledForSlotbar
  getSpareCountText
  calcUnitSlotMissionInfoTextsWidth
  getSlotCrewHint
}
