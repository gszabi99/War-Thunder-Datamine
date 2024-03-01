from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { getTip } = require("%scripts/loading/loadingTips.nut")

{
  let class LoadingTip {
    eventMask = EV_TIMER | EV_ON_CMD
    unitTypeMaskPID = dagui_propid_add_name_id("unitTypeMask")
    timerIntervalPID = dagui_propid_add_name_id("timer_interval_msec")

    function onAttach(obj) {
      obj.set_prop_latent(this.timerIntervalPID, 1000)

      let unitTypeMask = obj?.unitTypeMask
      if (unitTypeMask)
        this.setValue(obj, unitTypeMask.tointeger())
      else
        this.updateTip(obj)

      return RETCODE_NOTHING
    }

    function getUnitTypeMask(obj) {
      return obj.getIntProp(this.unitTypeMaskPID, 0)
    }

    function setValue(obj, unitTypeMask) { //to set unit type from scripts
      if (!u.isInteger(unitTypeMask) || unitTypeMask == this.getUnitTypeMask(obj))
        return
      obj.setIntProp(this.unitTypeMaskPID, unitTypeMask)
      this.updateTip(obj)
    }

    function onTimer(obj, _dt) {
      this.updateTip(obj)
    }

    function updateTip(obj) {
      obj.getScene().performDelayed(this, function() {
          if (!obj.isValid())
            return

          let textObj = obj.findObject("tip_hint")
          if (checkObj(textObj))
            textObj.setValue(getTip(this.getUnitTypeMask(obj)))
        })
    }
  }

  replace_script_gui_behaviour("bhvLoadingTip", LoadingTip)
}