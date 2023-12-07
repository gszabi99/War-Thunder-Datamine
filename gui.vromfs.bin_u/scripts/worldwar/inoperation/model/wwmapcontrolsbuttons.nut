from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let enums = require("%sqStdLibs/helpers/enums.nut")
let transportManager = require("%scripts/worldWar/inOperation/wwTransportManager.nut")
let actionModesManager = require("%scripts/worldWar/inOperation/wwActionModesManager.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")

enum ORDER {
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
  template = {
    funcName = null
    sortOrder = -1
    shortcut = null
    keyboardShortcut = ""
    getActionName = @() ""
    getKeyboardShortcut = @() showConsoleButtons.value
      ? ""
      : loc("ui/parentheses/space", { text = this.keyboardShortcut })
    text = @() $"{this.getActionName()}{this.getKeyboardShortcut()}"
    isHidden = @() true
    isEnabled = @() !::g_world_war.isCurrentOperationFinished()
  }
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
        return loc("worldWar/armyFlyOut")
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.REINFORCEMENT)
        return loc("worldWar/armyDeploy")

      return loc("worldWar/armyMove")
    }
    isHidden = @() !showConsoleButtons.value
  }
  ENTRENCH = {
    id = "army_entrench_button"
    funcName = "onArmyEntrench"
    sortOrder = ORDER.ENTRENCH
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.ENTRENCH
    keyboardShortcut = "E"
    style = $"accessKey:'J:{WW_MAP_CONSPLE_SHORTCUTS.ENTRENCH} | E';"
    getActionName = @() loc("worldWar/armyEntrench")
    isHidden = function () {
      let armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames) {
        let army = ::g_world_war.getArmyByName(armyName)
        let unitType = army.getUnitType()
        if (g_ww_unit_type.isGround(unitType) ||
            g_ww_unit_type.isInfantry(unitType))
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
    style = $"accessKey:'J:{WW_MAP_CONSPLE_SHORTCUTS.STOP} | S';"
    getActionName = @() loc("worldWar/armyStop")
    isHidden = @() ::ww_get_selected_armies_names().len() == 0
  }

  PREPARE_FIRE = {
    id = "army_prepare_fire_button"
    funcName = "onArtilleryArmyPrepareToFire"
    sortOrder = ORDER.PREPARE_FIRE
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.PREPARE_FIRE
    keyboardShortcut = "A"
    style = $"accessKey:'J:{WW_MAP_CONSPLE_SHORTCUTS.PREPARE_FIRE} | A';"
    getActionName = @() actionModesManager.getCurActionModeId() == AUT_ArtilleryFire
      ? loc("worldWar/armyCancel")
      : loc("worldWar/armyFire")
    isHidden = function () {
      let armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames) {
        let army = ::g_world_war.getArmyByName(armyName)
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
    style = $"accessKey:'J:L.Thumb | T';"
    getActionName = function() {
      if (actionModesManager.getCurActionModeId() == AUT_TransportLoad)
        return loc("worldWar/armyCancel")

      return loc("worldwar/loadArmyToTransport")
    }
    isHidden = function () {
      let armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames) {
        let army = ::g_world_war.getArmyByName(armyName)
        if (army.isTransport())
          return false
      }

      return true
    }
    isEnabled = function() {
      if (::g_world_war.isCurrentOperationFinished())
        return false

      let armiesNames = ::ww_get_selected_armies_names()
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
    style = $"accessKey:'J:R.Thumb | R';"
    getActionName = function() {
      if (actionModesManager.getCurActionModeId() == AUT_TransportUnload)
        return loc("worldWar/armyCancel")

      return loc("worldwar/unloadArmyFromTransport")
    }
    isHidden = function () {
      let armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames) {
        let army = ::g_world_war.getArmyByName(armyName)
        if (army.isTransport())
          return false
      }

      return true
    }
    isEnabled = function() {
      if (::g_world_war.isCurrentOperationFinished())
        return false

      let armiesNames = ::ww_get_selected_armies_names()
      foreach (armyName in armiesNames)
        if (!transportManager.isEmptyTransport(armyName))
          return true

      return false
    }
  }
}, null, "name")

::g_ww_map_controls_buttons.types.sort(@(a, b) a.sortOrder <=> b.sortOrder)

::g_ww_map_controls_buttons.setSelectedObjectCode <- function setSelectedObjectCode(code) {
  this.selectedObjectCode = code
}
