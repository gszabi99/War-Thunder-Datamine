local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")

const GLOBAL_BATTLES_REFRESH_MIN_TIME = 1000 //ms
const GLOBAL_BATTLES_REQUEST_TIME_OUT = 45000 //ms
const GLOBAL_BATTLES_LIST_TIME_OUT = 300000 //ms


local GlobalBattlesList = class
{
  list = []
  lastUpdateTimeMsec = -GLOBAL_BATTLES_LIST_TIME_OUT
  lastRequestTimeMsec = -GLOBAL_BATTLES_REQUEST_TIME_OUT
  isInUpdate = false

  /* ********************************************************************************
     ******************************* PUBLIC FUNCTIONS *******************************
     ******************************************************************************** */

  function isNewest()
  {
    return (!isInUpdate &&
            ::dagor.getCurTime() - lastUpdateTimeMsec < GLOBAL_BATTLES_REFRESH_MIN_TIME)
  }

  function canRequestByTime()
  {
    local checkTime = isInUpdate
      ? GLOBAL_BATTLES_REQUEST_TIME_OUT
      : GLOBAL_BATTLES_REFRESH_MIN_TIME
    return  ::dagor.getCurTime() - lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !isNewest() && canRequestByTime()
  }

  function isListValid()
  {
    return (::dagor.getCurTime() - lastUpdateTimeMsec < GLOBAL_BATTLES_LIST_TIME_OUT)
  }

  function validateList()
  {
    if (!isListValid())
      list.clear()
  }

  function getList()
  {
    validateList()
    requestList()

    return list
  }

  function requestList()
  {
    if (!canRequest())
      return false

    isInUpdate = true
    lastRequestTimeMsec = ::dagor.getCurTime()

    local cb = ::Callback(requestListCb, this)
    local errorCb = ::Callback(requestError, this)

    ::g_tasker.charRequestJson("cln_ww_get_active_battles", ::DataBlock(), null, cb, errorCb)
    return true
  }

  /* ********************************************************************************
     ******************************* PRIVATE FUNCTIONS ******************************
     ******************************************************************************** */

  function requestListCb(data)
  {
    isInUpdate = false
    lastUpdateTimeMsec = ::dagor.getCurTime()

    updateGlobalBattlesList(data)
    ::ww_event("UpdateGlobalBattles")
  }

  function requestError(taskResult)
  {
    isInUpdate = false
  }

  function updateGlobalBattlesList(data)
  {
    list.clear()
    foreach (operationId, operation in data)
    {
      local countries = {}
      if ("countries" in operation)
        foreach (countryData in operation.countries)
          if ("side" in countryData && "country" in countryData)
            countries[countryData.side] <- countryData.country

      if ("battles" in operation)
        foreach (battle in operation.battles)
        {
          local wwBattle = WwGlobalBattle(::DataBlockAdapter(battle), {countries = countries})
          wwBattle.setOperationId(operationId.tointeger())
          list.append(wwBattle)
        }
    }
  }
}

return GlobalBattlesList()
