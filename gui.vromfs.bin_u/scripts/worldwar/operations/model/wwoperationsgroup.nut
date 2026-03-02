from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
import "%sqStdLibs/helpers/enums.nut" as enums

let u = require("%sqStdLibs/helpers/u.nut")
let { getMapByName } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { wwStatusType } = require("%scripts/worldWar/operations/model/wwGlobalStatusType.nut")

let WwOperationsGroup = class {
  mapId = ""

  constructor(v_mapId) {
    this.mapId = v_mapId
  }

  function isEqual(opGroup) {
    return opGroup != null && opGroup.mapId == this.mapId
  }

  function getMap() {
    return getMapByName(this.mapId)
  }

  function getNameText() {
    let map = this.getMap()
    return map ? map.getNameText() : ""
  }

  function getDescription() {
    let map = this.getMap()
    return map ? map.getDescription() : ""
  }

  function getGeoCoordsText() {
    local map = this.getMap()
    return map ? map.getGeoCoordsText() : ""
  }

  _operationsList = null
  function getOperationsList() {
    if (!this._operationsList) {
      let mapId = this.mapId
      this._operationsList = wwStatusType.ACTIVE_OPERATIONS
        .getList(@(op) op.getMapId() == mapId)
    }
    return this._operationsList
  }

  




  _countriesByTeams = null
  function getCountriesByTeams() {
    if (this._countriesByTeams)
      return this._countriesByTeams

    this._countriesByTeams = {}
    foreach (op in this.getOperationsList())
      this._countriesByTeams = u.tablesCombine(this._countriesByTeams, op.getCountriesByTeams(),
        function(list1, list2) {
          if (!list1)
            return clone list2
          if (!list2)
            return list1
          foreach (country in list2)
            u.appendOnce(country, list1)
          return list1
        }
      )

    return this._countriesByTeams
  }

  function canJoinByCountry(country) {
    let countriesByTeams = this.getCountriesByTeams()
    foreach (cList in countriesByTeams)
      if (isInArray(country, cList))
        return true
    return false
  }

  hasActiveOperations = @() this.getOperationsList().findvalue(
    @(o) o.isAvailableToJoin()) != null
  hasOperations = @() this.getOperationsList().len() > 0

  function getCantJoinReasonData(country) {
    let res = {
      canJoin = false
      reasonText = ""
    }

    if (!this.canJoinByCountry(country)) {
      res.reasonText = loc("worldWar/chooseAvailableCountry")
      return res
    }

    
    let operation = u.search(this.getOperationsList(),  function(op) { return op.canJoinByCountry(country) })
    if (!operation)
      return res
    return operation.getCantJoinReasonData(country)
  }

  function join(country) {
    let opList = this.getOperationsList().filter( function(op) { return op.canJoinByCountry(country) })
    if (!opList.len()) {
      showInfoMsgBox(this.getCantJoinReasonData(country).reasonText)
      return false
    }

    u.chooseRandom(opList).join(country)
  }

  function isMyClanParticipate() {
    foreach (o in this.getOperationsList())
      if (o.isMyClanParticipate())
        return true
    return false
  }
}

enums.enumsAddTypes(wwStatusType, {
  OPERATIONS_GROUPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS | WW_GLOBAL_STATUS_TYPE.MAPS

    function loadList() {
      let mapsList = wwStatusType.MAPS.getList()
      this.cachedList = mapsList.map(@(map) WwOperationsGroup(map.name))
    }
  }
})

let getOperationGroupByMapId = @(mapId)
  u.search(wwStatusType.OPERATIONS_GROUPS.getList(), @(og) og.mapId == mapId)
    ?? WwOperationsGroup(mapId)

return { getOperationGroupByMapId }
