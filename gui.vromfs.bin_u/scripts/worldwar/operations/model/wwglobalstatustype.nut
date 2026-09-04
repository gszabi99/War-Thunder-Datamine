import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/enums.nut" import enumsAddTypes
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { refreshGlobalStatusData, getValidGlobalStatusListMask, setValidGlobalStatusListMask, getGlobalStatusData, updateCurData, pushStatusChangedEvent } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")




let loadListImpls = {}

let wwStatusType = {
  types = []
  template = {
    typeMask = 0 
    charDataId = null 
    invalidateByOtherStatusType = 0 
    emptyCharData = []
    cachedList = null

    getList = function(filterFunc = null) {
      refreshGlobalStatusData()
      let validListsMask = getValidGlobalStatusListMask()
      if (!this.cachedList || !(validListsMask & this.typeMask)) {
        let impl = loadListImpls?[this.typeName]
        assert(impl != null, @() $"wwStatusType.{this.typeName}: no loadList registered")
        impl.call(this)
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

  }

}


enumsAddTypes(wwStatusType, {
  MAPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.MAPS
    charDataId = "maps"
    emptyCharData = {}
  }
  ACTIVE_OPERATIONS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
    charDataId = "activeOperations"
  }
  OPERATIONS_GROUPS = {
    typeMask = WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS | WW_GLOBAL_STATUS_TYPE.MAPS
  }
  QUEUE = {
    typeMask = WW_GLOBAL_STATUS_TYPE.QUEUE
    charDataId = "queue"
    invalidateByOtherStatusType = WW_GLOBAL_STATUS_TYPE.MAPS
    emptyCharData = {}
  }
}, null, "typeName")




function setStatusTypeLoadList(typeName:string, loadList:function) {
  assert(typeName in wwStatusType && typeName not in loadListImpls)
  loadListImpls[typeName] <- loadList
}

function onGlobalStatusReceived(newData) {
  local changedListsMask = 0
  foreach (gsType in wwStatusType.types)
    if (!u.isEqual(gsType.getData(getGlobalStatusData()), gsType.getData(newData)))
      changedListsMask = changedListsMask | gsType.typeMask

  if (!changedListsMask)
    return

  foreach (gsType in wwStatusType.types)
    if (gsType.invalidateByOtherStatusType & changedListsMask)
      changedListsMask = changedListsMask | gsType.typeMask

  updateCurData(newData)
  setValidGlobalStatusListMask(getValidGlobalStatusListMask() & ~changedListsMask)
  pushStatusChangedEvent(changedListsMask)
}

addListenersWithoutEnv({
  WWRawGlobalStatusReceived = @(p) onGlobalStatusReceived(p.data)
  function MyClanIdChanged(_p) {
    foreach (op in wwStatusType.ACTIVE_OPERATIONS.getList())
      op.resetCache()
    foreach (q in wwStatusType.QUEUE.getList())
      q.resetCache()
    pushStatusChangedEvent(WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS
      | WW_GLOBAL_STATUS_TYPE.OPERATIONS_GROUPS
      | WW_GLOBAL_STATUS_TYPE.MAPS
      | WW_GLOBAL_STATUS_TYPE.QUEUE)
  }
})

return { wwStatusType, setStatusTypeLoadList }