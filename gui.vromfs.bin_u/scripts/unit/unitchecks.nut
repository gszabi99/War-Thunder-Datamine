from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import clan_get_exp, remove_calculate_modification_effect_jobs, calculate_ship_parameters_async, calculate_tank_parameters_async, calculate_min_and_max_parameters, calculate_mod_or_weapon_effect
from "%scripts/clans/clanState.nut" import is_in_clan

let { get_time_msec } = require("dagor.time")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { canResearchUnit, canBuyNotResearched, isUnitsEraUnlocked, isUnitUsable,
  isUnitGroup } = require("%scripts/unit/unitStatus.nut")
let { isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { getCantBuyUnitReason } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitExp } = require("%scripts/unit/unitInfo.nut")
let { buyUnit, CheckFeatureLockAction, checkFeatureLock, showCantBuyOrResearchUnitMsgbox } = require("%scripts/unit/unitActions.nut")
let { showNotAvailableMsgBox } = require("%scripts/gameModes/gameModeMesasge.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { hangar_get_current_unit_name, force_retrace_decorators,
  hangar_force_reload_model } = require("hangar")


const MODIFICATORS_REQUEST_TIMEOUT_MSEC = 20000

function afterUpdateAirModificators(unit, callback) {
  if (unit.secondaryWeaponMods)
    unit.secondaryWeaponMods = null 
  broadcastEvent("UnitModsRecount", { unit = unit })
  if (callback != null)
    callback()
}

function checkForResearch(unit) {
  
  if (!checkFeatureLock(unit, CheckFeatureLockAction.RESEARCH))
    return false

  let isSquadronVehicle = unit.isSquadronVehicle()
  if (canResearchUnit(unit) && !isSquadronVehicle)
    return true

  if (!isUnitSpecial(unit) && !isUnitGift(unit)
    && !isSquadronVehicle && !isUnitsEraUnlocked(unit)) {
    showInfoMsgBox(getCantBuyUnitReason(unit), "need_unlock_rank")
    return false
  }

  if (isSquadronVehicle) {
    if (min(clan_get_exp(), unit.reqExp - getUnitExp(unit)) <= 0
      && (!hasFeature("ClanVehicles") || !is_in_clan())) {
      if (!hasFeature("ClanVehicles")) {
        showNotAvailableMsgBox()
        return false
      }

      let button = [["#mainmenu/btnFindSquadron", @() loadHandler(gui_handlers.ClansModalHandler)]]
      local defButton = "#mainmenu/btnFindSquadron"
      let msg = [loc("mainmenu/needJoinSquadronForResearch")]

      let canBuyNotResearchedUnit = canBuyNotResearched(unit)
      let priceText = unit.getOpenCost().getTextAccordingToBalance()
      if (canBuyNotResearchedUnit) {
        button.append(["purchase", @() buyUnit(unit, true)])
        defButton = "purchase"
        msg.append("\n")
        msg.append(loc("mainmenu/canOpenVehicle", { price = priceText }))
      }
      button.append(["cancel", function() {}])

      scene_msg_box("cant_research_squadron_vehicle", null, "\n".join(msg, true),
        button, defButton)

      return false
    }
    else
      return true
  }

  return showCantBuyOrResearchUnitMsgbox(unit)
}


function checkUnitModsUpdate(air, callBack = null, forceUpdate = false, needMinMaxEffectsForAllUnitTypes = false) {
  if (!air.isInited) {
    script_net_assert_once("not inited unit request", "try to call checkUnitModsUpdate for not inited unit")
    return false
  }

  if (air.modificatorsRequestTime > 0
    && air.modificatorsRequestTime + MODIFICATORS_REQUEST_TIMEOUT_MSEC > get_time_msec()) {
    if (forceUpdate)
      remove_calculate_modification_effect_jobs()
    else
      return false
  }
  else if (!forceUpdate && air.modificators)
    return true

  if (air.isShipOrBoat()) {
    air.modificatorsRequestTime = get_time_msec()
    calculate_ship_parameters_async(air.name, this,  function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect) {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }

        if (needMinMaxEffectsForAllUnitTypes) {
          air.minChars = effect.min
          air.maxChars = effect.max
        }

        if (!air.modificatorsBase)
          air.modificatorsBase = air.modificators
      }

      afterUpdateAirModificators(air, callBack)
    })
    return false
  }

  if (air.isTank()) {
    air.modificatorsRequestTime = get_time_msec()
    calculate_tank_parameters_async(air.name, this,  function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect) {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }

        if (needMinMaxEffectsForAllUnitTypes) {
          air.minChars = effect.min
          air.maxChars = effect.max
        }

        if (!air.modificatorsBase) 
          air.modificatorsBase = air.modificators
      }
      afterUpdateAirModificators(air, callBack)
    })
    return false
  }

  if (air.isHuman()) {
    return true
  }

  air.modificatorsRequestTime = get_time_msec()
  calculate_min_and_max_parameters(air.name, this,  function(effect, ...) {
    air.modificatorsRequestTime = -1
    if (effect) {
      air.modificators = {
        arcade = effect.arcade
        historical = effect.historical
        fullreal = effect.fullreal
      }
      air.minChars = effect.min
      air.maxChars = effect.max

      if (isUnitSpecial(air) && !isUnitUsable(air))
        air.modificators = effect.max
    }
    afterUpdateAirModificators(air, callBack)
  })
  return false
}


function checkSecondaryWeaponModsRecount(unit, callback = null) {
  let uType = getEsUnitType(unit)
  if (uType == ES_UNIT_TYPE_AIRCRAFT || uType == ES_UNIT_TYPE_HELICOPTER) {
    let weaponName = getLastWeapon(unit.name)
    local secondaryMods = unit.secondaryWeaponMods
    if (secondaryMods && secondaryMods.weaponName == weaponName) {
      if (secondaryMods.effect)
        return true
      if (callback)
        secondaryMods.callback = callback
      return false
    }

    unit.secondaryWeaponMods = {
      weaponName = weaponName
      effect = null
      callback = callback
    }

    calculate_mod_or_weapon_effect(unit.name, weaponName, false, this, function(effect, ...) {
      secondaryMods = unit.secondaryWeaponMods
      if (!secondaryMods || weaponName != secondaryMods.weaponName)
        return

      secondaryMods.effect <- effect ?? {}
      broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
      if (secondaryMods.callback != null) {
        secondaryMods.callback()
        secondaryMods.callback = null
      }
    })
    return false
  }

  if (uType == ES_UNIT_TYPE_BOAT || uType == ES_UNIT_TYPE_SHIP) {
    let torpedoMod = "torpedoes_movement_mode"
    let mod = getModificationByName(unit, torpedoMod)
    if (!mod || mod?.effects)
      return true
    calculate_mod_or_weapon_effect(unit.name, torpedoMod, true, this, function(effect, ...) {
      mod.effects <- effect
      if (callback)
        callback()
      broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
    })
    return false
  }
  return true
}



function updateUnitAfterSwitchMod(unit, modName = null) {
  if (!unit)
    return

  if (unit.name == hangar_get_current_unit_name() && modName) {
    let modsList = modName == ""
      ? unit.modifications
      : [ getModificationByName(unit, modName) ]
    foreach (mod in modsList) {
      if (!(mod?.requiresModelReload ?? false))
        continue

      hangar_force_reload_model()
      force_retrace_decorators()
      break
    }
  }

  if (!isUnitGroup(unit))
    checkUnitModsUpdate(unit, null, true)

}

return {
  checkForResearch
  checkUnitModsUpdate
  checkSecondaryWeaponModsRecount
  updateUnitAfterSwitchMod
}
