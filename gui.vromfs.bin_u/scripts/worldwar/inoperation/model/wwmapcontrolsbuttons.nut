local enums = require("sqStdlibs/helpers/enums.nut")
local transportManager = require("scripts/worldWar/inOperation/wwTransportManager.nut")
local actionModesManager = require("scripts/worldWar/inOperation/wwActionModesManager.nut")

global enum WW_MAP_CONSPLE_SHORTCUTS
{
  LMB_IMITATION = "RT"
  MOVE = "A"
  ENTRENCH = "RB"
  STOP = "Y"
  PREPARE_FIRE = "LB"
  TRANSPORT_LOAD = "LT"
  TRANSPORT_UNLOAD = "R3"
}

enum ORDER
{
  ENTRENCH
  PREPARE_FIRE
  TRANSPORT_LOAD
  TRANSPORT_UNLOAD
  MOVE
  STOP
}

::g_ww_map_controls_buttons <- {
  types = []
  cache = {}
  selectedObjectCode = mapObjectSelect.NONE
}

::g_ww_map_controls_buttons.template <- {
  funcName = null
  sortOrder = -1
  shortcut = null
  keyboardShortcut = ""
  getActionName = @() ""
  getKeyboardShortcut = @() ::show_console_buttons
    ? ""
    : ::loc("ui/parentheses/space", { text = keyboardShortcut})
  text = @() $"{getActionName()}{getKeyboardShortcut()}"
  isHidden = @() true
  isEnabled = @() !::g_world_war.isCurrentOperationFinished()
}

enums.addTypesByGlobalName("g_ww_map_controls_buttons",
{
  MOVE = {
    id = "army_move_button"
    funcName = "onArmyMove"
    sortOrder = ORDER.MOVE
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.MOVE
    text = function () {
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.AIRFIELD)
        return ::loc("worldWar/armyFlyOut")
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.REINFORCEMENT)
        return ::loc("worldWar/armyDeploy")

      return ::loc("worldWar/armyMove")
    }
    isHidden = @() !::show_console_buttons
  }
  ENTRENCH = {
    id = "army_entrench_button"
    funcName = "onArmyEntrench"
    sortOrder = ORDER.ENTRENCH
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.ENTRENCH
    keyboardShortcut = "E"
    style = "accessKey:'J:RB | E';"
    getActionName = @() ::loc("worldWar/armyEntrench")
    isHidden = function () {
      local armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames)
      {
        local army = ::g_world_war.getArmyByName(armyName)
        local unitType = army.getUnitType()
        if (::g_ww_unit_type.isGround(unitType) ||
            ::g_ww_unit_type.isInfantry(unitType))
          return false
      }

      return true
    }
    isEnabled = function() {
      if (!::g_world_war.isCurrentOperationFinished())
        foreach (army in ::g_world_war.getSelectedArmies())
          if (!army.isEntrenched())
            return true

      return false
    }
  }

  STOP = {
    id = "army_stop_button"
    funcName = "onArmyStop"
    sortOrder = ORDER.STOP
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.STOP
    keyboardShortcut = "S"
    style = "accessKey:'J:Y | S';"
    getActionName = @() ::loc("worldWar/armyStop")
    isHidden = @() ::ww_get_selected_armies_names().len() == 0
  }

  PREPARE_FIRE = {
    id = "army_prepare_fire_button"
    funcName = "onArtilleryArmyPrepareToFire"
    sortOrder = ORDER.PREPARE_FIRE
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.PREPARE_FIRE
    keyboardShortcut = "A"
    style = "accessKey:'J:LB | A';"
    getActionName = @() actionModesManager.getCurActionModeId() == ::AUT_ArtilleryFire
      ? ::loc("worldWar/armyCancel")
      : ::loc("worldWar/armyFire")
    isHidden = function () {
      local armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames)
      {
        local army = ::g_world_war.getArmyByName(armyName)
        if (army.hasArtilleryAbility)
          return false
      }

      return true
    }
  }

  TRANSPORT_LOAD = {
    id = "army_transport_load_button"
    funcName = "onTransportArmyLoad"
    sortOrder = ORDER.TRANSPORT_LOAD
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.TRANSPORT_LOAD
    keyboardShortcut = "T"
    style = "accessKey:'J:LT | T';"
    getActionName = function() {
      if (actionModesManager.getCurActionModeId() == ::AUT_TransportLoad)
        return ::loc("worldWar/armyCancel")

      return ::loc("worldwar/loadArmyToTransport")
    }
    isHidden = function () {
      local armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames)
      {
        local army = ::g_world_war.getArmyByName(armyName)
        if (army.isTransport())
          return false
      }

      return true
    }
    isEnabled = function() {
      if (::g_world_war.isCurrentOperationFinished())
        return false

      local armiesNames = ::ww_get_selected_armies_names()
      foreach (armyName in armiesNames)
        if (!transportManager.isFullLoadedTransport(armyName))
          return true

      return false
    }
  }

  TRANSPORT_UNLOAD = {
    id = "army_transport_unload_button"
    funcName = "onTransportArmyUnload"
    sortOrder = ORDER.TRANSPORT_UNLOAD
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.TRANSPORT_UNLOAD
    keyboardShortcut = "R"
    style = "accessKey:'J:R3 | R';"
    getActionName = function() {
      if (actionModesManager.getCurActionModeId() == ::AUT_TransportUnload)
        return ::loc("worldWar/armyCancel")

      return ::loc("worldwar/unloadArmyFromTransport")
    }
    isHidden = function () {
      local armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames)
      {
        local army = ::g_world_war.getArmyByName(armyName)
        if (army.isTransport())
          return false
      }

      return true
    }
    isEnabled = function() {
      if (::g_world_war.isCurrentOperationFinished())
        return false

      local armiesNames = ::ww_get_selected_armies_names()
      foreach (armyName in armiesNames)
        if (!transportManager.isEmptyTransport(armyName))
          return true

      return false
    }
  }
}, null, "name")

::g_ww_map_controls_buttons.types.sort(@(a,b) a.sortOrder <=> b.sortOrder)

::g_ww_map_controls_buttons.setSelectedObjectCode <- function setSelectedObjectCode(code)
{
  selectedObjectCode = code
}
