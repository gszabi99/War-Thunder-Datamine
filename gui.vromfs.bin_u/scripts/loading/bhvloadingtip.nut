{
  let class LoadingTip
  {
    eventMask = ::EV_TIMER | ::EV_ON_CMD
    unitTypeMaskPID = ::dagui_propid.add_name_id("unitTypeMask")
    timerIntervalPID = ::dagui_propid.add_name_id("timer_interval_msec")

    function onAttach(obj)
    {
      obj.set_prop_latent(timerIntervalPID, 1000)

      let unitTypeMask = obj?.unitTypeMask
      if (unitTypeMask)
        setValue(obj, unitTypeMask.tointeger())
      else
        updateTip(obj)

      return ::RETCODE_NOTHING
    }

    function getUnitTypeMask(obj)
    {
      return obj.getIntProp(unitTypeMaskPID, 0)
    }

    function setValue(obj, unitTypeMask) //to set unit type from scripts
    {
      if (!::u.isInteger(unitTypeMask) || unitTypeMask == getUnitTypeMask(obj))
        return
      obj.setIntProp(unitTypeMaskPID, unitTypeMask)
      updateTip(obj)
    }

    function onTimer(obj, dt)
    {
      updateTip(obj)
    }

    function updateTip(obj)
    {
      obj.getScene().performDelayed(this, function()
        {
          if (!obj.isValid())
            return

          let textObj = obj.findObject("tip_hint")
          if (::check_obj(textObj))
            textObj.setValue(::g_tips.getTip(getUnitTypeMask(obj)))
        })
    }
  }

  ::replace_script_gui_behaviour("bhvLoadingTip", LoadingTip)
}