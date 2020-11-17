local { get_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

class ::items_classes.Ticket extends ::BaseItem
{
  static iType = itemType.TICKET
  static defaultLocId = "ticket"
  //static defaultIcon = "#ui/gameuiskin#items_booster_shape1"
  static typeIcon = "#ui/gameuiskin#item_type_tickets"
  static linkActionLocId = "mainmenu/signUp"

  static includeInRecentItems = false

  canBuy = true

  eventEconomicNamesArray = null // Event's economic name.
  isActiveTicket = false
  haveAwards = false
  maxDefeatCount = 0
  maxSequenceDefeatCount = 0
  clanTournament = false
  battleLimit = 0

  textLayerStyle = "ticket_name_text"

  customLayers = null

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)

    local params = blk?.tournamentTicketParams
    maxDefeatCount = params?.maxDefeatCount ?? 0
    maxSequenceDefeatCount = params?.maxSequenceDefeatCount ?? 0
    haveAwards = params?.awards ?? false
    battleLimit = params?.battleLimit ?? 0
    customLayers = blk?.customLayers ?? {}

    eventEconomicNamesArray = params != null ? params % "tournamentName" : []
    if (!eventEconomicNamesArray.len())
      ::dagor.debug("Item Ticket: empty tournamentTicketParams", "Items: missing any tournamentName in ticket tournamentTicketParams, " + id)
    else
    {
      local tournamentBlk = ::get_tournaments_blk()
      clanTournament = clanTournament || get_blk_value_by_path(tournamentBlk, eventEconomicNamesArray[0] + "/clanTournament", false)
      //handling closed sales
      canBuy = canBuy && !get_blk_value_by_path(tournamentBlk, eventEconomicNamesArray[0] + "/saleClosed", false)

      if (isInventoryItem && !isActiveTicket)
      {
        local tBlk = ::DataBlock()
        ::get_tournament_info_blk(eventEconomicNamesArray[0], tBlk)
        isActiveTicket = ::isInArray(tBlk?.activeTicketUID, uids)
      }
    }
  }

  function isCanBuy()
  {
    return base.isCanBuy() && (!clanTournament || ::is_in_clan())
  }

  function isActive(...)
  {
    return isActiveTicket
  }

  function getIcon(addItemName = true)
  {
    return getLayersData(true, addItemName)
  }

  function getBigIcon()
  {
    return getLayersData(false)
  }

  function getIconTableForEvent(event, eventEconomicName = "")
  {
    return {
      unitType = _getUnitType(event)
      diffCode = _getDiffCode(event)
      mode = _getTournamentMode(event)
      type = _getTournamentType(event)
      name = _getNameForLayer(event, eventEconomicName)
    }
  }

  function getLayersData(small = true, addItemName = true)
  {
    local iconTable = null
    foreach(eventId in eventEconomicNamesArray)
    {
      local event = ::events.getEventByEconomicName(eventId)
      local eventIconTable = getIconTableForEvent(event, eventId)
      if (!iconTable)
        iconTable = eventIconTable
      else
        iconTable = ::u.tablesCombine(iconTable,
                                      eventIconTable,
                                      function(resultTblVal, eventTblVal)
                                      {
                                        return resultTblVal != eventTblVal? null : eventTblVal
                                      })
    }

    if (!iconTable)
      iconTable = getIconTableForEvent(null)

    local unitTypeLayer = ::getTblValue("unitType", customLayers)? "_" + customLayers.unitType : iconTable.unitType
    local insertLayersArrayCfg = []
    insertLayersArrayCfg.append(_getUnitTypeLayer(unitTypeLayer, small))
    insertLayersArrayCfg.append(_getDifficultyLayer(::getTblValue("diffCode", customLayers) || iconTable.diffCode, small))
    insertLayersArrayCfg.append(_getTournamentModeLayer(::getTblValue("mode", customLayers) || iconTable.mode, small))
    insertLayersArrayCfg.append(_getTournamentTypeLayer(::getTblValue("type", customLayers) || iconTable.type, small))
    insertLayersArrayCfg.append(addItemName ? _getNameLayer(::getTblValue("name", iconTable), small) : null)

    return ::LayersIcon.genInsertedDataFromLayer(_getBackground(small), insertLayersArrayCfg)
  }

  function getBasePartOfLayerId(small)
  {
    return iconStyle + (small? "_shop" : "")
  }

  function _getBackground(small)
  {
    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small))
  }

  function _getUnitType(event)
  {
    if (!event)
      return null

    local unitTypeMask = ::events.getEventUnitTypesMask(event)

    local unitsString = ""
    foreach(unitType in unitTypes.types)
      if (unitType.bit & unitTypeMask)
        unitsString += "_" + unitType.name

    return unitsString
  }

  function _getUnitTypeLayer(unitsString, small)
  {
    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + unitsString)
  }

  function _getDiffCode(event)
  {
    return event? ::events.getEventDiffCode(event) : null
  }

  function _getDifficultyLayer(diffCode, small)
  {
    if (diffCode == null)
      return null
    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + "_diff" + diffCode)
  }

  function _getTournamentMode(event)
  {
    if (!event)
      return null

    if (::getTblValue("clans_only", event, false))
      return "clan"
    if (::events.getMaxTeamSize(event) == 1)
      return "pvp"
    if (::getTblValue("squads_only", event, false))
      return "squad"

    return "team"
  }

  function _getTournamentModeLayer(mode, small)
  {
    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + "_gm_" + mode)
  }

  function _getTournamentType(event)
  {
    if (!event)
      return null

    if (::events.isRaceEvent(event))
      return "race"

    return "deathmatch"
  }

  function _getTournamentTypeLayer(lType, small)
  {
    return ::LayersIcon.findLayerCfg(getBasePartOfLayerId(small) + "_gt_" + lType)
  }

  function _getNameForLayer(event, eventEconomicName = "")
  {
    local text = locId ? ::loc(locId + "/short", ::loc(locId, "")) : ""
    if (text == "")
      text = ::events.getNameByEconomicName(eventEconomicName)
    if (text == "")
      text = ::loc("item/" + id, ::loc("item/" + defaultLocId, ""))
    return text
  }

  function _getNameLayer(text, small)
  {
    if (!small || !text)
      return null

    local layerCfg = ::LayersIcon.findLayerCfg(textLayerStyle)
    if (!layerCfg)
      return null

    layerCfg.text <- text
    return layerCfg
  }

  function getName(colored = true)
  {
    local name = locId ? ::loc(locId + "/short", ::loc(locId, "")) : ""
    if (name == "" && eventEconomicNamesArray.len())
    {
      if (eventEconomicNamesArray.len() > 1)
        name = ::loc("item/" + defaultLocId + "/multipleEvents")
      else
      {
        local eventName = ::events.getNameByEconomicName(eventEconomicNamesArray[0])
        eventName = colored ? ::colorize("userlogColoredText", eventName) : eventName
        name = ::loc("item/" + defaultLocId, { name = eventName })
      }
    }
    if (name == "")
      name = ::loc("item/" + id, "")
    return name
  }

  function getTypeName()
  {
    return ::loc("item/ticket/reduced")
  }

  function getTicketTournamentData(eventId)
  {
    local blk = ::DataBlock()
    ::get_tournament_info_blk(eventId, blk)
    local data = {}
    data.defCount <- blk?.ticketDefeatCount ?? 0
    data.sequenceDefeatCount <- blk?.ticketSequenceDefeatCount ?? 0
    data.battleCount <- blk?.battleCount ?? 0
    data.numUnfinishedSessions <- 0
    data.timeToWait <- 0
    local curTime = ::get_charserver_time_sec()
    local sessions = blk?.sessions
    if (sessions != null)
    {
      foreach (session in sessions % "data")
      {
        local timeExpired = ::getTblValue("timeExpired", session, 0)
        local timeDelta = timeExpired - curTime
        if (timeDelta <= 0)
          continue
        ++data.numUnfinishedSessions
        if (data.timeToWait == 0 || data.timeToWait > timeDelta)
          data.timeToWait = timeDelta
      }
    }

    // Check for total defeats count.
    local checkTotalDefCount = _checkTicketDefCount(data.defCount, maxDefeatCount, data.numUnfinishedSessions)

    // Check for sequence defeats count.
    local checkSequenceDefCount = _checkTicketDefCount(data.sequenceDefeatCount, maxSequenceDefeatCount, data.numUnfinishedSessions)

    // Player can't join ticket's tournament if number of
    // unfinished sessions exceeds number of possible defeats.
    data.canJoinTournament <- checkTotalDefCount && checkSequenceDefCount
    return data
  }

  function getDefeatCountText(tournamentData, valueColor = "activeTextColor")
  {
    local text = ""
    if (maxDefeatCount)
      text = ::UnlockConditions.addToText(text, ::loc("ticket/defeat_count"),
        tournamentData.defCount + "/" + maxDefeatCount, valueColor)
    return text
  }

  function getSequenceDefeatCountText(tournamentData, valueColor = "activeTextColor")
  {
    local text = ""
    if (maxSequenceDefeatCount)
      text = ::UnlockConditions.addToText(text, ::loc("ticket/defeat_count_in_a_row"),
        tournamentData.sequenceDefeatCount + "/" + maxSequenceDefeatCount, valueColor)
    return text
  }

  function getBattleCountText(tournamentData, valueColor = "activeTextColor")
  {
    local text = ""
    if (battleLimit)
      text = ::UnlockConditions.addToText(text, ::loc("ticket/battle_count"),
        tournamentData.battleCount + "/" + battleLimit, valueColor)
    return text
  }

  function getAvailableDefeatsText(eventId, valueColor = "activeTextColor")
  {
    local textParts = []
    if (isActive())
    {
      local ticketTournamentData = getTicketTournamentData(eventId)
      textParts.append(getDefeatCountText(ticketTournamentData, valueColor))
      textParts.append(getSequenceDefeatCountText(ticketTournamentData, valueColor))
      textParts.append(getBattleCountText(ticketTournamentData, valueColor))
    }
    else
    {
      local locParams = {}
      if (maxDefeatCount)
      {
        locParams = {value = ::colorize(valueColor, maxDefeatCount)}
        textParts.append(::loc("ticket/max_defeat_count", locParams))
      }
      if (maxSequenceDefeatCount)
      {
        locParams = {value = ::colorize(valueColor, maxSequenceDefeatCount)}
        textParts.append(::loc("ticket/max_defeat_count_in_a_row", locParams))
      }
      if (battleLimit)
      {
        locParams = {value = ::colorize(valueColor, battleLimit)}
        textParts.append(::loc("ticket/battle_limit", locParams))
      }
    }

    local text = ::g_string.implode(textParts, "\n")
    if (text.len() == 0)
      text = ::loc("ticket/noRestrictions")

    return text
  }

  function getTournamentRewardsText(eventId)
  {
    local text = ""
    local event = ::events.getEventByEconomicName(eventId)
    if (event)
    {
      local baseReward = ::EventRewards.getBaseVictoryReward(event)
      if (baseReward)
        text += (text.len() ? "\n" : "") + ::loc("tournaments/reward/everyVictory",  {reward = baseReward})

      if (::EventRewards.haveRewards(event))
      {
        text += (text.len() ? "\n\n" : "") + ::loc("tournaments/specialRewards") + ::loc("ui/colon")
        local specialRewards = ::EventRewards.getSortedRewardsByConditions(event)
        foreach (conditionId, rewardsList in specialRewards)
          foreach (reward in rewardsList)
            text += "\n" + ::EventRewards.getConditionText(reward) + " - " + ::EventRewards.getRewardDescText(reward)
      }
    }
    return text
  }

  function getDescription()
  {
    local desc = []
    foreach(eventId in eventEconomicNamesArray)
    {
      if (desc.len())
        desc.append("\n")

      if (eventEconomicNamesArray.len() > 1)
        desc.append(::colorize("activeTextColor", ::events.getNameByEconomicName(eventId)))
      desc.append(getAvailableDefeatsText(eventId))
    }

    desc.append(base.getDescription())
    return ::g_string.implode(desc, "\n")
  }

  function getLongDescription()
  {
    local desc = []
    foreach(eventId in eventEconomicNamesArray)
    {
      if (desc.len())
        desc.append("\n")

      if (eventEconomicNamesArray.len() > 1)
        desc.append(::colorize("activeTextColor", ::events.getNameByEconomicName(eventId)))
      desc.append(getAvailableDefeatsText(eventId))
      desc.append(getTournamentRewardsText(eventId))
    }

    desc.append(base.getDescription())
    return ::g_string.implode(desc, "\n")
  }

  function _checkTicketDefCount(defCount, maxDefCount, numUnfinishedSessions)
  {
    if (maxDefCount == 0)
      return true
    return maxDefCount - defCount > numUnfinishedSessions
  }

  function isForEvent(checkEconomicName)
  {
    return ::isInArray(checkEconomicName, eventEconomicNamesArray)
  }
}
