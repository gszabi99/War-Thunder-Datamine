#explicit-this
#no-root-fallback

::gui_bhv.ActivateSelect <- class extends ::gui_bhv.posNavigator
{
  bhvId = "ActivateSelect"
  valuePID = ::dagui_propid.add_name_id("value")  //values by bits   chosen:yes;
  selectedPID = ::dagui_propid.add_name_id("_selected")    //only 1     selected:yes;
  canChooseByMClick = true

  function setValue(obj, value)
  {
    if (this.chooseItemImpl(obj, value, false, false))
      this.setSelectedValue(obj, value)
  }

  function getSelectedValue(obj)
  {
    return obj.getIntProp(this.selectedPID, -1)
  }

  function setSelectedValue(obj, value)
  {
    this.selectItem(obj, value, null, false)
  }

  function onSelectAction(obj)
  {
  }

  function chooseItemImpl(obj, idx, needSound = true, needActivateChoosenItem = true)
  {
    let idxObj = this.getChildObj(obj, idx)
    if (!idxObj)
      return false

    local needNotify = false
    let prevIdx = this.getValue(obj)
    if (prevIdx!=idx)
    {
      needNotify = true
      let prevObj = this.getChildObj(obj, prevIdx)
      if (prevObj)
        prevObj["chosen"] = "no"
    }

    obj.setIntProp(this.valuePID, idx)
    idxObj["chosen"] = "yes"

    if (needSound && needNotify)
      obj.getScene().playSound("choose")
    if (needNotify)
      obj.sendNotify("select")
    else if (needActivateChoosenItem)
      obj.sendNotify("activate")
    return true
  }

  chooseItem = @(obj, idx, needSound = true) this.chooseItemImpl(obj, idx, needSound)

  function onShortcutSelect(obj, is_down)
  {
    let value = this.getHoveredChild(obj).hoveredIdx ?? -1
    if (is_down) {
      if (value < 0)
        return RETCODE_NOTHING
      ::set_script_gui_behaviour_events(this.bhvId, obj, EV_MOUSE_HOVER_CHANGE)
      this.onActivatePushed(obj, value)
      return RETCODE_HALT
    }

    let pushedIdx = obj.getIntProp(this.activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return RETCODE_HALT
    let wasHoldStarted = this.onActivateUnpushed(obj)
    if ((!wasHoldStarted || this.needActionAfterHold(obj)) && pushedIdx == value)
      this.chooseItem(obj, value)
    return RETCODE_HALT
  }

  isOnlyHover = @(obj) false
}