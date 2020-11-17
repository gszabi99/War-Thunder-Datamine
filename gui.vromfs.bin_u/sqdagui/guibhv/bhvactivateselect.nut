class gui_bhv.ActivateSelect extends gui_bhv.posNavigator
{
  valuePID = ::dagui_propid.add_name_id("value")  //values by bits   chosen:yes;
  selectedPID = ::dagui_propid.add_name_id("_selected")    //only 1     selected:yes;
  canChooseByMClick = true

  function setValue(obj, value)
  {
    if (chooseItemImpl(obj, value, false, false))
      setSelectedValue(obj, value)
  }

  function getSelectedValue(obj)
  {
    return obj.getIntProp(selectedPID, -1)
  }

  function setSelectedValue(obj, value)
  {
    selectItem(obj, value, null, false)
  }

  function onSelectAction(obj)
  {
  }

  function chooseItemImpl(obj, idx, needSound = true, needActivateChoosenItem = true)
  {
    local idxObj = getChildObj(obj, idx)
    if (!idxObj)
      return false

    local needNotify = false
    local prevIdx = getValue(obj)
    if (prevIdx!=idx)
    {
      needNotify = true
      local prevObj = getChildObj(obj, prevIdx)
      if (prevObj)
        prevObj["chosen"] = "no"
    }

    obj.setIntProp(valuePID, idx)
    idxObj["chosen"] = "yes"

    if (needSound && needNotify)
      obj.getScene().playSound("choose")
    if (needNotify)
      obj.sendNotify("select")
    else if (needActivateChoosenItem)
      obj.sendNotify("activate")
    return true
  }

  chooseItem = @(obj, idx, needSound = true) chooseItemImpl(obj, idx, needSound)

  function onShortcutSelect(obj, is_down)
  {
    if (is_down)
      return ::RETCODE_NOTHING

    local selected = isShortcutsByHover(obj) ? getHoveredChild(obj).hoveredIdx : getSelectedValue(obj)
    if (selected >= 0)
      chooseItem(obj, selected)
    return ::RETCODE_HALT
  }

  isOnlyHover = @(obj) false
}