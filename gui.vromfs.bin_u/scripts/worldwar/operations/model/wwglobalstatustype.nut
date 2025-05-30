from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let u = require("%sqStdLibs/helpers/u.nut")
let { WwMap } = require("%scripts/worldWar/operations/model/wwMap.nut")
let WwQueue = require("%scripts/worldWar/externalServices/wwQueue.nut")

let WwOperation = require("%scripts/worldWar/operations/model/wwOperation.nut")

let enums = require("%sqStdLibs/helpers/enums.nut")
let seenWWMapsAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)
let {
  refreshGlobalStatusData,
  getValidGlobalStatusListMask,
  setValidGlobalStatusListMask,
  getGlobalStatusData
} = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")

const MAPS_OUT_OF_DATE_DAYS = 1

::g_ww_global_status_type <- {
  types = []
}

::g_ww_global_status_type.template <- {
  typeMask = 0 
  charDataId = null 
  invalidateByOtherStatusType = 0 
  emptyCharData = []
  cachedList = null

  getList = function(filterFunc = null) {
    refreshGlobalStatusData()
    let validListsMask = getValidGlobalStatusListMask()
    if (!this.cachedList || !(validListsMask & this.typeMask)) {
      this.loadList()
      setValidGlobalStatusListMask(validListsMask | this.typeMask)
    }
    if (filterFunc)
      return this.cachedList.filter(filterFunc)
    return this.cachedList
  }

  getData = function(globalStatusData = null) {
    if (this.charDataId == null)
      return null
    return (globalStatusData ?? getGlobalStatusData())?[this.charDataId] ?? this.emptyCharData
  }

  loadList = @() this.cachedList = this.getData()
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
      if (!u.isTable(data))
        return

      let mapsList = ::g_ww_global_status_type.MAPS.getList()
      foreach (mapId, map in mapsList)
        this.cachedList[mapId] <- WwQueue(map, getTblValue(mapId, data))
    }
  }

  ACTIVE_OPERATIONS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
    charDataId = "activeOperations"

    loadList = function() {
      this.cachedList = []
      let data = this.getData()
      if (!u.isArray(data))
        return

      foreach (opData in data) {
        let operation = WwOperation(opData)
        if (operation.isValid())
          this.cachedList.append(operation)
      }
    }
  }

  MAPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.MAPS
    charDataId = "maps"
    emptyCharData = {}

    loadList = function() {
      this.cachedList = {}
      let data = this.getData()
      if (!u.isTable(data) || (data.len() <= 0))
        return

      foreach (name, mapData in data)
        this.cachedList[name] <- WwMap(name, mapData)

      let guiScene = get_cur_gui_scene()
      if (guiScene) 
        guiScene.performDelayed(this,
          function() {
            seenWWMapsAvailable.setDaysToUnseen(MAPS_OUT_OF_DATE_DAYS)
            seenWWMapsAvailable.onListChanged()
          })
    }
  }

  OPERATIONS_GROUPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS | WW_GLOBAL_STATUS_TYPE.MAPS

    loadList = function() {
      let mapsList = ::g_ww_global_status_type.MAPS.getList()
      this.cachedList = mapsList.map(@(map) ::WwOperationsGroup(map.name))
    }
  }
})

seenWWMapsAvailable.setListGetter(function() {
  return ::g_ww_global_status_type.MAPS.getList()
    .filter(@(map) map.isAnnounceAndNotDebug())
    .map(@(map) map.name)
})