from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%globalScripts/guiBehaviourConsts.nut" import *
from "%scripts/dagui_natives.nut" import stop_gui_sound, start_gui_sound
from "%scripts/dagui_library.nut" import *

let rouletteAnim = require("%scripts/items/roulette/rouletteAnim.nut")

let BhvRoulette = class {
  eventMask    = EV_ON_CMD | EV_TIMER
  valuePID     = dagui_propid_add_name_id("value")

  function onAttach(obj) {
    if (obj?.value) {
      try { this.setValue(obj, obj.value) }
      catch(e) { script_net_assert_once("bad bhvRoulette value", $"BhvRoulette: bad value on attach: '{obj.value}'") }
    }
    return RETCODE_NOTHING
  }

  function onDetach(_obj) {
    stop_gui_sound("roulette_spin")
    return RETCODE_NOTHING
  }

  function setValue(obj, value) {
    let config = rouletteAnim.calcAnimConfig(obj, value, obj.getUserData())
    if (!config)
      return

    obj.setUserData(config)
    if (!config.isJustStarted)
      return

    obj.getScene().playSound("roulette_start")
    start_gui_sound("roulette_spin")
    obj.left = "0"
  }

  function onTimer(obj, dt) {
    let config = obj.getUserData()
    if (!config)
      return

    let prevTime = config.time
    config.time += dt
    obj.left = (config.animFunc(config.time) + 0.5).tointeger()

    if (prevTime <= config.timeToStopSound && config.time > config.timeToStopSound) {
      stop_gui_sound("roulette_spin")
      obj.getScene().playSound("roulette_stop")
    }
  }
}

replace_script_gui_behaviour("bhvRoulette", BhvRoulette)

return {}