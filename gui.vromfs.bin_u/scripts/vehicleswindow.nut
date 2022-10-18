let { isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")

::gui_handlers.VehiclesWindow <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL

  // Session lobby info or event object.
  teamDataByTeamName = null
  roomSpecialRules = null

  function initScreen()
  {
    let view = {
      headerText = ::loc("lobby/vehicles")
      showOkButton = true
    }
    let data = ::handyman.renderCached("%gui/vehiclesWindow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)

    foreach (team in ::events.getSidesList())
    {
      let teamName = ::events.getTeamName(team)
      let teamObj = scene.findObject(teamName)
      if(!::checkObj(teamObj))
        continue
      let teamData = ::getTblValue(teamName, teamDataByTeamName, null)
      if (!::events.isTeamDataPlayable(teamData))
        continue

      let unitTypes = ::events.getUnitTypesByTeamDataAndName(teamData, teamName)
      ::events.fillAirsList(this, teamObj, teamData, unitTypes, roomSpecialRules)
    }
  }
}

::update_vehicle_info_button <- function update_vehicle_info_button(scene, room)
{
  ::showBtn("vehicles_info_button_block",
    !isSlotbarOverrided(::SessionLobby.getMissionName(true, room))
      && !::events.isEventAllUnitAllowed(::SessionLobby.getPublicData(room)),
    scene
  )
}
