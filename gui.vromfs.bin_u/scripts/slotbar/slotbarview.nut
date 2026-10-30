import "%scripts/time.nut" as time
from "%scripts/langUtils/harmonized.nut" import is_harmonized_unit_image_required
from "%scripts/events/eventsManager.nut" import events
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/daguiUtil.nut" import removeTextareaTags, toPixels
from "%scripts/money.nut" import Cost
from "%scripts/unit/unitInfo.nut" import getUnitName, bit_unit_status, getUnitReqExp, getUnitExp, image_for_air
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit, isUnitGift, isUnitBought
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/unit/unitInfoTexts.nut" import getUnitItemStatusText, getUnitRarity, getUnitClassIco
from "%scripts/unit/unitInfoRoles.nut" import getUnitRole, getUnitRoleIcon
from "%scripts/unit/unitStatus.nut" import isUnitElite, isUnitDefault, canResearchUnit, isUnitUsable, isUnitInResearch, isUnitsEraUnlocked, isUnitGroup, isUnitBroken
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitInSlotbar
from "%scripts/unit/unitBitStatus.nut" import getBitStatus
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/weaponry/weaponryInfo.nut" import getLastWeapon, checkUnitWeapons, getWeaponsStatusName
from "%scripts/weaponry/bulletsInfo.nut" import getUnitLastBullets
from "%scripts/respawn/respawnState.nut" import isCrewAvailableInSession, isSpareAircraftInSlot, isRespawnWithUniversalSpare, isUnitDisabledByMatching
from "%scripts/shop/unitCardPkg.nut" import getUnitShopPriceText
from "%scripts/misCustomRules/missionCustomState.nut" import getCurMissionRules
from "%scripts/slotbar/crewsList.nut" import getCrewById
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff, isUnitAllowedForGameMode
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom
from "%scripts/crew/crew.nut" import getCrewLevel, isCrewMaxLevel, isCrewNeedUnseenIcon
from "%scripts/crew/crewSpecType.nut" import getSpecTypeByCrewAndUnit
from "%scripts/crew/crewPointsText.nut" import getCrewSpText
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx
from "%scripts/events/eventInfo.nut" import getEventEconomicName
from "%scripts/shop/shopCountryInfo.nut" import get_units_count_at_rank
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getRoomEvent, isUnitAllowedForRoom
from "%scripts/options/optionsExt.nut" import get_unit_preset_img
from "%scripts/discounts/discountsState.nut" import getEntitlementUnitDiscount
from "%scripts/unit/canBuyUnitOnMarketplace.nut" import canBuyUnitOnMarketplace
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "%scripts/unit/unitMrankSelectionState.nut" import getUnitSelectedBattleRating
from "unit" import get_player_unit_name, is_player_unit_alive
from "string" import format, split_by_chars
from "math" import round
from "gameplayBinding" import isInFlight
from "chardResearch" import shopIsModificationEnabled
from "guiMission" import get_max_spawns_unit_count, get_unit_wp_to_respawn
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "mission" import get_game_mode
from "dagor.debug" import debug_dump_stack
from "%scripts/dagui_natives.nut" import clan_get_exp, get_spare_aircrafts_count, get_slot_delay, shop_get_spawn_score, is_era_available, rented_units_get_last_max_full_rent_time, utf8_strlen
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/misCustomRules/ruleConsts.nut" import RESPAWNS_UNLIMITED
from "%scripts/utils_sa.nut" import colorTextByValues, get_tomoe_unit_icon
from "%scripts/clans/clanState.nut" import is_in_clan
from "guiRespawn" import getNumUsedUnitSpawns, isRespawnScreen

let SecondsUpdater = require("%scripts/sqDagui/timer/secondsUpdater.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")


const DEFAULT_STATUS = "none"

let objectsVisibilityByUnitSlotType = {
  common = {
    shopAirImg = true
    crewImage = false
    eliteIcon = true
    progressDiv = true
    classIconPlace = true
    weapons_icon = false
  }
  empty = {
    shopInServiceImg = false
    shopAirImg = false
    crewImage = true
    recentlyReleasedIcon = false
    eliteIcon = false
    talismanIcon = false
    progressDiv = false
    classIconPlace = false
    bottomLineTextDiv = false
    rank_text = false
    extraInfoBlockTop = false
    slotBtn_battle = false
    rent_icon = false
    weapons_icon = false
    repair_icon = false
    crewNumText = true
  }
}

let suffixTable = {
  shopItem = ""
  shopItemText = "_txt"
  discount = "-discount"
  bonus = "-bonus"
}

function updateVisibilityObjectsByUnitSlotType(slotObj, slotType) {
  showObjectsByTable(slotObj, objectsVisibilityByUnitSlotType[slotType])
  slotObj.slotType = slotType
}

function getSlotPartIdFromSlotId(slotId, slotPart) {
  return $"{slotId}{suffixTable?[slotPart] ?? ""}"
}

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

  let maxTime = rented_units_get_last_max_full_rent_time(unit.name)
  let totalRentTimeSec = maxTime == 0 ? -1 : maxTime
  info.progress = (360 - round(360.0 * unit.getRentTimeleft() / totalRentTimeSec).tointeger())

  return info
}

function getItemButtonsEmpty(specType) {
  return specType == null ? { specIconBlock = false }
    : {
      specIconBlock = true
      specTypeIcon = specType.trainedIcon
      specTypeTooltip = specType.getName()
    }
}

function getItemButtonsCommon(unit, params) {
  let { toBattle = false, showWarningIcon = false, specType = null, toBattleButtonAction = "onSlotBattle",
    hasExtraInfoBlockTop = false, isLocalState = true } = params

  let rentInfo = getUnitSlotRentInfo(unit, params)

  return {
    hasToBattleButton = toBattle
    toBattleButtonAction
    hasExtraInfoBlockTop
    specIconBlock = showWarningIcon || specType != null
    showWarningIcon = showWarningIcon
    hasRepairIcon = isLocalState && isUnitBroken(unit)
    weaponsStatus = getWeaponsStatusName(isLocalState && isUnitUsable(unit) ? checkUnitWeapons(unit) : UNIT_WEAPONS_READY)
    hasRentIcon = rentInfo.hasIcon
    hasRentProgress = rentInfo.hasProgress
    rentProgress = rentInfo.progress
    specTypeIcon = specType?.trainedIcon
    specTypeTooltip = specType?.getName() ?? ""
  }
}

