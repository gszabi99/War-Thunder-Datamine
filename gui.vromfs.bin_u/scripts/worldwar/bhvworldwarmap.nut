local actionModesManager = require("scripts/worldWar/inOperation/wwActionModesManager.nut")

class ::ww_gui_bhv.worldWarMapControls
{
  eventMask = ::EV_MOUSE_L_BTN | ::EV_MOUSE_EXT_BTN | ::EV_MOUSE_WHEEL | ::EV_PROCESS_SHORTCUTS | ::EV_TIMER | ::EV_MOUSE_MOVE

  selectedObjectPID    = ::dagui_propid.add_name_id("selectedObject")
  airfieldPID    = ::dagui_propid.add_name_id("selectedAirfield")
  selectedArmiesID = "selectedArmies"
  objectsHoverEnabledID = ::dagui_propid.add_name_id("objectsHoverEnabled")

  function onLMouse(obj, mx, my, is_up, bits)
  {
    if (is_up)
      return ::RETCODE_NOTHING

    ::ww_event("ClearSelectFromLogArmy")
    ::ww_clear_outlined_zones()
    local mapPos = ::Point2(mx, my)

    local curActionMode = actionModesManager.getCurActionMode()
    if (curActionMode != null)
    {
      curActionMode.useAction(mapPos)
      return ::RETCODE_PROCESSED
    }

    if (ww_is_append_path_mode_active())
    {
      onMoveCommand(obj, mapPos, true)
      return ::RETCODE_PROCESSED
    }

    local selectedObject = mapObjectSelect.NONE
    if (checkBattle(obj, mapPos))
      selectedObject = mapObjectSelect.BATTLE
    else if (checkArmy(obj, mapPos))
      return ::RETCODE_PROCESSED
    else if (checkAirfield(obj, mapPos))
      return ::RETCODE_PROCESSED
    else if (checkRearZone(obj, mapPos))
      return ::RETCODE_PROCESSED

    setSelectedObject(obj, selectedObject)
    sendMapEvent("ClearSelection")

    return ::RETCODE_PROCESSED
  }

  function onMouseMove(obj, mx, my, bits)
  {
    enableObjectsHover(obj, true)

    return ::RETCODE_PROCESSED
  }

  function isObjectsHoverEnabled(obj)
  {
    return obj.getIntProp(objectsHoverEnabledID, 1) != 0
  }

  function enableObjectsHover(obj, enable)
  {
    obj.setIntProp(objectsHoverEnabledID, enable ? 1 : 0)
  }

  function clearSelectionBySelectedObject(obj, value)
  {
    if (value != mapObjectSelect.ARMY)
      clearSelectedArmies(obj)

    if (value != mapObjectSelect.AIRFIELD)
      clearAirfields(obj)

    if (value != mapObjectSelect.REINFORCEMENT)
      sendMapEvent("ClearSelectionBySelectedObject", {objSelected = value})
  }

  function setSelectedObject(obj, value)
  {
    obj.setIntProp(selectedObjectPID, value)
    clearSelectionBySelectedObject(obj, value)
    clearAllHover()
    enableObjectsHover(obj, false)
  }

  function getSelectedObject(obj)
  {
    return obj.getIntProp(selectedObjectPID, mapObjectSelect.NONE)
  }

  function selectedReinforcement(obj, reinforcementName)
  {
    sendMapEvent("SelectedReinforcement", {name = reinforcementName})
    setSelectedObject(obj, mapObjectSelect.REINFORCEMENT)
    ::ww_event("ArmyStatusChanged")
  }

