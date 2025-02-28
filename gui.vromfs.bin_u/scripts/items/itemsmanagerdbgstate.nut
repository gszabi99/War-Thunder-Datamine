from "%scripts/dagui_library.nut" import *

local dbgTrophiesListInternal = []
local dbgUpdateInternalItemsCount = 0

let incDbgUpdateInternalItemsCount = @() ++dbgUpdateInternalItemsCount

let getInternalItemsDebugInfo = @() {
  dbgTrophiesListInternal
  dbgLoadedTrophiesCount = dbgTrophiesListInternal.len()
  dbgUpdateInternalItemsCount
}

return {
  dbgTrophiesListInternal
  incDbgUpdateInternalItemsCount
  getInternalItemsDebugInfo
}