function getExtraInfoBottomDataEmpty(params) {
  let { forceCrewInfoUnit = null, crewId = -1, hasActions = false, crew = null } = params

  let hasCrew = crew != null

  let extraInfoBlock = (forceCrewInfoUnit != null && hasCrew) ? {
      hasExtraInfoBlock = true
      hasCrewIdTextInfo = false
      hasCrewInfo       = true
      crewNum           = $"{crew.idInCountry + 1}"
      crewLevel         = getCrewLevel(crew, forceCrewInfoUnit, forceCrewInfoUnit.getCrewUnitType()).tointeger().tostring()
      crewSpecIcon      = getSpecTypeByCrewAndUnit(crew, forceCrewInfoUnit).trainedIcon
      isEmptySlot       = "yes"
      crewId
      forcedUnit        = forceCrewInfoUnit.name

    } : hasCrew ? {
      hasExtraInfoBlock = true
      hasCrewIdTextInfo = true
      hasActions
      crewNum = $"{crew.idInCountry + 1}"
      isEmptySlot = "yes"
      crewNumWithTitle = $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}"
      crewId = crewId.tostring()
      crewIdInCountry = crew?.idInCountry
    } : {}

  return extraInfoBlock
}

function getSlotUnitNameText(unit, params) {
  local res = getUnitName(unit)
  let { missionRules = null, showAdditionExtraInfo = false } = params
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
    unlocked = true, sessionWpBalance = 0, weaponPrice = 0,
    totalSpawnScore = -1, overlayPrice = -1, showAsTrophyContent = false,
    isReceivedPrizes = false, crew = null, missionRules = null
  } = params
  local { spawnDelay = null } = params

  local priceText = ""
  if ((haveRespawnCost || haveSpawnDelay || missionRules?.isRageTokensRespawnEnabled) && unlocked) {
    spawnDelay = haveSpawnDelay ? (spawnDelay ?? get_slot_delay(unit.name, 0)) : 0
    if (spawnDelay > 0)
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
      let br = getUnitSelectedBattleRating(un, ediff)
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
  let battleRatingStr = format("%.1f", getUnitSelectedBattleRating(unit, ediff))
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
    return $"{loc("icon/universalSpare")} {loc("ui/minus")} {loc("mission_hint/spare/universal_spawn")}"
  if (crew && isSpareAircraftInSlot(crew.idInCountry))
    return hasSpare
      ? $"{spareCount}{loc("icon/universalSpare")} {loc("ui/minus")} {loc("mission_hint/spare/spawn")}"
      : loc("icon/universalSpare")
  if (hasSpare)
    return $"{spareCount}{loc("icon/spare")} {loc("ui/minus")} {loc("mission_hint/spare")}"
  return ""
}

function getUnitSlotPriceHintText(unit, params) {
  let { haveRespawnCost = false, haveSpawnDelay = false,
    unlocked = true, sessionWpBalance = 0, weaponPrice = 0,
    totalSpawnScore = -1, crew = null, hasAlternativeBase = false
  } = params
  local { spawnDelay = null } = params

  if (!unlocked || !(haveRespawnCost || haveSpawnDelay))
    return ""

  spawnDelay = haveSpawnDelay ? (spawnDelay ?? get_slot_delay(unit.name, 0)) : 0
  if (spawnDelay > 0) {
    let delayHint = $"{time.secondsToString(spawnDelay)} {loc("ui/minus")} {loc("mission_hint/spawn_delay")}"
    return hasAlternativeBase
      ? $"{delayHint}\n{loc("mission_hint/spawn_delay_alternative_base")}"
      : delayHint
  }

  local hintTexts = []

  local wpToRespawn = get_unit_wp_to_respawn(unit.name)
  if (wpToRespawn > 0 && crew != null && isCrewAvailableInSession(crew, unit)) {
    wpToRespawn += weaponPrice
    let wpToRespawnText = colorTextByValues(Cost(wpToRespawn).toStringWithParams({ isWpAlwaysShown = true }),
      sessionWpBalance, wpToRespawn, true, false)
    hintTexts.append($"{wpToRespawnText} {loc("ui/minus")} {loc("mission_hint/cost_sl")}")
  }

  let reqUnitSpawnScore = shop_get_spawn_score(unit.name, getLastWeapon(unit.name), getUnitLastBullets(unit))
  if (reqUnitSpawnScore > 0 && totalSpawnScore > -1) {
    local reqSpawnScoreText = loc("shop/spawnScore", { cost = reqUnitSpawnScore })
    let totalSpawnScoreText = loc("shop/spawnScore", { cost = totalSpawnScore })
    if (reqUnitSpawnScore > totalSpawnScore)
      reqSpawnScoreText = colorize("badTextColor", reqSpawnScoreText)
    hintTexts.append($"{reqSpawnScoreText} {loc("ui/minus")} {loc("mission_hint/cost_sp", { current_cost_sp = totalSpawnScoreText})}")
  }

  return hintTexts.len() > 0 ? "\n".join(hintTexts, true) : ""
}

function getRandomUnitHintData(groupName, missionRules) {
  if (!groupName || !missionRules)
    return false

  let unitsList = missionRules.getRandomUnitsList(groupName)
  let randomUnits = []

  foreach (unitName in unitsList) {
    let unit = getAircraftByName(unitName)
    if (!unit)
      randomUnits.append({ name = unitName })
    else
      randomUnits.append({
        name = getUnitName(unit)
        unitClassIcon = getUnitClassIco(unit.name)
        shopItemType = getUnitRole(unit)
      })
  }

  return randomUnits
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
    isTooltipByHold     = showConsoleButtons.get()
  })
  return handyman.renderCached("%gui/slotbar/slotbarSlotFake.tpl", fakeSlotView)
}

