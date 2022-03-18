let { markObjShortcutOnHover } = require("%sqDagui/guiBhv/guiBhvUtils.nut")

/*
work same as OptionsNavigator focus N child in current child
but have 2 axis navigation as posNavigator by real size and positions of self childs
*/

::gui_bhv.PosOptionsNavigator <- class extends ::gui_bhv.posNavigator
{
  bhvId = "PosOptionsNavigator"
  canChooseByMClick = false

  function onAttach(obj)
  {
    markObjShortcutOnHover(obj, true)
    return ::RETCODE_NOTHING
  }

  function onDetach(obj) {
    markObjShortcutOnHover(obj, false)
    return ::RETCODE_NOTHING
  }

  setChildSelected = @(obj, childObj, isSelected = true) null
  onShortcutSelect = @(obj, is_down) ::RETCODE_NOTHING

  function eachSelectable(obj, handler) {
    local idx = 0
    for(local i = 0; i < obj.childrenCount(); i++)
    {
      let rowObj = obj.getChild(i)
      if (!rowObj.isValid())
        continue
      if (isInteractiveObj(rowObj)) {
        if (rowObj.isVisible() || rowObj.isEnabled())
          if (handler(rowObj, idx))
            return
        idx++
        continue
      }
      for(local j = 0; j < rowObj.childrenCount(); j++)
      {
        let cellObj = rowObj.getChild(j)
        if (isInteractiveObj(cellObj)) {
          if (cellObj.isEnabled() && cellObj.isVisible())
            if (handler(cellObj, idx))
              return
          idx++
          continue
        }

        for(local k = 0; k < cellObj.childrenCount(); k++)
        {
          let elem = cellObj.getChild(k)
          if (isInteractiveObj(elem)) {
            if (elem.isEnabled() && elem.isVisible())
              if (handler(elem, idx))
                return
            idx++
            continue
          }
        }
      }
    }
  }

  function setValue(obj, value)
  {
    if (type(value) != "integer")
      return
    local child = null
    eachSelectable(obj, function(elem, idx) {
      if (idx < value)
        return false
      child = elem
      return true
    })
    if (child)
      hoverMove(obj, child)
  }

  isOnlyHover = @(obj) true
  isInteractiveObj = @(obj) obj.getFinalProp("interactive") == "yes"
}
