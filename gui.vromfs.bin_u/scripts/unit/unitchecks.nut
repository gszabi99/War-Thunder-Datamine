from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/unit/unitStatus.nut" import canResearchUnit, canBuyNotResearched, isUnitsEraUnlocked, isUnitUsable, isUnitGroup
from "%scripts/unit/unitShopInfo.nut" import isUnitGift
from "%scripts/unit/unitInfoTexts.nut" import getCantBuyUnitReason
from "%scripts/unit/unitInfo.nut" import getUnitExp
from "%scripts/unit/unitActions.nut" import buyUnit, CheckFeatureLockAction, checkFeatureLock, showCantBuyOrResearchUnitMsgbox
from "%scripts/gameModes/gameModeMesasge.nut" import showNotAvailableMsgBox
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/weaponry/weaponryInfo.nut" import getLastWeapon
from "%scripts/weaponry/modificationInfo.nut" import getModificationByName
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "dagor.time" import get_time_msec
from "hangar" import hangar_get_current_unit_name, force_retrace_decorators, hangar_force_reload_model
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import clan_get_exp, remove_calculate_modification_effect_jobs
from "%scripts/unit/unitCalcRequests.nut" import calculateShipParameters, calculateTankParameters, calculateMinAndMaxParameters, calculateModOrWeaponEffect
from "%scripts/clans/clanState.nut" import is_in_clan

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

      let button = [["#mainmenu/btnFindSquadron", @() loadHandler(get_gui_handler("ClansModalHandler"))]]
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
    calculateShipParameters(air.name, function(effect) {
      air.modificatorsRequestTime = -1
      if (effect && effect.len() > 0) {
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
    calculateTankParameters(air.name, function(effect) {
      air.modificatorsRequestTime = -1
      if (effect && effect.len() > 0) {
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
  calculateMinAndMaxParameters(air.name, function(effect) {
    air.modificatorsRequestTime = -1
    if (effect && effect.len() > 0) {
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

    calculateModOrWeaponEffect(unit.name, weaponName, false, function(effect) {
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
    const torpedoMod = "torpedoes_movement_mode"
    let mod = getModificationByName(unit, torpedoMod)
    if (!mod || mod?.effects)
      return true
    calculateModOrWeaponEffect(unit.name, torpedoMod, true, function(effect) {
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
      ? unit.getModifications()
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

return freeze({
  checkForResearch
  checkUnitModsUpdate
  checkSecondaryWeaponModsRecount
  updateUnitAfterSwitchMod
})
