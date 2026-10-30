from "%scripts/worldWar/worldWarCfgState.nut" import getLastPlayedOperationId
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById, getNearestMapToBattle
from "%scripts/dagui_library.nut" import *

function getOperationNameTextByIdAndMapName(operationId, mapName = null) {
  local res = "".concat(loc("ui/number_sign"), operationId)
  if (mapName)
    res =  " ".concat(mapName, res)
  return res
}


function getPlayedOperationText(needMapName = true) {
  let operation = getOperationById(getLastPlayedOperationId())
  if (operation != null)
    return operation.getMapText()

  let nearestAvailableMapToBattle = getNearestMapToBattle()
  if (!nearestAvailableMapToBattle)
    return ""

  let name = needMapName ? nearestAvailableMapToBattle.getNameText() : loc("mainmenu/btnWorldwar")
  if (nearestAvailableMapToBattle.isActive())
    return loc("worldwar/operation/isNow", { name = name })

  return loc("worldwar/operation/willBegin", { name = name
    time = nearestAvailableMapToBattle.getChangeStateTimeText() })
}


return freeze({
  getOperationNameTextByIdAndMapName
  getPlayedOperationText
})