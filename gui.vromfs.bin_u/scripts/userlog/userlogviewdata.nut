//-file:plus-string
from "%scripts/dagui_natives.nut" import clan_get_role_name, get_name_by_unlock_type
from "%scripts/dagui_library.nut" import *
from "%scripts/social/psConsts.nut" import bit_activity, ps4_activity_feed

let { g_team } = require("%scripts/teams.nut")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { abs, round } = require("math")
let { Cost, Money, Balance, money_type } = require("%scripts/money.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let { getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getEntitlementConfig, getEntitlementName, getEntitlementPrice } = require("%scripts/onlineShop/entitlements.nut")
let { isCrossPlayEnabled, getTextWithCrossplayIcon, needShowCrossPlayInfo
} = require("%scripts/social/crossplay.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffect.nut")
let { getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { getTournamentRewardData } = require("%scripts/userLog/userlogUtils.nut")
let { getTotalRewardDescText, getConditionText } = require("%scripts/events/eventRewards.nut")
let { getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { stripTags, cutPrefix, split, startsWith, endsWith } = require("%sqstd/string.nut")
let { WwMap } = require("%scripts/worldWar/operations/model/wwMap.nut")
let { getDifficultyTypeById, EASY_TASK, HARD_TASK
} = require("%scripts/unlocks/battleTaskDifficulty.nut")
let getBattleRewards = require("%scripts/userLog/getUserLogBattleRewardsTable.nut")
let { intToHexString } = require("%sqStdLibs/helpers/toString.nut")
let { getBattleTaskById, getDifficultyByProposals, getBattleTaskUserLogText,
  getBattleTaskUpdateDesc, getDifficultyTypeByTask
} = require("%scripts/unlocks/battleTasks.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/types.nut")
let { getCrewSpTextIfNotZero } = require("%scripts/crew/crewPointsText.nut")
let { getCrewById } = require("%scripts/slotbar/slotbarState.nut")
let { items_classes } = require("%scripts/items/itemsClasses/itemsClasses.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { eventsTableConfig } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { cloneDefaultUnlockData } = require("%scripts/unlocks/unlocksModule.nut")
let { getBonus } = require("%scripts/bonusModule.nut")
let { measureType } = require("%scripts/measureType.nut")
let { getSkillCrewLevel, crewSkillPages, loadCrewSkillsOnce
} = require("%scripts/crew/crew.nut")
let { isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

let imgFormat = @"img {size:t='%s'; background-image:t='%s';
 background-repeat:t='aspect-ratio'; margin-right:t='0.01@scrn_tgt;'} "
let textareaFormat = "textareaNoTab {id:t='description'; width:t='pw'; text:t='%s'} "
let descriptionBlkMultipleFormat = "tdiv { flow:t='h-flow'; width:t='pw'; {0} }"

let clanActionNames = {
  [ULC_CREATE]                  = "create",
  [ULC_DISBAND]                 = "disband",

  [ULC_REQUEST_MEMBERSHIP]      = "request_membership",
  [ULC_CANCEL_MEMBERSHIP]       = "cancel_membership",
  [ULC_REJECT_MEMBERSHIP]       = "reject_candidate",
  [ULC_ACCEPT_MEMBERSHIP]       = "accept_candidate",

  [ULC_DISMISS]                 = "dismiss_member",
  [ULC_CHANGE_ROLE]             = "change_role",
  [ULC_CHANGE_ROLE_AUTO]        = "change_role_auto",
  [ULC_LEAVE]                   = "leave",
  [ULC_DISBANDED_BY_LEADER]     = "disbanded_by_leader",

  [ULC_ADD_TO_BLACKLIST]        = "add_to_blacklist",
  [ULC_DEL_FROM_BLACKLIST]      = "remove_from_blacklist",
  [ULC_CHANGE_CLAN_INFO]        = "clan_info_was_changed",
  [ULC_CLAN_INFO_WAS_CHANGED]   = "clan_info_was_renamed",
  [ULC_DISBANDED_BY_ADMIN]      = "clan_disbanded_by_admin",
  [ULC_UPGRADE_CLAN]            = "clan_was_upgraded",
  [ULC_UPGRADE_MEMBERS]         = "clan_max_members_count_was_increased",
}
let getClanActionName = @(action) clanActionNames?[action] ?? "unknown"

function getDecoratorUnlock(resourceId, resourceType) {
  let unlock = cloneDefaultUnlockData()
  local decoratorType = null
  unlock.id = resourceId
  decoratorType = getTypeByResourceType(resourceType)
  if (decoratorType != decoratorTypes.UNKNOWN) {
    unlock.name = decoratorType.getLocName(unlock.id, true)
    unlock.desc = decoratorType.getLocDesc(unlock.id)
    unlock.image = decoratorType.userlogPurchaseIcon

    let decorator = getDecorator(unlock.id, decoratorType)
    if (decorator && !is_in_loading_screen()) {
      unlock.descrImage <- decoratorType.getImage(decorator)
      unlock.descrImageRatio <- decoratorType.getRatio(decorator)
      unlock.descrImageSize <- decoratorType.getImageSize(decorator)
    }
  }

  return unlock
}

local function getResourcesConfig(resources) {
  if (resources == null)
    return null

  let res = {
    description = []
    logImg = null
    resourcesImagesMarkupArr = []
  }

  //after convertation from DataBlk to table array with 1 element becomes table.
  //So we normalize data format.
  if (u.isTable(resources))
    resources = [resources]

  foreach (resource in resources) {
    let unlock = getDecoratorUnlock(resource.resourceId, resource.resourceType)
    let desc = unlock?.desc ?? ""
    if (desc != "")
      res.description.append(desc)

    res.logImg = unlock?.image ?? res.logImg
    let descrImage = unlock?.descrImage ?? ""
    if (descrImage != "") {
      let imgSize = unlock?.descrImageSize ?? "0.05sh, 0.05sh"
      res.resourcesImagesMarkupArr.append(format(imgFormat, imgSize, unlock.descrImage))
    }
  }

  return res
}

function getLinkMarkup(text, url, acccessKeyName = null) {
  if (!u.isString(url) || url.len() == 0 || !hasFeature("AllowExternalLink"))
    return ""

  let btnParams = {
    text = text
    isHyperlink = true
    link = url
  }
  if (acccessKeyName && acccessKeyName.len() > 0) {
    btnParams.acccessKeyName <- acccessKeyName
  }
  return handyman.renderCached("%gui/commonParts/button.tpl", btnParams)
}

::update_repair_cost <- function update_repair_cost(units, repairCost) {
  local idx = 0
  while (($"cost{idx}") in units) {
    let cost = getTblValue($"cost{idx}", units, 0)
    if (cost > 0)
      repairCost.rCost += cost
    else
      repairCost.notEnoughCost -= cost
    idx++
  }
}

::get_userlog_view_data <- function get_userlog_view_data(logObj) {
  let colon = loc("ui/colon")
  let res = {
    name = "",
    time = time.buildDateTimeStr(logObj.time, true)
    tooltip = ""
    logImg = null
    logImg2 = null
    logBonus = null
    logIdx = logObj.idx
    buttonName = null
    isUserLogBattles = logObj.type == EULT_SESSION_RESULT
  }

  let isMissionExtrLog = isMissionExtrByName(logObj?.mission ?? "")
  local logName = ::getLogNameByType(logObj.type)
  local priceText = Cost(("wpCost" in logObj) ? logObj.wpCost : 0,
    ("goldCost" in logObj) ? logObj.goldCost : 0).tostring()

  if (priceText != "")
    priceText = loc("ui/parentheses/space", { text = priceText })

  if (logObj.type == EULT_SESSION_START ||
      logObj.type == EULT_EARLY_SESSION_LEAVE ||
      logObj.type == EULT_SESSION_RESULT) {
    if (logObj?.container.countryFlag)
      res.logImg2 = getCountryIcon(logObj.container.countryFlag)
    else if (::checkCountry(logObj?.country, "userlog EULT_SESSION_"))
      res.logImg2 = getCountryIcon(logObj.country)

    let eventId = logObj?.eventId
    local mission = ::get_mission_name(logObj.mission, logObj)
    if (eventId != null && !::events.isEventRandomBattlesById(eventId)) {
      local locName = ""

      if ("eventLocName" in logObj)
        locName = logObj.eventLocName
      else
        locName = $"events/{eventId}/name"
      logName = $"event/{logName}"
      mission = loc(locName, eventId)
    }

    local nameLoc = isMissionExtrLog ? "userLog/session_result_extr" : $"userlog/{logName}"
    if (logObj.type == EULT_EARLY_SESSION_LEAVE)
      res.logImg = "#ui/gameuiskin#log_leave"
    else if (logObj.type == EULT_SESSION_RESULT) {
      if (!isMissionExtrLog)
        nameLoc += logObj.win ? "/win" : "/lose"
      res.logImg = $"#ui/gameuiskin#{logObj.win? "log_win" : "log_lose"}"
    }
    res.name = format(loc(nameLoc), mission)

    local desc = ""
    local descBottom = ""
    local wp = getTblValue("wpEarned", logObj, 0) + getTblValue("baseTournamentWp", logObj, 0)
    local gold = getTblValue("goldEarned", logObj, 0) + getTblValue("baseTournamentGold", logObj, 0)
    let xp = getTblValue("xpEarned", logObj, 0)
    local earnedText = Cost(wp, gold, xp).toStringWithParams({ isWpAlwaysShown = true })
    if (!isMissionExtrLog && earnedText != "") {
      earnedText = loc("ui/colon") + $"<color=@activeTextColor>{earnedText}</color>"
      desc += ((desc != "") ? "\n" : "") + loc("userlog/earned") + earnedText
    }

    if (!isMissionExtrLog && (logObj.type == EULT_SESSION_RESULT) && ("activity" in logObj)) {
      let activity = measureType.PERCENT_FLOAT.getMeasureUnitsText(logObj.activity)
      desc += "\n" + loc("debriefing/Activity") + loc("ui/colon") + activity
    }

    if (("friendlyFirePenalty" in logObj) && logObj.friendlyFirePenalty != 0) {
      desc += "\n" + loc("debriefing/FriendlyKills") + loc("ui/colon")
      desc += "<color=@activeTextColor>" +
        Cost(logObj.friendlyFirePenalty).toStringWithParams({ isWpAlwaysShown = true }) + "</color>"
      wp += logObj.friendlyFirePenalty
    }

    if (("nRespawnsWp" in logObj) && logObj.nRespawnsWp != 0) {
      desc += "\n" + loc("debriefing/MultiRespawns") + loc("ui/colon")
      desc += "<color=@activeTextColor>" +
        Cost(logObj.nRespawnsWp).toStringWithParams({ isWpAlwaysShown = true }) + "</color>"
      wp += logObj.nRespawnsWp
    }

    let damagedVehicles = []
    if ("aircrafts" in logObj) {
      foreach (air in logObj.aircrafts)
        if (air.value < 1.0)
          damagedVehicles.append(air.name)
    }

    if ("manuallySpentRepairCost" in logObj) {
      local idx = 0
      while ($"aname{idx}" in logObj.manuallySpentRepairCost) {
        let name = getTblValue($"aname{idx}", logObj.manuallySpentRepairCost)
        if (name && !damagedVehicles.contains(name))
          damagedVehicles.append(name)
        idx++
      }
    }

    if (damagedVehicles.len() > 0)
      desc = "".concat(
        desc
        "\n"
        loc("userlog/broken_airs")
        loc("ui/colon")
        ", ".join(damagedVehicles.map(@(v) getUnitName(v)))
      )

    if ("spare" in logObj) {
      local aText = ""
      foreach (air in logObj.spare)
        if (air.value > 0) {
          aText += ((aText != "") ? ", " : "") + getUnitName(air.name)
          if (air.value > 1)
            aText += format(" (%d)", air.value.tointeger())
        }
      if (aText != "")
        desc += "\n" + loc("userlog/used_spare") + loc("ui/colon") + aText
    }

    let containerLog = getTblValue("container", logObj)

    local freeRepair = ("aircrafts" in logObj) && logObj.aircrafts.len() > 0
    let repairCost = { rCost = 0, notEnoughCost = 0 }
    let aircraftsRepaired = getTblValue("aircraftsRepaired", containerLog)
    if (aircraftsRepaired)
      ::update_repair_cost(aircraftsRepaired, repairCost);

    let unitsRepairedManually = getTblValue("manuallySpentRepairCost", logObj)
    if (unitsRepairedManually)
      ::update_repair_cost(unitsRepairedManually, repairCost);

    if (repairCost.rCost > 0) {
      desc += "\n" + loc("shop/auto_repair_cost") + loc("ui/colon")
      desc += "<color=@activeTextColor>" + Cost(-repairCost.rCost).toStringWithParams({ isWpAlwaysShown = true }) + "</color>"
      wp -= repairCost.rCost
      freeRepair = false
    }
    if (repairCost.notEnoughCost != 0) {
      desc += "\n" + loc("shop/auto_repair_failed") + loc("ui/colon")
      desc += "<color=@warningTextColor>(" +
        Cost(repairCost.notEnoughCost).toStringWithParams({ isWpAlwaysShown = true }) + ")</color>"
      freeRepair = false
    }

    if (freeRepair && ("autoRepairWasOn" in logObj) && logObj.autoRepairWasOn) {
      desc += "\n" + loc("shop/auto_repair_free")
    }

    let wRefillWp = getTblValue("wpCostWeaponRefill", containerLog, 0)
    let wRefillGold = getTblValue("goldCostWeaponRefill", containerLog, 0)
    if (wRefillWp || wRefillGold) {
      desc += "\n" + loc("shop/auto_buy_weapons_cost") + loc("ui/colon")
      desc += "<color=@activeTextColor>" + Cost(-wRefillWp, -wRefillGold).tostring() + "</color>"
      wp -= wRefillWp
      gold -= wRefillGold
    }

    let expensesCompensation = containerLog?.wpExpensesCompensation ?? 0
    if (expensesCompensation > 0) {
      res.compensation <- "".concat(loc("userlog/expenses_compensation"), colon,
        "<color=@activeTextColor>", Cost(expensesCompensation), "</color>")
      wp += expensesCompensation
    }

    local rp = 0
    if ("rpEarned" in logObj) {
      local descUnits = ""
      local descMods = ""

      local idx = 0
      while (($"aname{idx}") in logObj.rpEarned) {
        let unitId = logObj.rpEarned[$"aname{idx}"]
        let modId = (($"mname{idx}") in logObj.rpEarned) ? logObj.rpEarned[$"mname{idx}"] : null
        let mrp = logObj.rpEarned[$"mrp{idx}"]

        let fromExcessRP = ($"merp{idx}") in logObj.rpEarned ? logObj.rpEarned[$"merp{idx}"] : 0
        rp += mrp + fromExcessRP

        local modText = ""
        if (modId)
          modText = $" - {getModificationName(getAircraftByName(unitId), modId)}"
        let title = $"{getUnitName(unitId)}{modText}"
        local item = "".join(["\n", title, loc("ui/colon"), "<color=@activeTextColor>",
          Cost().setRp(mrp).tostring(), "</color>"])

        if (fromExcessRP > 0)
          item += " + " + loc("userlog/excessExpEarned") + loc("ui/colon") +
            "<color=@activeTextColor>" + Cost().setRp(fromExcessRP).tostring() + "</color>"

        if (!modId)
          descUnits += item
        else
          descMods += item

        idx++
      }

      if (descUnits.len())
        descBottom = "".concat(descBottom, "\n<color=@activeTextColor>", loc("debriefing/researched_unit"), loc("ui/colon"), "</color>", descUnits)
      if (descMods.len())
        descBottom = "".concat(descBottom, "\n<color=@activeTextColor>", loc("debriefing/research_list"), loc("ui/colon"), "</color>", descMods)
    }

    if (getTblValue("haveTeamkills", logObj, false))
      descBottom = "".concat(descBottom, ((descBottom != "") ? "\n\n" : ""), "<color=@activeTextColor>", loc("debriefing/noAwardsCaption"), "</color>")

    let usedItems = []

    if ("affectedBoosters" in logObj) {
      local affectedBoosters = logObj.affectedBoosters
      // Workaround for a bug (duplicating 'affectedBoosters' blocks),
      // which doesn't even exist on Production. Please remove it after ~ 2015-09-25:
      if (type(affectedBoosters) == "array")
        affectedBoosters = affectedBoosters.top()

      local activeBoosters = getTblValue("activeBooster", affectedBoosters, [])
      if (type(activeBoosters) == "table")
        activeBoosters = [ activeBoosters ]

      if (activeBoosters.len() > 0)
        foreach (effectType in boosterEffectType) {
          let boostersArray = []
          foreach (_idx, block in activeBoosters) {
            let item = findItemById(block.itemId)
            if (item && effectType.checkBooster(item))
              boostersArray.append(item)
          }

          if (boostersArray.len())
            usedItems.append(getActiveBoostersDescription(boostersArray, effectType))
        }

      if (usedItems.len())
        descBottom = "".concat(descBottom, "\n\n",
          colorize("activeTextColor", "".concat(loc("debriefing/used_items"), loc("ui/colon"))),
          "\n", "\n".join(usedItems, true))
    }

    if (("tournamentResult" in logObj) && (::events.getEvent(eventId)?.leaderboardEventTable == null)) {
      let now = getTblValue("newStat", logObj.tournamentResult)
      let was = getTblValue("oldStat", logObj.tournamentResult)
      let lbDiff = ::leaderboarsdHelpers.getLbDiff(now, was)
      let items = []
      foreach (lbFieldsConfig in eventsTableConfig) {
        if (!(lbFieldsConfig.field in now)
          || !::events.checkLbRowVisibility(lbFieldsConfig, { eventId }))
          continue

        items.append(::getLeaderboardItemView(lbFieldsConfig,
                                                 now[lbFieldsConfig.field],
                                                 getTblValue(lbFieldsConfig.field, lbDiff, null)))
      }
      let lbStatsBlk = ::getLeaderboardItemWidgets({ items = items })
      if (!("descriptionBlk" in res))
        res.descriptionBlk <- ""
      res.descriptionBlk += format("tdiv { width:t='pw'; flow:t='h-flow'; %s }", lbStatsBlk)
    }

    let roomId = logObj?.roomId ?? 0
    if (roomId > 0)
      descBottom = "".concat(descBottom, "\n\n", loc("options/session"), colon, intToHexString(roomId))

    if (!isMissionExtrLog) {
      res.tooltip = (logObj.type == EULT_SESSION_RESULT) ? loc("debriefing/total") : loc("userlog/interimResults");
      local totalText = res.tooltip
      totalText = "<color=@userlogColoredText>" + totalText + loc("ui/colon") + "</color>"

      let total = Cost(wp, gold, xp, rp).toStringWithParams({ isWpAlwaysShown = true })
      totalText += $"<color=@activeTextColor>{total}</color>"

      descBottom = "".concat(descBottom, "\n", totalText)
      res.tooltip += loc("ui/colon") + $"<color=@activeTextColor>{total}</color>"
    }

    if (!isMissionExtrLog &&
        (logObj.type == EULT_SESSION_RESULT || logObj.type == EULT_EARLY_SESSION_LEAVE)) {
      let ecSpawnScore = getTblValue("ecSpawnScore", logObj, 0)
      if (ecSpawnScore > 0)
      descBottom = "".concat(descBottom, "\n<color=@userlogColoredText>", loc("debriefing/total/ecSpawnScore"), loc("ui/colon"), "</color>",
        "<color=@activeTextColor>", ecSpawnScore, "</color>")
      let wwSpawnScore = logObj?.wwSpawnScore ?? 0
      if (wwSpawnScore > 0)
        descBottom = "".concat(descBottom, "\n",
          colorize("@userlogColoredText", "".concat(loc("debriefing/total/wwSpawnScore"), loc("ui/colon"))),
          colorize("@activeTextColor", wwSpawnScore))
    }

    if (desc != "")
      res.description <- desc
    if (descBottom != "")
      res.descriptionBottom <- descBottom

    let expMul = logObj?.xpFirstWinInDayMul ?? 1.0
    let wpMul = logObj?.wpFirstWinInDayMul ?? 1.0
    if (expMul > 1.0 || wpMul > 1.0)
      res.logBonus = getBonus(expMul, wpMul, "item", "Log")

    if (hasFeature("ServerReplay"))
      if (getTblValue("dedicatedReplay", logObj, false)) {
        if (!("descriptionBlk" in res))
          res.descriptionBlk <- ""
        res.descriptionBlk += getLinkMarkup(loc("mainmenu/btnViewServerReplay"),
          getCurCircuitOverride("serverReplayURL", loc("url/serv_replay")).subst({ roomId = logObj.roomId }), "Y")
      }
  }
  else if (logObj.type == EULT_AWARD_FOR_PVE_MODE) {
    if ("country" in logObj)
      if (::checkCountry(logObj.country,$"userlog EULT_AWARD_FOR_PVE_MODE, {logObj.mission}"))
        res.logImg2 = getCountryIcon(logObj.country)

    local nameLoc = $"userlog/{logName}"
    local nameLocPostfix = ""
    let win = ("win" in logObj) && logObj.win

    if ("spectator" in logObj) {
      res.logImg = "#ui/gameuiskin#player_spectator.svg"
      nameLocPostfix = " " + loc("multiplayer/team_won") + loc("ui/colon")
        + (win ? g_team.A.getNameInPVE() : g_team.B.getNameInPVE())
    }
    else {
      res.logImg = $"#ui/gameuiskin#{win? "log_win" : "log_lose"}"
      nameLoc += win ? "/win" : "/lose"
    }

    let mission = ::get_mission_name(logObj.mission, logObj)
    res.name = loc(nameLoc, { mode = loc($"multiplayer/{logObj.mode}Mode"), mission = mission }) + nameLocPostfix

    local desc = ""
    local earnedText = Cost(logObj?.wpEarned ?? 0, logObj?.goldEarned ?? 0, 0, logObj?.xpEarned ?? 0)
      .toStringWithParams({ isWpAlwaysShown = true })
    if (earnedText != "") {
      earnedText = loc("debriefing/total") + loc("ui/colon") + earnedText
      desc += ((desc != "") ? "\n" : "") + earnedText
    }
    if (desc != "") {
      res.description <- desc
      res.tooltip = desc
    }
  }
  else if (logObj.type == EULT_BUYING_AIRCRAFT) {
    res.name = format(loc($"userlog/{logName}"), getUnitName(logObj.aname)) + priceText
    res.logImg = "#ui/gameuiskin#log_buy_aircraft"
    let country = ::getShopCountry(logObj.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = getCountryIcon(country)
  }
  else if (logObj.type == EULT_REPAIR_AIRCRAFT) {
    res.name = format(loc($"userlog/{logName}"), getUnitName(logObj.aname)) + priceText
    res.logImg = "#ui/gameuiskin#log_repair_aircraft"
    let country = ::getShopCountry(logObj.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = getCountryIcon(country)
  }
  else if (logObj.type == EULT_REPAIR_AIRCRAFT_MULTI) {
    if (("postSession" in logObj) && logObj.postSession)
      logName += "_auto"
    local totalCost = 0
    local desc = ""
    local idx = 0
    local country = ""
    local oneCountry = true
    while (($"aname{idx}") in logObj) {
      if (desc != "")
        desc += "\n"
      let airName = logObj[$"aname{idx}"]
      desc += getUnitName(airName) + loc("ui/colon") +
        Cost(logObj[$"cost{idx}"]).toStringWithParams({ isWpAlwaysShown = true })
      totalCost += logObj[$"cost{idx}"]
      if (oneCountry) {
        let c = ::getShopCountry(airName)
        if (idx == 0)
          country = c
        else if (country != c)
            oneCountry = false
      }
      idx++
    }
    priceText = Cost(totalCost).tostring()
    if (priceText != "")
      priceText = " (" + priceText + ")"
    res.name = loc($"userlog/{logName}") + priceText
    if (desc != "") {
      res.description <- desc
      res.tooltip = desc
    }
    res.logImg = "#ui/gameuiskin#log_repair_aircraft"
    if (oneCountry && ::checkCountry(country, "getShopCountry"))
      res.logImg2 = getCountryIcon(country)
  }
  else if (logObj.type == EULT_BUYING_WEAPON || logObj.type == EULT_BUYING_WEAPON_FAIL) {
    res.name = format(loc($"userlog/{logName}"), getUnitName(logObj.aname)) + priceText
    res.logImg = "".concat("#ui/gameuiskin#", logObj.type == EULT_BUYING_WEAPON ? "log_buy_weapon" : "log_refill_weapon_no_money")
    if (("wname" in logObj) && ("aname" in logObj)) {
      res.description <- getWeaponNameText(logObj.aname, false, logObj.wname, ", ")
      if ("count" in logObj && logObj.count > 1)
        res.description +=$" x{logObj.count}"
      res.tooltip = res.description
    }
  }
  else if (logObj.type == EULT_BUYING_WEAPONS_MULTI) {
    let auto = !("autoMode" in logObj) || logObj.autoMode
    if (auto)
      res.name = loc("userlog/buy_weapons_auto") + priceText
    else
      res.name = format(loc("userlog/buy_weapon"), logObj.rawin("aname0") ? getUnitName(logObj.aname0) : "") + priceText

    res.description <- ""
    local idx = 0
    let airDesc = {}
    do {
      local desc = ""

      if (logObj.rawin($"aname{idx}") && logObj.rawin($"wname{idx}")) {
        desc = getWeaponNameText(logObj[$"aname{idx}"], false, logObj[$"wname{idx}"], ", ")
        local wpCost = 0
        local goldCost = 0
        if (logObj.rawin($"wcount{idx}")) {
          if (logObj.rawin($"wwpCost{idx}"))
            wpCost = logObj[$"wwpCost{idx}"]
          if (logObj.rawin($"wgoldCost{idx}"))
            goldCost = logObj[$"wgoldCost{idx}"]

          desc += " x" + logObj[$"wcount{idx}"] + " " + Cost(wpCost, goldCost).tostring()
        }
        if (logObj[$"aname{idx}"] in airDesc)
          airDesc[logObj[$"aname{idx}"]] += "\n" + desc
        else
          airDesc[logObj[$"aname{idx}"]] <- desc
      }

      idx++
    } while (($"wname{idx}") in logObj)

    if (auto) {
      idx = 0
      do {
        local desc = ""
        if (logObj.rawin($"maname{idx}") && logObj.rawin($"mname{idx}")) {
        desc = $"{desc}{getModificationName(getAircraftByName(logObj[$"maname{idx}"]), logObj[$"mname{idx}"])}"
          local wpCost = 0
          local goldCost = 0
          if (logObj.rawin($"mcount{idx}")) {
            if (logObj.rawin($"mwpCost{idx}"))
              wpCost = logObj[$"mwpCost{idx}"]
            if (logObj.rawin($"mgoldCost{idx}"))
              goldCost = logObj[$"mgoldCost{idx}"]

            desc += " x" + logObj[$"mcount{idx}"] + " " + Cost(wpCost, goldCost).tostring()
          }
          if (logObj[$"maname{idx}"] in airDesc)
            airDesc[logObj[$"maname{idx}"]] += "\n" + desc
          else
            airDesc[logObj[$"maname{idx}"]] <- desc
        }
        idx++
      } while (($"mname{idx}") in logObj)
    }

    foreach (aname, iname in airDesc) {
      if (res.description != "")
        res.description += "\n\n"
      if (auto)
        res.description += colorize("activeTextColor", getUnitName(aname)) + loc("ui/colon") + "\n"
      res.description += iname
    }

    res.tooltip = res.description
    res.logImg = "#ui/gameuiskin#log_buy_weapon"
  }
  else if (logObj.type == EULT_NEW_RANK) {
    if (("country" in logObj) && logObj.country != "common" && ::checkCountry(logObj.country, "EULT_NEW_RANK")) {
      res.logImg2 = getCountryIcon(logObj.country)
      res.name = format(loc($"userlog/{logName}/country"), logObj.newRank.tostring())
    }
    else {
      res.logImg = "#ui/gameuiskin#prestige0"
      res.name = format(loc($"userlog/{logName}"), logObj.newRank.tostring())
    }
  }
  else if (logObj.type == EULT_BUYING_SLOT || logObj.type == EULT_TRAINING_AIRCRAFT || logObj.type == EULT_UPGRADING_CREW
      || logObj.type == EULT_SPECIALIZING_CREW || logObj.type == EULT_PURCHASINGSKILLPOINTS) {
    let crew = getCrewById(logObj.id)
    let crewName = crew ? (crew.idInCountry + 1).tostring() : "?"
    let country = crew ? crew.country : ("country" in logObj) ? logObj.country : ""
    let airName = ("aname" in logObj) ? getUnitName(logObj.aname) : ("aircraft" in logObj) ? getUnitName(logObj.aircraft) : ""
    if (::checkCountry(country, "userlog EULT_*_CREW"))
      res.logImg2 = getCountryIcon(country)
    res.logImg = "#ui/gameuiskin#log_crew"

    res.name = loc($"userlog/{logName}",
                         { skillPoints = getCrewSpTextIfNotZero(getTblValue("skillPoints", logObj, 0)),
                           crewName = crewName,
                           unitName = airName
                         })
    res.name += priceText

    if (logObj.type == EULT_UPGRADING_CREW) {
      loadCrewSkillsOnce()
      local desc = ""
      local total = 0
      foreach (page in crewSkillPages)
        if ((page.id in logObj) && logObj[page.id].len() > 0) {
          let groupName = loc($"crew/{page.id}")
          desc = $"{desc}{desc != "" ? "\n" : ""}{groupName}{loc("ui/colon")}"
          foreach (item in page.items)
            if (item.name in logObj[page.id]) {
              let numPoints = getSkillCrewLevel(item, logObj[page.id][item.name])
              let skillName = loc($"crew/{item.name}")
              desc = $"{desc}{desc != "" ? "\n" : ""}{nbsp}{nbsp}+{numPoints} {skillName}"
              total += numPoints
            }
        }
      res.name = $"{res.name} (+{total} {loc("userlog/crewLevel")})"
      if (desc != "") {
        res.description <- desc
        res.tooltip = desc
      }
    }
  }
  else if (logObj.type == EULT_BUYENTITLEMENT) {
    let ent = getEntitlementConfig(logObj.name)
    if ("cost" in logObj)
      ent["goldCost"] <- logObj.cost
    local costText = getEntitlementPrice(ent)
    if (costText != "")
      costText = " (" + costText + ")"

    res.name = format(loc($"userlog/{logName}"), getEntitlementName(ent)) + costText
    res.logImg = "#ui/gameuiskin#log_online_shop"
  }
  else if (logObj.type == EULT_NEW_UNLOCK) {
    let config = ::build_log_unlock_data(logObj)

    res.name = config.title
    if (config.name != "")
      res.name += loc("ui/colon") + "<color=@userlogColoredText>" + config.name + "</color>"
    res.logImg = config.image
    if ("country" in logObj && ::checkCountry(logObj.country, "EULT_NEW_UNLOCK"))
      res.logImg2 = getCountryIcon(logObj.country)
    else if ((config?.image2 ?? "") != "")
      res.logImg2 = config?.image2

    let unlock = getUnlockById(logObj?.unlockId ?? logObj?.id ?? "")
    local desc = ""
    if (!(unlock?.isMultiUnlock ?? false) && "desc" in config) {
      desc = config.desc
      res.tooltip = config.desc
    }

    if (config.rewardText != "") {
      res.name += loc("ui/parentheses/space", { text = config.rewardText })
      desc += ((desc == "") ? "" : "\n\n") + loc("challenge/reward") + " " + config.rewardText
    }

    if (desc != "")
      res.description <- desc

    if (("descrImage" in config) && config.descrImage != "") {
      let imgSize = ("descrImageSize" in config) ? config.descrImageSize : "0.05sh, 0.05sh"
      res.descriptionBlk <- format(imgFormat, imgSize, config.descrImage)
    }
    if ((config.type == UNLOCKABLE_SLOT ||
         config.type == UNLOCKABLE_AWARD)
         && "country" in logObj)
      res.logImg2 = getCountryIcon(logObj.country)

    if (config.type == UNLOCKABLE_SKILLPOINTS && config.image2 != "")
      res.logImg2 = config.image2
  }
  else if (logObj.type == EULT_BUYING_MODIFICATION || logObj.type == EULT_BUYING_MODIFICATION_FAIL) {
    res.name = format(loc($"userlog/{logName}"), getUnitName(logObj.aname)) + priceText
    res.logImg = "".concat("#ui/gameuiskin#", logObj.type == EULT_BUYING_MODIFICATION ? "log_buy_mods" : "log_refill_weapon_no_money")
    if (("mname" in logObj) && ("aname" in logObj)) {
      res.description <- getModificationName(getAircraftByName(logObj.aname), logObj.mname)
      if ("count" in logObj && logObj.count > 1)
        res.description +=$" x{logObj.count}"

      local xpEarnedText = ("xpEarned" in logObj) ? Cost().setRp(logObj.xpEarned).tostring() : ""
      if (xpEarnedText != "") {
        xpEarnedText = loc("reward") + loc("ui/colon") + $"<color=@activeTextColor>{xpEarnedText}</color>"
        res.description += ((res.description != "") ? "\n" : "") + xpEarnedText
      }
      res.tooltip = res.description
    }
  }
  else if (logObj.type == EULT_BUYING_SPARE_AIRCRAFT) {
    let count = getTblValue("count", logObj, 1)
    if (count == 1)
      res.name = format(loc($"userlog/{logName}"), getUnitName(logObj.aname)) + priceText
    else
      res.name = loc($"userlog/{logName}/multiple", {
                     numSparesColored = colorize("userlogColoredText", count)
                     numSpares = count
                     unitName = colorize("userlogColoredText", getUnitName(logObj.aname))
                   }) + priceText
    res.logImg = "#ui/gameuiskin#log_buy_spare_aircraft"
    let country = ::getShopCountry(logObj.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = getCountryIcon(country)
  }
  else if (logObj.type == EULT_CLAN_ACTION) {
    res.logImg = "#ui/gameuiskin#log_clan_action"
    let info = {
      action = getTblValue("clanActionType", logObj, -1)
      clan = ("clanName" in logObj) ? ::ps4CheckAndReplaceContentDisabledText(logObj.clanName) : ""
      player = getTblValue("initiatorNick", logObj, "")
      role = ("role" in logObj) ? loc("clan/" + clan_get_role_name(logObj.role)) : ""
      status = ("enabled" in logObj) ? loc("clan/" + (logObj.enabled ? "opened" : "closed")) : ""
      tag = getTblValue("clanTag", logObj, "")
      tagOld = getTblValue("clanTagOld", logObj, "")
      clanOld = ("clanNameOld" in logObj) ? ::ps4CheckAndReplaceContentDisabledText(logObj.clanNameOld) : ""
      sizeIncrease = getTblValue("sizeIncrease", logObj, -1)
    }
    let typeTxt = getClanActionName(info.action)
    res.name = loc("userlog/" + logName + "/" + typeTxt, info) + priceText

    if ("comment" in logObj && logObj.comment != "") {
      res.description <- loc("clan/userlogComment") + "\n" + ::ps4CheckAndReplaceContentDisabledText(::g_chat.filterMessageText(logObj.comment, false))
      res.tooltip = res.description
    }
  }
  else if (logObj.type == EULT_BUYING_RESOURCE || logObj.type == EULT_BUYING_UNLOCK) {
    local config = cloneDefaultUnlockData()
    local resourceType = ""
    local decoratorType = null
    if (logObj.type == EULT_BUYING_RESOURCE) {
      resourceType = logObj.resourceType
      config = getDecoratorUnlock(logObj.resourceId, logObj.resourceType)
      decoratorType = getTypeByResourceType(resourceType)
    }
    else if (logObj.type == EULT_BUYING_UNLOCK && logObj.unlockId.indexof("ship_flag_") != null) {
      decoratorType = decoratorTypes.FLAGS
      config = getDecoratorUnlock(logObj.unlockId, decoratorType.resourceType)
      resourceType = decoratorType.resourceType
    }
    else {
      config = ::build_log_unlock_data(logObj)
      resourceType = logObj?.isAerobaticSmoke ? "smoke" : get_name_by_unlock_type(config.type)
    }

    res.name = "".concat(format(loc($"userlog/{logName}/{resourceType}"), config.name), priceText)

    local desc = config?.desc ?? ""
    if (decoratorType)
      desc = decoratorType.getLocDesc(config.id)

    if (!u.isEmpty(desc))
      res.description <- desc

    res.logImg = config.image

    if (getTblValue("descrImage", config, "") != "") {
      let imgSize = getTblValue("descrImageSize", config, "0.05sh, 0.05sh")
      res.descriptionBlk <- format(imgFormat, imgSize, config.descrImage)
    }
  }
  else if (logObj.type == EULT_CHARD_AWARD) {
    let rewardType = getTblValue("rewardType", logObj, "")
    res.name = loc($"userlog/{rewardType}")
    res.description <- loc("userlog/" + getTblValue("name", logObj, ""))

    let wp = logObj?.wpEarned ?? 0, gold = logObj?.goldEarned ?? 0, exp = logObj?.xpEarned ?? 0
    let reward = Cost(wp.tointeger(), gold.tointeger(), 0, exp.tointeger()).tostring()
    if (reward != "")
      res.description += " <color=@activeTextColor>" + reward + "</color>"

    local idx = 0
    local lineReward = ""
    while (($"chardReward{idx}") in logObj) {
      let blk = logObj[$"chardReward{idx}"]

      if ("country" in blk)
        lineReward += loc(blk.country) + loc("ui/colon")

      if ("name" in blk)
        lineReward += loc(blk.name) + " "

      if ("aname" in blk) {
        lineReward += getUnitName(blk.aname) + loc("ui/colon")
        if ("wname" in blk)
          lineReward += getWeaponNameText(blk.aname, false, blk.wname, loc("ui/comma")) + " "
        if ("mname" in blk)
          lineReward = "".join([
            lineReward, getModificationName(getAircraftByName(blk.aname), blk.mname), " "])
      }

      let blkWp = blk?.wpEarned ?? 0
      let blkGold = blk?.goldEarned ?? 0
      let blkExp = blk?.xpEarned ?? 0
      local blkReward = Cost(blkWp.tointeger(), blkGold.tointeger()).tostring()
      if (blkExp) {
        let changeLightToXP = blk?.name == MSG_FREE_EXP_DENOMINATE_OLD
        blkReward += ((blkReward != "") ? ", " : "") + (changeLightToXP ?
          (blkExp + " <color=@white>" + loc("mainmenu/experience/oldName") + "</color>")
          : Cost().setRp(blkExp.tointeger()).tostring())
      }

      lineReward += blkReward
      if (lineReward != "")
        lineReward += "\n"

      idx++
    }

    if ("clanDuelReward" in logObj) {
      let rewardBlk = logObj.clanDuelReward

      let difficultyStr = loc(getTblValue("difficulty", rewardBlk, ""))
      lineReward += loc("difficulty_name") + " <color=@white>" + difficultyStr +
          "</color>\n"

      if ("era" in rewardBlk) {
        let era = rewardBlk.era
        lineReward += loc("userLog/clanDuelRewardRank") + " <color=@white>" + era +
            "</color>\n"
      }

      let clanPlace = getTblValue("clanPlace", rewardBlk, -1)

      let clanRating = getTblValue("clanRating", rewardBlk, -1)

      //show rating only for place reward due for rating-reward rating showed in header
      if (clanPlace > 0)
        lineReward += loc("userLog/clanDuelRewardClanRating") + " <color=@white>" + clanRating +
            "</color>\n"

      let equalClanPlacesCount = getTblValue("equalClanPlacesCount", rewardBlk, -1)
      if (equalClanPlacesCount > 1) {
        lineReward += loc("userLog/clanDuelRewardEqualClanPlaces") + " <color=@white>" +
            (equalClanPlacesCount - 1) + "</color>\n"
      }

      res.description = ""
      let rewardCurency = Cost(wp, gold, exp).tostring()
      if (rewardCurency != "")
        res.description += loc("reward") + loc("ui/colon") + " " + colorize("activeTextColor", rewardCurency)

      //We don't want ~100 localization strings like "Your squadron took Nth place.".
      //So we left unique localizations only for top 3.
      if (clanPlace > 3)
        res.name = loc("userlog/ClanSeasonRewardPlaceN", { place = clanPlace.tostring() })
      else if (clanPlace > 0)
        res.name = loc("userlog/ClanSeasonRewardPlace" + clanPlace.tostring())
      else if (clanRating > 0)
        res.description = loc("userlog/ClanRewardRatingReached", { rating = clanRating.tostring() })


      let place = getTblValue("place", rewardBlk, -1)
      if (place > 0)
        lineReward += loc("userLog/clanDuelRewardPlace") + " <color=@white>" + place +
            "</color>\n"

      let rating = round(rewardBlk.rating);
      lineReward += loc("userLog/clanDuelRewardRating") + " <color=@white>" + rating +
            "</color>\n"

      let equalPlacesCount = getTblValue("equalPlacesCount", rewardBlk, -1)
      if (equalPlacesCount > 1) {
        lineReward += loc("userLog/clanDuelRewardEqualPlaces") + " <color=@white>" +
            (equalPlacesCount - 1) + "</color>\n"
      }

      let config = {
        locId = "clan_duel_reward"
        subType = ps4_activity_feed.CLAN_DUEL_REWARD
      }
      let customConfig = {
        gold = gold
        place = place
        blkParamName = "CLAN_DUEL_REWARD"
      }

      activityFeedPostFunc(config, customConfig, bit_activity.PS4_ACTIVITY_FEED)

      let resourcesConfig = getResourcesConfig(rewardBlk?.resource)
      if (resourcesConfig != null) {
        if (resourcesConfig.description.len() > 0) {
          let desc = "\n\n".join(resourcesConfig.description)
          res.description <- $"{res?.description ?? ""}{("description" in  res) ? "\n\n" : ""}{desc}"
        }
        res.logImg = resourcesConfig.logImg
        if (resourcesConfig.resourcesImagesMarkupArr.len() > 0)
          res.descriptionBlk <- descriptionBlkMultipleFormat.subst("".join(resourcesConfig.resourcesImagesMarkupArr))
      }
    }

    if (rewardType == "EveryDayLoginAward" || rewardType == "PeriodicCalendarAward") {
      let prefix = "trophy/"
      let pLen = prefix.len()
      if (rewardType == "EveryDayLoginAward")
        res.name += loc("ui/parentheses/space", {
          text = colorize("userlogColoredText", loc("enumerated_day", {
              number = getTblValue("progress", logObj, 0) + (getTblValue("daysFor0", logObj, 0) - 1)
        })) })

      let name = logObj.chardReward0.name
      let itemId = (name.len() > pLen && name.slice(0, pLen) == prefix) ? name.slice(pLen) : name
      let item = findItemById(itemId)
      if (item)
        lineReward = colorize("activeTextColor", item.getName())
      res.logImg = items_classes.Trophy.typeIcon
      res.descriptionBlk <- ::get_userlog_image_item(item)
    }
    else if (isInArray(rewardType, ["WagerStageWin", "WagerStageFail", "WagerWin", "WagerFail"])) {
      let itemId = getTblValue("id", logObj)
      let item = findItemById(itemId)
      if (item) {
        if (isInArray(rewardType, ["WagerStageWin", "WagerStageFail"]))
          res.name += loc("ui/colon") + colorize("userlogColoredText", item.getName())
        else
          res.name = loc($"userlog/{rewardType}", { wagerName = colorize("userlogColoredText", item.getName()) })

        let desc = []
        desc.append(loc("items/wager/numWins", { numWins = getTblValue("numWins", logObj), maxWins = item.maxWins }))
        desc.append(loc("items/wager/numFails", { numFails = getTblValue("numFails", logObj), maxFails = item.maxFails }))

        res.logImg = "#ui/gameuiskin#unlock_achievement"
        res.description += (res.description == "" ? "" : "\n") + "\n".join(desc, true)
        res.descriptionBlk <- ::get_userlog_image_item(item)
      }
    }
    else if (rewardType == "TournamentReward") {
      let result = getTournamentRewardData(logObj)
      let desc = []
      foreach (rewardBlk in result)
        desc.append(getConditionText(rewardBlk))

      lineReward = getTotalRewardDescText(result)
      res.description = "\n".join(desc, true)
      res.name = loc($"userlog/{rewardType}", {
                         name = colorize("userlogColoredText", ::events.getNameByEconomicName(getTblValue("name", logObj)))
                       })
    }

    if (lineReward != "")
      res.description += (res.description == "" ? "" : "\n") + lineReward
  }
  else if (logObj.type == EULT_ADMIN_ADD_GOLD || logObj.type == EULT_ADMIN_REVERT_GOLD) {
    let goldAdd = logObj?.goldAdd ?? 0
    let goldBalance = logObj?.goldBalance ?? 0
    let suffix = (goldAdd >= 0) ? "/positive" : "/negative"

    res.name = loc("userlog/" + logName + suffix, {
      gold = Money(money_type.none, 0, abs(goldAdd)).toStringWithParams({ isGoldAlwaysShown = true }),
      balance = Balance(0, goldBalance).toStringWithParams({ isGoldAlwaysShown = true })
    })
    res.description <- logObj?.comment ?? "" // not localized
  }
  else if (logObj.type == EULT_BUYING_SCHEME) {
    res.description <- getUnitName(logObj.unit) + priceText
  }
  else if (logObj.type == EULT_OPEN_ALL_IN_TIER) {
    let locTbl = {
      unitName = getUnitName(logObj.unit)
      tier = get_roman_numeral(logObj.tier)
      exp = 0
    }

    local desc = ""
    if ("expToInvUnit" in logObj && "resUnit" in logObj) {
      locTbl.resUnitExpInvest <- Cost().setRp(logObj.expToInvUnit).tostring()
      locTbl.resUnitName <- getUnitName(logObj.resUnit)
      desc = "\n" + loc($"userlog/{logName}/resName", locTbl)
      locTbl.exp += logObj.expToInvUnit
    }

    if ("expToExcess" in logObj) {
      locTbl.expToExcess <- Cost().setRp(logObj.expToExcess).tostring()
      desc += "\n" + loc($"userlog/{logName}/excessName", locTbl)
      locTbl.exp += logObj.expToExcess
    }

    locTbl.exp = Cost().setRp(locTbl.exp).tostring()
    res.name <- loc($"userlog/{logName}/name", locTbl)
    res.description <- loc($"userlog/{logName}/desc", locTbl) + desc

    let country = ::getShopCountry(logObj.unit)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = getCountryIcon(country)
  }
  else if (logObj.type == EULT_BUYING_MODIFICATION_MULTI) {
    if ("maname0" in logObj)
      res.name = format(loc($"userlog/{logName}"), getUnitName(getTblValue("maname0", logObj, ""))) + priceText
    else
      res.name = format(loc($"userlog/{logName}"), "")
    res.logImg = "#ui/gameuiskin#log_buy_mods"

    res.description <- ""
    local idx = 0
    let airDesc = {}

    idx = 0
    do {
      local desc = ""
      if (logObj.rawin($"maname{idx}") && logObj.rawin($"mname{idx}")) {
        desc = $"{desc}{getModificationName(getAircraftByName(logObj[$"maname{idx}"]), logObj[$"mname{idx}"])}"
        local wpCost = 0
        local goldCost = 0
        if (logObj.rawin($"mcount{idx}")) {
          if (logObj.rawin($"mwpCost{idx}"))
            wpCost = logObj[$"mwpCost{idx}"]
          if (logObj.rawin($"mgoldCost{idx}"))
            goldCost = logObj[$"mgoldCost{idx}"]

          desc += " x" + logObj[$"mcount{idx}"] + " " + Cost(wpCost, goldCost).tostring()
        }
        if (logObj[$"maname{idx}"] in airDesc)
          airDesc[logObj[$"maname{idx}"]] += "\n" + desc
        else
          airDesc[logObj[$"maname{idx}"]] <- desc
      }
      idx++
    } while (($"mname{idx}") in logObj)

    foreach (aname, iname in airDesc) {
      if (res.description != "")
        res.description += "\n\n"
      res.description += colorize("activeTextColor", getUnitName(aname)) + loc("ui/colon") + "\n"
      res.description += iname
    }
    res.tooltip = res.description
  }
  else if (logObj.type == EULT_OPEN_TROPHY) {
    let itemId = logObj?.itemDefId ?? logObj?.id ?? ""
    local item = findItemById(itemId)

    if (!item && logObj?.trophyItemDefId) {
      let extItem = findItemById(logObj?.trophyItemDefId)
      if (extItem)
        item = extItem.getContentItem()
    }

    if (item) {
      let tags = item?.itemDef.tags
      let isAutoConsume = tags?.autoConsume ?? false
      let cost = item.isEveryDayAward() ? Cost() : item.getCost()
      logName = (item?.userlogOpenLoc ?? logName) != logName
        || item.isEveryDayAward() ? item.userlogOpenLoc
          : $"{cost.gold > 0 ? "purchase_" : ""}{logName}"

      let usedText = isAutoConsume
        ? ::trophyReward.getRewardText(logObj, false, "userlogColoredText")
        : loc($"userlog/{logName}/short")
      let costText = cost.gold > 0
        ? loc("ui/parentheses/space", { text = $"{cost.getGoldText(true, false)}" }) : ""
      res.name = isAutoConsume
        ? " ".concat(item.blkType == "unlock" ? ""
          : loc("ItemBlueprintAssembleUnitInfo"), usedText)
        : " ".concat(usedText, loc("trophy/unlockables_names/trophy"), costText)

      res.logImg = item.getSmallIconName()
      if (isAutoConsume && "country" in tags
        && ::checkCountry($"country_{tags.country}", "autoConsume EULT_OPEN_TROPHY"))
          res.logImg2 = getCountryIcon($"country_{tags.country}")

      let nameMarkup = item.getNameMarkup()
      let rewardMarkup = format(textareaFormat,
        stripTags($"{loc("reward")}{loc("ui/colon")}"))
      res.descriptionBlk <- isAutoConsume
        ? ::get_userlog_image_item(item)
        : "".concat(format(textareaFormat,
          $"{stripTags(usedText)}{loc("ui/colon")}"), $"{nameMarkup}{rewardMarkup}")

      local resTextArr = []
      local rewards = {}
      if (!isAutoConsume) {
        if (logObj?.item) {
          if (type(logObj.item) == "array") {
            let items = logObj.item
            while (items.len()) {
              let inst = items.pop()
              if (inst in rewards)
                rewards[inst] += 1
              else
                rewards[inst] <- 1
            }
          }
          else
            rewards = { [logObj.item] = 1 }
          foreach (idx, val in rewards) {
            let data = {
              type = logObj.type
              item = idx
              count = val
            }
            resTextArr.append(::trophyReward.getRewardText(data))
            res.descriptionBlk = "".concat(res.descriptionBlk,
              ::trophyReward.getRewardsListViewData(logObj.__merge(data)))
          }
        }
        else {
          resTextArr = [::trophyReward.getRewardText(logObj)]
          res.descriptionBlk = $"{res.descriptionBlk}{::trophyReward.getRewardsListViewData(logObj)}"
        }

        let rewardText = "\n".join(resTextArr, true)
        let reward = $"{loc("reward")}{loc("ui/colon")}{rewardText}"
        res.tooltip = $"{usedText}{loc("ui/colon")}{item.getName()}\n{reward}"
      }
    }
    else
      res.name = loc($"userlog/{logName}", { trophy = loc("userlog/no_trophy"),
        reward = loc("userlog/trophy_deleted") })

    /*
    local prizes = ::trophyReward.getRewardList(logObj)
    if (prizes.len() == 1) //!!FIX ME: need to move this in PrizesView too
    {
      local prize = prizes[0]
      local prizeType = ::trophyReward.getRewardType(prize)

      if (isInArray(prizeType, [ "gold", "warpoints", "exp", "entitlement" ]))
      {
        local color = prizeType == "entitlement" ? "userlogColoredText" : "activeTextColor"
        local title = colorize(color, rewardText)
        res.descriptionBlk += format(textareaFormat, stripTags(loc("reward") + loc("ui/colon") + title))
      }
      else if (prizeType == "item")
      {
        res.descriptionBlk += format(textareaFormat, stripTags(loc("reward") + loc("ui/colon")))
        res.descriptionBlk += ::get_userlog_image_item(findItemById(prize.item))
      }
      else if (prizeType == "unlock" && getTblValue("unlockType", logObj) == "decal")
      {
        local title = colorize("userlogColoredText", rewardText)
        local config = ::build_log_unlock_data({ id = logObj.unlock })
        local imgSize = getTblValue("descrImageSize", config, "0.05sh, 0.05sh")
        res.descriptionBlk += format(textareaFormat, stripTags(loc("reward") + loc("ui/colon") + title))
        res.descriptionBlk += format(imgFormat, imgSize, config.descrImage)
      }
      else
      {
        res.descriptionBlk += format(textareaFormat, stripTags(loc("reward") + loc("ui/colon")))
        res.descriptionBlk += ::PrizesView.getPrizesListView(prizes)
      }
    }
    else
    {
        res.descriptionBlk += format(textareaFormat, stripTags(loc("reward") + loc("ui/colon")))
        res.descriptionBlk += ::PrizesView.getPrizesListView(prizes)
    }
    */
  }
  else if (logObj.type == EULT_BUY_ITEM) {
    let itemId = getTblValue("id", logObj, "")
    let item = findItemById(itemId)
    let locId = "userlog/" + logName + ((logObj.count > 1) ? "/multiple" : "")
    res.name = loc(locId, {
                     itemName = colorize("userlogColoredText", item ? item.getName() : "")
                     price = Cost(logObj.cost * logObj.count, logObj.costGold * logObj.count).tostring()
                     amount = logObj.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item, { type = logObj.type })
    res.logImg = (item && item.getSmallIconName()) || BaseItem.typeIcon
  }
  else if (logObj.type == EULT_NEW_ITEM) {
    let itemId = getTblValue("id", logObj, "")
    let item = findItemById(itemId)
    let locId = "userlog/" + logName + ((logObj.count > 1) ? "/multiple" : "")
    res.logImg = (item && item.getSmallIconName()) || BaseItem.typeIcon
    res.name = loc(locId, {
                     itemName = colorize("userlogColoredText", item ? item.getName() : "")
                     amount = logObj.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item, { count = logObj.count })
  }
  else if (logObj.type == EULT_ACTIVATE_ITEM) {
    let itemId = getTblValue("id", logObj, "")
    let item = findItemById(itemId)
    res.logImg = (item && item.getSmallIconName()) || BaseItem.typeIcon
    let nameId = (item?.isSpecialOffer ?? false) ? "specialOffer/recived" : logName
    res.name = loc($"userlog/{nameId}", {
                     itemName = colorize("userlogColoredText", item ? item.getName() : "")
                   })
    if ("itemType" in logObj && logObj.itemType == "wager") {
      local wager = 0;
      local wagerGold = 0;

      if ("wager" in logObj)
        wager = logObj.wager

      if ("wagerGold" in logObj)
        wagerGold = logObj.wagerGold

      if (wager > 0 || wagerGold > 0)
        res.description <- loc("userlog/" + logName + "_desc/wager") + " " +
          Cost(wager, wagerGold).tostring()
    }
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (logObj.type == EULT_REMOVE_ITEM) {
    let itemId = getTblValue("id", logObj, "")
    let item = findItemById(itemId)
    let reason = logObj?.reason ?? "unknown"
    let nameId = (item?.isSpecialOffer ?? false) ? "specialOffer" : logName
    local locId = $"userlog/{nameId}/{reason}"
    if (reason == "replaced") {
      let replaceItemId = getTblValue("replaceId", logObj, "")
      let replaceItem = findItemById(replaceItemId)
      res.name = loc(locId, {
                     itemName = colorize("userlogColoredText", item ? item.getName() : "")
                     replacedItemName = colorize("userlogColoredText", replaceItem ? replaceItem.getName() : "")
                   })
      res.descriptionBlk <- ::get_userlog_image_item(item) + ::get_userlog_image_item(replaceItem)
    }
    else {
      res.name = loc(locId, {
                     itemName = colorize("userlogColoredText", item ? item.getName() : "")
                   })
      res.descriptionBlk <- ::get_userlog_image_item(item)
    }
    let itemTypeValue = logObj?.itemType ?? ""
    if (itemTypeValue == "universalSpare" && reason == "unknown") {
      locId = $"userlog/{logName}"
      let unit =  getTblValue("unit", logObj)
      if (unit != null)
        res.logImg2 = getCountryIcon(::getShopCountry(unit))
      let numSpares = getTblValue("numSpares", logObj, 1)
      res.name = loc($"{locId}_name/universalSpare", {
                     numSparesColored = colorize("userlogColoredText", numSpares)
                     numSpares = numSpares
                     unitName = (unit != null ? colorize("userlogColoredText", getUnitName(unit)) : "")
                   })
      res.descriptionBlk <- format(textareaFormat,
                                stripTags(loc($"{locId}_desc/universalSpare") + loc("ui/colon")))
      res.descriptionBlk += item.getNameMarkup(numSpares, true)
    }
    else if (itemTypeValue == "wager") {
      let earned = Cost(getTblValue("wpEarned", logObj, 0), getTblValue("goldEarned", logObj, 0))
      if (earned > ::zero_money)
        res.description <- loc("userlog/" + logName + "_desc/wager") + " " + earned.tostring()
    }
    res.logImg = (item && item.getSmallIconName()) || BaseItem.typeIcon
  }
  else if (logObj.type == EULT_INVENTORY_ADD_ITEM ||
           logObj.type == EULT_INVENTORY_FAIL_ITEM) {
    local amount = 0
    local itemsNumber = 0
    local firstItemName = ""
    local itemsListText = ""

    res.descriptionBlk <- ""
    foreach (data in logObj) {
      if (!("itemDefId" in data))
        continue

      let item = findItemById(data.itemDefId)
      if (!item)
        continue

      let quantity = data?.quantity ?? 1
      res.descriptionBlk += item.getNameMarkup(quantity, true, true)
      res.logImg = res.logImg || item.getSmallIconName()

      amount += quantity
      itemsListText += $"\n {loc("ui/bullet")}{item.getNameWithCount(true, quantity)}"
      if (itemsNumber == 0)
        firstItemName = item.getName()

      itemsNumber ++
    }

    let costString = Cost(("wpCost" in logObj) ? logObj.wpCost * amount : 0,
      ("goldCost" in logObj) ? logObj.goldCost * amount : 0).tostring()

    res.logImg = res.logImg || BaseItem.typeIcon

    let locId = costString == "" ? $"userlog/{logName}"
      : amount > 1 ? "userlog/buy_item/multiple"
      : "userlog/buy_item"

    res.name = loc(locId, {
      numItemsColored = colorize("userlogColoredText", amount)
      numItems = amount
      numItemsAdd = amount
      itemName = itemsNumber == 1 ? firstItemName : ""
      price = costString
      amount = amount
    })

    if (itemsNumber > 1)
      res.tooltip = loc(locId, {
        numItemsColored = colorize("userlogColoredText", amount)
        numItems = amount
        numItemsAdd = amount
        itemName = itemsListText
        price = costString
        amount = amount
      })
  }
  else if (logObj.type == EULT_TICKETS_REMINDER) {
    res.name = loc($"userlog/{logName}") + loc("ui/colon") +
        colorize("userlogColoredText", ::events.getNameByEconomicName(logObj.name))

    let desc = []
    if (getTblValue("battleLimitReminder", logObj))
      desc.append(loc("userlog/battleLimitReminder") + loc("ui/colon") + logObj.battleLimitReminder)
    if (getTblValue("defeatCountReminder", logObj))
      desc.append(loc("userlog/defeatCountReminder") + loc("ui/colon") + logObj.defeatCountReminder)
    if (getTblValue("sequenceDefeatCountReminder", logObj))
      desc.append(loc("userlog/sequenceDefeatCountReminder") + loc("ui/colon") + logObj.sequenceDefeatCountReminder)

    res.description <- "\n".join(desc, true)
  }
  else if (logObj.type == EULT_BUY_BATTLE) {
    res.name = loc($"userlog/{logName}") + loc("ui/colon") +
      colorize("userlogColoredText", ::events.getNameByEconomicName(logObj.tournamentName))

    let cost = Cost()
    cost.wp = getTblValue("costWP", logObj, 0)
    cost.gold = getTblValue("costGold", logObj, 0)
    res.description <- loc("events/battle_cost", { cost = cost.tostring() })
  }
  else if (logObj.type == EULT_CONVERT_EXPERIENCE) {
    let logId = $"userlog/{logName}"

    res.logImg = "#ui/gameuiskin#convert_xp.svg"
    let unitName = logObj["unit"]
    let country = ::getShopCountry(unitName)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = getCountryIcon(country)

    let cost = Cost()
    cost.wp = getTblValue("costWP", logObj, 0)
    cost.gold = getTblValue("costGold", logObj, 0)
    let exp = getTblValue("exp", logObj, 0)

    res.description <- loc($"{logId}/desc", { cost = cost.tostring(), unitName = getUnitName(unitName),
      exp = Cost().setFrp(exp).tostring() })
  }
  else if (logObj.type == EULT_SELL_BLUEPRINT) {
    let itemId = getTblValue("id", logObj, "")
    let item = findItemById(itemId)
    let locId = "userlog/" + logName + ((logObj.count > 1) ? "/multiple" : "")
    res.name = loc(locId, {
                     itemName = colorize("userlogColoredText", item ? item.getName() : "")
                     price = Cost(logObj.cost * logObj.count, logObj.costGold * logObj.count).tostring()
                     amount = logObj.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (isInArray(logObj.type, [EULT_PUNLOCK_ACCEPT,
                                  EULT_PUNLOCK_CANCELED,
                                  EULT_PUNLOCK_EXPIRED,
                                  EULT_PUNLOCK_NEW_PROPOSAL,
                                  EULT_PUNLOCK_ACCEPT_MULTI])) {
    local locNameId = $"userlog/{logName}"
    res.logImg = EASY_TASK.image

    if ((logObj.type == EULT_PUNLOCK_ACCEPT_MULTI || logObj.type == EULT_PUNLOCK_NEW_PROPOSAL) && "new_proposals" in logObj) {
      if (logObj.new_proposals.len() > 1) {
        if (getDifficultyByProposals(logObj.new_proposals) == HARD_TASK) {
          res.logImg = HARD_TASK.image
          locNameId = "userlog/battle_tasks_new_proposal/special"
        }
        res.description <- getBattleTaskUpdateDesc(logObj.new_proposals)
      }
      else
        locNameId = "userlog/battle_tasks_accept"
    }

    local taskName = ""

    if (logObj?.id) {
      let battleTask = getBattleTaskById(logObj.id)
      if (battleTask)
        res.logImg = getDifficultyTypeByTask(battleTask).image
      else
        res.logImg = getDifficultyTypeById(logObj.id).image

      taskName = getBattleTaskUserLogText(logObj, logObj.id)
    }

    res.buttonName = loc("mainmenu/battleTasks/OtherTasksCount")
    res.name = loc(locNameId, { taskName = taskName })
  }
  else if (logObj.type == EULT_PUNLOCK_REROLL_PROPOSAL && "new_proposals" in logObj) {
    let text = getBattleTaskUpdateDesc(logObj.new_proposals)
    if (logObj.new_proposals.len() > 1)
      res.description <- text
    else
      res.name = loc($"userlog/{logName}", { taskName = text })

    res.logImg = getDifficultyByProposals(logObj.new_proposals).image
  }
  else if (logObj.type == EULT_CONVERT_BLUEPRINTS) {
    let locId = $"userlog/{logName}"
    res.name = loc(locId, {
                     from = loc("userlog/blueprintpart_name/" + getTblValue("from", logObj, ""))
                     to = loc("userlog/blueprintpart_name/" + getTblValue("to", logObj, ""))
                   })

    res.description <- loc($"{locId}/desc")

    foreach (unitName, unitData in logObj) {
      if (!("result" in unitData))
        continue

      let resItem = findItemById(unitData.result)
      res.description += "\n" + loc($"{unitName}_0") + loc("ui/colon") + ::get_userlog_image_item(resItem)
      local idx = 0
      while (($"source{idx}") in unitData) {
        let srcItem = findItemById(unitData[$"source{idx}"])
        res.description += ::get_userlog_image_item(srcItem)
        idx++
      }
    }
  }
  else if (logObj.type == EULT_RENT_UNIT || logObj.type == EULT_RENT_UNIT_EXPIRED) {
    let unitName = getTblValue("unit", logObj)
    if (unitName) {
      res.name = loc($"userlog/{logName}", { unitName = loc($"{unitName}_0") })
      if (logObj.type == EULT_RENT_UNIT) {
        res.description <- ""
        if ("rentTimeSec" in logObj)
          res.description += loc("mainmenu/rent/rentTimeSec",
            { time = time.hoursToString(time.secondsToHours(logObj.rentTimeSec)) })
      }
    }
  }
  else if (logObj.type == EULT_EXCHANGE_WARBONDS) {
    let awardData = getTblValue("award", logObj)
    if (awardData) {
      let wbPriceText = ::g_warbonds.getWarbondPriceText(awardData?.cost ?? 0)
      let awardBlk = DataBlockAdapter(awardData)
      let awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
      res.name = awardType.getUserlogBuyText(awardBlk, wbPriceText)
    }
  }
  else if (logObj.type == EULT_WW_START_OPERATION || logObj.type == EULT_WW_CREATE_OPERATION) {
    let locId = logObj.type == EULT_WW_CREATE_OPERATION ? "worldWar/userlog/createOperation"
                                                         : "worldWar/userlog/startOperation"
    local operation = ""
    if (::is_worldwar_enabled())
      operation = ::WwOperation.getNameTextByIdAndMapName(
        getTblValue("operationId", logObj),
        WwMap.getNameTextByMapName(getTblValue("mapName", logObj))
      )
    res.name = loc(locId, { clan = logObj?.name, operation = operation })
    let appName = ::getContact(logObj?.registratorId.tostring())?.getName()
    let description = [appName ? $"{loc("worldwar/applicant")}{colon} {appName}" : ""]

    if (logObj?.wpCost != null) {
      let costString = Cost(logObj.wpCost).toStringWithParams({ isWpAlwaysShown = true })
      description.append($"{loc("worldwar/creation_cost")}{colon} {costString}")
    }
    res.description <- "\n".join(description, true)
  }
  else if (logObj.type == EULT_WW_END_OPERATION) {
    local textLocId = "worldWar/userlog/endOperation/"
    textLocId += getTblValue("winner", logObj) ? "win" : "lose"
    let mapName = getTblValue("mapName", logObj)
    let opId = getTblValue("operationId", logObj)
    let earnedText = Cost(getTblValue("wp", logObj, 0)).toStringWithParams({ isWpAlwaysShown = true })
    res.name = loc(textLocId, {
      opId = opId, mapName = loc($"worldWar/map/{mapName}"), reward = earnedText })

    let description = [
      $"{loc("multiplayer/lb_kills_player")}{colon}{logObj.userStats.playerKills}",
      $"{loc("multiplayer/lb_kills_ai")}{colon}{logObj.userStats.aiKills}",
      $"{loc("multiplayer/flyouts")}{colon}{logObj.userStats.flyouts}",
      $"{loc("multiplayer/deaths")}{colon}{logObj.userStats.deaths}",
      $"{loc("multiplayer/mission_score")}{colon}{logObj.userStats.score}",
      $"{loc("multiplayer/mission_wp_earned")}{colon}{logObj.userStats.wpEarned}"
    ]

    let hasManager = logObj?.managerStats == null ? false : true
    if (hasManager) {
      let { actionsCount = 0, totalActionsCount = 0 } = logObj?.managerStats
      let activity = totalActionsCount > 0
        ? round_by_value(actionsCount.tofloat() / totalActionsCount.tofloat(), 0.01)
        : 0
      description.append(
        $"{loc("multiplayer/total_score")}{colon}{logObj.managerStats.totalScore}",
        $"{loc("multiplayer/commander_activity")}{colon}{"".concat((activity * 100 + 0.5).tointeger(), "%")}"
      )
    }
    let reward = Cost((logObj?.wp ?? 0) - (logObj?.managerStats.wpManager ?? 0)).toStringWithParams({
      isWpAlwaysShown = true })
    description.append(
      "",
      $"{loc("worldWar/endOperation/reward")}{colon}{reward}"
    )

    if (hasManager) {
      let manager_reward = Cost(logObj?.managerStats.wpManager ?? 0).toStringWithParams({
        isWpAlwaysShown = true })
      description.append($"{loc("worldWar/endOperation/manager_reward")}{colon}{manager_reward}")
    }
    res.description <- "\n".join(description)
  }
  else if (logObj.type == EULT_INVITE_TO_TOURNAMENT) {
    if ("action_tss" in logObj) {
      let action_tss = logObj.action_tss
      local desc = ""

      if (action_tss == "awards_tournament") {
        res.name = loc("userlog/awards_tss_tournament", { TournamentName = logObj.tournament_name })
        foreach (_award_idx, award_val in logObj.awards) {
          if (award_val.type == "gold")
            desc += "\n" + "<color=@activeTextColor>" +
              Cost(0, abs(award_val.award)).toStringWithParams({ isGoldAlwaysShown = true }) + "</color>"
          if (award_val.type == "premium")
            desc += "\n" + "<color=@activeTextColor>" + award_val.award + "</color>"
          if (award_val.type == "booster") {
            foreach (block in award_val.award) {
              let item = findItemById(block)
              if (!("descriptionBlk" in res))
                res.descriptionBlk <- ""
              res.descriptionBlk += ::get_userlog_image_item(item)
            }
          }
          if (award_val.type == "title")
            desc += "\n" + "<color=@activeTextColor>" + loc("trophy/unlockables_names/title") + ": " +
              getUnlockNameText(UNLOCKABLE_TITLE, award_val.award) + "</color>"
        }
      }
      else if (action_tss == "invite_to_pick_tss") {
        res.name = loc("userlog/invite_to_pick_tss", { TournamentName = logObj.tournament_name })
        if (!("descriptionBlk" in res))
          res.descriptionBlk <- ""
        if ("circuit" in logObj)
          res.descriptionBlk += getLinkMarkup(loc("mainmenu/btnPickTSS"),
            getCurCircuitOverride("serverPickTssURL", loc("url/serv_pick_tss")).subst({ port = logObj.port, circuit = logObj.circuit }), "Y")
        desc += loc("invite_to_pick_tss/desc")
      }
      else if (action_tss == "invite_to_tournament") {
        res.name = loc("userlog/invite_to_tournament_name", { TournamentName = logObj.tournament_name })
        if ("name_battle" in logObj) {
          desc += loc("invite_to_tournament/desc")
          desc += "\n" + logObj.name_battle
        }
      }

      if (desc != "")
        res.description <- desc
      if (logObj?.battleId && hasFeature("Tournaments") && (!needShowCrossPlayInfo() || isCrossPlayEnabled()))
        res.buttonName = getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("chat/btnJoin"))
    }
  }
  else if (logObj.type == EULT_CLAN_UNITS) {
    let textLocId =$"userlog/clanUnits/{logObj.optype}"
    res.name = loc($"{textLocId}/name")

    let descLoc =$"{textLocId}/desc"

    if (logObj.optype == "flush") {
      res.description <- loc(descLoc, { unit = loc($"{logObj.unit}_0"), rp = Cost().setSap(logObj.rp).tostring() })
    }
    else if (logObj.optype == "add_unit") {
      res.description <- loc(descLoc, { unit = loc($"{logObj.unit}_0") })
    }
    else if (logObj.optype == "buy_closed_unit") {
      res.description <- loc(descLoc, { unit = loc($"{logObj.unit}_0"), cost = Cost(0, logObj.costGold) })
    }
  }
  else if (logObj.type == EULT_WW_AWARD) {
    res.name = loc("worldwar/personal/award")
    let awardsFor = logObj?.awardsFor
    let descLines = []
    if (awardsFor != null) {
      let day = cutPrefix(awardsFor.table, "day")
      let period = day ? loc("enumerated_day", { number = day }) : loc("worldwar/allSeason")
      let modeStr = split(awardsFor.mode, "__")
      local mapName = null
      local country = null
      foreach (partStr in modeStr) {
        if (startsWith(partStr, "country_"))
          country = partStr
        if (endsWith(partStr, "_wwmap"))
          mapName = partStr
      }
      country = country ? loc(country) : loc("worldwar/allCountries")
      mapName = mapName ? loc($"worldWar/map/{mapName}") : loc("worldwar/allMaps")
      let leaderboard = loc("mainmenu/leaderboard") + loc("ui/colon")
        + loc("ui/comma").join([period, mapName, country], true)
      descLines.append(leaderboard)

      if ("user_leaderboards" == awardsFor.leaderboard_type) {
         res.name = loc("worldwar/personal/award")
         descLines.append(loc("multiplayer/place") + loc("ui/colon") + awardsFor.place)
       }
      else if ( "clan_leaderboards"== awardsFor.leaderboard_type) {
        res.name = loc("worldwar/clan/award")
        descLines.append(loc("multiplayer/clan_place") + loc("ui/colon") + awardsFor.clan_place)
        descLines.append(loc("multiplayer/place_in_clan_leaderboard") + loc("ui/colon") + awardsFor.place)
      }
    }
    let item = findItemById(logObj?.itemDefId)
    if (item)
      descLines.append(colorize("activeTextColor", item.getName()))
    res.logImg = item?.getSmallIconName()

    let markupArr = []
    let itemMarkup = ::get_userlog_image_item(item)
    if (itemMarkup != "")
      markupArr.append(itemMarkup)

    let resourcesConfig = getResourcesConfig(logObj?.resources.resource)
    if (resourcesConfig != null) {
      if (resourcesConfig.description.len() > 0)
        descLines.append($"\n{"\n\n".join(resourcesConfig.description)}")
      res.logImg = res.logImg ?? resourcesConfig.logImg
      markupArr.extend(resourcesConfig.resourcesImagesMarkupArr)
    }

    res.descriptionBlk <- descriptionBlkMultipleFormat.subst("".join(markupArr))
    res.description <- "\n".join(descLines, true)
  }
  else if (logObj.type == EULT_COMPLAINT_UPHELD) {
    res.name = loc($"userlog/{logName}/successful_single")
  }

  if (isMissionExtrLog || (res?.description ?? "") != "") {
    if (!("descriptionBlk" in res))
      res.descriptionBlk <- ""

    if (!isMissionExtrLog) {
      let battleRewards = logObj.type == EULT_SESSION_RESULT ? getBattleRewards(logObj) : []
      let hasAdditionalInfo = battleRewards.findvalue(@(r) r?.battleRewardTooltipId != null) != null
      let blk = hasAdditionalInfo
        ? handyman.renderCached("%gui/userLog/userLogBattleRewardsTable.tpl", {battleRewards})
        : ""

      if (!hasAdditionalInfo && battleRewards.len() > 0) {
        let rewardsStrs = battleRewards.map(function(r) {
          let name = r.name
          let rewards = ", ".join([r?.wp, r?.exp].filter(@(cost) cost != null && cost.toPlainText() != ""))
          return $"{name}: {colorize("@activeTextColor", rewards)}"
        })
        let rewardsShortDescr = "\n".join(rewardsStrs)
        res.description = "".concat(rewardsShortDescr, "\n\n", res.description)
      }

      res.descriptionBlk = "".concat(res.descriptionBlk,
        blk,
        "textareaNoTab { id:t='description'; width:t='pw'; text:t='",
        stripTags(res?.description ?? ""), "';}",
      )
    }

    if (isMissionExtrLog && logObj.type == EULT_SESSION_RESULT) {
      let inventoryLogObjects = ::getUserLogsList({ show = [ EULT_INVENTORY_ADD_ITEM ] })
        .filter(@(l) l.roomId == logObj.roomId)

      let itemDefIdCountMap = {}
      foreach (inventoryLogObj in inventoryLogObjects)
        foreach (val in inventoryLogObj) {
          if (type(val) != "table" || ("itemDefId" not in val))
            continue

          let quantity = val?.quantity ?? 1
          if (itemDefIdCountMap?[val.itemDefId] == null)
            itemDefIdCountMap[val.itemDefId] <- quantity
          else
            itemDefIdCountMap[val.itemDefId] += quantity
        }

      let view = { items = [] }
      foreach (inventoryLogObj in inventoryLogObjects)
        foreach (val in inventoryLogObj) {
          if (type(val) != "table" || ("itemDefId" not in val))
            continue

          let item = findItemById(val.itemDefId)
          if (!item)
            continue

          let count = itemDefIdCountMap?[val.itemDefId] ?? -1
          if (count == -1)
            continue

          itemDefIdCountMap[val.itemDefId] = -1
          view.items.append(item.getViewData({
            count
            enableBackground = false
          }))
        }

      if (view.items.len() > 0) {
        let markup = handyman.renderCached("%gui/items/item.tpl", view)
        res.descriptionBlk = "".concat(res.descriptionBlk,
          format("tdiv { width:t='pw'; flow:t='h-flow'; %s }", markup))
      }
    }

    if ("compensation" in res) {
      let compensationBlk = handyman.renderCached("%gui/userLog/userLogCompensation.tpl", {compensation = res.compensation})
      res.descriptionBlk = "".concat(res.descriptionBlk, compensationBlk)
    }

    if ("descriptionBottom" in res) {
      res.descriptionBlk = "".concat(res.descriptionBlk, "textareaNoTab { id:t='descriptionBottom'; width:t='pw'; text:t='",
        stripTags(res.descriptionBottom), "';}")
    }

    if (logObj.type == EULT_SESSION_RESULT && is_platform_pc)
      res.descriptionBlk = "".concat(res.descriptionBlk,
        "textareaNoTab { position:t='absolute';pos:t='pw-w, ph-h'; text:t='#userlog/copyToClipboard' }")
  }

  //------------- when userlog not found or not full filled -------------//
  if (res.name == "")
    res.name = loc($"userlog/{logName}")

  return res
}