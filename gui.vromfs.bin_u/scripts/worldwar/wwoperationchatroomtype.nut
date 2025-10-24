from "%scripts/dagui_library.nut" import *
let { wwRoomsTypeData, addChatRoomType } = require("%scripts/chat/chatRoomType.nut")
let { hasMenuWWOperationChats } = require("%scripts/user/matchingFeature.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { wwGetOperationId } = require("worldwar")
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

