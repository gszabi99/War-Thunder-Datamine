local { doesLocTextExist, loc } = require("dagor.localize")

{
  class BhvHint
  {
    eventMask    = ::EV_ON_CMD
    valuePID               = ::dagui_propid.add_name_id("value")
    wrapInRowPID           = ::dagui_propid.add_name_id("isWrapInRowAllowed")

    isUpdateInProgressPID  = ::dagui_propid.add_name_id("_isUpdateInProgress")

    function onAttach(obj)
    {
      if (obj?.value && !obj.getIntProp(isUpdateInProgressPID, 0))
        obj.getScene().performDelayed(this, function()
        {
          if (obj.isValid())
            updateView(obj)
        })
      return ::RETCODE_NOTHING
    }

    function setValue(obj, newValue)
    {
      if (!::u.isString(newValue) || obj?.value == newValue)
        return
      obj.value = newValue
      updateView(obj)
    }

    function updateView(obj)
    {
      if (!("g_hints" in getroottable()))
        return

      obj.setIntProp(isUpdateInProgressPID, 1)

      local params = {
        isWrapInRowAllowed = obj.getFinalProp("isWrapInRowAllowed") == "yes"
        flowAlign = obj.getFinalProp("flow-align") ?? "center"
        showShortcutsNameIfNotAssign = true
      }
      local value = obj?.value ?? ""
      local markup = ::g_hints.buildHintMarkup(doesLocTextExist(value) ? loc(value) : value, params)
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), null)

      obj.setIntProp(isUpdateInProgressPID, 0)
    }
  }

  ::replace_script_gui_behaviour("bhvHint", BhvHint)
}