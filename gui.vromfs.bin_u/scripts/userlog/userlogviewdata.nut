local time = require("scripts/time.nut")
local { getWeaponNameText } = require("scripts/weaponry/weaponryDescription.nut")
local { getModificationName } = require("scripts/weaponry/bulletsVisual.nut")
local { getBulletsSetData } = require("scripts/weaponry/bulletsInfo.nut")
local { getEntitlementConfig, getEntitlementName, getEntitlementPrice } = require("scripts/onlineShop/entitlements.nut")
local { isCrossPlayEnabled,
        getTextWithCrossplayIcon,
        needShowCrossPlayInfo } = require("scripts/social/crossplay.nut")
local activityFeedPostFunc = require("scripts/social/activityFeed/activityFeedPostFunc.nut")

local imgFormat = "img {size:t='%s'; background-image:t='%s'; margin-right:t='0.01@scrn_tgt;'} "
local textareaFormat = "textareaNoTab {id:t='description'; width:t='pw'; text:t='%s'} "
local descriptionBlkMultipleFormat = "tdiv { flow:t='h-flow'; width:t='pw'; {0} }"
local { boosterEffectType } = require("scripts/items/boosterEffect.nut")
local { getActiveBoostersDescription } = require("scripts/items/itemVisual.nut")

local clanActionNames = {
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
local getClanActionName = @(action) clanActionNames?[action] ?? "unknown"

local function getDecoratorUnlock(resourceId, resourceType)
{
  local unlock = ::create_default_unlock_data()
  local decoratorType = null
  unlock.id = resourceId
  decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
  if (decoratorType != ::g_decorator_type.UNKNOWN)
  {
    unlock.name = decoratorType.getLocName(unlock.id, true)
    unlock.desc = decoratorType.getLocDesc(unlock.id)
    unlock.image = decoratorType.userlogPurchaseIcon

    local decorator = ::g_decorator.getDecorator(unlock.id, decoratorType)
    if (decorator && !::is_in_loading_screen())
    {
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

  local res = {
    description = []
    logImg = null
    resourcesImagesMarkupArr = []
  }

  //after convertation from DataBlk to table array with 1 element becomes table.
  //So we normalize data format.
  if (::u.isTable(resources))
    resources = [resources]

  foreach (resource in resources) {
    local unlock = getDecoratorUnlock(resource.resourceId, resource.resourceType)
    local desc = unlock?.desc ?? ""
    if (desc != "")
      res.description.append(desc)

    res.logImg = unlock?.image ?? res.logImg
    local descrImage = unlock?.descrImage ?? ""
    if (descrImage != "") {
      local imgSize = unlock?.descrImageSize ?? "0.05sh, 0.05sh"
      res.resourcesImagesMarkupArr.append(::format(imgFormat, imgSize, unlock.descrImage))
    }
  }

  return res
}

local function getLinkMarkup(text, url, acccessKeyName=null)
{
  if (!::u.isString(url) || url.len() == 0 || !::has_feature("AllowExternalLink"))
    return ""

  local btnParams = {
    text = text
    isHyperlink = true
    link = url
  }
  if (acccessKeyName && acccessKeyName.len() > 0)
  {
    btnParams.acccessKeyName <- acccessKeyName
  }
  return ::handyman.renderCached("gui/commonParts/button", btnParams)
}

::update_repair_cost <- function update_repair_cost(units, repairCost)
{
  local idx = 0
  while (("cost"+idx) in units) {
    local cost = ::getTblValue("cost"+idx, units, 0)
    if (cost>0)
      repairCost.rCost += cost
    else
      repairCost.notEnoughCost -= cost
    idx++
  }
}

::get_userlog_view_data <- function get_userlog_view_data(log)
{
  local res = {
    name = "",
    time = time.buildDateTimeStr(log.time, true)
    tooltip = ""
    logImg = null
    logImg2 = null
    logBonus = null
    logIdx = log.idx
    buttonName = null
  }
  local logName = getLogNameByType(log.type)
  local priceText = ::Cost(("wpCost" in log) ? log.wpCost : 0,
    ("goldCost" in log) ? log.goldCost : 0).tostring()
  if (priceText!="")  priceText = " ("+priceText+")"

  if (log.type == ::EULT_SESSION_START ||
      log.type == ::EULT_EARLY_SESSION_LEAVE ||
      log.type == ::EULT_SESSION_RESULT)
  {
    if (("country" in log) && ::checkCountry(log.country, "userlog EULT_SESSION_"))
      res.logImg2 = ::get_country_icon(log.country)

    local mission = get_mission_name(log.mission, log)
    if ("eventId" in log && !::events.isEventRandomBattlesById(log.eventId))
    {
      local locName = ""

      if ("eventLocName" in log)
       locName = log.eventLocName
      else
       locName = "events/" + log.eventId + "/name"
      logName = "event/" + logName
      mission = ::loc(locName, log.eventId)
    }

    local nameLoc = "userlog/"+logName
    if (log.type==::EULT_EARLY_SESSION_LEAVE)
      res.logImg = "#ui/gameuiskin#log_leave"
    else
      if (log.type==::EULT_SESSION_RESULT)
      {
        nameLoc += log.win? "/win":"/lose"
        res.logImg = "#ui/gameuiskin#" + (log.win? "log_win" : "log_lose")
      }
    res.name = format(::loc(nameLoc), mission)

    local desc = ""
    local wp = ::getTblValue("wpEarned", log, 0) + ::getTblValue("baseTournamentWp", log, 0)
    local gold = ::getTblValue("goldEarned", log, 0) + ::getTblValue("baseTournamentGold", log, 0)
    local xp = ::getTblValue("xpEarned", log, 0)
    local earnedText = ::Cost(wp, gold, xp).toStringWithParams({isWpAlwaysShown = true})
    if (earnedText!="")
    {
      earnedText = ::loc("ui/colon") + "<color=@activeTextColor>" + earnedText + "</color>"
      desc += ((desc!="")? "\n":"") + ::loc("userlog/earned") + earnedText
    }

    if (log.type == ::EULT_SESSION_RESULT && ("activity" in log))
    {
      local activity = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(log.activity)
      desc += "\n" + ::loc("conditions/activity") + ::loc("ui/colon") + activity
    }

    if (("friendlyFirePenalty" in log) && log.friendlyFirePenalty != 0)
    {
      desc += "\n" + ::loc("debriefing/FriendlyKills") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" +
        ::Cost(log.friendlyFirePenalty).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
      wp += log.friendlyFirePenalty
    }

    if (("nRespawnsWp" in log) && log.nRespawnsWp != 0)
    {
      desc += "\n" + ::loc("debriefing/MultiRespawns") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" +
        ::Cost(log.nRespawnsWp).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
      wp += log.nRespawnsWp
    }

    if ("aircrafts" in log)
    {
      local aText = ""
      foreach(air in log.aircrafts)
        if (air.value < 1.0)
          aText += ((aText!="")? ", ":"") + ::getUnitName(air.name)// + format(" (%d%%)", (100.0*air.value).tointeger())
      if (aText!="")
        desc += "\n" + ::loc("userlog/broken_airs") + ::loc("ui/colon") + aText
    }

    if ("spare" in log)
    {
      local aText = ""
      foreach(air in log.spare)
        if (air.value > 0)
        {
          aText += ((aText!="")? ", ":"") + ::getUnitName(air.name)
          if (air.value > 1)
            aText += format(" (%d)", air.value.tointeger())
        }
      if (aText!="")
        desc += "\n" + ::loc("userlog/used_spare") + ::loc("ui/colon") + aText
    }

    local containerLog = ::getTblValue("container", log)

    local freeRepair = ("aircrafts" in log) && log.aircrafts.len() > 0
    local repairCost = {rCost = 0, notEnoughCost = 0}
    local aircraftsRepaired = ::getTblValue("aircraftsRepaired", containerLog)
    if (aircraftsRepaired)
      update_repair_cost(aircraftsRepaired, repairCost);

    local unitsRepairedManually = ::getTblValue("manuallySpentRepairCost", log)
    if (unitsRepairedManually)
      update_repair_cost(unitsRepairedManually, repairCost);

    if (repairCost.rCost>0)
    {
      desc += "\n" + ::loc("shop/auto_repair_cost") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" + ::Cost(-repairCost.rCost).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
      wp -= repairCost.rCost
      freeRepair = false
    }
    if (repairCost.notEnoughCost!=0)
    {
      desc += "\n" + ::loc("shop/auto_repair_failed") + ::loc("ui/colon")
      desc += "<color=@warningTextColor>(" +
        ::Cost(repairCost.notEnoughCost).toStringWithParams({isWpAlwaysShown = true}) + ")</color>"
      freeRepair = false
    }

    if (freeRepair && ("autoRepairWasOn" in log) && log.autoRepairWasOn)
    {
      desc += "\n" + ::loc("shop/auto_repair_free")
    }

    local wRefillWp = ::getTblValue("wpCostWeaponRefill", containerLog, 0)
    local wRefillGold = ::getTblValue("goldCostWeaponRefill", containerLog, 0)
    if (wRefillWp || wRefillGold)
    {
      desc += "\n" + ::loc("shop/auto_buy_weapons_cost") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" + ::Cost(-wRefillWp, -wRefillGold).tostring() + "</color>"
      wp -= wRefillWp
      gold -= wRefillGold
    }

    local rp = 0
    if ("rpEarned" in log)
    {
      local descUnits = ""
      local descMods = ""

      local idx = 0
      while (("aname"+idx) in log.rpEarned)
      {
        local unitId = log.rpEarned["aname"+idx]
        local modId = (("mname"+idx) in log.rpEarned) ? log.rpEarned["mname"+idx] : null
        local mrp = log.rpEarned["mrp"+idx]

        local fromExcessRP = ("merp" + idx) in log.rpEarned ? log.rpEarned["merp" + idx] : 0
        rp += mrp + fromExcessRP

        local modText = ""
        if (modId)
        {
          local unit = getAircraftByName(unitId)
          local bulletsSet = getBulletsSetData(unit, modId)
          modText = $" - {getModificationName(unit, modId, bulletsSet)}"
        }
        local title = $"{::getUnitName(unitId)}{modText}"
        local item = "".join(["\n", title, ::loc("ui/colon"),"<color=@activeTextColor>",
          ::Cost().setRp(mrp).tostring(), "</color>"])

        if (fromExcessRP > 0)
          item += " + " + ::loc("userlog/excessExpEarned") + ::loc("ui/colon") +
            "<color=@activeTextColor>" + ::Cost().setRp(fromExcessRP).tostring() + "</color>"

        if (!modId)
          descUnits += item
        else
          descMods += item

        idx++
      }

      if (descUnits.len())
        desc += "\n\n<color=@activeTextColor>" + ::loc("debriefing/researched_unit") + ::loc("ui/colon") + "</color>" + descUnits
      if (descMods.len())
        desc += "\n\n<color=@activeTextColor>" + ::loc("debriefing/research_list") + ::loc("ui/colon") + "</color>" + descMods
    }

    if (::getTblValue("haveTeamkills", log, false))
      desc += ((desc!="")? "\n\n":"") + "<color=@activeTextColor>" + ::loc("debriefing/noAwardsCaption") + "</color>"

    local usedItems = []

    if ("affectedBoosters" in log)
    {
      local affectedBoosters = log.affectedBoosters
      // Workaround for a bug (duplicating 'affectedBoosters' blocks),
      // which doesn't even exist on Production. Please remove it after ~ 2015-09-25:
      if (type(affectedBoosters) == "array")
        affectedBoosters = affectedBoosters.top()

      local activeBoosters = ::getTblValue("activeBooster", affectedBoosters, [])
      if (type(activeBoosters) == "table")
        activeBoosters = [ activeBoosters ]

      if (activeBoosters.len() > 0)
        foreach(effectType in boosterEffectType)
        {
          local boostersArray = []
          foreach(idx, block in activeBoosters)
          {
            local item = ::ItemsManager.findItemById(block.itemId)
            if (item && effectType.checkBooster(item))
              boostersArray.append(item)
          }

          if (boostersArray.len())
            usedItems.append(getActiveBoostersDescription(boostersArray, effectType))
        }

      if (usedItems.len())
        desc += "\n\n" + ::colorize("activeTextColor", ::loc("debriefing/used_items") + ::loc("ui/colon")) +
          "\n" + ::g_string.implode(usedItems, "\n")
    }


    if ("tournamentResult" in log)
    {
      local now = ::getTblValue("newStat", log.tournamentResult)
      local was = ::getTblValue("oldStat", log.tournamentResult)
      local lbDiff = ::leaderboarsdHelpers.getLbDiff(now, was)
      local items = []
      foreach (lbFieldsConfig in ::events.eventsTableConfig)
      {
        if (!(lbFieldsConfig.field in now)
          || !::events.checkLbRowVisibility(lbFieldsConfig, { eventId = log?.eventId }))
          continue

        items.append(::getLeaderboardItemView(lbFieldsConfig,
                                                 now[lbFieldsConfig.field],
                                                 ::getTblValue(lbFieldsConfig.field, lbDiff, null)))
      }
      local lbStatsBlk = ::getLeaderboardItemWidgets({ items = items })
      if (!("descriptionBlk" in res))
        res.descriptionBlk <- ""
      res.descriptionBlk += ::format("tdiv { width:t='pw'; flow:t='h-flow'; %s }", lbStatsBlk)
    }

    res.tooltip = (log.type==::EULT_SESSION_RESULT) ? ::loc("debriefing/total") : ::loc("userlog/interimResults");
    local totalText = res.tooltip
    totalText = "<color=@userlogColoredText>" + totalText + ::loc("ui/colon") + "</color>"

    local total = ::Cost(wp, gold, xp, rp).toStringWithParams({isWpAlwaysShown = true})
    totalText += "<color=@activeTextColor>" + total + "</color>"

    desc += "\n\n" + totalText
    res.tooltip += ::loc("ui/colon") + "<color=@activeTextColor>" + total + "</color>"

    if (log.type == ::EULT_SESSION_RESULT || log.type == ::EULT_EARLY_SESSION_LEAVE)
    {
      local ecSpawnScore = ::getTblValue("ecSpawnScore", log, 0)
      if (ecSpawnScore > 0)
        desc += "\n" + "<color=@userlogColoredText>" + ::loc("debriefing/total/ecSpawnScore") +  ::loc("ui/colon") + "</color>"
                + "<color=@activeTextColor>" + ecSpawnScore + "</color>"
      local wwSpawnScore = log?.wwSpawnScore ?? 0
      if (wwSpawnScore > 0)
        desc += "\n"
          + ::colorize("@userlogColoredText", ::loc("debriefing/total/wwSpawnScore")
            + ::loc("ui/colon"))
          + ::colorize("@activeTextColor", wwSpawnScore)
    }

    if (desc!="")
      res.description <- desc

    local expMul = log?.xpFirstWinInDayMul ?? 1.0
    local wpMul = log?.wpFirstWinInDayMul ?? 1.0
    if(expMul > 1.0 || wpMul > 1.0)
      res.logBonus = getBonus(expMul, wpMul, "item", "Log")

    if (::has_feature("ServerReplay"))
      if (::getTblValue("dedicatedReplay", log, false))
      {
        if (!("descriptionBlk" in res))
          res.descriptionBlk <- ""
        res.descriptionBlk += getLinkMarkup(::loc("mainmenu/btnViewServerReplay"),
                                                ::loc("url/serv_replay", {roomId = log.roomId}), "Y")
      }
  }
  else if (log.type==::EULT_AWARD_FOR_PVE_MODE)
  {
    if ("country" in log)
      if (::checkCountry(log.country, "userlog EULT_AWARD_FOR_PVE_MODE, " + log.mission))
        res.logImg2 = ::get_country_icon(log.country)

    local nameLoc = "userlog/" + logName
    local nameLocPostfix = ""
    local win = ("win" in log) && log.win

    if ("spectator" in log)
    {
      res.logImg = "#ui/gameuiskin#player_spectator.svg"
      nameLocPostfix = " " + ::loc("multiplayer/team_won") + ::loc("ui/colon")
        + (win ? ::g_team.A.getNameInPVE() : ::g_team.B.getNameInPVE())
    }
    else
    {
      res.logImg = "#ui/gameuiskin#" + (win? "log_win" : "log_lose")
      nameLoc += win? "/win":"/lose"
    }

    local mission = ::get_mission_name(log.mission, log)
    res.name = ::loc(nameLoc, { mode = ::loc("multiplayer/"+log.mode+"Mode"), mission = mission }) + nameLocPostfix

    local desc = ""
    local earnedText = ::Cost(log?.wpEarned ?? 0, log?.goldEarned ?? 0, 0, log?.xpEarned ?? 0)
      .toStringWithParams({isWpAlwaysShown = true})
    if (earnedText!="")
    {
      earnedText = ::loc("debriefing/total") + ::loc("ui/colon") + earnedText
      desc += ((desc!="")? "\n":"") + earnedText
    }
    if (desc!="")
    {
      res.description <- desc
      res.tooltip = desc
    }
  } else
  if (log.type==::EULT_BUYING_AIRCRAFT)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#log_buy_aircraft"
    local country = ::getShopCountry(log.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_REPAIR_AIRCRAFT)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#log_repair_aircraft"
    local country = ::getShopCountry(log.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_REPAIR_AIRCRAFT_MULTI)
  {
    if (("postSession" in log) && log.postSession)
      logName += "_auto"
    local totalCost = 0
    local desc = ""
    local idx = 0
    local country = ""
    local oneCountry = true
    while (("aname"+idx) in log) {
      if (desc!="") desc+="\n"
      local airName = log["aname"+idx]
      desc += ::getUnitName(airName) + ::loc("ui/colon") +
        ::Cost(log["cost"+idx]).toStringWithParams({isWpAlwaysShown = true})
      totalCost += log["cost"+idx]
      if (oneCountry)
      {
        local c = ::getShopCountry(airName)
        if (idx==0)
          country = c
        else
          if (country!=c)
            oneCountry = false
      }
      idx++
    }
    priceText = ::Cost(totalCost).tostring()
    if (priceText!="")  priceText = " ("+priceText+")"
    res.name = ::loc("userlog/"+logName) + priceText
    if (desc!="")
    {
      res.description <- desc
      res.tooltip = desc
    }
    res.logImg = "#ui/gameuiskin#log_repair_aircraft"
    if (oneCountry && ::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_BUYING_WEAPON || log.type==::EULT_BUYING_WEAPON_FAIL)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#" + ((log.type==::EULT_BUYING_WEAPON)? "log_buy_weapon" : "log_refill_weapon_no_money")
    if (("wname" in log) && ("aname" in log))
    {
      res.description <- getWeaponNameText(log.aname, false, log.wname, ", ")
      if ("count" in log && log.count > 1)
        res.description += " x" + log.count
      res.tooltip = res.description
    }
  } else
  if (log.type==::EULT_BUYING_WEAPONS_MULTI)
  {
    local auto = !("autoMode" in log) || log.autoMode
    if (auto)
      res.name = ::loc("userlog/buy_weapons_auto") + priceText
    else
      res.name = format(::loc("userlog/buy_weapon"), log.rawin("aname0") ? ::getUnitName(log.aname0) : "") + priceText

    res.description <- ""
    local idx = 0
    local airDesc = {}
    do {
      local desc = ""

      if(log.rawin("aname"+idx) && log.rawin("wname"+idx))
      {
        desc = getWeaponNameText(log["aname"+idx], false, log["wname"+idx], ", ")
        local wpCost = 0
        local goldCost = 0
        if(log.rawin("wcount"+idx))
        {
          if(log.rawin("wwpCost"+idx))
            wpCost = log["wwpCost"+idx]
          if(log.rawin("wgoldCost"+idx))
            goldCost = log["wgoldCost"+idx]

          desc += " x" + log["wcount"+idx] + " " +::Cost(wpCost, goldCost).tostring()
        }
        if (log["aname"+idx] in airDesc)
          airDesc[log["aname"+idx]] += "\n" + desc
        else
          airDesc[log["aname"+idx]] <- desc
      }

      idx++
    } while (("wname"+idx) in log)

    if (auto)
    {
      idx = 0
      do {
        local desc = ""
        if(log.rawin("maname"+idx) && log.rawin("mname"+idx))
        {
          local unit = getAircraftByName(log["maname"+idx])
          local modifName = log["mname"+idx]
          local bulletsSet = getBulletsSetData(unit, modifName)
          desc += getModificationName(unit, modifName, bulletsSet)
          local wpCost = 0
          local goldCost = 0
          if(log.rawin("mcount"+idx))
          {
            if(log.rawin("mwpCost"+idx))
              wpCost = log["mwpCost"+idx]
            if(log.rawin("mgoldCost"+idx))
              goldCost = log["mgoldCost"+idx]

            desc += " x" + log["mcount"+idx] + " " + ::Cost(wpCost, goldCost).tostring()
          }
          if (log["maname"+idx] in airDesc)
            airDesc[log["maname"+idx]] += "\n" + desc
          else
            airDesc[log["maname"+idx]] <- desc
          }
        idx++
      } while (("mname"+idx) in log)
    }

    foreach (aname, iname in airDesc)
    {
      if (res.description != "" )
        res.description += "\n\n"
      if (auto)
        res.description += ::colorize("activeTextColor", ::getUnitName(aname)) + ::loc("ui/colon") + "\n"
      res.description += iname
    }

    res.tooltip = res.description
    res.logImg = "#ui/gameuiskin#log_buy_weapon"
  } else
  if (log.type==::EULT_NEW_RANK)
  {
    if (("country" in log) && log.country!="common" && ::checkCountry(log.country, "EULT_NEW_RANK"))
    {
      res.logImg2 = ::get_country_icon(log.country)
      res.name = format(::loc("userlog/"+logName+"/country"), log.newRank.tostring())
    } else
    {
      res.logImg = "#ui/gameuiskin#prestige0"
      res.name = format(::loc("userlog/"+logName), log.newRank.tostring())
    }
  } else
  if (log.type==::EULT_BUYING_SLOT || log.type==::EULT_TRAINING_AIRCRAFT || log.type==::EULT_UPGRADING_CREW
      || log.type==::EULT_SPECIALIZING_CREW || log.type==::EULT_PURCHASINGSKILLPOINTS)
  {
    local crew = get_crew_by_id(log.id)
    local crewName = crew? (crew.idInCountry+1).tostring() : "?"
    local country = crew? crew.country : ("country" in log)? log.country : ""
    local airName = ("aname" in log)? ::getUnitName(log.aname) : ("aircraft" in log)? ::getUnitName(log.aircraft) : ""
    if (::checkCountry(country, "userlog EULT_*_CREW"))
      res.logImg2 = ::get_country_icon(country)
    res.logImg = "#ui/gameuiskin#log_crew"

    res.name = ::loc("userlog/"+logName,
                         { skillPoints = ::getCrewSpText(::getTblValue("skillPoints", log, 0)),
                           crewName = crewName,
                           unitName = airName
                         })
    res.name += priceText

    if (log.type==::EULT_UPGRADING_CREW)
    {
      ::load_crew_skills_once()
      local desc = ""
      local total = 0
      foreach(page in ::crew_skills)
        if ((page.id in log) && log[page.id].len()>0)
        {
          desc+=((desc!="")? "\n":"") + ::loc("crew/"+page.id) + ::loc("ui/colon")
          foreach(item in page.items)
            if (item.name in log[page.id])
            {
              desc+=((desc!="")? "\n":"") + ::nbsp + ::nbsp + "+" + log[page.id][item.name] +" "+ ::loc("crew/"+item.name)
              total += log[page.id][item.name]
            }
        }
      res.name += format(" (+%d %s)", total, ::loc("userlog/crewLevel"))
      if (desc!="")
      {
        res.description <- desc
        res.tooltip = desc
      }
    }
  } else
  if (log.type==::EULT_BUYENTITLEMENT)
  {
    local ent = getEntitlementConfig(log.name)
    if ("cost" in log)
      ent["goldCost"] <- log.cost
    local costText = getEntitlementPrice(ent)
    if (costText!="")
      costText = " (" + costText + ")"

    res.name = format(::loc("userlog/"+logName), getEntitlementName(ent)) + costText
    res.logImg = "#ui/gameuiskin#log_online_shop"
  } else
  if (log.type == ::EULT_NEW_UNLOCK)
  {
    local config = build_log_unlock_data(log)

    res.name = config.title
    if (config.name!="")
      res.name += ::loc("ui/colon") + "<color=@userlogColoredText>" + config.name + "</color>"
    res.logImg = config.image
    if ("country" in log && ::checkCountry(log.country, "EULT_NEW_UNLOCK"))
      res.logImg2 = ::get_country_icon(log.country)
    else if ((config?.image2 ?? "") != "")
      res.logImg2 = config?.image2

    local unlock = ::g_unlocks.getUnlockById(log?.unlockId ?? log?.id ?? "")
    local desc = ""
    if (!(unlock?.isMultiUnlock ?? false) && "desc" in config)
    {
      desc = config.desc
      res.tooltip = config.desc
    }

    if (config.rewardText != "")
    {
      res.name += ::loc("ui/parentheses/space", {text = config.rewardText})
      desc += ((desc=="")? "":"\n\n") + ::loc("challenge/reward") + " " + config.rewardText
    }

    if (desc != "")
      res.description <- desc

    if (("descrImage" in config) && config.descrImage!="")
    {
      local imgSize = ("descrImageSize" in config)? config.descrImageSize : "0.05sh, 0.05sh"
      res.descriptionBlk <- format(imgFormat, imgSize, config.descrImage)
    }
    if ((config.type == ::UNLOCKABLE_SLOT ||
         config.type == ::UNLOCKABLE_AWARD)
         && "country" in log)
      res.logImg2 = ::get_country_icon(log.country)

    if (config.type == ::UNLOCKABLE_SKILLPOINTS && config.image2 != "")
      res.logImg2 = config.image2
  } else
  if (log.type==::EULT_BUYING_MODIFICATION || log.type == ::EULT_BUYING_MODIFICATION_FAIL)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#" + ((log.type==::EULT_BUYING_MODIFICATION)? "log_buy_mods" : "log_refill_weapon_no_money")
    if (("mname" in log) && ("aname" in log))
    {
      local unit = getAircraftByName(log.aname)
      local bulletsSet = getBulletsSetData(unit, log.mname)
      res.description <- getModificationName(unit, log.mname, bulletsSet)
      if ("count" in log && log.count > 1)
        res.description += " x" + log.count

      local xpEarnedText = ("xpEarned" in log)? ::Cost().setRp(log.xpEarned).tostring() : ""
      if (xpEarnedText!="")
      {
        xpEarnedText = ::loc("reward") + ::loc("ui/colon") + "<color=@activeTextColor>" + xpEarnedText + "</color>"
        res.description += ((res.description!="")? "\n":"") + xpEarnedText
      }
      res.tooltip = res.description
    }
  } else
  if (log.type==::EULT_BUYING_SPARE_AIRCRAFT)
  {
    local count = ::getTblValue("count", log, 1)
    if (count == 1)
      res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    else
      res.name = ::loc("userlog/"+logName+"/multiple", {
                     numSparesColored = ::colorize("userlogColoredText", count)
                     numSpares = count
                     unitName = ::colorize("userlogColoredText", ::getUnitName(log.aname))
                   }) + priceText
    res.logImg = "#ui/gameuiskin#log_buy_spare_aircraft"
    local country = ::getShopCountry(log.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_CLAN_ACTION)
  {
    res.logImg = "#ui/gameuiskin#log_clan_action"
    local info = {
      action = ::getTblValue("clanActionType", log, -1)
      clan = ("clanName" in log)? ::ps4CheckAndReplaceContentDisabledText(log.clanName) : ""
      player = ::getTblValue("initiatorNick", log, "")
      role = ("role" in log)? ::loc("clan/" + ::clan_get_role_name(log.role)) : ""
      status = ("enabled" in log) ? ::loc("clan/" + (log.enabled ? "opened" : "closed")) : ""
      tag = ::getTblValue("clanTag", log, "")
      tagOld = ::getTblValue("clanTagOld", log, "")
      clanOld = ("clanNameOld" in log)? ::ps4CheckAndReplaceContentDisabledText(log.clanNameOld) : ""
      sizeIncrease = ::getTblValue("sizeIncrease", log, -1)
    }
    local typeTxt = getClanActionName(info.action)
    res.name = ::loc("userlog/"+logName+"/"+typeTxt, info) + priceText

    if ("comment" in log && log.comment!="")
    {
      res.description <- ::loc("clan/userlogComment") + "\n" + ::ps4CheckAndReplaceContentDisabledText(::g_chat.filterMessageText(log.comment, false))
      res.tooltip = res.description
    }
  } else
  if (log.type==::EULT_BUYING_RESOURCE || log.type==::EULT_BUYING_UNLOCK)
  {
    local config = ::create_default_unlock_data()
    local resourceType = ""
    local decoratorType = null
    if (log.type==::EULT_BUYING_RESOURCE)
    {
      resourceType = log.resourceType
      config = getDecoratorUnlock(log.resourceId, log.resourceType)
      decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
    }
    else if (log.type==::EULT_BUYING_UNLOCK)
    {
      config = ::build_log_unlock_data(log)
      resourceType = log?.isAerobaticSmoke ? "smoke" : ::get_name_by_unlock_type(config.type)
    }

    res.name = format(::loc("userlog/"+logName+"/"+resourceType), config.name) + priceText

    local desc = config?.desc ?? ""
    if (decoratorType)
      desc = decoratorType.getLocDesc(config.id)

    if (!::u.isEmpty(desc))
      res.description <- desc

    res.logImg = config.image

    if (::getTblValue("descrImage", config, "") != "")
    {
      local imgSize = ::getTblValue("descrImageSize", config, "0.05sh, 0.05sh")
      res.descriptionBlk <- ::format(imgFormat, imgSize, config.descrImage)
    }
  }
  else if (log.type==::EULT_CHARD_AWARD)
  {
    local rewardType = ::getTblValue("rewardType", log, "")
    res.name = ::loc("userlog/" + rewardType)
    res.description <- ::loc("userlog/" + ::getTblValue("name", log, ""))

    local wp = log?.wpEarned ?? 0, gold = log?.goldEarned ?? 0, exp = log?.xpEarned ?? 0
    local reward = ::Cost(wp.tointeger(), gold.tointeger(), 0, exp.tointeger()).tostring()
    if (reward != "")
      res.description += " <color=@activeTextColor>" + reward + "</color>"

    local idx = 0
    local lineReward = ""
    while (("chardReward"+idx) in log)
    {
      local blk = log["chardReward"+idx]

      if ("country" in blk)
        lineReward += ::loc(blk.country) + ::loc("ui/colon")

      if ("name" in blk)
        lineReward += ::loc(blk.name)+" "

      if ("aname" in blk)
      {
        lineReward += ::getUnitName(blk.aname) + ::loc("ui/colon")
        if ("wname" in blk)
          lineReward += getWeaponNameText(blk.aname, false, blk.wname, ::loc("ui/comma")) + " "
        if ("mname" in blk)
        {
          local unit = getAircraftByName(blk.aname)
          local bulletsSet = getBulletsSetData(unit, blk.mname)
          lineReward += getModificationName(unit, blk.mname, bulletsSet) + " "
        }
      }

      local blkWp = blk?.wpEarned ?? 0
      local blkGold = blk?.goldEarned ?? 0
      local blkExp = blk?.xpEarned ?? 0
      local blkReward = ::Cost(blkWp.tointeger(), blkGold.tointeger()).tostring()
      if (blkExp)
      {
        local changeLightToXP = blk?.name == ::MSG_FREE_EXP_DENOMINATE_OLD
        blkReward += ((blkReward!="")? ", ":"") + ( changeLightToXP ?
          (blkExp + " <color=@white>" + ::loc("mainmenu/experience/oldName") + "</color>")
          : ::Cost().setRp(blkExp.tointeger()).tostring())
      }

      lineReward += blkReward
      if (lineReward != "")
        lineReward += "\n"

      idx++
    }

    if ("clanDuelReward" in log)
    {
      local rewardBlk = log.clanDuelReward

      local difficultyStr = ::loc(::getTblValue("difficulty", rewardBlk, ""))
      lineReward += ::loc("difficulty_name") + " <color=@white>" + difficultyStr +
          "</color>\n"

      if ("era" in rewardBlk)
      {
        local era = rewardBlk.era
        lineReward += ::loc("userLog/clanDuelRewardRank") + " <color=@white>" + era +
            "</color>\n"
      }

      local clanPlace = ::getTblValue("clanPlace", rewardBlk, -1)

      local clanRating = ::getTblValue("clanRating", rewardBlk, -1)

      //show rating only for place reward due for rating-reward rating showed in header
      if (clanPlace > 0)
        lineReward += ::loc("userLog/clanDuelRewardClanRating") + " <color=@white>" + clanRating +
            "</color>\n"

      local equalClanPlacesCount = ::getTblValue("equalClanPlacesCount", rewardBlk, -1)
      if (equalClanPlacesCount > 1)
      {
        lineReward += ::loc("userLog/clanDuelRewardEqualClanPlaces") + " <color=@white>" +
            (equalClanPlacesCount - 1) + "</color>\n"
      }

      res.description = ""
      local rewardCurency = ::Cost(wp, gold, exp).tostring()
      if (rewardCurency != "")
        res.description += ::loc("reward") + ::loc("ui/colon") + " " + ::colorize("activeTextColor", rewardCurency)

      //We don't want ~100 localization strings like "Your squadron took Nth place.".
      //So we left unique localizations only for top 3.
      if (clanPlace > 3)
        res.name = ::loc("userlog/ClanSeasonRewardPlaceN", {place = clanPlace.tostring()})
      else if (clanPlace > 0)
        res.name = ::loc("userlog/ClanSeasonRewardPlace" + clanPlace.tostring())
      else if (clanRating > 0)
        res.description = ::loc("userlog/ClanRewardRatingReached", {rating = clanRating.tostring()})


      local place = ::getTblValue("place", rewardBlk, -1)
      if (place > 0)
        lineReward += ::loc("userLog/clanDuelRewardPlace") + " <color=@white>" + place +
            "</color>\n"

      local rating = round(rewardBlk.rating);
      lineReward += ::loc("userLog/clanDuelRewardRating") + " <color=@white>" + rating +
            "</color>\n"

      local equalPlacesCount = ::getTblValue("equalPlacesCount", rewardBlk, -1)
      if (equalPlacesCount > 1)
      {
        lineReward += ::loc("userLog/clanDuelRewardEqualPlaces") + " <color=@white>" +
            (equalPlacesCount - 1) + "</color>\n"
      }

      local config = {
        locId = "clan_duel_reward"
        subType = ps4_activity_feed.CLAN_DUEL_REWARD
      }
      local customConfig = {
        gold = gold
        place = place
        blkParamName = "CLAN_DUEL_REWARD"
      }

      activityFeedPostFunc(config, customConfig, bit_activity.PS4_ACTIVITY_FEED)

      local resourcesConfig = getResourcesConfig(rewardBlk?.resource)
      if (resourcesConfig != null) {
        if (resourcesConfig.description.len() > 0) {
          local desc = "\n\n".join(resourcesConfig.description)
          res.description <- $"{res?.description ?? ""}{("description" in  res) ? "\n\n" : ""}{desc}"
        }
        res.logImg = resourcesConfig.logImg
        if (resourcesConfig.resourcesImagesMarkupArr.len() > 0)
          res.descriptionBlk <- descriptionBlkMultipleFormat.subst("".join(resourcesConfig.resourcesImagesMarkupArr))
      }
    }

    if (rewardType == "EveryDayLoginAward" || rewardType == "PeriodicCalendarAward")
    {
      local prefix = "trophy/"
      local pLen = prefix.len()
      if (rewardType == "EveryDayLoginAward")
        res.name += ::loc("ui/parentheses/space", {
          text = ::colorize("userlogColoredText", ::loc("enumerated_day", {
              number = ::getTblValue("progress", log, 0) + (::getTblValue("daysFor0", log, 0)-1)
        }))})

      local name = log.chardReward0.name
      local itemId = (name.len() > pLen && name.slice(0, pLen) == prefix) ? name.slice(pLen) : name
      local item = ::ItemsManager.findItemById(itemId)
      if (item)
        lineReward = ::colorize("activeTextColor", item.getName())
      res.logImg = ::items_classes.Trophy.typeIcon
      res.descriptionBlk <- ::get_userlog_image_item(item)
    }
    else if (::isInArray(rewardType, ["WagerStageWin", "WagerStageFail", "WagerWin", "WagerFail"]))
    {
      local itemId = ::getTblValue("id", log)
      local item = ::ItemsManager.findItemById(itemId)
      if (item)
      {
        if (::isInArray(rewardType, ["WagerStageWin", "WagerStageFail"]))
          res.name += ::loc("ui/colon") + ::colorize("userlogColoredText", item.getName())
        else
          res.name = ::loc("userlog/" + rewardType, {wagerName = ::colorize("userlogColoredText", item.getName())})

        local desc = []
        desc.append(::loc("items/wager/numWins", { numWins = ::getTblValue("numWins", log), maxWins = item.maxWins }))
        desc.append(::loc("items/wager/numFails", {numFails = ::getTblValue("numFails", log), maxFails = item.maxFails}))

        res.logImg = "#ui/gameuiskin#unlock_achievement"
        res.description += (res.description == ""? "" : "\n") + ::g_string.implode(desc, "\n")
        res.descriptionBlk <- ::get_userlog_image_item(item)
      }
    }
    else if (rewardType == "TournamentReward")
    {
      local result = ::getTournamentRewardData(log)
      local desc = []
      foreach(rewardBlk in result)
        desc.append(::EventRewards.getConditionText(rewardBlk))

      lineReward = ::EventRewards.getTotalRewardDescText(result)
      res.description = ::g_string.implode(desc, "\n")
      res.name = ::loc("userlog/" + rewardType, {
                         name = ::colorize("userlogColoredText", ::events.getNameByEconomicName(::getTblValue("name", log)))
                       })
    }

    if (lineReward != "")
      res.description += (res.description == ""? "" : "\n") + lineReward
  } else
  if (log.type==::EULT_ADMIN_ADD_GOLD || log.type==::EULT_ADMIN_REVERT_GOLD)
  {
    local goldAdd = log?.goldAdd ?? 0
    local goldBalance = log?.goldBalance ?? 0
    local suffix = (goldAdd >= 0) ? "/positive" : "/negative"

    res.name = ::loc("userlog/" + logName + suffix, {
      gold = ::Money(money_type.none, 0, ::abs(goldAdd)).toStringWithParams({isGoldAlwaysShown = true}),
      balance = ::Balance(0, goldBalance).toStringWithParams({isGoldAlwaysShown = true})
    })
    res.description <- log?.comment ?? "" // not localized
  }
  else if (log.type == ::EULT_BUYING_SCHEME)
  {
    res.description <- ::getUnitName(log.unit) + priceText
  }
  else if (log.type == ::EULT_OPEN_ALL_IN_TIER)
  {
    local locTbl = {
      unitName = ::getUnitName(log.unit)
      tier = ::get_roman_numeral(log.tier)
      exp = 0
    }

    local desc = ""
    if ("expToInvUnit" in log && "resUnit" in log)
    {
      locTbl.resUnitExpInvest <- ::Cost().setRp(log.expToInvUnit).tostring()
      locTbl.resUnitName <- ::getUnitName(log.resUnit)
      desc = "\n" + ::loc("userlog/"+logName+"/resName", locTbl)
      locTbl.exp += log.expToInvUnit
    }

    if ("expToExcess" in log)
    {
      locTbl.expToExcess <- ::Cost().setRp(log.expToExcess).tostring()
      desc += "\n" + ::loc("userlog/"+logName+"/excessName", locTbl)
      locTbl.exp += log.expToExcess
    }

    locTbl.exp = ::Cost().setRp(locTbl.exp).tostring()
    res.name <- ::loc("userlog/"+logName+"/name", locTbl)
    res.description <- ::loc("userlog/"+logName+"/desc", locTbl) + desc

    local country = ::getShopCountry(log.unit)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  }
  else if (log.type == ::EULT_BUYING_MODIFICATION_MULTI)
  {
    if ("maname0" in log)
      res.name = format(::loc("userlog/"+logName), ::getUnitName(getTblValue("maname0", log, ""))) + priceText
    else
      res.name = format(::loc("userlog/"+logName), "")
    res.logImg = "#ui/gameuiskin#" + "log_buy_mods"

    res.description <- ""
    local idx = 0
    local airDesc = {}

    idx = 0
    do {
      local desc = ""
      if(log.rawin("maname"+idx) && log.rawin("mname"+idx))
      {
        local unit = getAircraftByName(log["maname"+idx])
        local bulletsSet = getBulletsSetData(unit, log["mname"+idx])
        desc += getModificationName(unit, log["mname"+idx], bulletsSet)
        local wpCost = 0
        local goldCost = 0
        if(log.rawin("mcount"+idx))
        {
          if(log.rawin("mwpCost"+idx))
            wpCost = log["mwpCost"+idx]
          if(log.rawin("mgoldCost"+idx))
            goldCost = log["mgoldCost"+idx]

          desc += " x" + log["mcount"+idx] + " " +::Cost(wpCost, goldCost).tostring()
        }
        if (log["maname"+idx] in airDesc)
          airDesc[log["maname"+idx]] += "\n" + desc
        else
          airDesc[log["maname"+idx]] <- desc
      }
      idx++
    } while (("mname"+idx) in log)

    foreach (aname, iname in airDesc)
    {
      if (res.description != "" )
        res.description += "\n\n"
      res.description += ::colorize("activeTextColor", ::getUnitName(aname)) + ::loc("ui/colon") + "\n"
      res.description += iname
    }
    res.tooltip = res.description
  }
  else if (log.type == ::EULT_OPEN_TROPHY)
  {
    local itemId = log?.itemDefId || log?.id || ""
    local item = ::ItemsManager.findItemById(itemId)

    if(!item && log?.trophyItemDefId)
    {
      local extItem = ::ItemsManager.findItemById(log?.trophyItemDefId)
      if (extItem)
        item = extItem.getContentItem()
    }

    if (item)
    {
      local cost = item.getCost()
      logName = (item?.userlogOpenLoc ?? logName) != logName ? item.userlogOpenLoc
        : $"{cost.gold > 0 ? "purchase_" : ""}{logName}"

      local usedText = ::loc($"userlog/{logName}/short")
      res.name = " ".concat(
          usedText,
          ::loc("trophy/unlockables_names/trophy"),
          cost.gold > 0
            ? ::loc("ui/parentheses/space", {text = $"{cost.getTextAccordingToBalance()}"}) : ""
        )
      res.logImg = item.getSmallIconName()

      res.descriptionBlk <- ::format(textareaFormat,
        $"{::g_string.stripTags(usedText)}{::loc("ui/colon")}")
      res.descriptionBlk += item.getNameMarkup()
      res.descriptionBlk += ::format(textareaFormat,
        ::g_string.stripTags($"{::loc("reward")}{::loc("ui/colon")}"))

      local resTextArr = []
      local rewards = {}
      if (log?.item)
      {
        if (typeof(log.item) == "array")
        {
          local items = log.item
          while(items.len())
          {
            local inst = items.pop()
            if (inst in rewards)
              rewards[inst] += 1
            else
              rewards[inst] <- 1
          }
        }
        else
          rewards = { [log.item] = 1 }
        foreach (idx, val in rewards)
        {
          local data = {
            type = log.type
            item = idx
            count = val
          }
          resTextArr.append(::trophyReward.getRewardText(data))
          res.descriptionBlk = "".concat(res.descriptionBlk,
            ::trophyReward.getRewardsListViewData(log.__merge(data)))
        }
      }
      else
      {
        resTextArr = [::trophyReward.getRewardText(log)]
        res.descriptionBlk = $"{res.descriptionBlk}{::trophyReward.getRewardsListViewData(log)}"
      }

      local rewardText = "\n".join(resTextArr, true)
      local reward = $"{::loc("reward")}{::loc("ui/colon")}{rewardText}"
      res.tooltip = $"{usedText}{::loc("ui/colon")}{item.getName()}\n{reward}"
    }
    else
      res.name = ::loc($"userlog/{logName}", { trophy = ::loc("userlog/no_trophy"),
        reward = ::loc("userlog/trophy_deleted") })

    /*
    local prizes = ::trophyReward.getRewardList(log)
    if (prizes.len() == 1) //!!FIX ME: need to move this in PrizesView too
    {
      local prize = prizes[0]
      local prizeType = ::trophyReward.getRewardType(prize)

      if (::isInArray(prizeType, [ "gold", "warpoints", "exp", "entitlement" ]))
      {
        local color = prizeType == "entitlement" ? "userlogColoredText" : "activeTextColor"
        local title = ::colorize(color, rewardText)
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon") + title))
      }
      else if (prizeType == "item")
      {
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
        res.descriptionBlk += ::get_userlog_image_item(::ItemsManager.findItemById(prize.item))
      }
      else if (prizeType == "unlock" && ::getTblValue("unlockType", log) == "decal")
      {
        local title = ::colorize("userlogColoredText", rewardText)
        local config = ::build_log_unlock_data({ id = log.unlock })
        local imgSize = ::getTblValue("descrImageSize", config, "0.05sh, 0.05sh")
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon") + title))
        res.descriptionBlk += format(imgFormat, imgSize, config.descrImage)
      }
      else
      {
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
        res.descriptionBlk += ::PrizesView.getPrizesListView(prizes)
      }
    }
    else
    {
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
        res.descriptionBlk += ::PrizesView.getPrizesListView(prizes)
    }
    */
  }
  else if (log.type == ::EULT_BUY_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local locId = "userlog/" + logName + ((log.count > 1) ? "/multiple" : "")
    res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     price = ::Cost(log.cost * log.count, log.costGold * log.count).tostring()
                     amount = log.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item, {type = log.type})
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
  }
  else if (log.type == ::EULT_NEW_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local locId = "userlog/" + logName + ((log.count > 1) ? "/multiple" : "")
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
    res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     amount = log.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item, { count = log.count })
  }
  else if (log.type == ::EULT_ACTIVATE_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
    local nameId = (item?.isSpecialOffer ?? false) ? "specialOffer/recived" : logName
    res.name = ::loc($"userlog/{nameId}", {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                   })
    if ("itemType" in log && log.itemType == "wager")
    {
      local wager = 0;
      local wagerGold = 0;

      if ("wager" in log)
        wager = log.wager

      if ("wagerGold" in log)
        wagerGold = log.wagerGold

      if (wager > 0 || wagerGold > 0)
        res.description <- ::loc("userlog/" + logName + "_desc/wager") + " " +
          ::Cost(wager, wagerGold).tostring()
    }
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (log.type == ::EULT_REMOVE_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local reason = ::getTblValue("reason", log, "unknown")
    local nameId = (item?.isSpecialOffer ?? false) ? "specialOffer" : logName
    local locId = $"userlog/{nameId}/{reason}"
    if (reason == "replaced")
    {
      local replaceItemId = ::getTblValue("replaceId", log, "")
      local replaceItem = ::ItemsManager.findItemById(replaceItemId)
      res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     replacedItemName = ::colorize("userlogColoredText", replaceItem ? replaceItem.getName() : "")
                   })
      res.descriptionBlk <- ::get_userlog_image_item(item) + ::get_userlog_image_item(replaceItem)
    }
    else
    {
      res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                   })
      res.descriptionBlk <- ::get_userlog_image_item(item)
    }
    local itemTypeValue = ::getTblValue("itemType", log, "")
    if (itemTypeValue == "universalSpare")
    {
      locId = "userlog/" + logName
      local unit =  ::getTblValue("unit", log)
      if (unit != null)
        res.logImg2 = ::get_country_icon(::getShopCountry(unit))
      local numSpares = ::getTblValue("numSpares", log, 1)
      res.name = ::loc(locId + "_name/universalSpare", {
                     numSparesColored = ::colorize("userlogColoredText", numSpares)
                     numSpares = numSpares
                     unitName = (unit != null ? ::colorize("userlogColoredText", ::getUnitName(unit)) : "")
                   })
      res.descriptionBlk <- ::format(textareaFormat,
                                ::g_string.stripTags(::loc(locId + "_desc/universalSpare") + ::loc("ui/colon")))
      res.descriptionBlk += item.getNameMarkup(numSpares,true)
    }
    else if (itemTypeValue == "wager")
    {
      local earned = ::Cost(::getTblValue("wpEarned", log, 0), ::getTblValue("goldEarned", log, 0))
      if (earned > ::zero_money)
        res.description <- ::loc("userlog/" + logName + "_desc/wager") + " " + earned.tostring()
    }
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
  }
  else if (log.type == ::EULT_INVENTORY_ADD_ITEM ||
           log.type == ::EULT_INVENTORY_FAIL_ITEM)
  {
    local amount = 0
    local itemsNumber = 0
    local firstItemName = ""
    local itemsListText = ""

    res.descriptionBlk <- ""
    foreach (data in log)
    {
      if (!("itemDefId" in data))
        continue

      local item = ::ItemsManager.findItemById(data.itemDefId)
      if (!item)
        continue

      local quantity = data?.quantity ?? 1
      res.descriptionBlk += item.getNameMarkup(quantity, true, true)
      res.logImg = res.logImg || item.getSmallIconName()

      amount += quantity
      itemsListText += "\n " + ::loc("event_dash") + " " + item.getNameWithCount(true, quantity)
      if (itemsNumber == 0)
        firstItemName = item.getName()

      itemsNumber ++
    }

    res.logImg = res.logImg || ::BaseItem.typeIcon
    local locId = "userlog/" + logName
    res.name = ::loc(locId, {
      numItemsColored = ::colorize("userlogColoredText", amount)
      numItems = amount
      numItemsAdd = amount
      itemName = itemsNumber == 1 ? firstItemName : ""
    })

    if (itemsNumber > 1)
      res.tooltip = ::loc(locId, {
        numItemsColored = ::colorize("userlogColoredText", amount)
        numItems = amount
        numItemsAdd = amount
        itemName = itemsListText
      })
  }
  else if (log.type == ::EULT_TICKETS_REMINDER)
  {
    res.name = ::loc("userlog/"+logName) + ::loc("ui/colon") +
        ::colorize("userlogColoredText", ::events.getNameByEconomicName(log.name))

    local desc = []
    if (::getTblValue("battleLimitReminder", log))
      desc.append(::loc("userlog/battleLimitReminder") + ::loc("ui/colon") + log.battleLimitReminder)
    if (::getTblValue("defeatCountReminder", log))
      desc.append(::loc("userlog/defeatCountReminder") + ::loc("ui/colon") + log.defeatCountReminder)
    if (::getTblValue("sequenceDefeatCountReminder", log))
      desc.append(::loc("userlog/sequenceDefeatCountReminder") + ::loc("ui/colon") + log.sequenceDefeatCountReminder)

    res.description <- ::g_string.implode(desc, "\n")
  }
  else if (log.type == ::EULT_BUY_BATTLE)
  {
    res.name = ::loc("userlog/"+logName) + ::loc("ui/colon") +
      ::colorize("userlogColoredText", ::events.getNameByEconomicName(log.tournamentName))

    local cost = ::Cost()
    cost.wp = ::getTblValue("costWP", log, 0)
    cost.gold = ::getTblValue("costGold", log, 0)
    res.description <- ::loc("events/battle_cost", {cost = cost.tostring()})
  }
  else if (log.type == ::EULT_CONVERT_EXPERIENCE)
  {
    local logId = "userlog/"+logName

    res.logImg = "#ui/gameuiskin#convert_xp"
    local unitName = log["unit"]
    local country = ::getShopCountry(unitName)
    if (checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)

    local cost = ::Cost()
    cost.wp = ::getTblValue("costWP", log, 0)
    cost.gold = ::getTblValue("costGold", log, 0)
    local exp = ::getTblValue("exp", log, 0)

    res.description <- ::loc(logId+"/desc", {cost = cost.tostring(), unitName = ::getUnitName(unitName),
      exp = ::Cost().setFrp(exp).tostring()})
  }
  else if (log.type == ::EULT_SELL_BLUEPRINT)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local locId = "userlog/" + logName + ((log.count > 1) ? "/multiple" : "")
    res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     price = ::Cost(log.cost * log.count, log.costGold * log.count).tostring()
                     amount = log.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (::isInArray(log.type, [::EULT_PUNLOCK_ACCEPT,
                                  ::EULT_PUNLOCK_CANCELED,
                                  ::EULT_PUNLOCK_EXPIRED,
                                  ::EULT_PUNLOCK_NEW_PROPOSAL,
                                  ::EULT_PUNLOCK_ACCEPT_MULTI]))
  {
    local locNameId = $"userlog/{logName}"
    res.logImg = ::g_battle_task_difficulty.EASY.image

    if ((log.type == ::EULT_PUNLOCK_ACCEPT_MULTI || log.type == ::EULT_PUNLOCK_NEW_PROPOSAL) && "new_proposals" in log)
    {
      if (log.new_proposals.len() > 1) {
        if (::g_battle_tasks.getDifficultyByProposals(log.new_proposals) == ::g_battle_task_difficulty.HARD) {
          res.logImg = ::g_battle_task_difficulty.HARD.image
          locNameId = "userlog/battle_tasks_new_proposal/special"
        }
        res.description <- ::g_battle_tasks.generateUpdateDescription(log.new_proposals)
      }
      else
        locNameId = "userlog/battle_tasks_accept"
    }

    local taskName = ""

    if (log?.id) {
      local battleTask = ::g_battle_tasks.getTaskById(log.id)
      if (battleTask)
        res.logImg = ::g_battle_task_difficulty.getDifficultyTypeByTask(battleTask).image
      else
        res.logImg = ::g_battle_task_difficulty.getDifficultyTypeById(log.id).image

      taskName = ::g_battle_tasks.generateStringForUserlog(log, log.id)
    }

    res.buttonName = ::loc("mainmenu/battleTasks/OtherTasksCount")
    res.name = ::loc(locNameId, {taskName = taskName})
  }
  else if (log.type == ::EULT_PUNLOCK_REROLL_PROPOSAL && "new_proposals" in log)
  {
    local text = ::g_battle_tasks.generateUpdateDescription(log.new_proposals)
    if (log.new_proposals.len() > 1)
      res.description <- text
    else
      res.name = ::loc($"userlog/{logName}", {taskName = text})

    res.logImg = ::g_battle_tasks.getDifficultyByProposals(log.new_proposals).image
  }
  else if (log.type == ::EULT_CONVERT_BLUEPRINTS)
  {
    local locId = "userlog/"+logName
    res.name = ::loc(locId, {
                     from = ::loc("userlog/blueprintpart_name/" + ::getTblValue("from", log, ""))
                     to = ::loc("userlog/blueprintpart_name/" + ::getTblValue("to", log, ""))
                   })

    res.description <- ::loc(locId+"/desc")

    foreach(unitName, unitData in log)
    {
      if (!("result" in unitData))
        continue

      local resItem = ::ItemsManager.findItemById(unitData.result)
      res.description += "\n" + ::loc(unitName+"_0") + ::loc("ui/colon") + ::get_userlog_image_item(resItem)
      local idx = 0
      while (("source"+idx) in unitData)
      {
        local srcItem = ::ItemsManager.findItemById(unitData["source"+idx])
        res.description += ::get_userlog_image_item(srcItem)
        idx++
      }
    }
  }
  else if (log.type == ::EULT_RENT_UNIT || log.type == ::EULT_RENT_UNIT_EXPIRED)
  {
    local unitName = ::getTblValue("unit", log)
    if (unitName)
    {
      res.name = ::loc("userlog/"+logName, {unitName = ::loc(unitName + "_0")})
      if (log.type == ::EULT_RENT_UNIT)
      {
        res.description <- ""
        if ("rentTimeSec" in log)
          res.description += ::loc("mainmenu/rent/rentTimeSec",
            {time = time.hoursToString(time.secondsToHours(log.rentTimeSec)) })
      }
    }
  }
  else if (log.type == ::EULT_EXCHANGE_WARBONDS)
  {
    local awardData = ::getTblValue("award", log)
    if (awardData)
    {
      local wbPriceText = ::g_warbonds.getWarbondPriceText(awardData?.cost ?? 0)
      local awardBlk = ::DataBlockAdapter(awardData)
      local awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
      res.name = awardType.getUserlogBuyText(awardBlk, wbPriceText)
    }
  }
  else if (log.type == ::EULT_WW_START_OPERATION || log.type == ::EULT_WW_CREATE_OPERATION)
  {
    local locId = log.type == ::EULT_WW_CREATE_OPERATION ? "worldWar/userlog/createOperation"
                                                         : "worldWar/userlog/startOperation"
    local operation = ""
    if (::is_worldwar_enabled())
      operation = ::WwOperation.getNameTextByIdAndMapName(
        ::getTblValue("operationId", log),
        ::WwMap.getNameTextByMapName(::getTblValue("mapName", log))
      )
    res.name = ::loc(locId,
      {
        clan = ::getTblValue("name", log)
        operation = operation
      })
  }
  else if (log.type == ::EULT_WW_END_OPERATION)
  {
    local textLocId = "worldWar/userlog/endOperation/"
    textLocId += ::getTblValue("winner", log) ? "win" : "lose"
    local mapName = ::getTblValue("mapName", log)
    local opId = ::getTblValue("operationId", log)
    local earnedText = ::Cost(::getTblValue("wp", log, 0)).toStringWithParams({isWpAlwaysShown = true})
    res.name = ::loc(textLocId, {
      opId = opId, mapName = ::loc("worldWar/map/" + mapName), reward = earnedText })

    local statsWpText = ::Cost(::getTblValue("wpStats", log, 0)).toStringWithParams({isWpAlwaysShown = true})
    res.description <- ::loc("worldWar/userlog/endOperation/stats", { reward = statsWpText })
  }
  else if (log.type == ::EULT_INVITE_TO_TOURNAMENT)
  {
    if ("action_tss" in log)
    {
      local action_tss = log.action_tss
      local desc = ""

      switch (action_tss)
      {
        case "awards_tournament":
          res.name = ::loc("userlog/awards_tss_tournament", {TournamentName = log.tournament_name})

          foreach(award_idx, award_val in log.awards)
          {
            if (award_val.type == "gold")
              desc += "\n" + "<color=@activeTextColor>" +
                ::Cost(0, ::abs(award_val.award)).toStringWithParams({isGoldAlwaysShown = true}) + "</color>"
            if (award_val.type == "premium")
              desc += "\n" + "<color=@activeTextColor>" + award_val.award + "</color>"
            if (award_val.type == "booster")
            {
              foreach(block in award_val.award)
                {
                  local item = ::ItemsManager.findItemById(block)
                  if (!("descriptionBlk" in res))
                    res.descriptionBlk <- ""
                  res.descriptionBlk += ::get_userlog_image_item(item)
                }
            }
            if (award_val.type == "title")
              desc += "\n" + "<color=@activeTextColor>" + ::loc("trophy/unlockables_names/title") + ": " +
                ::get_unlock_name_text(::UNLOCKABLE_TITLE, award_val.award) + "</color>"
          }
          break;

        case "invite_to_pick_tss":
          res.name = ::loc("userlog/invite_to_pick_tss", {TournamentName = log.tournament_name})
          if (!("descriptionBlk" in res))
            res.descriptionBlk <- ""
          if("circuit" in log)
            res.descriptionBlk += getLinkMarkup(::loc("mainmenu/btnPickTSS"),
              ::loc("url/serv_pick_tss", {port = log.port, circuit = log.circuit}), "Y")
          desc += ::loc("invite_to_pick_tss/desc")
          break;

        case "invite_to_tournament":
          res.name = ::loc("userlog/invite_to_tournament_name", {TournamentName = log.tournament_name})
          if("name_battle" in log)
          {
            desc += ::loc("invite_to_tournament/desc")
            desc += "\n" + log.name_battle
          }
          break;
        }

        if (desc!="")
          res.description <- desc
        if (log?.battleId && ::has_feature("Tournaments") && (!needShowCrossPlayInfo() || isCrossPlayEnabled()))
          res.buttonName = getTextWithCrossplayIcon(needShowCrossPlayInfo(), ::loc("chat/btnJoin"))
    }
  }
  else if (log.type == ::EULT_CLAN_UNITS)
  {
    local textLocId = "userlog/clanUnits/" + log.optype
    res.name = ::loc(textLocId + "/name")

    local descLoc = textLocId + "/desc"

    if (log.optype == "flush")
    {
      res.description <- ::loc(descLoc, {unit = ::loc(log.unit + "_0"), rp = ::Cost().setSap(log.rp).tostring()})
    }
    else if (log.optype == "add_unit")
    {
      res.description <- ::loc(descLoc, {unit = ::loc(log.unit + "_0")})
    }
    else if (log.optype == "buy_closed_unit")
    {
      res.description <- ::loc(descLoc, {unit = ::loc(log.unit + "_0"), cost = ::Cost(0, log.costGold)})
    }
  }
  else if (log.type == ::EULT_WW_AWARD)
  {
    res.name = ::loc("worldwar/personal/award")
    local awardsFor = log?.awardsFor
    local descLines = []
    if (awardsFor != null) {
      local day = ::g_string.cutPrefix(awardsFor.table, "day")
      local period = day ? ::loc("enumerated_day", {number = day}) : ::loc("worldwar/allSeason")
      local modeStr = ::g_string.split(awardsFor.mode, "__")
      local mapName = null
      local country = null
      foreach (partStr in modeStr)
      {
        if(::g_string.startsWith(partStr, "country_"))
          country = partStr
        if(::g_string.endsWith(partStr, "_wwmap"))
          mapName = partStr
      }
      country = country ? ::loc(country) : ::loc("worldwar/allCountries")
      mapName = mapName ? ::loc("worldWar/map/" + mapName) : ::loc("worldwar/allMaps")
      local leaderboard = ::loc("mainmenu/leaderboard") + ::loc("ui/colon")
        + ::g_string.implode([period, mapName, country], ::loc("ui/comma"))
      descLines.append(leaderboard)

      switch (awardsFor.leaderboard_type)
      {
       case "user_leaderboards" :
         res.name = ::loc("worldwar/personal/award")
         descLines.append(::loc("multiplayer/place") + ::loc("ui/colon") + awardsFor.place)
         break
       case "clan_leaderboards" :
         res.name = ::loc("worldwar/clan/award")
         descLines.append(::loc("multiplayer/clan_place") + ::loc("ui/colon") + awardsFor.clan_place)
         descLines.append(::loc("multiplayer/place_in_clan_leaderboard") + ::loc("ui/colon") + awardsFor.place)
         break
      }
    }
    local item = ::ItemsManager.findItemById(log?.itemDefId)
    if (item)
      descLines.append(::colorize("activeTextColor", item.getName()))
    res.logImg = item?.getSmallIconName()

    local markupArr = []
    local itemMarkup = ::get_userlog_image_item(item)
    if (itemMarkup != "")
      markupArr.append(itemMarkup)

    local resourcesConfig = getResourcesConfig(log?.resources.resource)
    if (resourcesConfig != null) {
      if (resourcesConfig.description.len() > 0)
        descLines.append($"\n{"\n\n".join(resourcesConfig.description)}")
      res.logImg = res.logImg ?? resourcesConfig.logImg
      markupArr.extend(resourcesConfig.resourcesImagesMarkupArr)
    }

    res.descriptionBlk <- descriptionBlkMultipleFormat.subst("".join(markupArr))
    res.description <- ::g_string.implode(descLines, "\n")
  }

  if ((res?.description ?? "") != "")
  {
    if (!("descriptionBlk" in res))
      res.descriptionBlk <- ""

    res.descriptionBlk = "".concat(res.descriptionBlk,
      "textareaNoTab { id:t='description'; width:t='pw'; text:t='",
      ::g_string.stripTags(res.description),"';}")
  }

  //------------- when userlog not found or not full filled -------------//
  if (res.name=="")
    res.name = ::loc("userlog/"+logName)

  return res
}
