::g_mroom_info <- {
  infoByRoomId = {}
}

g_mroom_info.get <- function get(roomId)
{
  clearOutdated()
  local info = ::getTblValue(roomId, infoByRoomId)
  if (info)
    return info

  info = ::MRoomInfo(roomId)
  infoByRoomId[roomId] <- info
  return info
}

g_mroom_info.clearOutdated <- function clearOutdated()
{
  foreach(roomId, info in infoByRoomId)
    if (!info.isValid())
      delete infoByRoomId[roomId]
}