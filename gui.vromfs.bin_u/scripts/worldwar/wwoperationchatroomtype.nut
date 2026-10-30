from "%scripts/chat/chatRoomType.nut" import addChatRoomType
from "%scripts/user/matchingFeature.nut" import hasMenuWWOperationChats
from "%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut" import getOperationById
from "%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut" import getCustomViewCountryData
from "worldwar" import wwGetOperationId
from "%scripts/dagui_library.nut" import *

let { wwRoomsTypeData } = require("%scripts/chat/chatRoomType.nut")
let { roomPrefix, getOperationId, getOperationSide checkRoomId } = wwRoomsTypeData

let getRoomName = function(roomId, _isColored = false) {
  let operationId = getOperationId(roomId)
  let opNumberStr = $"{loc("mainmenu/operationsMap")} {loc("ui/number_sign")}{operationId}"
  let operation = getOperationById(operationId)
  if (operation == null)
    return opNumberStr

  let country = operation.getCountryBySide(getOperationSide(roomId))
  if (country == null)
    return opNumberStr

  let countryData = getCustomViewCountryData(country, operation.getMapId())
  return $"{opNumberStr} ({loc(countryData.locId)})"
}

addChatRoomType({
  WW_OPERATION = {
    roomPrefix
    isErrorPopupAllowed = false
    needShowMessagePopup = false
    needCountAsImportant = true
    isHaveOwner = false
    leaveLocId = "worldwar/leaveChannel"
    getOperationId
    getOperationSide
    getTooltip = @(roomId) getRoomName(roomId)
    isVisible = @() hasMenuWWOperationChats.get()
    canBeClosed = @(roomId) getOperationId(roomId) != wwGetOperationId()
    getRoomName
    errorLocPostfix = { ["401"] = "/wwoperation" }
    checkRoomId
  }
})