function buildEmptySlot(id, _unit, params) {
  let { specType = null, emptyCost = null,
    crewId = -1, isShowDragAndDropIcon = false } = params

  let crew = crewId >= 0 ? getCrewById(crewId) : null
  let hasCrew = crew != null
  let extraInfoData = getExtraInfoBottomDataEmpty(params.__merge({ crew }))
  let itemButtons = getItemButtonsEmpty(specType)

  let priceText = emptyCost ? emptyCost.getTextAccordingToBalance() : ""
  let emptySlotView = params.__merge({
    slotId = $"td_{id}"
    shopItemId = id
    shopItemTextId = $"{id}_txt"
    shopItemTextValue = params?.emptyText ?? ""
    shopStatus = params?.status
    shopItemPriceText = priceText
    itemButtons = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", { itemButtons })
    extraInfoBlock = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", extraInfoData)
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
    else if (!isUsable && !firstUnboughtUnit && (canBuyUnit(a) || canBuyUnitOnline(a)))
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
    hasButton           = showConsoleButtons.get()
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
    isTooltipByHold     = showConsoleButtons.get()
    bottomButton        = handyman.renderCached("%gui/slotbar/slotbarItemBottomButton.tpl", bottomButtonView)
    hasFullGroupBlock   = params?.fullGroupBlock ?? true
    fullGroupBlockId    = $"td_{id}"
    isGroupInactive     = inactive
  })

  return handyman.renderCached("%gui/slotbar/slotbarSlotGroup.tpl", groupSlotView)
}

function getAirResearchProgressData(params) {
  let { showProgress, unitExpGranted, isLockedSquadronVehicle, unitReqExp, isVehicleInResearch,
    forceNotInResearch, diffExp } = params

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
  return airResearchProgressView
}

function getExtraInfoBottomDataCommon(unit, params) {
  let { hasActions = false, forceCrewInfoUnit = null, crewId = -1,
    showCrewUnseenIcon = false, hasExtraInfoBlock = false, crew } = params

  let hasCrewInfo = crewId >= 0
  if (hasCrewInfo) {
    let unitForCrewInfo = forceCrewInfoUnit || unit
    let crewSpec = getSpecTypeByCrewAndUnit(crew, unitForCrewInfo)
    let crewLevelText = (crew && unitForCrewInfo) ? getCrewLevel(crew, unitForCrewInfo, unitForCrewInfo.getCrewUnitType()).tointeger().tostring() : ""

    return {
      crewId
      hasExtraInfoBlock
      hasCrewInfo
      hasActions
      crewLevel = crewLevelText
      crewSpecIcon = crewSpec.trainedIcon
      hasCrewUnseenIcon = showCrewUnseenIcon && isCrewNeedUnseenIcon(crew, unitForCrewInfo) ? "yes" : "no"
      crewNum = $"{(crew?.idInCountry ?? 0) + 1}"
      crewIdInCountry = crew?.idInCountry
      forcedUnit = null
      hasCrewIdTextInfo = false
    }
  }

  return {
    hasExtraInfoBlock = false
  }
}

function getExtraInfoTopData(unit, params) {
  let { isLocalState = true, missionRules = null, hasExtraInfoBlockTop = false,
    showAdditionExtraInfo = false, crew, priceText, isRandomUnit } = params

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
      leftHistoricalSpawns = max(0, maxSpawns - numSpawns)
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
  let priceHintText = hasPriceText ? getUnitSlotPriceHintText(unit, params) : ""
  let additionalHistoricalRespawnsHintText = hasAdditionalHistoricalRespawns
    ? $"{additionalHistoricalRespawns} {loc("ui/minus")} {loc("mission_hint/spawns_per_battle", { unit_name = getUnitName(unit.name)})}"
    : ""
  let additionalRespawnsHintText = hasAdditionalRespawns
    ? $"{additionalRespawns} {loc("ui/minus")} {loc("mission_hint/spawns_per_unit", {army = armyLocName})}"
    : ""

  let groupName = missionRules?.getRandomUnitsGroupName(unit.name)
  let randomUnits = isRandomUnit ? getRandomUnitHintData(groupName, missionRules) : null
  let hasRandomUnitsList = (randomUnits?.len() ?? 0) > 1

  let isUnitDisabled = isInFlight() && crew && isUnitDisabledByMatching(crew.idInCountry)
  let unitClassIco = getUnitClassIco(unit.name)

  let extraInfoTopView = {
    hasExtraInfo = false
    hasExtraInfoBlockTop
    hasPriceText = false
    hasSpareInfo = false
    hasAdditionalRespawns = false
    hasAdditionalHistoricalRespawns = false
    hasDice = false
    priceHintText
    hasPriceSeparator = false
    hasAdditionalRespawnsSeparator = false
    hasSpareSeparator = false
    hasDiceSeparator = false
    priceText
    priceWidth = "fw"
    isRandomUnit
    hasRandomUnitsList
    randomUnits
    addHistoricalRespawnsWidth = "fw"
    unitClassIco
    unitClassIcoColor
    additionalHistoricalRespawns
    additionalRespawns
    addRespawnsWidth = "fw"
    spareCount = spareText
    spareHintText
    additionalRespawnsHintText
    additionalHistoricalRespawnsHintText
  }

  if (!isUnitDisabled)
    extraInfoTopView.__update({
      hasPriceSeparator = hasPriceText && hasAdditionalHistoricalRespawns
      hasAdditionalRespawnsSeparator = hasAdditionalRespawns && (hasPriceText || hasAdditionalHistoricalRespawns)
      hasSpareSeparator = hasSpareInfo && (hasPriceText || hasAdditionalRespawns || hasAdditionalHistoricalRespawns)
      hasExtraInfo = hasPriceText || hasAdditionalRespawns || hasSpareInfo || hasAdditionalHistoricalRespawns || isRandomUnit
      hasDiceSeparator = isRandomUnit && (hasPriceText || hasAdditionalRespawns || hasAdditionalHistoricalRespawns || hasSpareInfo)
      hasDice = isRandomUnit
      hasPriceText
      hasSpareInfo
      hasAdditionalRespawns
      hasAdditionalHistoricalRespawns
    })

  if (hasPriceText && !isUnitDisabled)
    extraInfoTopView.__update(calcUnitSlotMissionInfoTextsWidth(priceText, additionalRespawns,
      hasAdditionalHistoricalRespawns ? additionalHistoricalRespawns : "", spareText))

  return extraInfoTopView
}

