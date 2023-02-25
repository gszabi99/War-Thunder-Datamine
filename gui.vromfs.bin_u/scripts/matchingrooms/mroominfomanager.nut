//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

::g_mroom_info <- {
  infoByRoomId = {}

  function get(roomId) {
    this.clearOutdated()
    local info = getTblValue(roomId, this.infoByRoomId)
    if (info)
      return info

    info = ::MRoomInfo(roomId)
    this.infoByRoomId[roomId] <- info
    return info
  }

  function clearOutdated() {
    let outdatedArr = []
    foreach (roomId, info in this.infoByRoomId)
      if (!info.isValid())
        outdatedArr.append(roomId)

    foreach (roomId in outdatedArr)
      delete this.infoByRoomId[roomId]
  }
}