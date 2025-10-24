from "%scripts/dagui_library.nut" import *

function getOperationNameTextByIdAndMapName(operationId, mapName = null) {
  local res = "".concat(loc("ui/number_sign"), operationId)
  if (mapName)
    res =  " ".concat(mapName, res)
  return res
}

return {
  getOperationNameTextByIdAndMapName
}