function getCommonSlotData(unit, params) {
  let { inactive = false, status = DEFAULT_STATUS, isLocalState = true, missionRules = null, tooltipParams = {}, shopResearchMode = false,
    forceNotInResearch = false, showInService = false, crewId = -1, showBR = hasFeature("GlobalShowBattleRating"),
    showCrewInfoTranslucent = false, hasActions = false } = params

  local slotInactive = inactive
  local shopStatus = status
  if (shopStatus == DEFAULT_STATUS) {
    let bitStatus = getBitStatus(unit, params)
    if (bit_unit_status.locked & bitStatus)
      slotInactive = shopResearchMode
    else if (bit_unit_status.disabled & bitStatus)
      slotInactive = true
    shopStatus = getUnitItemStatusText(bitStatus, false)
  }

  let hasCrewInfo = crewId >= 0
  let crew = params?.crew ?? (hasCrewInfo ? getCrewById(crewId) : null)
  let groupName = missionRules?.getRandomUnitsGroupName(unit.name)
  let isRandomUnit = groupName && (isRespawnScreen() || !is_player_unit_alive() || get_player_unit_name() != unit.name)
  let isOwn = isUnitBought(unit)
  let isUsable = isUnitUsable(unit)
  let special = isUnitSpecial(unit)
  let isVehicleInResearch = isUnitInResearch(unit) && !forceNotInResearch
  let isSquadronVehicle = unit.isSquadronVehicle()
  let unitReqExp = getUnitReqExp(unit)
  local unitExpGranted = getUnitExp(unit)
  let diffExp = isSquadronVehicle
    ? min(clan_get_exp(), unitReqExp - unitExpGranted)
    : (params?.diffExp ?? 0)
  if (isSquadronVehicle && isVehicleInResearch)
    unitExpGranted += diffExp

  let isLockedSquadronVehicle = isSquadronVehicle && !is_in_clan() && diffExp <= 0
  let showProgress = isLocalState && !isOwn && canResearchUnit(unit) && !isInFlight() && (!isLockedSquadronVehicle || unitExpGranted > 0)
  let priceText = getUnitSlotPriceText(unit, params.__merge({ crew }))

  let airResearchProgressView = getAirResearchProgressData({ showProgress, unitExpGranted, isLockedSquadronVehicle,
    unitReqExp, isVehicleInResearch, forceNotInResearch, diffExp })

  let airResearchProgressBlk = handyman.renderCached("%gui/slotbar/airResearchProgress.tpl", airResearchProgressView)

  return {
    shopStatus
    slotInactive
    hasCrewInfo
    crew
    isRandomUnit
    priceText
    showDiscount = isLocalState && !isOwn && (!isUnitGift(unit) || getEntitlementUnitDiscount(unit.name))
    tooltipId = getTooltipType("UNIT").getTooltipId(unit.name, tooltipParams.__update({ isRandomUnit }))
    isElite = (isLocalState && isOwn && isUnitElite(unit)) || (!isOwn && special)
    showInService = showInService && isUsable
    isItemLocked = params?.isItemLocked ??
      (isLocalState && !isUsable && !special && !isSquadronVehicle && !canBuyUnitOnMarketplace(unit) && !isUnitsEraUnlocked(unit))
    isMounted = isUnitInSlotbar(unit)
    isBroken = isLocalState && isUnitBroken(unit)
    hasTalismanIcon = isLocalState && (special || shopIsModificationEnabled(unit.name, "premExpMul"))
    crewNumWithTitle = hasCrewInfo ? $"{loc("mainmenu/crewTitle")}{(crew?.idInCountry ?? 0) + 1}" : ""
    shopItemText = getSlotUnitNameText(unit, params)
    isLongPriceText = isUnitPriceTextLong(priceText)
    progressText = showProgress ? getUnitSlotResearchProgressText(unit, priceText) : ""
    progressStatus = showProgress ? getUnitSlotProgressStatus(unit, params) : ""
    unitRarity = getUnitRarity(unit)
    unitRankText = getUnitSlotRankText(unit, crew, showBR, params?.getEdiffFunc() ?? getCurrentGameModeEdiff())
    crewInfoTranslucent = showCrewInfoTranslucent ? "yes" : "no"
    refuseOpenHoverMenu = !hasActions ? "yes" : "no"
    hasContextCursor = hasActions
    shopItemType = getUnitRole(unit)
    unitClassIcon = getUnitRoleIcon(unit)
    shopAirImg = image_for_air(unit)
    airResearchProgressBlk
  }
}