  function onMoveCommand(obj, clickPos, append)
  {
    if (append && !::ww_can_append_path_point_for_selected_armies())
      return

    local currentSelectedObject = getSelectedObject(obj)
    local armyTargetName = findHoverBattle(clickPos.x, clickPos.y)?.id ?? ::ww_find_army_name_by_coordinates(clickPos.x, clickPos.y)

    if (currentSelectedObject == mapObjectSelect.AIRFIELD)
    {
      local airfieldIdx = ::ww_get_selected_airfield();
      local checkFlewOutArmy = (@(obj, airfieldIdx) function() {
          local army = ::ww_find_last_flew_out_army_name_by_airfield(airfieldIdx)
          if ( army && army != "" )
          {
            selectArmy(obj, army, true)
            setSelectedObject(obj, mapObjectSelect.ARMY)
          }
        })(obj, airfieldIdx)

      local mapCell = ::ww_get_map_cell_by_coords(clickPos.x, clickPos.y)
      if (::ww_is_cell_generally_passable(mapCell))
        ::gui_handlers.WwAirfieldFlyOut.open(
          airfieldIdx, clickPos, armyTargetName, ::Callback(checkFlewOutArmy, this))
      else
        ::g_popups.add("", ::loc("worldwar/charError/MOVE_REJECTED"),
          null, null, null, "send_air_army_error")
    }
    else if (currentSelectedObject == mapObjectSelect.ARMY)
      ::g_world_war.moveSelectedArmes(clickPos.x, clickPos.y, armyTargetName, append)
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, bits)
  {
    if (is_up)
      return ::RETCODE_NOTHING

    if (btn_id != 2)  //right mouse button
      return ::RETCODE_NOTHING

    local curActionMode = actionModesManager.getCurActionMode()
    if (curActionMode != null)
    {
      actionModesManager.setActionMode()
      return ::RETCODE_NOTHING
    }

    //-- rclick ---- (easy to search)
    if (ww_is_append_path_mode_active())
      return ::RETCODE_NOTHING

    ::ww_clear_outlined_zones()
    local mapPos = ::Point2(mx, my)

    sendMapEvent("RequestReinforcement", {cellIdx = ::ww_get_map_cell_by_coords(mapPos.x, mapPos.y)})

    local currentSelectedObject = getSelectedObject(obj)
    if (currentSelectedObject != mapObjectSelect.NONE)
      onMoveCommand(obj, mapPos, false)

    return ::RETCODE_PROCESSED
  }

  function onTimer(obj, dt)
  {
    local params = obj.getUserData() || {}
    local isMapObjHovered = obj.isHovered()
    if (!("isMapHovered" in params))
      params.isMapHovered <- isMapObjHovered

    if (isMapObjHovered)
    {
      if (!params.isMapHovered)
        onMapHover(obj)
    }
    else
    {
      if (params.isMapHovered)
        onMapUnhover(obj)
      return
    }
    params.isMapHovered = true

    local mousePos = ::get_dagui_mouse_cursor_pos_RC()
    local hoverChanged = false

    local hoverEnabled = isObjectsHoverEnabled(obj)

    if (hoverEnabled)
    {
      local hoverBattleId = null
      local hoverBattle = findHoverBattle(mousePos[0], mousePos[1])
      if (hoverBattle)
        hoverBattleId = hoverBattle.id

      local lastSavedBattleName = ::getTblValue("battleName", params)
      if (hoverBattleId != lastSavedBattleName)
      {
        if (!hoverBattleId)
          params.rawdelete("battleName")
        else
          params.battleName <- hoverBattleId

        hoverChanged = true
      }

      local armyName = ::ww_find_army_name_by_coordinates(mousePos[0], mousePos[1])
      local lastSavedArmyName = ::getTblValue("armyName", params)
      if (armyName != lastSavedArmyName)
      {
        if (!armyName)
          params.rawdelete("armyName")
        else
          params.armyName <- armyName

        hoverChanged = true
      }

      local airfieldIndex = ::ww_find_airfield_by_coordinates(mousePos[0], mousePos[1])
      local lastAirfieldIndex = ::getTblValue("airfieldIndex", params)
      if (airfieldIndex != lastAirfieldIndex)
      {
        if (airfieldIndex < 0)
          params.rawdelete("airfieldIndex")
        else
          params.airfieldIndex <- airfieldIndex

        hoverChanged = true
      }
    }

    local zoneIndex = ::ww_get_zone_idx(mousePos[0], mousePos[1])
    local lastZoneIndex = ::getTblValue("zoneIndex", params)
    if (zoneIndex != lastZoneIndex)
    {
      if (zoneIndex < 0)
        params.rawdelete("zoneIndex")
      else
        params.zoneIndex <- zoneIndex

      hoverChanged = true
    }

    if (!hoverChanged)
      return

    updateHoveredObjects(params)

    obj.setUserData(params)
    sendMapEvent("UpdateCursorByTimer", params)
  }

