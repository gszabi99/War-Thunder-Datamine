from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { haveRewards, getBaseVictoryReward, getSortedRewardsByConditions, getRewardDescText,
  getConditionText } = require("%scripts/events/eventRewards.nut")
let { addToText } = require("%scripts/unlocks/unlocksConditions.nut")

::items_classes.Ticket <- class extends ::BaseItem
{
  static iType = itemType.TICKET
  static defaultLocId = "ticket"
  //static defaultIcon = "#ui/gameuiskin#items_booster_shape1.png"
  static typeIcon = "#ui/gameuiskin#item_type_tickets.svg"
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

    let params = blk?.tournamentTicketParams
    this.maxDefeatCount = params?.maxDefeatCount ?? 0
    this.maxSequenceDefeatCount = params?.maxSequenceDefeatCount ?? 0
    this.haveAwards = params?.awards ?? false
    this.battleLimit = params?.battleLimit ?? 0
    this.customLayers = blk?.customLayers ?? {}

    this.eventEconomicNamesArray = params != null ? params % "tournamentName" : []
    if (!this.eventEconomicNamesArray.len())
      log("Item Ticket: empty tournamentTicketParams", "Items: missing any tournamentName in ticket tournamentTicketParams, " + this.id)
    else
    {
      let tournamentBlk = ::get_tournaments_blk()
      this.clanTournament = this.clanTournament || get_blk_value_by_path(tournamentBlk, this.eventEconomicNamesArray[0] + "/clanTournament", false)
      //handling closed sales
      this.canBuy = this.canBuy && !get_blk_value_by_path(tournamentBlk, this.eventEconomicNamesArray[0] + "/saleClosed", false)

      if (this.isInventoryItem && !this.isActiveTicket)
      {
        let tBlk = ::DataBlock()
        ::get_tournament_info_blk(this.eventEconomicNamesArray[0], tBlk)
        this.isActiveTicket = isInArray(tBlk?.activeTicketUID, this.uids)
      }
    }
  }

  function isCanBuy()
  {
    return base.isCanBuy() && (!this.clanTournament || ::is_in_clan())
  }

  function isActive(...)
  {
    return this.isActiveTicket
  }

  function getIcon(addItemName = true)
  {
    return this.getLayersData(true, addItemName)
  }

  function getBigIcon()
  {
    return this.getLayersData(false)
  }

  function getIconTableForEvent(event, eventEconomicName = "")
  {
    return {
      unitType = this._getUnitType(event)
      diffCode = this._getDiffCode(event)
      mode = this._getTournamentMode(event)
      type = this._getTournamentType(event)
      name = this._getNameForLayer(event, eventEconomicName)
    }
  }

  function getLayersData(small = true, addItemName = true)
  {
    local iconTable = null
    foreach(eventId in this.eventEconomicNamesArray)
    {
      let event = ::events.getEventByEconomicName(eventId)
      let eventIconTable = this.getIconTableForEvent(event, eventId)
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
      iconTable = this.getIconTableForEvent(null)

    let unitTypeLayer = getTblValue("unitType", this.customLayers)? "_" + this.customLayers.unitType : iconTable.unitType
    let insertLayersArrayCfg = []
    insertLayersArrayCfg.append(this._getUnitTypeLayer(unitTypeLayer, small))
    insertLayersArrayCfg.append(this._getDifficultyLayer(getTblValue("diffCode", this.customLayers) || iconTable.diffCode, small))
    insertLayersArrayCfg.append(this._getTournamentModeLayer(getTblValue("mode", this.customLayers) || iconTable.mode, small))
    insertLayersArrayCfg.append(this._getTournamentTypeLayer(getTblValue("type", this.customLayers) || iconTable.type, small))
    insertLayersArrayCfg.append(addItemName ? this._getNameLayer(getTblValue("name", iconTable), small) : null)

    return ::LayersIcon.genInsertedDataFromLayer(this._getBackground(small), insertLayersArrayCfg)
  }

  function getBasePartOfLayerId(small)
  {
    return this.iconStyle + (small? "_shop" : "")
  }

  function _getBackground(small)
  {
    return ::LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small))
  }

  function _getUnitType(event)
  {
    if (!event)
      return null

    let unitTypeMask = ::events.getEventUnitTypesMask(event)

    local unitsString = ""
    foreach(unitType in unitTypes.types)
      if (unitType.bit & unitTypeMask)
        unitsString += "_" + unitType.name

    return unitsString
  }

  function _getUnitTypeLayer(unitsString, small)
  {
    return ::LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + unitsString)
  }

  function _getDiffCode(event)
  {
    return event? ::events.getEventDiffCode(event) : null
  }

  function _getDifficultyLayer(diffCode, small)
  {
    if (diffCode == null)
      return null
    return ::LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + "_diff" + diffCode)
  }

  function _getTournamentMode(event)
  {
    if (!event)
      return null

    if (getTblValue("clans_only", event, false))
      return "clan"
    if (::events.getMaxTeamSize(event) == 1)
      return "pvp"
    if (getTblValue("squads_only", event, false))
      return "squad"

    return "team"
  }

  function _getTournamentModeLayer(mode, small)
  {
    return ::LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + "_gm_" + mode)
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
    return ::LayersIcon.findLayerCfg(this.getBasePartOfLayerId(small) + "_gt_" + lType)
  }

  function _getNameForLayer(_event, eventEconomicName = "")
  {
    local text = this.locId ? loc(this.locId + "/short", loc(this.locId, "")) : ""
    if (text == "")
      text = ::events.getNameByEconomicName(eventEconomicName)
    if (text == "")
      text = loc("item/" + this.id, loc("item/" + this.defaultLocId, ""))
    return text
  }

  function _getNameLayer(text, small)
  {
    if (!small || !text)
      return null

    let layerCfg = ::LayersIcon.findLayerCfg(this.textLayerStyle)
    if (!layerCfg)
      return null

    layerCfg.text <- text
    return layerCfg
  }

  function getName(colored = true)
  {
    local name = this.locId ? loc(this.locId + "/short", loc(this.locId, "")) : ""
    if (name == "" && this.eventEconomicNamesArray.len())
    {
      if (this.eventEconomicNamesArray.len() > 1)
        name = loc("item/" + this.defaultLocId + "/multipleEvents")
      else
      {
        local eventName = ::events.getNameByEconomicName(this.eventEconomicNamesArray[0])
        eventName = colored ? colorize("userlogColoredText", eventName) : eventName
        name = loc("item/" + this.defaultLocId, { name = eventName })
      }
    }
    if (name == "")
      name = loc("item/" + this.id, "")
    return name
  }

  function getTypeName()
  {
    return loc("item/ticket/reduced")
  }

  function getTicketTournamentData(eventId)
  {
    let blk = ::DataBlock()
    ::get_tournament_info_blk(eventId, blk)
    let data = {}
    data.defCount <- blk?.ticketDefeatCount ?? 0
    data.sequenceDefeatCount <- blk?.ticketSequenceDefeatCount ?? 0
    data.battleCount <- blk?.battleCount ?? 0
    data.numUnfinishedSessions <- 0
    data.timeToWait <- 0
    let curTime = ::get_charserver_time_sec()
    let sessions = blk?.sessions
    if (sessions != null)
    {
      foreach (session in sessions % "data")
      {
        let timeExpired = getTblValue("timeExpired", session, 0)
        let timeDelta = timeExpired - curTime
        if (timeDelta <= 0)
          continue
        ++data.numUnfinishedSessions
        if (data.timeToWait == 0 || data.timeToWait > timeDelta)
          data.timeToWait = timeDelta
      }
    }

    // Check for total defeats count.
    let checkTotalDefCount = this._checkTicketDefCount(data.defCount, this.maxDefeatCount, data.numUnfinishedSessions)

    // Check for sequence defeats count.
    let checkSequenceDefCount = this._checkTicketDefCount(data.sequenceDefeatCount, this.maxSequenceDefeatCount, data.numUnfinishedSessions)

    // Player can't join ticket's tournament if number of
    // unfinished sessions exceeds number of possible defeats.
    data.canJoinTournament <- checkTotalDefCount && checkSequenceDefCount
    return data
  }

  function getDefeatCountText(tournamentData, valueColor = "activeTextColor")
  {
    local text = ""
    if (this.maxDefeatCount)
      text = addToText(text, loc("ticket/defeat_count"),
        tournamentData.defCount + "/" + this.maxDefeatCount, valueColor)
    return text
  }

  function getSequenceDefeatCountText(tournamentData, valueColor = "activeTextColor")
  {
    local text = ""
    if (this.maxSequenceDefeatCount)
      text = addToText(text, loc("ticket/defeat_count_in_a_row"),
        tournamentData.sequenceDefeatCount + "/" + this.maxSequenceDefeatCount, valueColor)
    return text
  }

  function getBattleCountText(tournamentData, valueColor = "activeTextColor")
  {
    local text = ""
    if (this.battleLimit)
      text = addToText(text, loc("ticket/battle_count"),
        tournamentData.battleCount + "/" + this.battleLimit, valueColor)
    return text
  }

  function getAvailableDefeatsText(eventId, valueColor = "activeTextColor")
  {
    let textParts = []
    if (this.isActive())
    {
      let ticketTournamentData = this.getTicketTournamentData(eventId)
      textParts.append(this.getDefeatCountText(ticketTournamentData, valueColor))
      textParts.append(this.getSequenceDefeatCountText(ticketTournamentData, valueColor))
      textParts.append(this.getBattleCountText(ticketTournamentData, valueColor))
    }
    else
    {
      local locParams = {}
      if (this.maxDefeatCount)
      {
        locParams = {value = colorize(valueColor, this.maxDefeatCount)}
        textParts.append(loc("ticket/max_defeat_count", locParams))
      }
      if (this.maxSequenceDefeatCount)
      {
        locParams = {value = colorize(valueColor, this.maxSequenceDefeatCount)}
        textParts.append(loc("ticket/max_defeat_count_in_a_row", locParams))
      }
      if (this.battleLimit)
      {
        locParams = {value = colorize(valueColor, this.battleLimit)}
        textParts.append(loc("ticket/battle_limit", locParams))
      }
    }

    local text = ::g_string.implode(textParts, "\n")
    if (text.len() == 0)
      text = loc("ticket/noRestrictions")

    return text
  }

  function getTournamentRewardsText(eventId)
  {
    local text = ""
    let event = ::events.getEventByEconomicName(eventId)
    if (event)
    {
      let baseReward = getBaseVictoryReward(event)
      if (baseReward)
        text += (text.len() ? "\n" : "") + loc("tournaments/reward/everyVictory",  {reward = baseReward})

      if (haveRewards(event))
      {
        text += (text.len() ? "\n\n" : "") + loc("tournaments/specialRewards") + loc("ui/colon")
        let specialRewards = getSortedRewardsByConditions(event)
        foreach (_conditionId, rewardsList in specialRewards)
          foreach (reward in rewardsList)
            text += "\n" + getConditionText(reward) + " - " + getRewardDescText(reward)
      }
    }
    return text
  }

  function getDescription()
  {
    let desc = []
    foreach(eventId in this.eventEconomicNamesArray)
    {
      if (desc.len())
        desc.append("\n")

      if (this.eventEconomicNamesArray.len() > 1)
        desc.append(colorize("activeTextColor", ::events.getNameByEconomicName(eventId)))
      desc.append(this.getAvailableDefeatsText(eventId))
    }

    desc.append(base.getDescription())
    return ::g_string.implode(desc, "\n")
  }

  function getLongDescription()
  {
    let desc = []
    foreach(eventId in this.eventEconomicNamesArray)
    {
      if (desc.len())
        desc.append("\n")

      if (this.eventEconomicNamesArray.len() > 1)
        desc.append(colorize("activeTextColor", ::events.getNameByEconomicName(eventId)))
      desc.append(this.getAvailableDefeatsText(eventId))
      desc.append(this.getTournamentRewardsText(eventId))
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
    return isInArray(checkEconomicName, this.eventEconomicNamesArray)
  }
}
