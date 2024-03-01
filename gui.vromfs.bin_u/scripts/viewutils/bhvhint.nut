from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { doesLocTextExist } = require("dagor.localize")

{
  let class BhvHint {
    eventMask    = EV_ON_CMD
    valuePID               = dagui_propid_add_name_id("value")
    wrapInRowPID           = dagui_propid_add_name_id("isWrapInRowAllowed")

    isUpdateInProgressPID  = dagui_propid_add_name_id("_isUpdateInProgress")

    function onAttach(obj) {
      if (obj?.value && !obj.getIntProp(this.isUpdateInProgressPID, 0))
        obj.getScene().performDelayed(this, function() {
          if (obj.isValid())
            this.updateView(obj)
        })
      return RETCODE_NOTHING
    }

    function setValue(obj, newValue) {
      if (!u.isString(newValue) || obj?.value == newValue)
        return
      obj.value = newValue
      this.updateView(obj)
    }

    function updateView(obj) {
      if (!("g_hints" in getroottable()))
        return

      obj.setIntProp(this.isUpdateInProgressPID, 1)

      let params = {
        isWrapInRowAllowed = obj.getFinalProp("isWrapInRowAllowed") == "yes"
        flowAlign = obj.getFinalProp("flow-align") ?? "center"
        showShortcutsNameIfNotAssign = true
      }
      let value = obj?.value ?? ""
      let markup = ::g_hints.buildHintMarkup(doesLocTextExist(value) ? loc(value) : value, params)
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), null)

      obj.setIntProp(this.isUpdateInProgressPID, 0)
    }
  }

  replace_script_gui_behaviour("bhvHint", BhvHint)
}