from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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
    if (!this.cachedList || !(validListsMask & this.typeMask))
    {
      this.loadList()
      setValidGlobalStatusListMask(validListsMask | this.typeMask)
    }
    if (filterFunc)
      return ::u.filter(this.cachedList, filterFunc)
    return this.cachedList
  }

  getData = function(globalStatusData = null)
  {
    if (this.charDataId == null)
      return null
    return (globalStatusData ?? getGlobalStatusData())?[this.charDataId] ?? this.emptyCharData
  }

  loadList = @() this.cachedList = this.getData()

  getShortStatusList = function(filterFunc = null)
  {
    refreshShortGlobalStatusData()
    let validListsMask = getValidShortGlobalStatusListMask()
    if (!this.cachedShortStatusList || !(validListsMask & this.typeMask))
    {
      this.loadShortList()
      setValidShortGlobalStatusListMask(validListsMask | this.typeMask)
    }
    if (filterFunc)
      return ::u.filter(this.cachedShortStatusList, filterFunc)
    return this.cachedShortStatusList
  }

  getShortData = function(globalStatusData = null) {
    if (this.charDataId == null)
      return null
    return (globalStatusData ?? getShortGlobalStatusData())?[this.charDataId] ?? this.emptyCharData
  }

  loadShortList = @() this.cachedShortStatusList = this.getShortData()
}

enums.addTypesByGlobalName("g_ww_global_status_type", {
  QUEUE = {
    typeMask = WW_GLOBAL_STATUS_TYPE.QUEUE
    charDataId = "queue"
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.MAPS

    emptyCharData = {}

    loadList = function() {
      this.cachedList = {}
      let data = this.getData()
      if (!::u.isTable(data))
        return

      let mapsList = ::g_ww_global_status_type.MAPS.getList()
      foreach(mapId, map in mapsList)
        this.cachedList[mapId] <-::WwQueue(map, getTblValue(mapId, data))
    }
  }

  ACTIVE_OPERATIONS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
    charDataId = "activeOperations"
    isAvailableInShortStatus = true

    loadList = function() {
      this.cachedList = []
      let data = this.getData()
      if (!::u.isArray(data))
        return

      foreach(opData in data) {
        let operation = ::WwOperation(opData)
        if (operation.isValid())
          this.cachedList.append(operation)
      }
    }

    loadShortList = function() {
      this.cachedShortStatusList = []
      let data = this.getShortData()
      if (!::u.isArray(data))
        return

      foreach(opData in data) {
        let operation = ::WwOperation(opData, true)
        if (operation.isValid())
          this.cachedShortStatusList.append(operation)
      }
    }
  }

  MAPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.MAPS
    charDataId = "maps"
    emptyCharData = {}
    isAvailableInShortStatus = true

    loadList = function() {
      this.cachedList = {}
      let data = this.getData()
      if (!::u.isTable(data) || (data.len() <= 0))
        return

      foreach(name, mapData in data)
        this.cachedList[name] <-::WwMap(name, mapData)
    }

    loadShortList = function() {
      this.cachedShortStatusList = {}
      let data = this.getShortData()
      if (!::u.isTable(data) || (data.len() <= 0))
        return

      foreach(name, mapData in data)
        this.cachedShortStatusList[name] <-::WwMap(name, mapData)

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
      this.cachedList = ::u.map(mapsList, @(map) ::WwOperationsGroup(map.name))
    }
  }
})

seenWWMapsAvailable.setListGetter(function() {
  return ::u.map(
    ::g_ww_global_status_type.MAPS.getShortStatusList().filter(@(map) map.isAnnounceAndNotDebug()),
    @(map) map.name)
})