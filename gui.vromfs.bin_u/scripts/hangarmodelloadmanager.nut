global enum HangarModelLoadState
{
  LOADING
  LOADED
}

/**
 * This class incapsulates hangar model loading.
 */
::HangarModelLoadManager <- class
{
  _isLoading = false

  constructor()
  {
    ::g_script_reloader.registerPersistentData("HangarModelLoadManager", this, ["_isLoading"])
  }

  function getLoadState()
  {
    // First check covers case when model was loaded from within C++.
    // Flag "_isLoading" covers model loading from Squirrel.
    return ::hangar_get_loaded_unit_name() == "" || _isLoading
      ? HangarModelLoadState.LOADING
      : HangarModelLoadState.LOADED
  }

  function loadModel(modelName)
  {
    if (modelName == ::hangar_get_current_unit_name())
      return
    _isLoading = true
    hangar_load_model(modelName)
    ::broadcastEvent("HangarModelLoading")
  }

  function _onHangarModelLoaded()
  {
    if (::hangar_get_loaded_unit_name() == ::hangar_get_current_unit_name()) {
      _isLoading = false
      ::broadcastEvent("HangarModelLoaded")
    }
  }
}

::hangar_model_load_manager <- HangarModelLoadManager()

/** This method is called from within C++. */
::on_hangar_model_loaded <- function on_hangar_model_loaded()
{
  ::hangar_model_load_manager._onHangarModelLoaded()
}
