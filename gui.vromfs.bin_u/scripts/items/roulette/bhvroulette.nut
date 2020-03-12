local rouletteAnim = ::require("rouletteAnim.nut")

local BhvRoulette = class
{
  eventMask    = ::EV_ON_CMD | ::EV_TIMER
  valuePID     = ::dagui_propid.add_name_id("value")

  function onAttach(obj)
  {
    if (obj?.value)
    {
      try { setValue(obj, obj.value) }
      catch(e) { ::script_net_assert_once("bad bhvRoulette value", "BhvRoulette: bad value on attach: '" + obj.value + "'") }
    }
    return ::RETCODE_NOTHING
  }

  function onDetach(obj)
  {
    ::stop_gui_sound("roulette_spin")
    return ::RETCODE_NOTHING
  }

  function setValue(obj, value)
  {
    local config = rouletteAnim.calcAnimConfig(obj, value, obj.getUserData())
    if (!config)
      return

    obj.setUserData(config)
    if (!config.isJustStarted)
      return

    ::play_gui_sound("roulette_start")
    ::start_gui_sound("roulette_spin")
    obj.left = "0"
  }

  function onTimer(obj, dt)
  {
    local config = obj.getUserData()
    if (!config)
      return

    local prevTime = config.time
    config.time += dt
    obj.left = (config.animFunc(config.time) + 0.5).tointeger()

    if (prevTime <= config.timeToStopSound && config.time > config.timeToStopSound)
    {
      ::stop_gui_sound("roulette_spin")
      ::play_gui_sound("roulette_stop")
    }
  }
}

::replace_script_gui_behaviour("bhvRoulette", BhvRoulette)

return {}