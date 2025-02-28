from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getSessionLobbyPublicData } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getSessionLobbyMissionName } = require("%scripts/missions/missionsUtilsModule.nut")

gui_handlers.VehiclesWindow <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL

  // Session lobby info or event object.
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
      let teamData = getTblValue(teamName, this.teamDataByTeamName, null)
      if (!events.isTeamDataPlayable(teamData))
        continue

      let unitTypes = events.getUnitTypesByTeamDataAndName(teamData, teamName)
      events.fillAirsList(this, teamObj, teamData, unitTypes, this.roomSpecialRules)
    }
  }
}

function updateVehicleInfoButton(scene, room) {
  showObjById("vehicles_info_button_block",
    !isSlotbarOverrided(getSessionLobbyMissionName(true, room))
      && !events.isEventAllUnitAllowed(getSessionLobbyPublicData(room)),
    scene
  )
}

return {
  updateVehicleInfoButton
}