  function onMapHover(obj)
  {
    ::g_world_war_render.setCategory(::ERC_AIRFIELD_ARROW, true)
  }

  function onMapUnhover(obj)
  {
    local params = {isMapHovered = false}
    updateHoveredObjects(params)
    sendMapEvent("UpdateCursorByTimer", params)
    obj.setUserData(params)
    ::g_world_war_render.setCategory(::ERC_AIRFIELD_ARROW, false)
  }

  function onMouseWheel(obj, mx, my, is_up, buttons)
  {
    local curActionMode = actionModesManager.getCurActionMode()
    if (curActionMode?.onMouseWheel != null)
    {
      curActionMode.onMouseWheel(is_up)
      return ::RETCODE_PROCESSED
    }

    ::ww_zoom_map(is_up)
    return ::RETCODE_PROCESSED
  }

  function checkArmy(obj, mapPos)
  {
    local armyList = ::ww_find_army_names_in_point(mapPos.x, mapPos.y)
    if (!armyList.len())
      return false

    local lastClickedArmyName = ""
    local selectedArmies = getSelectedArmiesOnMap(obj)
    if (selectedArmies.len())
      lastClickedArmyName = selectedArmies.top()

    local armyIdx  = armyList.findindex(@(name) name == lastClickedArmyName) ?? -1
    local nextArmyIdx = armyIdx + 1
    local nextArmyName = nextArmyIdx in armyList? armyList[nextArmyIdx] : armyList[0]

    return nextArmyName ? selectArmy(obj, nextArmyName) : false
  }

  function getSelectedArmiesOnMap(obj)
  {
    local selectedArmies = ::getTblValue(selectedArmiesID, obj.getUserData(), "")
    return ::split(selectedArmies, ",")
  }

  function selectArmy(obj, armyName, forceReplace = false, armyType = mapObjectSelect.ARMY)
  {
    if (!::checkObj(obj))
      return

    ::ww_event("SelectLogArmyByName", {name = armyName})

    local selectedArmies = getSelectedArmiesOnMap(obj)
    if (::isInArray(armyName, selectedArmies))
    {
      sendMapEvent("ArmySelected", { armyName = armyName, armyType = armyType })
      return true
    }

    local addToSelection = (!forceReplace) && ::ww_is_add_selected_army_mode_active()
    if (!addToSelection)
    {
      selectedArmies.clear()
    }

    selectedArmies.append(armyName)
    setSelectedArmies(obj, selectedArmies)
    setSelectedObject(obj, mapObjectSelect.ARMY)
    sendMapEvent("ArmySelected", {
      armyName = armyName,
      armyType = armyType,
      addToSelection = addToSelection })
    ::get_cur_gui_scene()?.playSound("ww_unit_select")

    return true
  }

  function setSelectedArmies(obj, selectedArmies)
  {
    local params = obj.getUserData() || {}
    params[selectedArmiesID] <- ::g_string.implode(selectedArmies, ",")
    obj.setUserData(params)
    local selectedArmiesInfo = []
    foreach (armyName in selectedArmies)
    {
      local army = ::g_world_war.getArmyByName(armyName)
      if (army != null)
      {
        local info = {name = armyName, hasAccess=army.hasManageAccess()}
        selectedArmiesInfo.append(info)
      }
    }
    ::ww_update_selected_armies_name(selectedArmiesInfo)
  }

  function clearSelectedArmies(obj)
  {
    setSelectedArmies(obj, [])
  }

  function selectAirfield(obj, params)
  {
    if (!::checkObj(obj))
      return false

    obj.setIntProp(airfieldPID, params.airfieldIdx)
    ::ww_select_airfield(params.airfieldIdx)
    if (params.airfieldIdx >= 0)
    {
      setSelectedObject(obj, mapObjectSelect.AIRFIELD)
      sendMapEvent("AirfieldSelected", params)
      ::get_cur_gui_scene()?.playSound("ww_airfield_select")
    }
    else
      sendMapEvent("AirfieldCleared")
    return true
  }

