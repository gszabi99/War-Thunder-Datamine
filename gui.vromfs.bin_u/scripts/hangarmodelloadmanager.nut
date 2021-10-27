enum HangarModelLoadState
{
  LOADING
  LOADED
}

local isLoading = persist("isLoading", @() ::Watched(false))

local hangarUnitName = ::Watched(::hangar_get_current_unit_name())

local function getLoadState() {
  // First check covers case when model was loaded from within C++.
  // Flag "isLoading" covers model loading from Squirrel.
  return ::hangar_get_loaded_unit_name() == "" || isLoading.value
    ? HangarModelLoadState.LOADING
    : HangarModelLoadState.LOADED
}

local function loadModel(modelName) {
  if (modelName == "" || modelName == ::hangar_get_current_unit_name())
    return
  isLoading(true)
  ::hangar_load_model(modelName)
  ::broadcastEvent("HangarModelLoading")
}

local function onHangarModelLoaded() {
  if (::hangar_get_loaded_unit_name() == ::hangar_get_current_unit_name()) {
    isLoading(false)
    hangarUnitName(::hangar_get_current_unit_name())
    ::broadcastEvent("HangarModelLoaded")
  }
}

/** This method is called from within C++. */
::on_hangar_model_loaded <- @() onHangarModelLoaded()

return {
  loadModel
  hasLoadedModel = @() getLoadState() == HangarModelLoadState.LOADED
  hangarUnitName
}