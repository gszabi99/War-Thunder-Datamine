from "%scripts/dagui_natives.nut" import ww_side_val_to_name
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let time = require("%scripts/time.nut")
let DataBlock  = require("DataBlock")
let { wwGetPlayerSide } = require("worldwar")
let { getWWLogsData, getWWLogArmyId, isWWPlayerWinner } = require("%scripts/worldWar/inOperation/model/wwOperationLog.nut")
let { g_ww_log_type } = require("%scripts/worldWar/inOperation/model/wwOperationLogTypes.nut")
let { wwObjectiveType } = require("%scripts/worldWar/inOperation/model/wwObjectivesTypes.nut")

class WwOperationLogView {
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

  constructor(logObj) {
    this.logBlk = logObj.blk
    this.logId = logObj.id
    this.logType = g_ww_log_type.getLogTypeByName(this.logBlk.type)

    this.logColor = this.getEventColor()
    this.zoneName = this.getZoneName()

    this.logTypeKey = this.logBlk.type
    this.logEndKey  = ""
    this.detailedInfoText = ""

    let { objectivesStaticBlk, logsArmies, logsBattles } = getWWLogsData()

    if (this.logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
        this.logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED) {
      this.logTypeKey = "".concat(this.logTypeKey, this.getEndToKey())
    }
    else if (this.logBlk.type == WW_LOG_TYPES.OBJECTIVE_COMPLETED) {
      this.logEndKey = this.logBlk.type + this.getEndToKey()
      let statBlk = objectivesStaticBlk.getBlockByName(this.logBlk.id)
      if (statBlk) {
        this.detailedInfoText = this.getObjectiveName(statBlk)
        this.logTypeKey = "".concat(this.logTypeKey, this.getObjectiveType(statBlk))
      }
    }
    else if (this.logBlk.type == WW_LOG_TYPES.ARMY_DIED)
      this.detailedInfoText = loc("ui/parentheses",
        { text = loc($"worldwar/log/army_died_{this.logBlk.reason}") })

    local wwArmyId = ""
    if ("army" in this.logBlk) {
      wwArmyId = getWWLogArmyId(this.logId, this.logBlk.army)
      let wwArmy = logsArmies[wwArmyId]
      wwArmy.getView().setId(wwArmyId)
      this.armyData = this.getArmyViewBasicData()
      this.armyData.army.append(wwArmy.getView())
    }

    if ("battle" in this.logBlk) {
      let wwBattle = logsBattles[this.logBlk.battle.id].battle
      this.detailedInfoText = wwBattle.getLocName()
      this.battleData = {
        battleView = {
          addClickCb = true
          battle = wwBattle.getView()
        }
        armySide1View = this.getArmyViewBasicData()
        armySide2View = this.getArmyViewBasicData()
      }

      for (local i = 0; i < this.logBlk.battle.teams.blockCount(); i++)
        foreach (army in this.logBlk.battle.teams.getBlock(i).armyNames % "item") {
          let wwBattleArmyId = getWWLogArmyId(this.logBlk.thisLogId, army)
          if (wwBattleArmyId == wwArmyId)
            continue

          let wwArmy = logsArmies[wwBattleArmyId]
          wwArmy.getView().setId(wwBattleArmyId)
          if (i == 0)
            this.battleData.armySide1View.army.append(wwArmy.getView())
          else
            this.battleData.armySide2View.army.append(wwArmy.getView())
        }
    }

    if ("damagedArmies" in this.logBlk) {
      this.dmgArmiesData = []
      foreach (army in this.logBlk.damagedArmies) {
        let wwBattleArmyId = getWWLogArmyId(this.logId, army.getBlockName())
        let wwArmy = logsArmies[wwBattleArmyId]
        wwArmy.getView().setId(wwBattleArmyId)
        this.dmgArmiesData.append({
          armyName = wwBattleArmyId
          casualties = wwArmy.getCasualtiesCount(army)
          killed = army.killed
        })
      }
      if (this.dmgArmiesData.len())
        this.logEndKey = "has_casualties"
    }

    this.basicInfoTable = {
      date_text = {
        text = this.getDate()
      }

      log_icon = {
        logCategoryName = this.logType.categoryName,
        ["background-image"] = this.getIconImage()
      }

      log_time = {
        text = this.getTime(),
        tooltip = this.getDateAndTime()
      }

      log_zone = {
        text = this.getZoneName(),
        isYourZone = this.isYourZone() ? "yes" : "no"
      }
    }

    local str = "".concat(loc($"worldwar/log/{this.logTypeKey}"), " ")
    if (this.logEndKey && this.logEndKey.len())
      str = "".concat(str, loc($"worldwar/log/{this.logEndKey}"), " ")

    this.textInfoTable = {
      text = colorize(this.logColor, str),
      tooltip = this.detailedInfoText
    }
  }