function buildCommonUnitSlot(id, unit, params) {
  let { showAdditionExtraInfo = false, isInTable = true } = params

  let commonSlotData = getCommonSlotData(unit, params)
  let { crew, priceText, isRandomUnit, airResearchProgressBlk } = commonSlotData

  let extraInfoTopView = getExtraInfoTopData(unit, params.__merge({ crew, priceText, isRandomUnit }))
  let { hasPriceText, hasSpareInfo, hasAdditionalRespawns, hasAdditionalHistoricalRespawns } = extraInfoTopView

  if (hasPriceText && hasSpareInfo && hasAdditionalRespawns && hasAdditionalHistoricalRespawns) {
    let roomEvent = getRoomEvent()
    let economicName = roomEvent != null ? getEventEconomicName(roomEvent) : null
    let unitName = unit.name
    debug_dump_stack()
    logerr($"[SLOTBAR] unit slot missiton block has 4 blocks /*economicName = {economicName}, unitName = {unitName}*/")
  }

  let itemButtons = getItemButtonsCommon(unit, params)
  let extraInfoViewBottom = getExtraInfoBottomDataCommon(unit, params.__merge({ crew })).__merge({ isEmptySlot = "no" })

  let resView = params.__merge(commonSlotData, {
    slotId              = $"td_{id}"
    isInTable
    bonusId             = id
    shopItemId          = id
    unitName            = unit.name
    crewId              = crew?.id.tostring()
    isPkgDev            = unit.isPkgDev
    isRecentlyReleased  = unit.isRecentlyReleased()
    discountId          = $"{id}-discount"
    shopItemTextId      = $"{id}_txt"
    priceText           = showAdditionExtraInfo ? "" : priceText
    isTooltipByHold     = showConsoleButtons.get()
    progressBlk         = airResearchProgressBlk
    itemButtons         = handyman.renderCached("%gui/slotbar/slotbarItemButtons.tpl", { itemButtons })
    extraInfoBlock      = handyman.renderCached("%gui/slotbar/slotExtraInfoBlock.tpl", extraInfoViewBottom)
    extraInfoBlockTop   = handyman.renderCached("%gui/slotbar/slotExtraInfoBlockTop.tpl", extraInfoTopView)
  })

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
    if (!isUnitGroup(unit) && rentedUnit.name != obj?.unit_name)
      return true

    local isActive = false

    
    let isRented = rentedUnit.isRented()
    if (isRented) {
      let objRentProgress = obj.findObject("rent_progress")
      if (checkObj(objRentProgress)) {
        let maxTime = rented_units_get_last_max_full_rent_time(unit.name)
        let totalRentTimeSec = maxTime == 0 ? -1 : maxTime
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
  return checkObj(slotObj) && slotObj.isVisible() ? slotObj : null
}

function isUnitEnabledForSlotbar(unit, params, customGameMode = null) {
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

  res = !mainMenuSlotbar || isUnitAllowedForGameMode(unit, customGameMode)
  if (!res || missionRules == null)
    return res

  let isAvaliableUnit = (missionRules.getUnitLeftRespawns(unit) != 0
    || missionRules.isUnitAvailableBySpawnScore(unit))
    && missionRules.isUnitEnabledByRandomGroups(unit.name)
  let isControlledUnit = !isRespawnScreen()
    && is_player_unit_alive()
    && get_player_unit_name() == unit.name

  return isAvaliableUnit || isControlledUnit
}

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

function updateCommonSlotData(slotObj, params) {
  let { slotObjId, unit, hasActions = false, crewId = -1, bottomLineText = null,
    isSlotbarItem = false, isInTable = true, hasExtraInfoBlockTop = false, hasLockedIcon = false,
    translucentText = false, slotbarWidgetHandler, selectOnHover = false, isCrewRecruit = false,
    needDnD = false, showAdditionExtraInfo = false } = params

  if (slotObj.slotType != "common")
    updateVisibilityObjectsByUnitSlotType(slotObj, "common")

  let { crew, shopStatus, slotInactive, hasCrewInfo, isRandomUnit, tooltipId, showDiscount, isElite, showInService,
    hasTalismanIcon, crewNumWithTitle, priceText, progressText, progressStatus, isMounted, isItemLocked,
    isBroken, unitRarity, unitRankText, crewInfoTranslucent, refuseOpenHoverMenu, hasContextCursor,
    isLongPriceText, shopItemText, shopItemType, unitClassIcon, shopAirImg, airResearchProgressBlk } = getCommonSlotData(unit, params)

  slotObj.inactive = isInTable && slotInactive ? "yes" : "no"
  slotObj.chosen = isInTable && isSlotbarItem ? "no" : "yes"
  slotObj.selected = isInTable && isSlotbarItem ? "no" : "yes"
  slotObj.crewId = crewId.tostring()
  slotObj.hasSelectedState = "yes"
  slotObj.isCrewRecruit = isCrewRecruit ? "yes" : "no"
  slotObj.updateEventHandler("on_end_edit", needDnD ? "onCrewDropFinish" : "", slotbarWidgetHandler)
  slotObj.updateEventHandler("on_drag_drop", needDnD ? "onCrewDrop" : "", slotbarWidgetHandler)
  slotObj.updateEventHandler("on_move", needDnD ? "onCrewMove" : "", slotbarWidgetHandler)
  slotObj.updateEventHandler("on_mouse_enter", selectOnHover ? "onUnitSlotMouseEnter" : "", slotbarWidgetHandler)

  slotObj.tooltipId = showConsoleButtons.get() ? tooltipId : ""

  let shopItemObj = slotObj.findObject(slotObjId)
  shopItemObj.tooltipId = showConsoleButtons.get() ? tooltipId : ""
  if(!showConsoleButtons.get()) {
    let tooltipObj = slotObj.findObject("tooltipObj")
    tooltipObj.tooltipId = tooltipId
  }

  shopItemObj.unit_name = unit.name
  shopItemObj.shopStat = shopStatus
  shopItemObj.unitRarity = unitRarity
  shopItemObj.isBroken = isBroken ? "yes" : "no"
  shopItemObj.isPkgDev = unit.isPkgDev ? "yes" : "no"
  shopItemObj.crew_id = crewId.tostring()
  shopItemObj.crewInfoTranslucent = crewInfoTranslucent
  shopItemObj.updateEventHandler("on_drag_start", needDnD ? "onUnitCellDragStart" : "", slotbarWidgetHandler)
  shopItemObj.updateEventHandler("on_drag_drop", needDnD ? "onUnitCellDrop" : "", slotbarWidgetHandler)
  shopItemObj.updateEventHandler("on_move", needDnD ? "onUnitCellMove" : "", slotbarWidgetHandler)
  shopItemObj.dragParent = needDnD ? "yes" :"no"
  shopItemObj.refuseOpenHoverMenu = refuseOpenHoverMenu
  shopItemObj.cursor = hasContextCursor ? "context-menu" : "normal"
  shopItemObj.isEmptySlot = "no"

  let shopInServiceImgObj = showObjById("shopInServiceImg", showInService, shopItemObj)
  if (showInService)
    shopInServiceImgObj.mounted = isMounted ? "yes" : "no"

  shopItemObj.isElite = isElite ? "yes" : "no"

  let shopAirImgObj = shopItemObj.findObject("shopAirImg")
  shopAirImgObj["foreground-image"] = shopAirImg

  showObjById("slotTopGradientLine", isSlotbarItem, shopItemObj)
  showObjById("slotBottomGradientLine", isSlotbarItem, shopItemObj)
  showObjById("recentlyReleasedIcon", unit.isRecentlyReleased(), shopItemObj)
  showObjById("talismanIcon", hasTalismanIcon, shopItemObj)

  let discountNotificationObj = showObjById(getSlotPartIdFromSlotId(slotObjId, "discount"), true, shopItemObj)
  discountNotificationObj.showDiscount = showDiscount ? "yes" : "no"

  showObjById(getSlotPartIdFromSlotId(slotObjId, "bonus"), true, shopItemObj)

  let shopItemTopLineObj = shopItemObj.findObject("shopItemTopLine")
  showObjById("shopItemDice", isRandomUnit, shopItemTopLineObj)

  let shopItemTextObj = shopItemTopLineObj.findObject(getSlotPartIdFromSlotId(slotObjId, "shopItemText"))
  shopItemTextObj.setValue(shopItemText)
  shopItemTextObj.translucent = translucentText ? "yes" : "no"

  let shopItemBottomLineObj = shopItemObj.findObject("shopItemBottomLine")
  let progressTextObj = shopItemBottomLineObj.findObject("progressText")
  progressTextObj.setValue(progressText)
  progressTextObj.progressStatus = progressStatus

  let airResearchProgressObj = shopItemBottomLineObj.findObject("airProgress")
  slotObj.getScene().replaceContentFromText(airResearchProgressObj, airResearchProgressBlk, airResearchProgressBlk.len(), slotbarWidgetHandler)

  let shopItemPriceObj = showObjById("priceText", !showAdditionExtraInfo, shopItemBottomLineObj)
  if (!showAdditionExtraInfo) {
    shopItemPriceObj.setValue(priceText)
    shopItemPriceObj.tinyFont = isLongPriceText ? "yes" : "no"
  }

  let hasBottomLineText = bottomLineText != null
  let rankTextObj = showObjById("rank_text", !hasBottomLineText, shopItemBottomLineObj)
  let bottomLineTextDivObj = showObjById("bottomLineTextDiv", hasBottomLineText, shopItemBottomLineObj)

  if (!hasBottomLineText) {
    rankTextObj.setValue(unitRankText)
    rankTextObj.tinyFont = isLongPriceText ? "yes" : "no"
    rankTextObj.locked = isItemLocked ? "yes" : "no"
    rankTextObj.translucent = translucentText ? "yes" : "no"
  }
  else {
    bottomLineTextDivObj.width = isLongPriceText ? "0.4pw" : "pw-1@tableIcoSize-0.003@sf"
    let bottomLineTextObj = bottomLineTextDivObj.findObject("bottomLineText")
    bottomLineTextObj.setValue(bottomLineText)
  }

  let classIconPlaceObj = shopItemBottomLineObj.findObject("classIconPlace")
  classIconPlaceObj["margin-top"] = hasBottomLineText ? "0.003@sf" : "0"
  let classIconObj = classIconPlaceObj.findObject("classIcon")
  classIconObj.setValue(unitClassIcon)
  classIconObj.shopItemType = shopItemType

  let crewNumWithTitleObj = shopItemBottomLineObj.findObject("crewNumWithTitle")
  crewNumWithTitleObj.setValue(crewNumWithTitle)

  showObjById("lockedIcon", hasLockedIcon, shopItemObj)

  let itemButtons = getItemButtonsCommon(unit, params)

  let slotBtnBattleObj = showObjById("slotBtn_battle", itemButtons.hasToBattleButton, shopItemObj)
  slotBtnBattleObj.hasToBattleButton = itemButtons.hasToBattleButton ? "yes" : "no"

  if (itemButtons.hasToBattleButton) {
    slotBtnBattleObj.showAboveInfoBlock = itemButtons.hasExtraInfoBlockTop ? "yes" : "no"
    slotBtnBattleObj.updateEventHandler("on_click", itemButtons.toBattleButtonAction, slotbarWidgetHandler)
  }

  let specIconsDivObj = shopItemObj.findObject("specIconsDiv")
  let specIconBlockObj = showObjById("specIconBlock", itemButtons.specIconBlock, specIconsDivObj)
  if (itemButtons.specIconBlock) {
    if (itemButtons.specTypeIcon) {
      specIconBlockObj.tooltip = itemButtons.specTypeTooltip
      specIconBlockObj.findObject("shopTrainedImg")["background-image"] = itemButtons.specTypeIcon ?? ""
    }
    showObjById("warningIcon", itemButtons.showWarningIcon, specIconsDivObj)
  }

  showObjById("repair_icon", itemButtons.hasRepairIcon, specIconsDivObj)

  let weaponsIconObj = showObjById("weapons_icon", itemButtons.weaponsStatus != "", specIconsDivObj)
  weaponsIconObj.weaponsStatus = itemButtons.weaponsStatus

  let rentIconObj = showObjById("rent_icon", itemButtons.hasRentIcon, shopItemObj)
  if (itemButtons.hasRentIcon) {
    let rentProgressObj = showObjById("rent_progress", itemButtons.hasRentProgress, rentIconObj)
    rentProgressObj["sector-angle-1"] = itemButtons.rentProgress
  }

  let extraInfoBottomData = getExtraInfoBottomDataCommon(unit, params)
  let extraInfoBlockObj = showObjById("extraInfoBlock", extraInfoBottomData.hasExtraInfoBlock, shopItemObj)
  if (extraInfoBottomData.hasExtraInfoBlock) {
    let extraInfoContentObj = extraInfoBlockObj.findObject("extra_info_content")
    extraInfoContentObj.crewIdInCountry = extraInfoBottomData?.crewIdInCountry
    extraInfoContentObj.crewId = crewId
    extraInfoContentObj.forcedUnit = extraInfoBottomData?.forcedUnit
    extraInfoContentObj.isEmptySlot = "no"

    extraInfoContentObj.findObject("crewNumText").setValue(extraInfoBottomData?.crewNum ?? "")

    showObjById("crewNumWithTitle", false, extraInfoContentObj)

    let crewInfoExpBlock = showObjById("crewInfoExpBlock", hasCrewInfo, extraInfoContentObj)
    if (hasCrewInfo) {
      crewInfoExpBlock.findObject("expAvailableIcon").hasUnseenIcon = extraInfoBottomData?.hasCrewUnseenIcon ?? "no"
      crewInfoExpBlock.findObject("crew_level").setValue(extraInfoBottomData?.crewLevel ?? "")
      crewInfoExpBlock.findObject("crew_spec")["background-image"] = extraInfoBottomData?.crewSpecIcon ?? ""
    }

    extraInfoContentObj.interactive = hasActions ? "yes" : "no"
    extraInfoContentObj.hasActions = hasActions ? "yes" : "no"
    extraInfoContentObj.updateEventHandler("on_drag_start", hasActions ? "onCrewDragStart" : "", slotbarWidgetHandler)
    extraInfoContentObj.updateEventHandler("on_hover", hasActions ? "" : "showCrewSlotHint", slotbarWidgetHandler)
  }

  let extraInfoBlockTopObj = showObjById("extraInfoBlockTop", hasExtraInfoBlockTop, shopItemObj)
  if (hasExtraInfoBlockTop) {
    let data = getExtraInfoTopData(unit, params.__merge({ crew, priceText, isRandomUnit }))

    extraInfoBlockTopObj.hasInfo = data.hasExtraInfo ? "yes" : "no"
    let extraInfoPriceTextObj = showObjById("extraInfoPriceText", data.hasPriceText, extraInfoBlockTopObj)
    extraInfoPriceTextObj.hasInfo = data.hasPriceText ? "yes" : "no"
    if (data.hasPriceText) {
      extraInfoPriceTextObj.width = data.priceWidth
      extraInfoPriceTextObj.setValue(data.priceText)
    }

    showObjById("priceSeparator", data.hasPriceSeparator, extraInfoBlockTopObj)

    let additionalHistoricalRespawnsNestObj = showObjById("additionalHistoricalRespawnsNest", data.hasAdditionalHistoricalRespawns, extraInfoBlockTopObj)
    additionalHistoricalRespawnsNestObj.hasInfo = data.hasAdditionalHistoricalRespawns ? "yes" : "no"
    if (data.hasAdditionalHistoricalRespawns) {
      additionalHistoricalRespawnsNestObj.width = data.addHistoricalRespawnsWidth
      let unitClassIcoObj = additionalHistoricalRespawnsNestObj.findObject("unitClassIco")
      unitClassIcoObj["background-image"] = data.unitClassIco
      unitClassIcoObj["background-color"] = data.unitClassIcoColor

      let additionalHistoricalRespawnsObj = additionalHistoricalRespawnsNestObj.findObject("additionalHistoricalRespawns")
      additionalHistoricalRespawnsObj.setValue(data.additionalHistoricalRespawns)
    }

    showObjById("additionalRespawnsSeparator", data.hasAdditionalRespawnsSeparator, extraInfoBlockTopObj)

    let additionalRespawnsObj = showObjById("additionalRespawns", data.hasAdditionalRespawns, extraInfoBlockTopObj)
    additionalRespawnsObj.hasInfo = data.hasAdditionalRespawns ? "yes" : "no"
    if (data.hasAdditionalRespawns) {
      additionalRespawnsObj.width = data.addRespawnsWidth
      additionalRespawnsObj.setValue(data.additionalRespawns)
    }

    showObjById("spareSeparator", data.hasSpareSeparator, extraInfoBlockTopObj)

    let spareCountObj = showObjById("spareCount", data.hasSpareInfo, extraInfoBlockTopObj)
    spareCountObj.hasInfo = data.hasSpareInfo ? "yes" : "no"
    if (data.hasSpareInfo)
      spareCountObj.setValue(data.spareCount)

    showObjById("diceSeparator", data.hasDiceSeparator, extraInfoBlockTopObj)

    let diceObj = showObjById("dice", data.hasDice, extraInfoBlockTopObj)
    if (data.hasDice)
      diceObj.hasInfo = "yes"

    showObjById("emptyExtraInfoText", !data.hasExtraInfo, extraInfoBlockTopObj)

    let slotMissionHintContainerObj = showObjById("slotMissionHintContainer", showAdditionExtraInfo, extraInfoBlockTopObj)
    if (showAdditionExtraInfo) {
      slotMissionHintContainerObj.hasInfo = "yes"
      let slotMissionHintObj = slotMissionHintContainerObj.findObject("slotMissionHint")

      let extraInfoPriceTextHintObj = showObjById("extraInfoPriceTextHint", data.hasPriceText, slotMissionHintObj)
      if (data.hasPriceText)
        extraInfoPriceTextHintObj.setValue(data.priceHintText)

      let additionalHistoricalRespawnsHintObj = showObjById("additionalHistoricalRespawnsHint", data.hasAdditionalHistoricalRespawns, slotMissionHintObj)
      if (data.hasAdditionalHistoricalRespawns) {
        additionalHistoricalRespawnsHintObj.findObject("unitClassIco")["background-image"] = data.unitClassIco
        additionalHistoricalRespawnsHintObj.findObject("hintText").setValue(data.additionalHistoricalRespawnsHintText)
      }

      let additionalRespawnsHintTextObj = showObjById("additionalRespawnsHintText", data.hasAdditionalRespawns, slotMissionHintObj)
      if (data.hasAdditionalRespawns)
        additionalRespawnsHintTextObj.setValue(data.additionalRespawnsHintText)

      let spareHintTextObj = showObjById("spareHintText", data.hasSpareInfo, slotMissionHintObj)
      if (data.hasSpareInfo)
        spareHintTextObj.setValue(data.spareHintText)

      showObjById("hasDice", data.hasDice, slotMissionHintObj)

      let hasRandomUnitsList = data.hasDice && data.hasRandomUnitsList
      showObjById("randomUnitsListText", hasRandomUnitsList, slotMissionHintObj)
      let randomUnitsListObj = showObjById("randomUnitsList", hasRandomUnitsList, slotMissionHintObj)
      if (hasRandomUnitsList) {
        let randomUnitsData = handyman.renderCached("%gui/slotbar/randomUnits.tpl", { randomUnits = data.randomUnits })
        slotObj.getScene().replaceContentFromText(randomUnitsListObj, randomUnitsData, randomUnitsData.len(), slotbarWidgetHandler)
      }
    }
  }
}

function updateEmptySlotData(slotObj, params) {
  let { slotObjId, specType = null, emptyCost = null, crewId = -1, hasActions = false,
    needDnD = false, crew = null, slotbarWidgetHandler } = params

  if (slotObj.slotType != "empty")
    updateVisibilityObjectsByUnitSlotType(slotObj, "empty")

  let hasCrew = crew != null

  let priceText = emptyCost ? emptyCost.getTextAccordingToBalance() : ""
  let data = params.__merge({
    shopItemTextId = getSlotPartIdFromSlotId(slotObjId, "shopItemText")
    shopItemTextValue = params?.emptyText ?? ""
    shopStatus = params?.status
    shopItemPriceText = priceText
    crewNumWithTitle = hasCrew ? $"{loc("mainmenu/crewTitle")}{crew.idInCountry + 1}" : "No crew"
    crewId = crewId.tostring()
  })

  slotObj.inactive = "no"
  slotObj.chosen = data.isSlotbarItem ? "no" : "yes"
  slotObj.selected = data.isSlotbarItem ? "no" : "yes"
  slotObj.crewId = data.crewId
  slotObj.hasSelectedState = "no"
  slotObj.isCrewRecruit = data?.isCrewRecruit ? "yes" : "no"
  slotObj.tooltipId = ""
  slotObj.updateEventHandler("on_end_edit", needDnD ? "onCrewDropFinish" : "", slotbarWidgetHandler)
  slotObj.updateEventHandler("on_drag_drop", needDnD ? "onCrewDrop" : "", slotbarWidgetHandler)
  slotObj.updateEventHandler("on_move", needDnD ? "onCrewMove" : "", slotbarWidgetHandler)
  slotObj.updateEventHandler("on_mouse_enter", data.selectOnHover ? "onUnitSlotMouseEnter" : "", slotbarWidgetHandler)
  slotObj.findObject("tooltipObj").tooltipId = ""

  let shopItemObj = slotObj.findObject(slotObjId)
  shopItemObj.unit_name = ""
  shopItemObj.shopStat = data.shopStatus
  shopItemObj.unitRarity = ""
  shopItemObj.isBroken = "no"
  shopItemObj.isPkgDev = "no"
  shopItemObj.crew_id = data.crewId
  shopItemObj.crewInfoTranslucent = ""
  shopItemObj.updateEventHandler("on_drag_start", "", slotbarWidgetHandler)
  shopItemObj.updateEventHandler("on_drag_drop", "", slotbarWidgetHandler)
  shopItemObj.updateEventHandler("on_move", "", slotbarWidgetHandler)
  shopItemObj.dragParent = "yes"
  shopItemObj.refuseOpenHoverMenu = "yes"
  shopItemObj.cursor = "normal"
  shopItemObj.isElite = "no"
  shopItemObj.isEmptySlot = "yes"
  shopItemObj.tooltipId = ""

  let crewImageObj = shopItemObj.findObject("crewImage")
  crewImageObj["background-image"] = data.crewImage

  showObjById("slotTopGradientLine", data.isSlotbarItem, shopItemObj)
  showObjById("slotBottomGradientLine", data.isSlotbarItem, shopItemObj)

  showObjById(getSlotPartIdFromSlotId(slotObjId, "discount"), false, shopItemObj)
  showObjById(getSlotPartIdFromSlotId(slotObjId, "bonus"), false, shopItemObj)

  let shopItemTopLineObj = shopItemObj.findObject("shopItemTopLine")
  showObjById("shopItemDice", false, shopItemTopLineObj)

  let shopItemTextObj = shopItemTopLineObj.findObject(data.shopItemTextId)
  shopItemTextObj.setValue(loc(data.shopItemTextValue.replace("#", "")))

  let shopItemBottomLineObj = shopItemObj.findObject("shopItemBottomLine")

  let shopItemPriceObj = showObjById("priceText", true, shopItemBottomLineObj)
  shopItemPriceObj.setValue(data.shopItemPriceText)

  let crewNumTextObj = shopItemBottomLineObj.findObject("crewNumWithTitle")
  crewNumTextObj.setValue(data.crewNumWithTitle)

  let itemButtons = getItemButtonsEmpty(specType)
  let specIconsDivObj = shopItemObj.findObject("specIconsDiv")

  specIconsDivObj.findObject("weapons_icon").weaponsStatus = ""

  let specIconBlockObj = showObjById("specIconBlock", itemButtons.specIconBlock, specIconsDivObj)
  if (itemButtons.specIconBlock) {
    if (itemButtons.specTypeIcon) {
      specIconBlockObj.tooltip = itemButtons.specTypeTooltip
      specIconBlockObj.findObject("shopTrainedImg")["background-image"] = itemButtons.specTypeIcon ?? ""
    }
  }

  let extraInfoData = getExtraInfoBottomDataEmpty(params)
  let hasExtraInfoBlock = extraInfoData?.hasExtraInfoBlock ?? false
  let extraInfoBlockObj = showObjById("extraInfoBlock", hasExtraInfoBlock, shopItemObj)
  if (hasExtraInfoBlock) {
    let extraInfoContentObj = extraInfoBlockObj.findObject("extra_info_content")
    extraInfoContentObj.crewIdInCountry = extraInfoData?.crewIdInCountry
    extraInfoContentObj.crewId = extraInfoData?.crewId
    extraInfoContentObj.forcedUnit = extraInfoData?.forcedUnit
    extraInfoContentObj.isEmptySlot = extraInfoData?.isEmptySlot

    extraInfoContentObj.findObject("crewNumText").setValue(extraInfoData?.crewNum)

    let crewNumWithTitleObj = showObjById("crewNumWithTitle", extraInfoData.hasCrewIdTextInfo, extraInfoContentObj)
    if (extraInfoData.hasCrewIdTextInfo)
      crewNumWithTitleObj.setValue(extraInfoData?.crewNumWithTitle)

    let hasCrewInfo = extraInfoData?.hasCrewInfo ?? false
    let crewInfoExpBlock = showObjById("crewInfoExpBlock", hasCrewInfo, extraInfoContentObj)
    if (hasCrewInfo) {
      crewInfoExpBlock.findObject("expAvailableIcon").hasUnseenIcon = extraInfoData?.hasCrewUnseenIcon ?? "no"
      crewInfoExpBlock.findObject("crew_level").setValue(extraInfoData?.crewLevel)
      crewInfoExpBlock.findObject("crew_spec")["background-image"] = extraInfoData?.crewSpecIcon
    }

    extraInfoContentObj.interactive = hasActions ? "yes" : "no"
    extraInfoContentObj.hasActions = hasActions ? "yes" : "no"
    extraInfoContentObj.updateEventHandler("on_drag_start", hasActions ? "onCrewDragStart" : "", slotbarWidgetHandler)
    extraInfoContentObj.updateEventHandler("on_hover", hasActions ? "" : "showCrewSlotHint", slotbarWidgetHandler)
  }
}

function updateSlotData(slotObj, params) {
  if (params?.unit == null)
    updateEmptySlotData(slotObj, params)
  else
    updateCommonSlotData(slotObj, params)
}

return freeze({
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
  updateSlotData
  getSlotPartIdFromSlotId
})
