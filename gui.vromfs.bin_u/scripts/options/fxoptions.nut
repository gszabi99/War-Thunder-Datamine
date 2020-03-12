const LOCAL_PATH_SHOWED_HDR_ON_START = "isShowedHdrSettingsOnStart"

class ::gui_handlers.fxOptions extends ::BaseGuiHandler
{
  sceneTplName = "gui/options/fxOptions"
  headerText = "#mainmenu/btnHdrSettings"

  LOCAL_PATH_SHOWED_ON_START = null

  /* settings format
    {
      id = "a", min = 1, max = 2, step = 1, scale = 1
      recScale = true, in case of need to recalculate, decrease spinner value before saving
    }
  */

  settings = null

  focusArray = ["options_list"]

  function getSceneTplView()
  {
    local view = {
      headerText = headerText
      rows = []
    }

    foreach (idx, s in settings)
    {
      s.min *= s.scale
      s.max *= s.scale
      local val = ::getroottable()?["get_{id}".subst(s)]()
      if (s?.recScale)
        val *= s.scale

      view.rows.append({
        id = "{id}".subst(s)
        option = ::create_option_slider(s.id, val.tointeger(), "onSettingChanged", true, "slider", s)
        leftInfoRows = [{
          label = "#options/{id}".subst(s)
          leftInfoWidth = "0.45pw"
        }]
      })
    }

    return view
  }

  function initScreen()
  {
    ::enableHangarControls(true)
    ::enable_menu_gradient(false)

    foreach (s in settings)
      onSettingChanged(scene.findObject(s.id))

    restoreFocus()
  }

  function onSettingChanged(obj)
  {
    if (!::check_obj(obj))
      return

    local curSetting = settings.findvalue(@(s) s.id == obj.id)
    if (!curSetting)
      return

    local val = obj.getValue().tofloat()
    if (curSetting?.recScale)
      val /= curSetting.scale

    updateSliderTextValue(obj.id, val)
    ::getroottable()?["set_{id}".subst(curSetting)](val, true)
  }

  function onResetToDefaults()
  {
    foreach (s in settings)
    {
      local defVal = ::getroottable()?["get_default_"  + s.id]()
      ::getroottable()?["set_" + s.id](defVal, true)
      updateSliderTextValue(s.id, defVal)
      if (s?.recScale)
        defVal *= s.scale

      defVal = defVal.tointeger()
      updateSliderValue(s.id, defVal)
    }
  }

  function updateSliderValue(name, value)
  {
    local valueObj = scene.findObject(name)
    if (::check_obj(valueObj))
      valueObj.setValue(value)
  }

  function updateSliderTextValue(name, value)
  {
    local valueObj = scene.findObject("value_" + name)
    if (::check_obj(valueObj))
      valueObj.setValue(value.tostring())
  }

  function goBack()
  {
    ::save_profile(false)
    ::enable_menu_gradient(true)
    if (LOCAL_PATH_SHOWED_ON_START != null)
      ::saveLocalByAccount(LOCAL_PATH_SHOWED_ON_START, true)
    base.goBack()
  }
}

return {
  openHdrSettings = @() ::handlersManager.loadHandler(::gui_handlers.fxOptions, {
    LOCAL_PATH_SHOWED_ON_START = LOCAL_PATH_SHOWED_HDR_ON_START
    settings = [
      {id = "paper_white_nits", min = 1, max = 10 step = 5, scale = 50}, //50 - 500
      {id = "hdr_brightness", min = 0.5, max = 2, step = 1, scale = 10, recScale = true} //0.5 - 2
  ]})
  needShowHdrSettingsOnStart = @() ::is_hdr_enabled() && !::loadLocalByAccount(LOCAL_PATH_SHOWED_HDR_ON_START, false)
}