  function getArmyViewBasicData() {
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

  function getId() {
    return this.logId
  }

  function isFirst() {
    return this.isFirstRow
  }

  function getEventColor() {
    if ("army" in this.logBlk) {
      let wwArmy = getWWLogsData().logsArmies[getWWLogArmyId(this.logBlk.thisLogId, this.logBlk.army)]
      if (!wwArmy)
        return WW_LOG_COLORS.NEUTRAL_EVENT

      let isMySideArmy = wwArmy.isMySide(wwGetPlayerSide())
      let btype = this.logBlk.type
      if (btype == WW_LOG_TYPES.ZONE_CAPTURED)
        return isMySideArmy ? WW_LOG_COLORS.GOOD_EVENT : WW_LOG_COLORS.BAD_EVENT
      if (btype == WW_LOG_TYPES.ARMY_RETREAT)
        return isMySideArmy ? WW_LOG_COLORS.BAD_EVENT : WW_LOG_COLORS.GOOD_EVENT
      if (btype == WW_LOG_TYPES.ARMY_DIED)
        return isMySideArmy ? WW_LOG_COLORS.BAD_EVENT : WW_LOG_COLORS.GOOD_EVENT
      return WW_LOG_COLORS.NEUTRAL_EVENT
    }

    if (this.logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
        this.logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED ||
        this.logBlk.type == WW_LOG_TYPES.OBJECTIVE_COMPLETED)
      return isWWPlayerWinner(this.logBlk) ? WW_LOG_COLORS.GOOD_EVENT : WW_LOG_COLORS.BAD_EVENT

    return WW_LOG_COLORS.NEUTRAL_EVENT
  }

  function getEndToKey() {
    if (this.logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
        this.logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED ||
        this.logBlk.type == WW_LOG_TYPES.OBJECTIVE_COMPLETED)
      return isWWPlayerWinner(this.logBlk) ? "_win" : "_lose"
    return ""
  }

  function getObjectiveName(statBlk) {
    let mySideName = ww_side_val_to_name(wwGetPlayerSide())
    let objectiveType = wwObjectiveType.getTypeByTypeName(statBlk.type)
    return "".concat("\"", objectiveType.getName(statBlk, DataBlock(), mySideName), "\"")
  }

  function getZoneName() {
    return this.logBlk?.zoneInfo.zoneName ?? ""
  }

  function isYourZone() {
    let zoneOwner = this.logBlk?.zoneInfo.ownedSide
    if (!zoneOwner)
      return false

    return zoneOwner == ww_side_val_to_name(wwGetPlayerSide())
  }

  function getObjectiveType(statBlk) {
    return statBlk?.mainObjective ? "_main" : "_additional"
  }

  function getZoneText() {
    return this.zoneName
  }

  function getDate() {
    return time.buildDateStr(this.logBlk.time)
  }

  function getTime() {
    return time.buildTimeStr(this.logBlk.time, false, false)
  }

  function getDateAndTime() {
    return time.buildDateTimeStr(this.logBlk.time)
  }

  function getLogColor() {
    return this.logColor
  }

  function getBasicInfoTable() {
    return this.basicInfoTable
  }

  function getTextInfoTable() {
    return this.textInfoTable
  }

  function getArmyData() {
    return this.armyData
  }

  function getBattleData() {
    return this.battleData
  }

  function getDmgArmiesData() {
    return this.dmgArmiesData
  }

  function isMySide() {
    if ("side" in this.logBlk)
      return this.logBlk.side == ww_side_val_to_name(wwGetPlayerSide())

    return false
  }

  function getIconImage() {
    return $"#ui/gameuiskin#{this.logType.iconImage}"
  }

  function getIconColor() {
    return this.logType.iconColor
  }

  function showDate() {
    return this.getDate() != this.prevLogDate
  }

  function getSide1ArmyBlockWidth() {
    return this.battleData.armySide1View.army.len()
  }

  function getSide2ArmyBlockWidth() {
    return this.battleData.armySide2View.army.len()
  }

  function setPrevLogDateValue(val) {
    this.prevLogDate = val
  }

  function setIsFirstRowValue(val) {
    this.isFirstRow = val
  }
}

return WwOperationLogView
