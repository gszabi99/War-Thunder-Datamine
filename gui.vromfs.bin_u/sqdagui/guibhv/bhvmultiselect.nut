class gui_bhv.MultiSelect extends gui_bhv.posNavigator
{
  bhvId = "MultiSelect"
  valuePID = ::dagui_propid.add_name_id("bitValue")  //values by bits   chosen:yes;
  selectedPID = ::dagui_propid.add_name_id("_selected")    //only 1     selected:yes;

  chosenPID = ::dagui_propid.add_name_id("chosen")    //only to init property if it not used in css.
  canChooseByMClick = true

  function getValue(obj)
  {
    return obj.getIntProp(valuePID, 0)
  }
  function setValue(obj, bitValue)
  {
    chooseItems(obj, bitValue, false)
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

  function chooseItems(obj, bitValue, needSound = true)
  {
    local needNotify = false
    local total = obj.childrenCount()
    bitValue = bitValue & ((1 << total) - 1) //validate mask by len

    local prevValue = getValue(obj)
    needNotify = prevValue != bitValue

    local soundName = null
    local valuesToUpdate = bitValue | prevValue //all what was selected or need to select
    for(local i = 0; i < total; i++)
      if (valuesToUpdate & (1 << i))
      {
        local childObj = getChildObj(obj, i)
        if (childObj.isValid())
        {
          if (!soundName && (bitValue & (1 << i)) != (prevValue & (1 << i)))
            soundName = (bitValue & (1 << i)) ? obj?.snd_switch_on : obj?.snd_switch_off
          childObj["chosen"] = (bitValue & (1 << i)) ? "yes" : "no"
        }
      }

    obj.setIntProp(valuePID, bitValue)

    if (needSound && needNotify && soundName)
      obj.getScene().playSound(soundName)
    if (needNotify)
      obj.sendNotify("select")
    return true
  }

  function chooseItem(obj, selIdx, needSound = true)
  {
    if (selIdx >= 0)
      chooseItems(obj, getValue(obj) ^ (1 << selIdx))
  }

  function onShortcutSelect(obj, is_down)
  {
    local value = (isShortcutsByHover(obj) ? getHoveredChild(obj).hoveredIdx : getSelectedValue(obj)) ?? -1
    if (is_down) {
      if (value < 0)
        return ::RETCODE_NOTHING
      ::set_script_gui_behaviour_events(bhvId, obj, ::EV_MOUSE_HOVER_CHANGE)
      onActivatePushed(obj, value)
      return ::RETCODE_HALT
    }

    local pushedIdx = obj.getIntProp(activatePushedIdxPID, -1)
    if (pushedIdx < 0)
      return ::RETCODE_HALT
    local wasHoldStarted = onActivateUnpushed(obj)
    if ((!wasHoldStarted || needActionAfterHold(obj)) && pushedIdx == value)
      chooseItem(obj, value)

    return ::RETCODE_HALT
  }

  isOnlyHover = @(obj) false
}