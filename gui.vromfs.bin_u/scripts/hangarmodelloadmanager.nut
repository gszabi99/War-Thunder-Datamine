from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

enum HangarModelLoadState
{
  LOADING
  LOADED
}

let isLoading = persist("isLoading", @() Watched(false))

let hangarUnitName = Watched(::hangar_get_current_unit_name())

let function getLoadState() {
  // First check covers case when model was loaded from within C++.
  // Flag "isLoading" covers model loading from Squirrel.
  return ::hangar_get_loaded_unit_name() == "" || isLoading.value
    ? HangarModelLoadState.LOADING
    : HangarModelLoadState.LOADED
}

let function loadModel(modelName) {
  if (modelName == "" || modelName == ::hangar_get_current_unit_name())
    return
  isLoading(true)
  ::hangar_load_model(modelName)
  ::broadcastEvent("HangarModelLoading", { modelName })
}

let function onHangarModelLoaded() {
  let modelName = ::hangar_get_current_unit_name()
  if (::hangar_get_loaded_unit_name() == modelName) {
    isLoading(false)
    hangarUnitName(modelName)
    ::broadcastEvent("HangarModelLoaded", { modelName })
  }
}

/** This method is called from within C++. */
::on_hangar_model_loaded <- @() onHangarModelLoaded()

return {
  loadModel
  hasLoadedModel = @() getLoadState() == HangarModelLoadState.LOADED
  hangarUnitName
}