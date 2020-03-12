local transportManager = require("scripts/worldWar/inOperation/wwTransportManager.nut")

local function setActionMode(modeId = ::AUT_None) {
  ::ww_set_curr_action_type(modeId)
  ::ww_event("ArmyStatusChanged")
}

local function useTransportAction(clickPos, requestActionCb) {
  local loadArmyName = ::ww_find_army_name_by_coordinates(clickPos.x, clickPos.y) ?? ""
  local cellIdx = ::ww_get_map_cell_by_coords(clickPos.x, clickPos.y)
  foreach (armyName in ::ww_get_selected_armies_names())
    if (::g_world_war.getArmyByName(armyName).isTransport())
      requestActionCb(armyName, loadArmyName, cellIdx)
}

local actionModesById = {
  [::AUT_ArtilleryFire] = {
    startArtilleryFire = function startArtilleryFire(mapPos, army) {
      local blk = ::DataBlock()
      blk.setStr("army", army.name)
      blk.setStr("point", $"{mapPos.x},{mapPos.y}")
      blk.setStr("radius", ww_artillery_get_attack_radius().tostring())

      local taskId = ::ww_send_operation_request("cln_ww_artillery_strike", blk)
      ::g_tasker.addTask(taskId, null, @() setActionMode(),
        ::Callback(function (errorCode) {
          ::g_world_war.popupCharErrorMsg("cant_fire", getTitle())
        }, this))
    }
    makeArtilleryFire = function makeArtilleryFire(mapPos, army) {
      if (army.canFire())
        startArtilleryFire(mapPos, army)
      else
        ::g_popups.add(getTitle(), ::loc("worldwar/artillery/notReadyToFire"),
          null, null, null, "cant_fire")
    }
    useAction = function useAction(clickPos) {
      local mapPos = ::ww_convert_map_to_world_position(clickPos.x, clickPos.y)
      local selectedArmies = ::ww_get_selected_armies_names()
      for (local i = 0; i < selectedArmies.len(); i++)
      {
        local army = ::g_world_war.getArmyByName(selectedArmies[i])
        if (army.hasArtilleryAbility)
          makeArtilleryFire(mapPos, army)
      }
    }
    setMode = @() setActionMode(::AUT_ArtilleryFire)
    getTitle = @() ::loc("worldwar/artillery/cant_fire")
    onMouseWheel = function onMouseWheel(is_up) {
      local attackRadius = ::ww_artillery_get_attack_radius() + (is_up ? 0.5 : -0.5)
      ::ww_artillery_set_attack_radius(attackRadius)
    }
  },
  [::AUT_TransportLoad] = {
    requestAction = function requestAction(transportName, armyName, cellIdx) {
      local errorId = ::ww_get_load_army_to_transport_error(transportName, armyName)
      if (errorId != "")
      {
        ::g_world_war.popupCharErrorMsg("load_transport_army_error", "", errorId)
        return
      }

      local params = ::DataBlock()
      params.setStr("transportName", transportName)
      params.setStr("armyName", armyName)
      local taskId = ::ww_send_operation_request("cln_ww_load_transport", params)
      ::g_tasker.addTask(taskId, null, @() setActionMode())
    }
    useAction = @(clickPos) useTransportAction(clickPos, requestAction)
    setMode = @() setActionMode(::AUT_TransportLoad)
    getTitle = @() ::loc("worldwar/cant_use_transport")
  },
  [::AUT_TransportUnload] = {
    requestAction = function requestAction(transportName, armyName, cellIdx) {
      local errorId = ::ww_get_unload_army_from_transport_error(transportName, armyName, cellIdx)
      if (errorId != "")
      {
        ::g_world_war.popupCharErrorMsg("unload_transport_army_error", "", errorId)
        return
      }

      local params = ::DataBlock()
      params.setStr("transportName", transportName)
      params.setStr("armyName", armyName)
      params.setInt("cellIdx", cellIdx)
      local taskId = ::ww_send_operation_request("cln_ww_unload_transport", params)
      ::g_tasker.addTask(taskId, null, @() setActionMode())
    }
    requestActionForAllLoadedArmy = function requestActionForAllLoadedArmy(transportName, armyName, cellIdx) {
      local loadedTransportArmy = transportManager.getLoadedTransport()?[transportName]
      if (loadedTransportArmy != null)
      {
        local armiesBlk =  loadedTransportArmy.armies
        for(local i = 0; i < armiesBlk.blockCount(); i++)
          requestAction(transportName, armiesBlk.getBlock(i).getBlockName(), cellIdx)
      }
    }
    useAction = @(clickPos) useTransportAction(clickPos, requestActionForAllLoadedArmy)
    setMode = @() setActionMode(::AUT_TransportUnload)
    getTitle = @() ::loc("worldwar/cant_use_transport")
  }
}

local getCurActionModeId = @() ::ww_get_curr_action_type()
local getCurActionMode = @() actionModesById?[getCurActionModeId()]

local function trySetActionModeOrCancel(modeId) {
  if (getCurActionModeId() == modeId)
  {
    setActionMode()
    return
  }

  local armiesNames = ::ww_get_selected_armies_names()
  if (!armiesNames.len())
    return

  if (armiesNames.len() > 1)
    return ::g_popups.add(actionModesById?[modeId].getTitle() ?? "",
      ::loc("worldwar/artillery/selectOneArmy"), null, null, null, "select_one_army")

  setActionMode(modeId)
}

return {
  setActionMode = setActionMode
  trySetActionModeOrCancel = trySetActionModeOrCancel
  getCurActionModeId = getCurActionModeId
  getCurActionMode = getCurActionMode
}