  function clearAirfields(obj)
  {
    selectAirfield(obj, {airfieldIdx = -1})
  }

  function checkAirfield(obj, mapPos)
  {
    local airfieldIndex = ::ww_find_airfield_by_coordinates(mapPos.x, mapPos.y)
    if (airfieldIndex < 0)
      return false

    return selectAirfield(obj, {airfieldIdx = airfieldIndex})
  }

  function checkBattle(obj, screenPos)
  {
    local battle = findHoverBattle(screenPos.x, screenPos.y)
    if (!battle)
      return false

    setSelectedObject(obj, mapObjectSelect.BATTLE)
    sendMapEvent("SelectedBattle", {battle = battle})

    return true
  }

  function checkRearZone(obj, mapPos)
  {
    local zoneName = ::ww_get_zone_name(::ww_get_zone_idx(mapPos.x, mapPos.y))
    foreach (side in ::g_world_war.getCommonSidesOrder())
      if (::isInArray(zoneName, ::g_world_war.getRearZonesOwnedToSide(side)))
      {
        sendMapEvent("RearZoneSelected", { side = ::ww_side_val_to_name(side) })
        return true
      }
  }

  function getBattleIconRadius()
  {
    return ::ww_get_battle_icon_radius()
  }

  function sendMapEvent(eventName, params = {})
  {
    ::ww_event("Map" + eventName, params)
  }

  function clearAllHover()
  {
    ::ww_update_hover_army_name("")
    ::ww_update_hover_battle_id("")
    ::ww_update_hover_airfield_id(-1)
  }

  function updateHoveredObjects(params)
  {
    local hoveredArmyName = ""
    local hoveredBattleName = ""
    local hoveredAirfieldId = -1
    local hoveredZoneId = -1

    if ("battleName" in params)
    {
      hoveredBattleName = params.battleName;
    }
    else if ("armyName" in params)
    {
      hoveredArmyName = params.armyName;
    }
    else if ("airfieldIndex" in params)
    {
      hoveredAirfieldId = params.airfieldIndex
    }

    if ("zoneIndex" in params)
    {
      hoveredZoneId = params.zoneIndex
    }

    ::ww_update_hover_army_name(hoveredArmyName)
    ::ww_update_hover_battle_id(hoveredBattleName)
    ::ww_update_hover_airfield_id(hoveredAirfieldId)
    ::ww_update_hover_zone_id(hoveredZoneId)
  }

  function findHoverBattle(screenPosX, screenPosY)
  {
    if (!::ww_get_battles_names().len())
      return false

    local mapPos = ::ww_convert_map_to_world_position(screenPosX, screenPosY)
    local battleIconRadSquare = getBattleIconRadius() * getBattleIconRadius()
    local filterFunc = (@(mapPos, battleIconRadSquare) function(battle) {
      local diff = battle.pos - mapPos
      return diff.lengthSq() <= battleIconRadSquare && !battle.isFinished()
    })(mapPos, battleIconRadSquare)
    local battles = ::g_world_war.getBattles(filterFunc)
    local haveAnyBattles = battles.len() > 0

    if (!haveAnyBattles)
      return false

    local sortFunc = (@(mapPos) function(battle1, battle2) {
      local diff1 = battle1.pos - mapPos
      local diff2 = battle2.pos - mapPos

      local l1 = diff1.lengthSq()
      local l2 = diff2.lengthSq()

      if (l1 != l2)
        return l1 > l2 ? 1 : -1

      return 0
    })(mapPos)
    battles.sort(sortFunc)

    return battles[0]
  }
}

::ww_is_append_path_mode_active <- function ww_is_append_path_mode_active()
{
  if (!::g_world_war.haveManagementAccessForSelectedArmies())
    return false

  return ::is_keyboard_btn_down(::DKEY_LSHIFT) || ::is_keyboard_btn_down(::DKEY_RSHIFT)
}

::ww_is_add_selected_army_mode_active <- function ww_is_add_selected_army_mode_active()
{
  return false//::is_keyboard_btn_down(::DKEY_LCONTROL) || ::is_keyboard_btn_down(::DKEY_RCONTROL)
}
