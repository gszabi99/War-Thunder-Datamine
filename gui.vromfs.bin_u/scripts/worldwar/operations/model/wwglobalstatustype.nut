from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
let { dynamic_content } = require("%sqstd/analyzer.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let {
  refreshGlobalStatusData,
  getValidGlobalStatusListMask,
  setValidGlobalStatusListMask,
  getGlobalStatusData,
  updateCurData,
  pushStatusChangedEvent,
} = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")

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

return { wwStatusType = dynamic_content(wwStatusType) }