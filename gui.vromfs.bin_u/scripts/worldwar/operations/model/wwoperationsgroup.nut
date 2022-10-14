from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { getMapByName } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

::WwOperationsGroup <- class
{
  mapId = ""

  constructor(v_mapId)
  {
    mapId = v_mapId
  }

  function isEqual(opGroup)
  {
    return opGroup != null && opGroup.mapId == mapId
  }

  function getMap()
  {
    return getMapByName(mapId)
  }

  function getNameText()
  {
    let map = getMap()
    return map ? map.getNameText() : ""
  }

  function getDescription()
  {
    let map = getMap()
    return map ? map.getDescription() : ""
  }

  function getGeoCoordsText()
  {
    local map = getMap()
    return map ? map.getGeoCoordsText() : ""
  }

  _operationsList = null
  function getOperationsList()
  {
    if (!_operationsList)
      _operationsList = ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList(
                          (@(mapId) function(op) { return op.getMapId() == mapId })(mapId)
                        )
    return _operationsList
  }

  /*
  return {
    [side] = ["country_germany"]
  }
  */
  _countriesByTeams = null
  function getCountriesByTeams()
  {
    if (_countriesByTeams)
      return _countriesByTeams

    _countriesByTeams = {}
    foreach(op in getOperationsList())
      _countriesByTeams = ::u.tablesCombine(_countriesByTeams, op.getCountriesByTeams(),
        function(list1, list2)
        {
          if (!list1)
            return clone list2
          if (!list2)
            return list1
          foreach(country in list2)
            ::u.appendOnce(country, list1)
          return list1
        }
      )

    return _countriesByTeams
  }

  function canJoinByCountry(country)
  {
    let countriesByTeams = getCountriesByTeams()
    foreach(cList in countriesByTeams)
      if (isInArray(country, cList))
        return true
    return false
  }

  hasActiveOperations = @() getOperationsList().findvalue(
    @(o) o.isAvailableToJoin()) != null
  hasOperations = @() getOperationsList().len() > 0

  function getCantJoinReasonData(country)
  {
    let res = {
      canJoin = false
      reasonText = ""
    }

    if (!canJoinByCountry(country))
    {
      res.reasonText = loc("worldWar/chooseAvailableCountry")
      return res
    }

    //find operation which can join by country
    let operation = ::u.search(getOperationsList(), (@(country) function(op) { return op.canJoinByCountry(country) })(country))
    if (!operation)
      return res
    return operation.getCantJoinReasonData(country)
  }

  function join(country)
  {
    let opList = ::u.filter(getOperationsList(), (@(country) function(op) { return op.canJoinByCountry(country) })(country))
    if (!opList.len())
    {
      ::showInfoMsgBox(getCantJoinReasonData(country).reasonText)
      return false
    }

    ::u.chooseRandom(opList).join(country)
  }

  function isMyClanParticipate()
  {
    foreach(o in getOperationsList())
      if (o.isMyClanParticipate())
        return true
    return false
  }
}
