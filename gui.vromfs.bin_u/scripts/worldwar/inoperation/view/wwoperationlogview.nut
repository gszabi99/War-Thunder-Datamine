let time = require("%scripts/time.nut")


::WwOperationLogView <- class
{
  logBlk = null
  logId = 0
  logType = null
  prevLogDate = ""
  isFirstRow = false

  armyData = null
  logColor = null
  zoneName = ""
  battleData = null
  dmgArmiesData = null

  logTypeKey = ""
  logEndKey  = ""
  detailedInfoText = ""

  basicInfoTable = null
  textInfoTable = null

  constructor(log)
  {
    logBlk = log.blk
    logId = log.id
    logType = ::g_ww_log_type.getLogTypeByName(logBlk.type)

    logColor = getEventColor()
    zoneName = getZoneName()

    logTypeKey = logBlk.type
    logEndKey  = ""
    detailedInfoText = ""

    if (logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
        logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED)
    {
      logTypeKey += getEndToKey()
    }
    else if (logBlk.type == WW_LOG_TYPES.OBJECTIVE_COMPLETED)
    {
      logEndKey = logBlk.type + getEndToKey()
      let statBlk = ::g_ww_logs.objectivesStaticBlk.getBlockByName(logBlk.id)
      if (statBlk)
      {
        detailedInfoText = getObjectiveName(statBlk)
        logTypeKey += getObjectiveType(statBlk)
      }
    }
    else if (logBlk.type == WW_LOG_TYPES.ARMY_DIED)
      detailedInfoText = ::loc("ui/parentheses",
        {text = ::loc("worldwar/log/army_died_" + logBlk.reason)})

    local wwArmyId = ""
    if ("army" in logBlk)
    {
      wwArmyId = ::g_ww_logs.getLogArmyId(logId, logBlk.army)
      let wwArmy = ::g_ww_logs.logsArmies[wwArmyId]
      wwArmy.getView().setId(wwArmyId)
      armyData = getArmyViewBasicData()
      armyData.army.append(wwArmy.getView())
    }

    if ("battle" in logBlk)
    {
      let wwBattle = ::g_ww_logs.logsBattles[logBlk.battle.id].battle
      detailedInfoText = wwBattle.getLocName()
      battleData = {
        battleView = {
          addClickCb = true
          battle = wwBattle.getView()
        }
        armySide1View = getArmyViewBasicData()
        armySide2View = getArmyViewBasicData()
      }

      for (local i = 0; i < logBlk.battle.teams.blockCount(); i++)
        foreach (army in logBlk.battle.teams.getBlock(i).armyNames % "item")
        {
          let wwBattleArmyId = ::g_ww_logs.getLogArmyId(logBlk.thisLogId, army)
          if (wwBattleArmyId == wwArmyId)
            continue

          let wwArmy = ::g_ww_logs.logsArmies[wwBattleArmyId]
          wwArmy.getView().setId(wwBattleArmyId)
          if (i == 0)
            battleData.armySide1View.army.append(wwArmy.getView())
          else
            battleData.armySide2View.army.append(wwArmy.getView())
        }
    }

    if ("damagedArmies" in logBlk)
    {
      dmgArmiesData = []
      foreach (army in logBlk.damagedArmies)
      {
        let wwBattleArmyId = ::g_ww_logs.getLogArmyId(logId, army.getBlockName())
        let wwArmy = ::g_ww_logs.logsArmies[wwBattleArmyId]
        wwArmy.getView().setId(wwBattleArmyId)
        dmgArmiesData.append({
          armyName = wwBattleArmyId
          casualties = wwArmy.getCasualtiesCount(army)
          killed = army.killed
        })
      }
      if (dmgArmiesData.len())
        logEndKey = "has_casualties"
    }

    basicInfoTable = {
      date_text = {
        text = getDate()
      }

      log_icon = {
        logCategoryName = logType.categoryName,
        ["background-image"] = getIconImage()
      }

      log_time = {
        text = getTime(),
        tooltip = getDateAndTime()
      }

      log_zone = {
        text = getZoneName(),
        isYourZone = isYourZone() ? "yes" : "no"
      }
    }

    local str = ::loc("worldwar/log/" + logTypeKey) + " "
    if (logEndKey && logEndKey.len())
      str += ::loc("worldwar/log/" + logEndKey) + " "

    textInfoTable = {
      text = ::colorize(logColor, str),
      tooltip = detailedInfoText
    }
  }

  function getArmyViewBasicData()
  {
    return {
      army = []
      isHoveredItem = true
      addArmyClickCb = true
      reqUnitTypeIcon = true
      hideArrivalTime = true
      showArmyGroupText = false
      hasTextAfterIcon = false
      battleDescriptionIconSize = WW_ARMY_GROUP_ICON_SIZE.SMALL
    }
  }

  function getId()
  {
    return logId
  }

  function isFirst()
  {
    return isFirstRow
  }

  function getEventColor()
  {
    if ("army" in logBlk)
    {
      let wwArmy = ::g_ww_logs.logsArmies[::g_ww_logs.getLogArmyId(logBlk.thisLogId, logBlk.army)]
      if (!wwArmy)
        return WW_LOG_COLORS.NEUTRAL_EVENT

      let isMySideArmy = wwArmy.isMySide(::ww_get_player_side())
      switch (logBlk.type)
      {
        case WW_LOG_TYPES.ZONE_CAPTURED:
          return isMySideArmy ? WW_LOG_COLORS.GOOD_EVENT : WW_LOG_COLORS.BAD_EVENT
        case WW_LOG_TYPES.ARMY_RETREAT:
          return isMySideArmy ? WW_LOG_COLORS.BAD_EVENT : WW_LOG_COLORS.GOOD_EVENT
        case WW_LOG_TYPES.ARMY_DIED:
          return isMySideArmy ? WW_LOG_COLORS.BAD_EVENT : WW_LOG_COLORS.GOOD_EVENT
      }
      return WW_LOG_COLORS.NEUTRAL_EVENT
    }

    if (logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
        logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED ||
        logBlk.type == WW_LOG_TYPES.OBJECTIVE_COMPLETED)
      return ::g_ww_logs.isPlayerWinner(logBlk) ? WW_LOG_COLORS.GOOD_EVENT : WW_LOG_COLORS.BAD_EVENT

    return WW_LOG_COLORS.NEUTRAL_EVENT
  }

  function getEndToKey()
  {
    if (logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
        logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED ||
        logBlk.type == WW_LOG_TYPES.OBJECTIVE_COMPLETED)
      return ::g_ww_logs.isPlayerWinner(logBlk) ? "_win" : "_lose"
    return ""
  }

  function getObjectiveName(statBlk)
  {
    let mySideName = ::ww_side_val_to_name(::ww_get_player_side())
    let objectiveType = ::g_ww_objective_type.getTypeByTypeName(statBlk.type)
    return "\"" + objectiveType.getName(statBlk, DataBlock(), mySideName) + "\""
  }

  function getZoneName()
  {
    return logBlk?.zoneInfo.zoneName ?? ""
  }

  function isYourZone()
  {
    let zoneOwner = logBlk?.zoneInfo.ownedSide
    if (!zoneOwner)
      return false

    return zoneOwner == ::ww_side_val_to_name(::ww_get_player_side())
  }

  function getObjectiveType(statBlk)
  {
    return statBlk?.mainObjective ? "_main" : "_additional"
  }

  function getZoneText()
  {
    return zoneName
  }

  function getDate()
  {
    return time.buildDateStr(logBlk.time)
  }

  function getTime()
  {
    return time.buildTimeStr(logBlk.time, false, false)
  }

  function getDateAndTime()
  {
    return time.buildDateTimeStr(logBlk.time)
  }

  function getLogColor()
  {
    return logColor
  }

  function getBasicInfoTable()
  {
    return basicInfoTable
  }

  function getTextInfoTable()
  {
    return textInfoTable
  }

  function getArmyData()
  {
    return armyData
  }

  function getBattleData()
  {
    return battleData
  }

  function getDmgArmiesData()
  {
    return dmgArmiesData
  }

  function isMySide()
  {
    if ("side" in logBlk)
      return logBlk.side == ::ww_side_val_to_name(::ww_get_player_side())

    return false
  }

  function getIconImage()
  {
    return "#ui/gameuiskin#" + logType.iconImage
  }

  function getIconColor()
  {
    return logType.iconColor
  }

  function showDate()
  {
    return getDate() != prevLogDate
  }

  function getSide1ArmyBlockWidth()
  {
    return battleData.armySide1View.army.len()
  }

  function getSide2ArmyBlockWidth()
  {
    return battleData.armySide2View.army.len()
  }

  function setPrevLogDateValue(val)
  {
    prevLogDate = val
  }

  function setIsFirstRowValue(val)
  {
    isFirstRow = val
  }
}
