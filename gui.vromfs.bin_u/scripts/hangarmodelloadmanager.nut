from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { hangar_load_model, hangar_get_current_unit_name, hangar_get_loaded_unit_name, hangar_is_model_loaded,




} = require("hangar")

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












function loadModel(modelName) {
  if (modelName == "" || (modelName == hangar_get_current_unit_name()




))
    return
  isLoading.set(true)
  hangar_load_model(modelName, false)
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




  hasLoadedModel = @() getLoadState() == HangarModelLoadState.LOADED
  hangarUnitName
}