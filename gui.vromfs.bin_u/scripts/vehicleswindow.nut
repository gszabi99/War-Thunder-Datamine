from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { events } = require("%scripts/events/eventsManager.nut")
let { getSessionLobbyPublicData } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getSessionLobbyMissionName } = require("%scripts/missions/missionsUtilsModule.nut")

let VehiclesWindow = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL

  
  teamDataByTeamName = null
  roomSpecialRules = null

  function initScreen() {
    let view = {
      headerText = loc("lobby/vehicles")
      showOkButton = true
    }
    let data = handyman.renderCached("%gui/vehiclesWindow.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)

    foreach (team in events.getSidesList()) {
      let teamName = events.getTeamName(team)
      let teamObj = this.scene.findObject(teamName)
      if (!checkObj(teamObj))
        continue
      let teamData = this.teamDataByTeamName?[teamName]
      if (!events.isTeamDataPlayable(teamData))
        continue

      let unitTypes = events.getUnitTypesByTeamDataAndName(teamData, teamName)
      events.fillAirsList(this, teamObj, teamData, unitTypes, this.roomSpecialRules)
    }
  }
}
register_gui_handler("VehiclesWindow", VehiclesWindow)

function updateVehicleInfoButton(scene, room) {
  showObjById("vehicles_info_button_block",
    !isSlotbarOverrided(getSessionLobbyMissionName(true, room))
      && !events.isEventAllUnitAllowed(getSessionLobbyPublicData(room)),
    scene
  )
}

return {
  VehiclesWindow
  updateVehicleInfoButton
}