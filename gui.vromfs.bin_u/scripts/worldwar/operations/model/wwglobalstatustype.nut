let enums = require("%sqStdLibs/helpers/enums.nut")
let seenWWMapsAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)
let { refreshGlobalStatusData,
  getValidGlobalStatusListMask,
  setValidGlobalStatusListMask,
  getGlobalStatusData
} = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
local {
  refreshShortGlobalStatusData,
  getValidShortGlobalStatusListMask,
  setValidShortGlobalStatusListMask,
  getShortGlobalStatusData
} = require("%scripts/worldWar/operations/model/wwShortGlobalStatus.nut")

const MAPS_OUT_OF_DATE_DAYS = 1

::g_ww_global_status_type <- {
  types = []
}

::g_ww_global_status_type.template <- {
  typeMask = 0 //WW_GLOBAL_STATUS_TYPE
  charDataId = null //data id on request "cln_ww_global_stats"
  invalidateByOtherStatusType = 0 //mask of WW_GLOBAL_STATUS_TYPE
  emptyCharData = []
  isAvailableInShortStatus = false

  cachedList = null
  cachedShortStatusList = null
  getList = function(filterFunc = null)
  {
    refreshGlobalStatusData()
    let validListsMask = getValidGlobalStatusListMask()
    if (!cachedList || !(validListsMask & typeMask))
    {
      loadList()
      setValidGlobalStatusListMask(validListsMask | typeMask)
    }
    if (filterFunc)
      return ::u.filter(cachedList, filterFunc)
    return cachedList
  }

  getData = function(globalStatusData = null)
  {
    if (charDataId == null)
      return null
    return (globalStatusData ?? getGlobalStatusData())?[charDataId] ?? emptyCharData
  }

  loadList = @() cachedList = getData()

  getShortStatusList = function(filterFunc = null)
  {
    refreshShortGlobalStatusData()
    let validListsMask = getValidShortGlobalStatusListMask()
    if (!cachedShortStatusList || !(validListsMask & typeMask))
    {
      loadShortList()
      setValidShortGlobalStatusListMask(validListsMask | typeMask)
    }
    if (filterFunc)
      return ::u.filter(cachedShortStatusList, filterFunc)
    return cachedShortStatusList
  }

  getShortData = function(globalStatusData = null) {
    if (charDataId == null)
      return null
    return (globalStatusData ?? getShortGlobalStatusData())?[charDataId] ?? emptyCharData
  }

  loadShortList = @() cachedShortStatusList = getShortData()
}

enums.addTypesByGlobalName("g_ww_global_status_type", {
  QUEUE = {
    typeMask = WW_GLOBAL_STATUS_TYPE.QUEUE
    charDataId = "queue"
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.MAPS

    emptyCharData = {}

    loadList = function() {
      cachedList = {}
      let data = getData()
      if (!::u.isTable(data))
        return

      let mapsList = ::g_ww_global_status_type.MAPS.getList()
      foreach(mapId, map in mapsList)
        cachedList[mapId] <-::WwQueue(map, ::getTblValue(mapId, data))
    }
  }

  ACTIVE_OPERATIONS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
    charDataId = "activeOperations"
    isAvailableInShortStatus = true

    loadList = function() {
      cachedList = []
      let data = getData()
      if (!::u.isArray(data))
        return

      foreach(opData in data) {
        let operation = ::WwOperation(opData)
        if (operation.isValid())
          cachedList.append(operation)
      }
    }

    loadShortList = function() {
      cachedShortStatusList = []
      let data = getShortData()
      if (!::u.isArray(data))
        return

      foreach(opData in data) {
        let operation = ::WwOperation(opData, true)
        if (operation.isValid())
          cachedShortStatusList.append(operation)
      }
    }
  }

  MAPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.MAPS
    charDataId = "maps"
    emptyCharData = {}
    isAvailableInShortStatus = true

    loadList = function() {
      cachedList = {}
      let data = getData()
      if (!::u.isTable(data) || (data.len() <= 0))
        return

      foreach(name, mapData in data)
        cachedList[name] <-::WwMap(name, mapData)
    }

    loadShortList = function() {
      cachedShortStatusList = {}
      let data = getShortData()
      if (!::u.isTable(data) || (data.len() <= 0))
        return

      foreach(name, mapData in data)
        cachedShortStatusList[name] <-::WwMap(name, mapData)

      let guiScene = ::get_cur_gui_scene()
      if (guiScene) //need all other configs invalidate too before push event
        guiScene.performDelayed(this,
          function() {
            seenWWMapsAvailable.setDaysToUnseen(MAPS_OUT_OF_DATE_DAYS)
            seenWWMapsAvailable.onListChanged()
          })
    }
  }

  OPERATIONS_GROUPS ={
    typeMask = WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS | WW_GLOBAL_STATUS_TYPE.MAPS

    loadList = function() {
      let mapsList = ::g_ww_global_status_type.MAPS.getList()
      cachedList = ::u.map(mapsList, @(map) ::WwOperationsGroup(map.name))
    }
  }
})

seenWWMapsAvailable.setListGetter(function() {
  return ::u.map(
    ::g_ww_global_status_type.MAPS.getShortStatusList().filter(@(map) map.isAnnounceAndNotDebug()),
    @(map) map.name)
})