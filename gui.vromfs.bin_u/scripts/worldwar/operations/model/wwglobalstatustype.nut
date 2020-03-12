local enums = ::require("sqStdlibs/helpers/enums.nut")
local seenWWMapsAvailable = ::require("scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)

const MAPS_OUT_OF_DATE_DAYS = 1

::g_ww_global_status_type <- {
  types = []
}

::g_ww_global_status_type.template <- {
  type = 0 //WW_GLOBAL_STATUS_TYPE
  charDataId = null //data id on request "cln_ww_global_stats"
  invalidateByOtherStatusType = 0 //mask of WW_GLOBAL_STATUS_TYPE
  emptyCharData = []

  cachedList = null
  getList = function(filterFunc = null)
  {
    ::g_ww_global_status.refreshData()
    if (!cachedList || !(::g_ww_global_status.validListsMask & type))
    {
      loadList()
      ::g_ww_global_status.validListsMask = ::g_ww_global_status.validListsMask | type
    }
    if (filterFunc)
      return ::u.filter(cachedList, filterFunc)
    return cachedList
  }

  getData = function(globalStatusData = null)
  {
    return !charDataId || ::getTblValue(charDataId, globalStatusData || ::g_ww_global_status.curData, emptyCharData)
  }

  loadList = function()
  {
    cachedList = getData()
  }
}

enums.addTypesByGlobalName("g_ww_global_status_type", {
  QUEUE = {
    type = WW_GLOBAL_STATUS_TYPE.QUEUE
    charDataId = "queue"
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.MAPS

    emptyCharData = {}

    loadList = function()
    {
      cachedList = {}
      local data = getData()
      if (!::u.isTable(data))
        return

      local mapsList = ::g_ww_global_status_type.MAPS.getList()
      foreach(mapId, map in mapsList)
        cachedList[mapId] <-::WwQueue(map, ::getTblValue(mapId, data))
    }
  }

  ACTIVE_OPERATIONS = {
    type = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
    charDataId = "activeOperations"

    loadList = function()
    {
      cachedList = []
      local data = getData()
      if (!::u.isArray(data))
        return

      foreach(opData in data)
      {
        local operation = ::WwOperation(opData)
        if (operation.isValid())
          cachedList.append(operation)
      }
    }
  }

  MAPS = {
    type = WW_GLOBAL_STATUS_TYPE.MAPS
    charDataId = "maps"
    emptyCharData = {}

    loadList = function()
    {
      cachedList = {}
      local data = getData()
      if (!::u.isTable(data) || (data.len() <= 0))
        return

      foreach(name, mapData in data)
        cachedList[name] <-::WwMap(name, mapData)

      local guiScene = ::get_cur_gui_scene()
      if (guiScene) //need all other configs invalidate too before push event
        guiScene.performDelayed(this,
          function() {
            seenWWMapsAvailable.setDaysToUnseen(MAPS_OUT_OF_DATE_DAYS)
            seenWWMapsAvailable.onListChanged()
          })
    }
  }

  OPERATIONS_GROUPS ={
    type = WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS | WW_GLOBAL_STATUS_TYPE.MAPS

    loadList = function()
    {
      local mapsList = ::g_ww_global_status_type.MAPS.getList()
      cachedList = ::u.map(mapsList, function(map) { return ::WwOperationsGroup(map.name) })
    }
  }
})

seenWWMapsAvailable.setListGetter(function() {
  return ::u.map(
    ::g_ww_global_status_type.MAPS.getList().filter(@(map) map.isAnnounceAndNotDebug()),
    @(map) map.name)
})