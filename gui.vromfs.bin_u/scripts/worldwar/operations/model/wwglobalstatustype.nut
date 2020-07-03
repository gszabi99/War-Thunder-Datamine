local enums = require("sqStdlibs/helpers/enums.nut")
local seenWWMapsAvailable = require("scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)
local { refreshGlobalStatusData,
  getValidGlobalStatusListMask,
  setValidGlobalStatusListMask,
  getGlobalStatusData
} = require("scripts/worldWar/operations/model/wwGlobalStatus.nut")
local {
  refreshShortGlobalStatusData,
  getValidShortGlobalStatusListMask,
  setValidShortGlobalStatusListMask,
  getShortGlobalStatusData
} = require("scripts/worldWar/operations/model/wwShortGlobalStatus.nut")

const MAPS_OUT_OF_DATE_DAYS = 1

::g_ww_global_status_type <- {
  types = []
}

::g_ww_global_status_type.template <- {
  type = 0 //WW_GLOBAL_STATUS_TYPE
  charDataId = null //data id on request "cln_ww_global_stats"
  invalidateByOtherStatusType = 0 //mask of WW_GLOBAL_STATUS_TYPE
  emptyCharData = []
  isAvailableInShortStatus = false

  cachedList = null
  cachedShortStatusList = null
  getList = function(filterFunc = null)
  {
    refreshGlobalStatusData()
    local validListsMask = getValidGlobalStatusListMask()
    if (!cachedList || !(validListsMask & type))
    {
      loadList()
      setValidGlobalStatusListMask(validListsMask | type)
    }
    if (filterFunc)
      return ::u.filter(cachedList, filterFunc)
    return cachedList
  }

  getShortStatusList = function(filterFunc = null)
  {
    refreshShortGlobalStatusData()
    local validListsMask = getValidShortGlobalStatusListMask()
    if (!cachedShortStatusList || !(validListsMask & type))
    {
      loadList(true)
      setValidShortGlobalStatusListMask(validListsMask | type)
    }
    if (filterFunc)
      return ::u.filter(cachedShortStatusList, filterFunc)
    return cachedShortStatusList
  }

  getData = function(globalStatusData = null, needShortStatus = false)
  {
    if (charDataId == null)
      return null
    local curData = globalStatusData ?? (needShortStatus
      ? getShortGlobalStatusData()
      : getGlobalStatusData())
    return curData?[charDataId] ?? emptyCharData
  }

  loadList = function(needShortStatus = false)
  {
    setCachedList(getData(null, needShortStatus), needShortStatus)
  }

  setCachedList = function(cache, isShortStatus) {
    if (isShortStatus)
      cachedShortStatusList = cache
    else
      cachedList = cache
  }
}

enums.addTypesByGlobalName("g_ww_global_status_type", {
  QUEUE = {
    type = WW_GLOBAL_STATUS_TYPE.QUEUE
    charDataId = "queue"
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.MAPS

    emptyCharData = {}

    loadList = function(needShortStatus = false)
    {
      local cacheList = {}
      local data = getData(null, needShortStatus)
      if (!::u.isTable(data)) {
        setCachedList(cacheList, needShortStatus)
        return
      }

      local mapsList = ::g_ww_global_status_type.MAPS.getList()
      foreach(mapId, map in mapsList)
        cacheList[mapId] <-::WwQueue(map, ::getTblValue(mapId, data))

      setCachedList(cacheList, needShortStatus)
    }
  }

  ACTIVE_OPERATIONS = {
    type = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
    charDataId = "activeOperations"
    isAvailableInShortStatus = true

    loadList = function(needShortStatus = false)
    {
      local cacheList = []
      local data = getData(null, needShortStatus)
      if (!::u.isArray(data)) {
        setCachedList(cacheList, needShortStatus)
        return
      }

      foreach(opData in data)
      {
        local operation = ::WwOperation(opData, needShortStatus)
        if (operation.isValid())
          cacheList.append(operation)
      }

      setCachedList(cacheList, needShortStatus)
    }
  }

  MAPS = {
    type = WW_GLOBAL_STATUS_TYPE.MAPS
    charDataId = "maps"
    emptyCharData = {}
    isAvailableInShortStatus = true

    loadList = function(needShortStatus = false)
    {
      local cacheList = {}
      local data = getData(null, needShortStatus)
      if (!::u.isTable(data) || (data.len() <= 0)) {
        setCachedList(cacheList, needShortStatus)
        return
      }

      foreach(name, mapData in data)
        cacheList[name] <-::WwMap(name, mapData, needShortStatus)

      setCachedList(cacheList, needShortStatus)
      local guiScene = ::get_cur_gui_scene()
      if (!needShortStatus)
        return
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

    loadList = function(needShortStatus = false)
    {
      local mapsList = ::g_ww_global_status_type.MAPS.getList()
      setCachedList(::u.map(mapsList, @(map) ::WwOperationsGroup(map.name)), needShortStatus)
    }
  }
})

seenWWMapsAvailable.setListGetter(function() {
  return ::u.map(
    ::g_ww_global_status_type.MAPS.getShortStatusList().filter(@(map) map.isAnnounceAndNotDebug()),
    @(map) map.name)
})