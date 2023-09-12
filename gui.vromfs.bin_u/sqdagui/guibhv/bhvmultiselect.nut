from "%sqDagui/daguiNativeApi.nut" import *
let { posNavigator } = require("bhvPosNavigator.nut")

let MultiSelect = class extends posNavigator {
  bhvId = "MultiSelect"
  valuePID = dagui_propid_add_name_id("bitValue")  //values by bits   chosen:yes;
  selectedPID = dagui_propid_add_name_id("_selected")    //only 1     selected:yes;

  chosenPID = dagui_propid_add_name_id("chosen")    //only to init property if it not used in css.
  canChooseByMClick = true

  function getValue(obj) {
    return obj.getIntProp(this.valuePID, 0)
  }
  function setValue(obj, bitValue) {
    this.chooseItems(obj, bitValue, false)
  }
  function getSelectedValue(obj) {
    return obj.getIntProp(this.selectedPID, -1)
  }
  function setSelectedValue(obj, value) {
    this.selectItem(obj, value, null, false)
  }

  function onSelectAction(_obj) {
  }

  function chooseItems(obj, bitValue, needSound = true) {
    local needNotify = false
    let total = obj.childrenCount()
    bitValue = bitValue & ((1 << total) - 1) //validate mask by len

    let prevValue = this.getValue(obj)
    needNotify = prevValue != bitValue

    local soundName = null
    let valuesToUpdate = bitValue | prevValue //all what was selected or need to select
    for (local i = 0; i < total; i++)
      if (valuesToUpdate & (1 << i)) {
        let childObj = this.getChildObj(obj, i)
        if (childObj.isValid()) {
          if (!soundName && (bitValue & (1 << i)) != (prevValue & (1 << i)))
            soundName = (bitValue & (1 << i)) ? obj?.snd_switch_on : obj?.snd_switch_off
          childObj["chosen"] = (bitValue & (1 << i)) ? "yes" : "no"
        }
      }

    obj.setIntProp(this.valuePID, bitValue)

    if (needSound && needNotify && soundName)
      obj.getScene().playSound(soundName)
    if (needNotify)
      obj.sendNotify("select")
    return true
  }

  function chooseItem(obj, selIdx, _needSound = true) {
    if (selIdx >= 0)
      this.chooseItems(obj, this.getValue(obj) ^ (1 << selIdx))
  }

  function onShortcutSelect(obj, is_down) {
    let value = this.getHoveredChild(obj).hoveredIdx ?? -1
    if (is_down) {
      if (value < 0)
        return RETCODE_NOTHING
      set_script_gui_behaviour_events(this.bhvId, obj, EV_MOUSE_HOVER_CHANGE)
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

  isOnlyHover = @(_obj) false
}
return {MultiSelect}