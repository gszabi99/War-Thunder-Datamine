from "%scripts/dagui_library.nut" import *
let { addChatRoomType } = require("%scripts/chat/chatRoomType.nut")
let { hasMenuWWOperationChats } = require("%scripts/user/matchingFeature.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { wwGetOperationId } = require("worldwar")

addChatRoomType({
  WW_OPERATION = {
    roomPrefix = "#_ww_"
    isErrorPopupAllowed = false
    needShowMessagePopup = false
    needCountAsImportant = true
    isHaveOwner = false
    leaveLocId = "worldwar/leaveChannel"
    getOperationId = @(roomId) roomId.split("_")[3].tointeger()
    getOperationSide = @(roomId) roomId.split("_")[5].tointeger()
    getTooltip = @(roomId) this.getRoomName(roomId)
    isVisible = @() hasMenuWWOperationChats.value
    canBeClosed = @(roomId) this.getOperationId(roomId) != wwGetOperationId()
    getRoomName = function(roomId, _isColored = false) {
      let operationId = this.getOperationId(roomId)
      let opNumberStr = $"{loc("mainmenu/operationsMap")} {loc("ui/number_sign")}{operationId}"
      let operation = getOperationById(operationId)
      if (operation == null)
        return opNumberStr

      let country = operation.getCountryBySide(this.getOperationSide(roomId))
      if (country == null)
        return opNumberStr

      let countryData = getCustomViewCountryData(country, operation.getMapId())
      return $"{opNumberStr} ({loc(countryData.locId)})"
    }
    checkRoomId = @(roomId) roomId.contains(this.roomPrefix)
    errorLocPostfix = { ["401"] = "/wwoperation" }
  }
})