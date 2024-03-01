from "%scripts/dagui_library.nut" import *
let MRoomInfo = require("%scripts/matchingRooms/mRoomInfo.nut")

let infoByRoomId = {}

function clearOutdated() {
  let outdatedArr = []
  foreach (roomId, info in infoByRoomId)
    if (!info.isValid())
      outdatedArr.append(roomId)

  foreach (roomId in outdatedArr)
    infoByRoomId.$rawdelete(roomId)
}

function getMroomInfo(roomId) {
  clearOutdated()
  local info = getTblValue(roomId, infoByRoomId)
  if (info)
    return info

  info = MRoomInfo(roomId)
  infoByRoomId[roomId] <- info
  return info
}

return {
  getMroomInfo
}