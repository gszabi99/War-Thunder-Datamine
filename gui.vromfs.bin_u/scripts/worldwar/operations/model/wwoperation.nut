//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let time = require("%scripts/time.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { getMapByName } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

enum WW_OPERATION_STATUSES {
  UNKNOWN = -1
  ES_ACTIVE = 1
  ES_PAUSED = 7
}

enum WW_OPERATION_PRIORITY { //bit enum
  NONE                       = 0
  CAN_JOIN_BY_ARMY_RELATIONS = 0x0001
  CAN_JOIN_BY_MY_CLAN        = 0x0002

  MAX                        = 0xFFFF
}

::WwOperation <- class {
  id = -1
  data = null
  status = WW_OPERATION_STATUSES.UNKNOWN

  isArmyGroupsDataGathered = false
  _myClanGroup = null
  _assignCountry = null

  isFinished = false //this parametr updated from local operation when return main menu of WWar

  constructor(v_data) {
    this.data = v_data
    this.id = getTblValue("_id", this.data, -1)
    this.status = getTblValue("st", this.data, WW_OPERATION_STATUSES.UNKNOWN)
  }

  function isValid() {
    return this.id >= 0
  }

  function isAvailableToJoin() {
    return !this.isFinished &&
      (this.status == WW_OPERATION_STATUSES.ES_ACTIVE
        || this.status == WW_OPERATION_STATUSES.ES_PAUSED)
  }

  function isEqual(operation) {
    return operation && operation.id == this.id
  }

  function getMapId() {
    return getTblValue("map", this.data, "unknown_map")
  }

  function getMap() {
    return getMapByName(this.getMapId())
  }

  function getNameText(full = true) {
    return this.getNameTextByIdAndMapName(this.id, full ? this.getMapText() : null)
  }

  static function getNameTextByIdAndMapName(operationId, mapName = null) {
    local res = loc("ui/number_sign") + operationId
    if (mapName)
      res = mapName + " " + res
    return res
  }

  function getMapText() {
    let map = this.getMap()
    return map ? map.getNameText() : ""
  }

  function getDescription(showClanParticipateStatus = true) {
    let txtList = []
    if (showClanParticipateStatus && this.isMyClanParticipate())
      txtList.append(colorize("userlogColoredText", loc("worldwar/yourClanInThisOperation")))
    let map = this.getMap()
    if (map)
      txtList.append(map.getDescription(false))
    return ::g_string.implode(txtList, "\n")
  }

  function getStartDateTxt() {
    return time.buildDateStr(this.data?.ct ?? 0)
  }

  function getGeoCoordsText() {
    let map = this.getMap()
    return map ? map.getGeoCoordsText() : ""
  }

  function getCantJoinReasonDataBySide(side) {
    let res = {
      canJoin = false
      country = ""
      reasonText = ""
    }

    if (::g_squad_manager.isSquadMember()) {
      let queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
      if (queue && queue.getQueueWwOperationId() != this.id)
        return res.__update({
          reasonText = loc("worldWar/cantJoinBecauseOfQueue", { operationInfo = this.getNameText() })
        })
    }

    let countryes = getTblValue(side, this.getCountriesByTeams(), [])
    let assignCountry = this.getMyAssignCountry()
    if (assignCountry) {
      res.country = assignCountry
      if (!isInArray(assignCountry, countryes))
        res.reasonText = loc("worldWar/cantPlayByThisSide")
      else
        res.canJoin = true

      return res
    }

    local summaryCantJoinReasonText = ""
    foreach (_idx, country in countryes) {
      let reasonData = this.getCantJoinReasonData(country)
      if (reasonData.canJoin) {
        res.canJoin = true
        res.country = country
        return res
      }

      if (!::u.isEmpty(summaryCantJoinReasonText))
        summaryCantJoinReasonText += "\n"

      summaryCantJoinReasonText += loc(country) + loc("ui/colon") + reasonData.reasonText
    }

    if (summaryCantJoinReasonText.len() > 0)
      res.reasonText = summaryCantJoinReasonText
    else
      res.canJoin = true

    return res
  }

  function getCantJoinReasonData(country) {
    let res = {
      canJoin = false
      reasonText = ""
    }

    let lastPlayedCountry = ::g_world_war.lastPlayedOperationCountry
    let lastPlayedOperationId = ::g_world_war.lastPlayedOperationId
    if (this.isMyClanParticipate() && country != this.getMyClanCountry()) // Join to opposite side
      res.reasonText = loc("worldWar/cantJoinByAnotherSideClan")
    else if (!this.isMyClanParticipate()
      && lastPlayedOperationId && lastPlayedOperationId == this.id
      && lastPlayedCountry && lastPlayedCountry != country) // Last played out of clan by another country
      res.reasonText = loc("worldWar/cantPlayByThisSide")
    else if (!this.canJoinByCountry(country)) // No such country in this operation
      res.reasonText = loc("worldWar/chooseAvailableCountry")

    if (!res.reasonText.len())
      res.canJoin = true

    return res
  }

  function join(country, onErrorCb = null, isSilence = false, onSuccess = null, forced = false) {
    let cantJoinReason = this.getCantJoinReasonData(country)
    if (!cantJoinReason.canJoin && !forced) { // Forced when invite in operation
      if (!isSilence)
        ::showInfoMsgBox(cantJoinReason.reasonText)
      return false
    }

    ::g_world_war.stopWar()
    return this._join(country, onErrorCb, isSilence, onSuccess)
  }

  function _join(country, onErrorCb, isSilence, onSuccess) {
    let taskId = ::ww_start_war(this.id)
    let cb = Callback(function() {
        ::g_world_war.onJoinOperationSuccess(this.id, country, isSilence, onSuccess)
      }, this)
    let errorCb = function(res) {
        ::g_world_war.stopWar()
        if (onErrorCb)
          onErrorCb(res)
      }
    ::g_tasker.addTask(taskId, { showProgressBox = true }, cb, errorCb)
    return taskId >= 0
  }

  function resetCache() {
    this.isArmyGroupsDataGathered = false
    this._myClanGroup = null
    this._assignCountry = null
  }

  function gatherArmyGroupsDataOnce() {
    if (this.isArmyGroupsDataGathered)
      return
    this.isArmyGroupsDataGathered = true

    let myClanId = ::clan_get_my_clan_id().tointeger()
    foreach (ag in this.getArmyGroups()) {
      if (ag?.clanId != myClanId)
        continue

      this._myClanGroup = ag
      this._assignCountry = this.getArmyGroupCountry(ag)
    }
  }

  function getArmyGroupsBySide(side) {
    let countriesByTeams = this.getCountriesByTeams()
    let sideCountries = getTblValue(side, countriesByTeams)

    return ::u.filter(
      this.getArmyGroups(),
      (@(sideCountries) function(ag) {
        return isInArray(getTblValue("cntr", ag, ""), sideCountries)
      })(sideCountries)
    )
  }

  function getMyClanGroup() {
    this.gatherArmyGroupsDataOnce()
    return this._myClanGroup
  }

  function getMyAssignCountry() {
    this.gatherArmyGroupsDataOnce()
    return this._assignCountry
  }

  function getMyClanCountry() {
    let myClanGroup = this.getMyClanGroup()
    return myClanGroup && this.getArmyGroupCountry(myClanGroup)
  }

  function isMyClanSide(side) {
    if (!this.isMyClanParticipate())
      return false

    let country = this.getMyClanCountry()
    let countries = getTblValue(side, this.getCountriesByTeams(), [])
    return isInArray(country, countries)
  }

  function isMyClanParticipate() {
    return this.isAvailableToJoin() && this.getMyClanGroup() != null
  }

  function canJoinByMyClan() {
    //can join after change clan only if played by the same country in this operation
    let assignCountry = this.getMyAssignCountry()
    return this.isMyClanParticipate() && (assignCountry == null || assignCountry == this.getMyClanCountry())
  }

  function getArmyGroups() {
    return getTblValue("armyGroups", this.data, [])
  }

  function getArmyGroupCountry(armyGroup) {
    return getTblValue("cntr", armyGroup)
  }

  function getCountriesByTeams() {
    let res = {}
    let map = this.getMap()
    if (!map)
      return res

    let countryToSide = map.getCountryToSideTbl()
    foreach (ag in this.getArmyGroups()) {
      let country = this.getArmyGroupCountry(ag)
      let side = getTblValue(country, countryToSide, SIDE_NONE)
      if (side == SIDE_NONE)
        continue

      if (!(side in res))
        res[side] <- []
      ::u.appendOnce(country, res[side])
    }
    return res
  }

  function canJoinByCountry(country) {
    foreach (ag in this.getArmyGroups())
      if (this.getArmyGroupCountry(ag) == country)
        return true
    return false
  }

  function isLastPlayed() {
    return this.id == ::g_world_war.lastPlayedOperationId
  }

  function getPriority() {
    local res = 0
    let availableByMyClan = this.canJoinByMyClan()
    if (availableByMyClan)
      res = res | WW_OPERATION_PRIORITY.CAN_JOIN_BY_MY_CLAN
    if (this.getMyAssignCountry() && (availableByMyClan || !this.getMyClanGroup()))
      res = res | WW_OPERATION_PRIORITY.CAN_JOIN_BY_ARMY_RELATIONS

    return res
  }

  getCluster = @() this.data?.cluster ?? ""
  setFinishedStatus = @(isFinish) this.isFinished = isFinish
}
