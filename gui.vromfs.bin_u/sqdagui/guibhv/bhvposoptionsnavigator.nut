/*
work same as OptionsNavigator focus N child in current child
but have 2 axis navigation as posNavigator by real size and positions of self childs
*/

class ::gui_bhv.PosOptionsNavigator extends ::gui_bhv.posNavigator
{
  canChooseByMClick = false

  skipFocusPID = ::dagui_propid.add_name_id("_skipFocus")

  function onAttach(obj)
  {
    clearAllSelections(obj)
    return base.onAttach(obj)
  }

  function onFocus(obj, event)
  {
    if (obj.getIntProp(skipFocusPID, 0))
      return ::RETCODE_HALT
    return base.onFocus(obj, event)
  }

  function clearAllSelections(obj)
  {
    for (local iRow=0; iRow < obj.childrenCount(); ++iRow)
      setChildSelected(obj, obj.getChild(iRow), false)
  }

  function setChildSelected(obj, childObj, isSelected = true)
  {
    local res = base.setChildSelected(obj, childObj, isSelected)
    if (!isSelected || !res)
      return res

    if (childObj.childrenCount() < 2)
      return res

    //Find nearest cell, that is visible
    local childIdx = 1
    for (local i = 1; i < childObj.childrenCount(); i++)
    {
      local cell = childObj.getChild(i)
      if (!cell.isVisible() || !cell.childrenCount())
        continue

      childIdx = i
      break
    }

    local cell = childObj.getChild(childIdx)
    if (!cell.childrenCount())
      return res

    obj.setIntProp(skipFocusPID, 1)
    cell.getChild(0).select()
    obj.setIntProp(skipFocusPID, 0)
    return res
  }

  function canSelectChild(obj)
  {
    return true
  }
}
