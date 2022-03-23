gui_bhv.ActivateSelect <- class extends gui_bhv.posNavigator
{
  bhvId = "ActivateSelect"
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
    let idxObj = getChildObj(obj, idx)
    if (!idxObj)
      return false

    local needNotify = false
    let prevIdx = getValue(obj)
    if (prevIdx!=idx)
    {
      needNotify = true
      let prevObj = getChildObj(obj, prevIdx)
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
    let value = getHoveredChild(obj).hoveredIdx ?? -1
    if (is_down) {
      if (value < 0)
        return ::RETCODE_NOTHING
      ::set_script_gui_behaviour_events(bhvId, obj, ::EV_MOUSE_HOVER_CHANGE)
      onActivatePushed(obj, value)
      return ::RETCODE_HALT
    }

    let pushedIdx = obj.getIntProp(activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return ::RETCODE_HALT
    let wasHoldStarted = onActivateUnpushed(obj)
    if ((!wasHoldStarted || needActionAfterHold(obj)) && pushedIdx == value)
      chooseItem(obj, value)
    return ::RETCODE_HALT
  }

  isOnlyHover = @(obj) false
}