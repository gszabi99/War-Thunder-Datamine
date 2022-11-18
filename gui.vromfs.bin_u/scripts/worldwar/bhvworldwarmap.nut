from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { split_by_chars } = require("string")
let actionModesManager = require("%scripts/worldWar/inOperation/wwActionModesManager.nut")
let { markObjShortcutOnHover } = require("%sqDagui/guiBhv/guiBhvUtils.nut")

::ww_gui_bhv.worldWarMapControls <- class {
  eventMask = EV_MOUSE_L_BTN | EV_MOUSE_EXT_BTN | EV_MOUSE_WHEEL | EV_PROCESS_SHORTCUTS | EV_TIMER | EV_MOUSE_MOVE

  selectedObjectPID    = ::dagui_propid.add_name_id("selectedObject")
  airfieldPID    = ::dagui_propid.add_name_id("selectedAirfield")
  selectedArmiesID = "selectedArmies"
  objectsHoverEnabledID = ::dagui_propid.add_name_id("objectsHoverEnabled")

  function onAttach(obj)
  {
    markObjShortcutOnHover(obj, true)
    return RETCODE_NOTHING
  }

  function selectInteractiveElements(obj, mx, my) {
    ::ww_event("ClearSelectFromLogArmy")
    ::ww_clear_outlined_zones()
    let mapPos = ::Point2(mx, my)

    let curActionMode = actionModesManager.getCurActionMode()
    if (curActionMode != null)
    {
      curActionMode.useAction(mapPos)
      return
    }

    if (::ww_is_append_path_mode_active())
    {
      this.onMoveCommand(obj, mapPos, true)
      return
    }

    local selectedObject = mapObjectSelect.NONE
    if (this.checkBattle(obj, mapPos))
      selectedObject = mapObjectSelect.BATTLE
    else if (this.checkArmy(obj, mapPos))
      return
    else if (this.checkAirfield(obj, mapPos))
      return
    else if (this.checkRearZone(obj, mapPos))
      return

    this.setSelectedObject(obj, selectedObject)
    this.sendMapEvent("ClearSelection")
  }

  function onLMouse(obj, mx, my, is_up, _bits)
  {
    if (is_up)
      return RETCODE_NOTHING

    this.selectInteractiveElements(obj, mx, my)
    return RETCODE_PROCESSED
  }

  function onMouseMove(obj, _mx, _my, _bits)
  {
    this.enableObjectsHover(obj, true)

    return RETCODE_PROCESSED
  }

  function isObjectsHoverEnabled(obj)
  {
    return obj.getIntProp(this.objectsHoverEnabledID, 1) != 0
  }

  function enableObjectsHover(obj, enable)
  {
    obj.setIntProp(this.objectsHoverEnabledID, enable ? 1 : 0)
  }

  function clearSelectionBySelectedObject(obj, value)
  {
    if (value != mapObjectSelect.ARMY)
      this.clearSelectedArmies(obj)

    if (value != mapObjectSelect.AIRFIELD)
      this.clearAirfields(obj)

    if (value != mapObjectSelect.REINFORCEMENT)
      this.sendMapEvent("ClearSelectionBySelectedObject", {objSelected = value})
  }

  function setSelectedObject(obj, value)
  {
    obj.setIntProp(this.selectedObjectPID, value)
    this.clearSelectionBySelectedObject(obj, value)
    this.clearAllHover()
    this.enableObjectsHover(obj, false)
  }

  function getSelectedObject(obj)
  {
    return obj.getIntProp(this.selectedObjectPID, mapObjectSelect.NONE)
  }

  function selectedReinforcement(obj, reinforcementName)
  {
    this.sendMapEvent("SelectedReinforcement", {name = reinforcementName})
    this.setSelectedObject(obj, mapObjectSelect.REINFORCEMENT)
    ::ww_event("ArmyStatusChanged")
  }

  function onMoveCommand(obj, clickPos, append)
  {
    if (append && !::ww_can_append_path_point_for_selected_armies())
      return

    let currentSelectedObject = this.getSelectedObject(obj)
    let armyTargetName = this.findHoverBattle(clickPos.x, clickPos.y)?.id ?? ::ww_find_army_name_by_coordinates(clickPos.x, clickPos.y)

    if (currentSelectedObject == mapObjectSelect.AIRFIELD)
    {
      let airfieldIdx = ::ww_get_selected_airfield();
      let checkFlewOutArmy = (@(obj, airfieldIdx) function() {
          let army = ::ww_find_last_flew_out_army_name_by_airfield(airfieldIdx)
          if ( army && army != "" )
          {
            this.selectArmy(obj, army, true)
            this.setSelectedObject(obj, mapObjectSelect.ARMY)
          }
        })(obj, airfieldIdx)

      let mapCell = ::ww_get_map_cell_by_coords(clickPos.x, clickPos.y)
      if (::ww_is_cell_generally_passable(mapCell))
        ::gui_handlers.WwAirfieldFlyOut.open(
          airfieldIdx, clickPos, armyTargetName, Callback(checkFlewOutArmy, this))
      else
        ::g_popups.add("", loc("worldwar/charError/MOVE_REJECTED"),
          null, null, null, "send_air_army_error")
    }
    else if (currentSelectedObject == mapObjectSelect.ARMY)
      ::g_world_war.moveSelectedArmes(clickPos.x, clickPos.y, armyTargetName, append)
  }

  function onExtMouse(obj, mx, my, btn_id, is_up, _bits)
  {
    if (is_up)
      return RETCODE_NOTHING

    if (btn_id != 2)  //right mouse button
      return RETCODE_NOTHING

    let curActionMode = actionModesManager.getCurActionMode()
    if (curActionMode != null)
    {
      actionModesManager.setActionMode()
      return RETCODE_NOTHING
    }

    //-- rclick ---- (easy to search)
    if (::ww_is_append_path_mode_active())
      return RETCODE_NOTHING

    ::ww_clear_outlined_zones()
    let mapPos = ::Point2(mx, my)

    this.sendMapEvent("RequestReinforcement", {cellIdx = ::ww_get_map_cell_by_coords(mapPos.x, mapPos.y)})

    let currentSelectedObject = this.getSelectedObject(obj)
    if (currentSelectedObject != mapObjectSelect.NONE)
      this.onMoveCommand(obj, mapPos, false)

    return RETCODE_PROCESSED
  }

  function onTimer(obj, _dt)
  {
    let params = obj.getUserData() || {}
    let isMapObjHovered = obj.isHovered()
    if (!("isMapHovered" in params))
      params.isMapHovered <- isMapObjHovered

    if (isMapObjHovered)
    {
      if (!params.isMapHovered)
        this.onMapHover(obj)
    }
    else
    {
      if (params.isMapHovered)
        this.onMapUnhover(obj)
      return
    }
    params.isMapHovered = true

    let mousePos = ::get_dagui_mouse_cursor_pos_RC()
    local hoverChanged = false

    let hoverEnabled = this.isObjectsHoverEnabled(obj)

    if (hoverEnabled)
    {
      local hoverBattleId = null
      let hoverBattle = this.findHoverBattle(mousePos[0], mousePos[1])
      if (hoverBattle)
        hoverBattleId = hoverBattle.id

      let lastSavedBattleName = getTblValue("battleName", params)
      if (hoverBattleId != lastSavedBattleName)
      {
        if (!hoverBattleId)
          params.rawdelete("battleName")
        else
          params.battleName <- hoverBattleId

        hoverChanged = true
      }

      let armyName = ::ww_find_army_name_by_coordinates(mousePos[0], mousePos[1])
      let lastSavedArmyName = getTblValue("armyName", params)
      if (armyName != lastSavedArmyName)
      {
        if (!armyName)
          params.rawdelete("armyName")
        else
          params.armyName <- armyName

        hoverChanged = true
      }

      let airfieldIndex = ::ww_find_airfield_by_coordinates(mousePos[0], mousePos[1])
      let lastAirfieldIndex = getTblValue("airfieldIndex", params)
      if (airfieldIndex != lastAirfieldIndex)
      {
        if (airfieldIndex < 0)
          params.rawdelete("airfieldIndex")
        else
          params.airfieldIndex <- airfieldIndex

        hoverChanged = true
      }
    }

    let zoneIndex = ::ww_get_zone_idx(mousePos[0], mousePos[1])
    let lastZoneIndex = getTblValue("zoneIndex", params)
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

    this.updateHoveredObjects(params)

    obj.setUserData(params)
    this.sendMapEvent("UpdateCursorByTimer", params)
  }

  function onMapHover(_obj)
  {
    ::g_world_war_render.setCategory(ERC_AIRFIELD_ARROW, true)
  }

  function onMapUnhover(obj)
  {
    let params = {isMapHovered = false}
    this.updateHoveredObjects(params)
    this.sendMapEvent("UpdateCursorByTimer", params)
    obj.setUserData(params)
    ::g_world_war_render.setCategory(ERC_AIRFIELD_ARROW, false)
  }

  function onMouseWheel(_obj, _mx, _my, is_up, _buttons)
  {
    let curActionMode = actionModesManager.getCurActionMode()
    if (curActionMode?.onMouseWheel != null)
    {
      curActionMode.onMouseWheel(is_up)
      return RETCODE_PROCESSED
    }

    ::ww_zoom_map(is_up)
    return RETCODE_PROCESSED
  }

  function checkArmy(obj, mapPos)
  {
    let armyList = ::ww_find_army_names_in_point(mapPos.x, mapPos.y)
    if (!armyList.len())
      return false

    local lastClickedArmyName = ""
    let selectedArmies = this.getSelectedArmiesOnMap(obj)
    if (selectedArmies.len())
      lastClickedArmyName = selectedArmies.top()

    let armyIdx  = armyList.findindex(@(name) name == lastClickedArmyName) ?? -1
    let nextArmyIdx = armyIdx + 1
    let nextArmyName = nextArmyIdx in armyList? armyList[nextArmyIdx] : armyList[0]

    return nextArmyName ? this.selectArmy(obj, nextArmyName) : false
  }

  function getSelectedArmiesOnMap(obj)
  {
    let selectedArmies = getTblValue(this.selectedArmiesID, obj.getUserData(), "")
    return split_by_chars(selectedArmies, ",")
  }

  function selectArmy(obj, armyName, forceReplace = false, armyType = mapObjectSelect.ARMY)
  {
    if (!checkObj(obj))
      return

    ::ww_event("SelectLogArmyByName", {name = armyName})

    let selectedArmies = this.getSelectedArmiesOnMap(obj)
    if (isInArray(armyName, selectedArmies))
    {
      this.sendMapEvent("ArmySelected", { armyName = armyName, armyType = armyType })
      return true
    }

    let addToSelection = (!forceReplace) && ::ww_is_add_selected_army_mode_active()
    if (!addToSelection)
    {
      selectedArmies.clear()
    }

    selectedArmies.append(armyName)
    this.setSelectedArmies(obj, selectedArmies)
    this.setSelectedObject(obj, mapObjectSelect.ARMY)
    this.sendMapEvent("ArmySelected", {
      armyName = armyName,
      armyType = armyType,
      addToSelection = addToSelection })
    ::get_cur_gui_scene()?.playSound("ww_unit_select")

    return true
  }

  function setSelectedArmies(obj, selectedArmies)
  {
    let params = obj.getUserData() || {}
    params[this.selectedArmiesID] <- ::g_string.implode(selectedArmies, ",")
    obj.setUserData(params)
    let selectedArmiesInfo = []
    foreach (armyName in selectedArmies)
    {
      let army = ::g_world_war.getArmyByName(armyName)
      if (army != null)
      {
        let info = {name = armyName, hasAccess=army.hasManageAccess()}
        selectedArmiesInfo.append(info)
      }
    }
    ::ww_update_selected_armies_name(selectedArmiesInfo)
  }

  function clearSelectedArmies(obj)
  {
    this.setSelectedArmies(obj, [])
  }

  function selectAirfield(obj, params)
  {
    if (!checkObj(obj))
      return false

    obj.setIntProp(this.airfieldPID, params.airfieldIdx)
    ::ww_select_airfield(params.airfieldIdx)
    if (params.airfieldIdx >= 0)
    {
      this.setSelectedObject(obj, mapObjectSelect.AIRFIELD)
      this.sendMapEvent("AirfieldSelected", params)
      ::get_cur_gui_scene()?.playSound("ww_airfield_select")
    }
    else
      this.sendMapEvent("AirfieldCleared")
    return true
  }

  function clearAirfields(obj)
  {
    this.selectAirfield(obj, {airfieldIdx = -1})
  }

  function checkAirfield(obj, mapPos)
  {
    let airfieldIndex = ::ww_find_airfield_by_coordinates(mapPos.x, mapPos.y)
    if (airfieldIndex < 0)
      return false

    return this.selectAirfield(obj, {airfieldIdx = airfieldIndex})
  }

  function checkBattle(obj, screenPos)
  {
    let battle = this.findHoverBattle(screenPos.x, screenPos.y)
    if (!battle)
      return false

    this.setSelectedObject(obj, mapObjectSelect.BATTLE)
    this.sendMapEvent("SelectedBattle", {battle = battle})

    return true
  }

  function checkRearZone(_obj, mapPos)
  {
    let zoneName = ::ww_get_zone_name(::ww_get_zone_idx(mapPos.x, mapPos.y))
    foreach (side in ::g_world_war.getCommonSidesOrder())
      if (isInArray(zoneName, ::g_world_war.getRearZonesOwnedToSide(side)))
      {
        this.sendMapEvent("RearZoneSelected", { side = ::ww_side_val_to_name(side) })
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

    let mapPos = ::ww_convert_map_to_world_position(screenPosX, screenPosY)
    let battleIconRadSquare = this.getBattleIconRadius() * this.getBattleIconRadius()
    let filterFunc = (@(mapPos, battleIconRadSquare) function(battle) {
      let diff = battle.pos - mapPos
      return diff.lengthSq() <= battleIconRadSquare && !battle.isFinished()
    })(mapPos, battleIconRadSquare)
    let battles = ::g_world_war.getBattles(filterFunc)
    let haveAnyBattles = battles.len() > 0

    if (!haveAnyBattles)
      return false

    let sortFunc = (@(mapPos) function(battle1, battle2) {
      let diff1 = battle1.pos - mapPos
      let diff2 = battle2.pos - mapPos

      let l1 = diff1.lengthSq()
      let l2 = diff2.lengthSq()

      if (l1 != l2)
        return l1 > l2 ? 1 : -1

      return 0
    })(mapPos)
    battles.sort(sortFunc)

    return battles[0]
  }

  function onShortcutActivate(obj, is_down)
  {
    if (is_down)
      return RETCODE_HALT

    let mousePos = ::get_dagui_mouse_cursor_pos_RC()
    this.selectInteractiveElements(obj, mousePos[0], mousePos[1])
    return RETCODE_HALT
  }

  function onShortcutCancel(obj, is_down) {
    if (is_down)
      return RETCODE_HALT

    this.setSelectedObject(obj, mapObjectSelect.NONE)
    this.sendMapEvent("ClearSelection")
    return RETCODE_HALT
  }
}

::ww_is_append_path_mode_active <- function ww_is_append_path_mode_active()
{
  if (!::g_world_war.haveManagementAccessForSelectedArmies())
    return false

  return ::is_keyboard_btn_down(DKEY_LSHIFT) || ::is_keyboard_btn_down(DKEY_RSHIFT)
}

::ww_is_add_selected_army_mode_active <- function ww_is_add_selected_army_mode_active()
{
  return false//::is_keyboard_btn_down(DKEY_LCONTROL) || ::is_keyboard_btn_down(DKEY_RCONTROL)
}
