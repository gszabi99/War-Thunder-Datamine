from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "eventbus" import eventbus_subscribe
from "hangar" import hangar_load_model, hangar_get_current_unit_name, hangar_get_loaded_unit_name, hangar_is_model_loaded, hangar_is_squad_loaded, set_master_unit_name
from "%scripts/dagui_library.nut" import *

enum HangarModelLoadState {
  LOADING
  LOADED
}

let isLoading = mkWatched(persist, "isLoading", false)

let hangarUnitName = Watched(hangar_get_current_unit_name())

function getLoadState() {
  
  
  return hangar_get_loaded_unit_name() == "" || isLoading.get() || !hangar_is_model_loaded()
    ? HangarModelLoadState.LOADING
    : HangarModelLoadState.LOADED
}

function loadFirearm(weaponName) {
  if (weaponName == hangar_get_current_unit_name() && hangar_is_squad_loaded())
    return
  isLoading.set(true)
  hangar_load_model(weaponName, false, true)
  broadcastEvent("HangarModelLoading", { modelName = weaponName })
}

function loadModel(modelName) {
  if (modelName == "" || (modelName == hangar_get_current_unit_name() && !hangar_is_squad_loaded()))
    return
  isLoading.set(true)
  let unit = getAircraftByName(modelName)
  let hasSlaves = unit?.slaveUnits
  let masterUnitName = hasSlaves ? modelName : unit?.masterUnit ?? ""
  set_master_unit_name(masterUnitName)
  hangar_load_model(modelName, isUnitSpecial(unit) || unit.marketplaceItemdefId, false)
  broadcastEvent("HangarModelLoading", { modelName })
}

function onHangarModelLoaded() {
  let modelName = hangar_get_current_unit_name()
  if (hangar_get_loaded_unit_name() == modelName) {
    isLoading.set(false)
    hangarUnitName.set(modelName)
    broadcastEvent("HangarModelLoaded", { modelName })
  }
}

eventbus_subscribe("onHangarModelLoaded", @(_) onHangarModelLoaded())

return {
  loadModel
  loadFirearm
  hasLoadedModel = @() getLoadState() == HangarModelLoadState.LOADED
  hangarUnitName
}