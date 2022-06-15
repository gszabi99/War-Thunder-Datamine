let { format } = require("string")
let shortcutsAxisListModule = require("%scripts/controls/shortcutsList/shortcutsAxis.nut")

::gui_handlers.AxisControls <- class extends ::gui_handlers.Hotkeys
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/joystickAxisInput.blk"
  sceneNavBlkName = null

  axisItem = null
  curJoyParams = null
  shortcuts = null
  shortcutItems = null

  setupAxisMode = null
  autodetectAxis = false
  axisRawValues = null
  axisShortcuts = null
  dontCheckControlsDupes = null
  numAxisInList = 0
  curDevice = null
  bindAxisNum = -1

  changedShortcuts = null
  changedAxes = null
  optionTableId = "axis_setup_table"

  function initScreen()
  {
    axisRawValues = []
    axisShortcuts = []
    dontCheckControlsDupes = []
    changedShortcuts = []
    changedAxes = []

    let titleObj = scene.findObject("axis_title")
    if (::check_obj(titleObj))
      titleObj.setValue(::loc("controls/" + axisItem.id))

    reinitScreen()
    dontCheckControlsDupes = ::refillControlsDupes()

    let timerObj = scene.findObject("axis_test_box")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)

    ::update_gamercards()
  }

  function reinitScreen() {
    curDevice = ::joystick_get_default()
    setupAxisMode = axisItem.axisIndex

    let axis = curJoyParams.getAxis(setupAxisMode)
    bindAxisNum = axis.axisId

    reinitAutodetectAxis()

    if ("modifiersId" in axisItem)
      foreach(name, shortcutId in axisItem.modifiersId)
        shortcutsAxisListModule[name].shortcutId = shortcutId

    fillAxisDropright()
    fillAxisTable(axis)
    updateAxisRelativeOptions(axis.relative)
  }

  function reinitAutodetectAxis()
  {
    let autodetectChBxObj = scene.findObject("autodetect_checkbox")
    if (::checkObj(autodetectChBxObj))
    {
      autodetectChBxObj.setValue(autodetectAxis)
      onChangeAutodetect(autodetectChBxObj)

      if (!autodetectAxis)
        updateAxisItemsPos([0, 0])
    }
  }

  function getAxisRawValues(device, idx)
  {
    local res = ::getTblValue(idx, axisRawValues)
    if (!res)
    {
      if (axisRawValues.len() <= idx)
        axisRawValues.resize(idx + 1, null)

      let rawPos = device.getAxisPosRaw(idx)
      res = {
              def = rawPos,
              last = rawPos,
              stuckTime = 0.0,
              inited = ::is_axis_digital(idx) || rawPos!=0
            }
      axisRawValues[idx] = res
    }
    return res
  }

  function fillAxisTable(axis)
  {
    let axisControlsTbl = scene.findObject(optionTableId)
    if (!::checkObj(axisControlsTbl))
      return

    let hideAxisOptionsArray = axisItem?.hideAxisOptions ?? []

    local data = ""
    foreach (idx, item in shortcutsAxisListModule.types)
    {
      local addTrParams = ""
      if (::isInArray(item.id, hideAxisOptionsArray))
        addTrParams = "hiddenTr:t='yes'; inactive:t='yes';"

      let hotkeyData = ::buildHotkeyItem(idx, shortcuts, item, axis, idx%2 == 0, addTrParams)
      data += hotkeyData.markup
    }

    guiScene.replaceContentFromText(axisControlsTbl, data, data.len(), this)

    let invObj = scene.findObject("invertAxis")
    if (::checkObj(invObj))
      invObj.setValue(axis.inverse ? 1 : 0)

    let relObj = scene.findObject("relativeAxis")
    if (::checkObj(relObj))
      relObj.setValue(axis.relative ? 1 : 0)

    updateAxisItemsPos([0,0])
    updateButtons()

    foreach(item in shortcutsAxisListModule.types)
      if (item.type == CONTROL_TYPE.SLIDER)
      {
        let slideObj = scene.findObject(item.id)
        if (::checkObj(slideObj))
          onSliderChange(slideObj)
      }
  }

  function onChangeAxisRelative(obj)
  {
    if (!::checkObj(obj))
      return

    updateAxisRelativeOptions(obj.getValue())
  }

  function updateAxisRelativeOptions(isRelative)
  {
    local txtObj = null
    txtObj = scene.findObject("txt_rangeMax")
    if (::check_obj(txtObj))
      txtObj.setValue(::loc(isRelative? "hotkeys/rangeInc" : "hotkeys/rangeMax"))

    txtObj = scene.findObject("txt_rangeMin")
    if (::check_obj(txtObj))
      txtObj.setValue(::loc(isRelative? "hotkeys/rangeDec" : "hotkeys/rangeMin"))

    foreach (item in [shortcutsAxisListModule.kRelSpd, shortcutsAxisListModule.kRelStep])
    {
      let idx = shortcutsAxisListModule.types.indexof(item)
      let obj = scene.findObject($"table_row_{idx}")
      if (!::check_obj(obj))
        continue

      obj.inactive = isRelative? "no" : "yes"
      obj.enable = isRelative? "yes" : "no"
    }
  }

  function onSliderChange(obj)
  {
    let textObj = obj?.id && obj.getParent().findObject(obj.id + "_value")
    if (!::checkObj(textObj))
      return

    let reqItem = shortcutsAxisListModule?[obj.id]
    if (reqItem?.type != CONTROL_TYPE.SLIDER)
      return

    let value = obj.getValue()
    local valueText = ""
    if ("showValueMul" in reqItem)
      valueText = (reqItem.showValueMul * value).tostring()
    else
      valueText = value * (reqItem?.showValuePercMul ?? 1) + "%"

    textObj.setValue(valueText)
  }

  function fillAxisDropright()
  {
    let listObj = scene.findObject("axis_list")
    if (!::checkObj(listObj))
      return

    curDevice = ::joystick_get_default()
    let curPreset = ::g_controls_manager.getCurPreset()
    numAxisInList = curDevice ? curPreset.getNumAxes() : 0

    local data = "option { id:t='axisopt_'; text:t='#joystick/axis_not_assigned' }\n"
    for(local i=0; i<numAxisInList; i++)
      data += format("option { id:t='axisopt_%d'; text:t='%s' }\n",
              i, ::g_string.stripTags(::remapAxisName(curPreset, i)))

    guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(curDevice? (bindAxisNum+1) : 0)

    updateAxisListValue()
  }

  function updateAxisListValue()
  {
    if (bindAxisNum > numAxisInList)
      return

    let listObj = scene.findObject("axis_list")
    if (!::checkObj(listObj))
      return

    //"-1", "+1" cos value is what we get from dropright, 0 is not recognized axis there,
    // but we have 0 axis

    if (listObj.getValue() - 1 == bindAxisNum)
      return

    listObj.setValue(bindAxisNum + 1)
  }

  function onChangeAutodetect(obj)
  {
    autodetectAxis = obj.getValue()
    updateAutodetectButtonStyle()
  }

  function updateAutodetectButtonStyle()
  {
    let obj = scene.findObject("btn_axis_autodetect")
    if (::checkObj(obj))
    {
      let text = ::loc("mainmenu/btn" + (autodetectAxis? "StopAutodetect":"AutodetectAxis"))
      obj.tooltip = text
      obj.text = text

      let imgObj = obj.findObject("autodetect_img")
      if (::checkObj(imgObj))
        imgObj["background-image"] = "#ui/gameuiskin#btn_autodetect_" + (autodetectAxis? "off" : "on") + ".svg"
    }
  }

  function onAxisReset()
  {
    bindAxisNum = -1

    ::set_controls_preset("")
    curJoyParams.resetAxis(setupAxisMode)
    let axis = curJoyParams.getAxis(setupAxisMode)

    foreach (item in shortcutsAxisListModule.types)
    {
      if (item.type == CONTROL_TYPE.SLIDER || item.type == CONTROL_TYPE.SPINNER || item.type == CONTROL_TYPE.SWITCH_BOX)
      {
        let slideObj = scene.findObject(item.id)
        if (::checkObj(slideObj))
          slideObj.setValue(item.value.call(this, axis))
      }
      else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
        clearBinds(item)
    }
  }

  function clearBinds(item)
  {
    let event = shortcuts[item.shortcutId]
    event.clear()
    onShortcutChange(item.shortcutId)
  }

  function onAxisBindChange(obj)
  {
    bindAxisNum = obj.getValue() - 1
    ::u.appendOnce(axisItem.modifiersId[""], changedShortcuts)
  }

  function onAxisRestore()
  {
    let axis = curJoyParams.getAxis(setupAxisMode)
    bindAxisNum = axis.axisId
    updateAxisListValue()
  }

  getScById = @(scId) shortcutsAxisListModule.types?[(scId ?? "-1").tointeger()]

  function onAxisInputTimer(obj, dt)
  {
    if (scene.getModalCounter() > 0)
      return

    curDevice = ::joystick_get_default()

    if (!curDevice)
      return

    local foundAxis = -1
    local deviation = 12000 //foundedAxis deviation, cant be lower than a initial value
    let totalAxes = curDevice.getNumAxes()

    for (local i = 0; i < totalAxes; i++)
    {
      let rawValues = getAxisRawValues(curDevice, i)
      let rawPos = curDevice.getAxisPosRaw(i)
      if (!rawValues.inited && rawPos!=0)
      {
        rawValues.def = rawPos //reinit
        rawValues.inited = true
      }
      let dPos = rawPos - rawValues.def

      if (::abs(dPos) > deviation)
      {
        foundAxis = i
        deviation = ::abs(dPos)

        if (fabs(rawPos-rawValues.last) < 1000)  //check stucked axes
        {
          rawValues.stuckTime += dt
          if (rawValues.stuckTime > 3.0)
            rawValues.def = rawPos //change cur value to def becoase of stucked
        } else
        {
          rawValues.last = rawPos
          rawValues.stuckTime = 0.0
        }
      }
    }

    if (autodetectAxis && foundAxis >= 0 && foundAxis != bindAxisNum)
      bindAxisNum = foundAxis

    updateAxisListValue()

    if (bindAxisNum < 0)
      return

    //!!FIX ME: Have to adjust the code below taking values from the table and only when they change
    local val = curDevice.getAxisPosRaw(bindAxisNum) / 32000.0

    let isInv = scene.findObject("invertAxis").getValue()

    let objDz = scene.findObject("deadzone")
    let deadzone = max_deadzone * objDz.getValue() / objDz.max.tofloat()
    let objNl = scene.findObject("nonlinearity")
    let nonlin = objNl.getValue().tofloat() / 10 - 1

    let objMul = scene.findObject("kMul")
    let kMul = objMul.getValue().tofloat() / 100.0
    let objAdd = scene.findObject("kAdd")
    let kAdd = objAdd.getValue().tofloat() / 50.0

    let devVal = val
    if (isInv)
      val = -1*val

    val = val*kMul+kAdd

    let valSign = val < 0? -1 : 1

    if (val > 1.0)
      val = 1.0
    else if (val < -1.0)
      val = -1.0

    val = fabs(val) < deadzone? 0 : valSign * ((fabs(val) - deadzone) / (1.0 - deadzone))

    val = valSign * (::pow(fabs(val), (1 + nonlin)))

    updateAxisItemsPos([val, devVal])
  }

  function updateAxisItemsPos(valsArray)
  {
    if (typeof(valsArray) != "array")
      return

    let objectsArray = ["test-game-box", "test-real-box"]
    foreach(idx, id in objectsArray)
    {
      let obj = scene.findObject(id)
      if (!::checkObj(obj))
        continue

      let leftPos = (valsArray[idx] + 1.0) * 0.5
      obj.left = format("%.3f(pw - w)", leftPos)
    }
  }

  function checkZoomOnMWheel()
  {
    if (bindAxisNum < 0 || !axisItem || axisItem.id!="zoom")
      return false

    let mWheelId = "mouse_z"
    let wheelObj = scene.findObject(mWheelId)
    if (!wheelObj) return false

    foreach(item in ::shortcutsList)
      if (item.id == mWheelId)
      {
        let value = wheelObj.getValue()
        if (("values" in item) && (value in item.values) && (item.values[value]=="zoom"))
        {
          let msg = format(::loc("msg/zoomAssignmentsConflict"), ::loc("controls/mouse_z"))
          this.msgBox("zoom_axis_assigned", msg,
          [
            ["replace", (@(wheelObj) function() {
              if (wheelObj && wheelObj.isValid())
                wheelObj.setValue(0)
              doAxisApply()
            })(wheelObj)],
            ["cancel", function()
            {
              bindAxisNum = -1
              doAxisApply()
            }]
          ], "replace")
          return true
        }
        return false
      }
    return false
  }

  function doAxisApply()
  {
    let alreadyBindedAxes = findBindedAxes(bindAxisNum, axisItem.checkGroup)
    if (alreadyBindedAxes.len() == 0)
    {
      doBindAxis()
      return
    }

    local actionText = ""
    foreach(item in alreadyBindedAxes)
      actionText += ((actionText=="")? "":", ") + ::loc("controls/" + item.id)
    let msg = ::loc("hotkeys/msg/unbind_axis_question", {
      action=actionText
    })
    this.msgBox("controls_axis_bind_existing_axis", msg, [
      ["add", function() { doBindAxis() }],
      ["replace", function() {
        foreach(item in alreadyBindedAxes) {
          curJoyParams.bindAxis(item.axisIndex, -1)
          changedAxes.append(item)
        }
        doBindAxis()
      }],
      ["cancel", function() {}],
    ], "add")
  }

  function findBindedAxes(curAxisId, checkGroup)
  {
    if (curAxisId < 0 || !axisItem.checkAssign)
      return []

    let res = []
    foreach(item in ::shortcutsList)
      if (item.type == CONTROL_TYPE.AXIS && item != axisItem && (checkGroup & item.checkGroup))
      {
        let axis = curJoyParams.getAxis(item.axisIndex)
        if (curAxisId == axis.axisId)
          res.append(item)
      }
    return res
  }

  function doBindAxis()
  {
    curDevice = ::joystick_get_default()
    ::set_controls_preset(""); //custom mode
    curJoyParams.bindAxis(setupAxisMode, bindAxisNum)
    doApplyJoystick()
    curJoyParams.applyParams(curDevice)
    guiScene.performDelayed(this, closeWnd)
  }

  function updateButtons()
  {
    let item = getCurItem()
    if (!item)
      return

    let showScReset = item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT
    this.showSceneBtn("btn_axis_reset_shortcut", showScReset)
    this.showSceneBtn("btn_axis_assign", showScReset)
  }

  function onTblSelect()
  {
    updateButtons()
  }

  function onTblDblClick()
  {
    let item = getCurItem()
    if (!item)
      return

    if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      callAssignButton()
  }

  function callAssignButton()
  {
    ::assignButtonWindow(this, onAssignButton)
  }

  function onAssignButton(dev, btn)
  {
    if (dev.len() > 0 && dev.len() == btn.len())
    {
      let item = getCurItem()
      if (item)
        bindShortcut(dev, btn, item)
    }
  }

  function findButtons(devs, btns, curItem)
  {
    let res = []

    if (::find_in_array(dontCheckControlsDupes, curItem.shortcutId) < 0)
      foreach (idx, event in shortcuts)
        if (axisItem.checkGroup & shortcutItems[idx].checkGroup)
          foreach (button_index, button in event)
          {
            if (!button || button.dev.len() != devs.len())
              continue
            local numEqual = 0
            for (local i = 0; i < button.dev.len(); i++)
              for (local j = 0; j < devs.len(); j++)
                if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                  numEqual++

            if (numEqual == btns.len() && ::find_in_array(dontCheckControlsDupes, shortcutItems[idx].id) < 0)
              res.append([idx, button_index])
          }

    return res
  }

  function getShortcutLocId(reqNameId, fullName = true)
  {
    if (!(reqNameId in shortcutItems))
      return ""

    let reqItem = shortcutItems[reqNameId]
    local reqName = reqItem.id

    if ("modifiersId" in reqItem)
      foreach(name, shortcutId in reqItem.modifiersId)
        if (shortcutId == reqNameId)
        {
          reqName = (fullName? reqItem.id + (name == ""? "" : "_"): "") + name
          break
        }

    return reqName
  }

  function bindShortcut(devs, btns, item)
  {
    if (!(item.shortcutId in shortcuts))
      return

    let curBinding = findButtons(devs, btns, item)
    if (curBinding.len() == 0)
    {
      doBind(devs, btns, item)
      return
    }

    for(local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0] == item.shortcutId)
        return

    local actions = ""
    foreach(idx, shortcut in curBinding)
      actions += (actions == ""? "" : ", ") + ::loc("hotkeys/" + getShortcutLocId(shortcut[0]))

    let msg = ::loc("hotkeys/msg/unbind_question", {action = actions})

    this.msgBox("controls_axis_bind_existing_shortcut", msg, [
      ["add", (@(devs, btns, item) function() {
        doBind(devs, btns, item)
      })(devs, btns, item)],
      ["replace", (@(curBinding, devs, btns, item) function() {
        foreach(binding in curBinding)
        {
          shortcuts[binding[0]].remove(binding[1])
          onShortcutChange(binding[0])
        }
        doBind(devs, btns, item)
      })(curBinding, devs, btns, item)],
      ["cancel", function() { }],
    ], "cancel")
    return
  }

  function doBind(devs, btns, item)
  {
    let event = shortcuts[item.shortcutId]
    event.append({
                   dev = devs,
                   btn = btns
                })

    if (event.len() > max_shortcuts)
      event.remove(0)

    ::set_controls_preset("") //custom mode
    onShortcutChange(item.shortcutId)
  }

  function updateShortcutText(shortcutId)
  {
    if (!(shortcutId in shortcuts) ||
      !::isInArray(shortcutId, ::u.values(axisItem.modifiersId)))
      return

    let itemId = getShortcutLocId(shortcutId, false)
    let obj = scene.findObject("txt_sc_"+ itemId)

    if (::checkObj(obj))
      obj.setValue(::get_shortcut_text({shortcuts = shortcuts, shortcutId = shortcutId}))
  }

  function onShortcutChange(shortcutId)
  {
    updateShortcutText(shortcutId)
    ::u.appendOnce(shortcutId, changedShortcuts)
  }

  function onButtonReset()
  {
    let item = getCurItem()
    if (!item)
      return

    shortcuts[item.shortcutId].clear()
    onShortcutChange(item.shortcutId)
  }

  function doApplyJoystick()
  {
    if (curJoyParams != null)
      doApplyJoystickImpl(shortcutsAxisListModule.types, curJoyParams.getAxis(setupAxisMode))
  }

  function onApply()
  {
    if (!checkZoomOnMWheel())
      doAxisApply()
  }

  function afterModalDestroy()
  {
    ::broadcastEvent("ControlsChangedShortcuts", {changedShortcuts = changedShortcuts})
    ::broadcastEvent("ControlsChangedAxes", {changedAxes = changedAxes})
  }

  function goBack()
  {
    onApply()
  }

  function setShortcutsParams(params) {
    curJoyParams = params.curJoyParams
    shortcuts = params.shortcuts
    shortcutItems = params.shortcutItems
    let axisId = axisItem.id
    axisItem = ::shortcutsList.findvalue(@(s) s.id == axisId) ?? axisItem
    reinitScreen()
  }
}
