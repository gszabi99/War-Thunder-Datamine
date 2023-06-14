//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { abs, fabs, pow } = require("math")
let shortcutsAxisListModule = require("%scripts/controls/shortcutsList/shortcutsAxis.nut")
let { MAX_DEADZONE, MAX_SHORTCUTS } = require("%scripts/controls/controlsConsts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getShortcutData } = require("%scripts/controls/shortcutsUtils.nut")
let { stripTags } = require("%sqstd/string.nut")

::gui_handlers.AxisControls <- class extends ::gui_handlers.Hotkeys {
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
  bindAxisNum = -1

  changedShortcuts = null
  changedAxes = null
  optionTableId = "axis_setup_table"

  function initScreen() {
    this.axisRawValues = []
    this.axisShortcuts = []
    this.dontCheckControlsDupes = []
    this.changedShortcuts = []
    this.changedAxes = []

    let titleObj = this.scene.findObject("axis_title")
    if (checkObj(titleObj))
      titleObj.setValue(loc("controls/" + this.axisItem.id))

    this.reinitScreen()
    this.dontCheckControlsDupes = ::refillControlsDupes()

    let timerObj = this.scene.findObject("axis_test_box")
    if (checkObj(timerObj))
      timerObj.setUserData(this)

    ::update_gamercards()
  }

  function reinitScreen() {
    this.setupAxisMode = this.axisItem.axisIndex

    let axis = this.curJoyParams.getAxis(this.setupAxisMode)
    this.bindAxisNum = axis.axisId

    this.reinitAutodetectAxis()

    if ("modifiersId" in this.axisItem)
      foreach (name, shortcutId in this.axisItem.modifiersId)
        shortcutsAxisListModule[name].shortcutId = shortcutId

    this.fillAxisDropright()
    this.fillAxisTable(axis)
    this.updateAxisRelativeOptions(axis.relative)
  }

  function reinitAutodetectAxis() {
    let autodetectChBxObj = this.scene.findObject("autodetect_checkbox")
    if (checkObj(autodetectChBxObj)) {
      autodetectChBxObj.setValue(this.autodetectAxis)
      this.onChangeAutodetect(autodetectChBxObj)

      if (!this.autodetectAxis)
        this.updateAxisItemsPos([0, 0])
    }
  }

  function getAxisRawValues(device, idx) {
    local res = getTblValue(idx, this.axisRawValues)
    if (!res) {
      if (this.axisRawValues.len() <= idx)
        this.axisRawValues.resize(idx + 1, null)

      let rawPos = device.getAxisPosRaw(idx)
      res = {
              def = rawPos,
              last = rawPos,
              stuckTime = 0.0,
              inited = ::is_axis_digital(idx) || rawPos != 0
            }
      this.axisRawValues[idx] = res
    }
    return res
  }

  function fillAxisTable(axis) {
    let axisControlsTbl = this.scene.findObject(this.optionTableId)
    if (!checkObj(axisControlsTbl))
      return

    let hideAxisOptionsArray = this.axisItem?.hideAxisOptions ?? []

    local data = ""
    foreach (idx, item in shortcutsAxisListModule.types) {
      local addTrParams = ""
      if (isInArray(item.id, hideAxisOptionsArray))
        addTrParams = "hiddenTr:t='yes'; inactive:t='yes';"

      let hotkeyData = ::buildHotkeyItem(idx, this.shortcuts, item, axis, idx % 2 == 0, addTrParams)
      data += hotkeyData.markup
    }

    this.guiScene.replaceContentFromText(axisControlsTbl, data, data.len(), this)

    let invObj = this.scene.findObject("invertAxis")
    if (checkObj(invObj))
      invObj.setValue(axis.inverse ? 1 : 0)

    let relObj = this.scene.findObject("relativeAxis")
    if (checkObj(relObj))
      relObj.setValue(axis.relative ? 1 : 0)

    this.updateAxisItemsPos([0, 0])
    this.updateButtons()

    foreach (item in shortcutsAxisListModule.types)
      if (item.type == CONTROL_TYPE.SLIDER) {
        let slideObj = this.scene.findObject(item.id)
        if (checkObj(slideObj))
          this.onSliderChange(slideObj)
      }
  }

  function onChangeAxisRelative(obj) {
    if (!checkObj(obj))
      return

    this.updateAxisRelativeOptions(obj.getValue())
  }

  function updateAxisRelativeOptions(isRelative) {
    local txtObj = null
    txtObj = this.scene.findObject("txt_rangeMax")
    if (checkObj(txtObj))
      txtObj.setValue(loc(isRelative ? "hotkeys/rangeInc" : "hotkeys/rangeMax"))

    txtObj = this.scene.findObject("txt_rangeMin")
    if (checkObj(txtObj))
      txtObj.setValue(loc(isRelative ? "hotkeys/rangeDec" : "hotkeys/rangeMin"))

    foreach (item in [shortcutsAxisListModule.kRelSpd, shortcutsAxisListModule.kRelStep]) {
      let idx = shortcutsAxisListModule.types.indexof(item)
      let obj = this.scene.findObject($"table_row_{idx}")
      if (!checkObj(obj))
        continue

      obj.inactive = isRelative ? "no" : "yes"
      obj.enable = isRelative ? "yes" : "no"
    }
  }

  function onSliderChange(obj) {
    let textObj = obj?.id && obj.getParent().findObject(obj.id + "_value")
    if (!checkObj(textObj))
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

  function fillAxisDropright() {
    let listObj = this.scene.findObject("axis_list")
    if (!checkObj(listObj))
      return

    let curDevice = ::joystick_get_default()
    let curPreset = ::g_controls_manager.getCurPreset()
    this.numAxisInList = curDevice ? curPreset.getNumAxes() : 0

    local data = "option { id:t='axisopt_'; text:t='#joystick/axis_not_assigned' }\n"
    for (local i = 0; i < this.numAxisInList; i++)
      data += format("option { id:t='axisopt_%d'; text:t='%s' }\n",
              i, stripTags(::remapAxisName(curPreset, i)))

    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(curDevice ? (this.bindAxisNum + 1) : 0)

    this.updateAxisListValue()
  }

  function updateAxisListValue() {
    if (this.bindAxisNum > this.numAxisInList)
      return

    let listObj = this.scene.findObject("axis_list")
    if (!checkObj(listObj))
      return

    //"-1", "+1" cos value is what we get from dropright, 0 is not recognized axis there,
    // but we have 0 axis

    if (listObj.getValue() - 1 == this.bindAxisNum)
      return

    listObj.setValue(this.bindAxisNum + 1)
  }

  function onChangeAutodetect(obj) {
    this.autodetectAxis = obj.getValue()
    this.updateAutodetectButtonStyle()
  }

  function updateAutodetectButtonStyle() {
    let obj = this.scene.findObject("btn_axis_autodetect")
    if (checkObj(obj)) {
      let text = loc("mainmenu/btn" + (this.autodetectAxis ? "StopAutodetect" : "AutodetectAxis"))
      obj.tooltip = text
      obj.text = text

      let imgObj = obj.findObject("autodetect_img")
      if (checkObj(imgObj))
        imgObj["background-image"] = "#ui/gameuiskin#btn_autodetect_" + (this.autodetectAxis ? "off" : "on") + ".svg"
    }
  }

  function onAxisReset() {
    this.bindAxisNum = -1

    this.curJoyParams.resetAxis(this.setupAxisMode)
    let axis = this.curJoyParams.getAxis(this.setupAxisMode)

    foreach (item in shortcutsAxisListModule.types) {
      if (item.type == CONTROL_TYPE.SLIDER || item.type == CONTROL_TYPE.SPINNER || item.type == CONTROL_TYPE.SWITCH_BOX) {
        let slideObj = this.scene.findObject(item.id)
        if (checkObj(slideObj))
          slideObj.setValue(item.value.call(this, axis))
      }
      else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
        this.clearBinds(item)
    }
  }

  function clearBinds(item) {
    let event = this.shortcuts[item.shortcutId]
    event.clear()
    this.onShortcutChange(item.shortcutId)
  }

  function onAxisBindChange(obj) {
    this.bindAxisNum = obj.getValue() - 1
    u.appendOnce(this.axisItem.modifiersId[""], this.changedShortcuts)
  }

  function onAxisRestore() {
    let axis = this.curJoyParams.getAxis(this.setupAxisMode)
    this.bindAxisNum = axis.axisId
    this.updateAxisListValue()
  }

  getScById = @(scId) shortcutsAxisListModule.types?[(scId ?? "-1").tointeger()]

  function onAxisInputTimer(_obj, dt) {
    if (this.scene.getModalCounter() > 0)
      return

    let curDevice = ::joystick_get_default()
    if (!curDevice)
      return

    local foundAxis = -1
    local deviation = 12000 //foundedAxis deviation, cant be lower than a initial value
    let totalAxes = curDevice.getNumAxes()

    for (local i = 0; i < totalAxes; i++) {
      let rawValues = this.getAxisRawValues(curDevice, i)
      let rawPos = curDevice.getAxisPosRaw(i)
      if (!rawValues.inited && rawPos != 0) {
        rawValues.def = rawPos //reinit
        rawValues.inited = true
      }
      let dPos = rawPos - rawValues.def

      if (abs(dPos) > deviation) {
        foundAxis = i
        deviation = abs(dPos)

        if (fabs(rawPos - rawValues.last) < 1000) {  //check stucked axes
          rawValues.stuckTime += dt
          if (rawValues.stuckTime > 3.0)
            rawValues.def = rawPos //change cur value to def becoase of stucked
        }
        else {
          rawValues.last = rawPos
          rawValues.stuckTime = 0.0
        }
      }
    }

    if (this.autodetectAxis && foundAxis >= 0 && foundAxis != this.bindAxisNum)
      this.bindAxisNum = foundAxis

    this.updateAxisListValue()

    if (this.bindAxisNum < 0)
      return

    //!!FIX ME: Have to adjust the code below taking values from the table and only when they change
    local val = curDevice.getAxisPosRaw(this.bindAxisNum) / 32000.0

    let isInv = this.scene.findObject("invertAxis").getValue()

    let objDz = this.scene.findObject("deadzone")
    let deadzone = MAX_DEADZONE * objDz.getValue() / objDz.max.tofloat()
    let objNl = this.scene.findObject("nonlinearity")
    let nonlin = objNl.getValue().tofloat() / 10 - 1

    let objMul = this.scene.findObject("kMul")
    let kMul = objMul.getValue().tofloat() / 100.0
    let objAdd = this.scene.findObject("kAdd")
    let kAdd = objAdd.getValue().tofloat() / 50.0

    let devVal = val
    if (isInv)
      val = -1 * val

    val = val * kMul + kAdd

    let valSign = val < 0 ? -1 : 1

    if (val > 1.0)
      val = 1.0
    else if (val < -1.0)
      val = -1.0

    val = fabs(val) < deadzone ? 0 : valSign * ((fabs(val) - deadzone) / (1.0 - deadzone))

    val = valSign * (pow(fabs(val), (1 + nonlin)))

    this.updateAxisItemsPos([val, devVal])
  }

  function updateAxisItemsPos(valsArray) {
    if (type(valsArray) != "array")
      return

    let objectsArray = ["test-game-box", "test-real-box"]
    foreach (idx, id in objectsArray) {
      let obj = this.scene.findObject(id)
      if (!checkObj(obj))
        continue

      let leftPos = (valsArray[idx] + 1.0) * 0.5
      obj.left = format("%.3f(pw - w)", leftPos)
    }
  }

  function checkZoomOnMWheel() {
    if (this.bindAxisNum < 0 || !this.axisItem || this.axisItem.id != "zoom")
      return false

    let mWheelId = "mouse_z"
    let wheelObj = this.scene.findObject(mWheelId)
    if (!wheelObj)
      return false

    foreach (item in ::shortcutsList)
      if (item.id == mWheelId) {
        let value = wheelObj.getValue()
        if (("values" in item) && (value in item.values) && (item.values[value] == "zoom")) {
          let msg = format(loc("msg/zoomAssignmentsConflict"), loc("controls/mouse_z"))
          this.msgBox("zoom_axis_assigned", msg,
          [
            ["replace", function() {
              if (wheelObj && wheelObj.isValid())
                wheelObj.setValue(0)
              this.doAxisApply()
            }],
            ["cancel", function() {
              this.bindAxisNum = -1
              this.doAxisApply()
            }]
          ], "replace")
          return true
        }
        return false
      }
    return false
  }

  function doAxisApply() {
    let alreadyBindedAxes = this.findBindedAxes(this.bindAxisNum, this.axisItem.checkGroup)
    if (alreadyBindedAxes.len() == 0) {
      this.doBindAxis()
      return
    }

    local actionText = ""
    foreach (item in alreadyBindedAxes)
      actionText += ((actionText == "") ? "" : ", ") + loc("controls/" + item.id)
    let msg = loc("hotkeys/msg/unbind_axis_question", {
      action = actionText
    })
    this.msgBox("controls_axis_bind_existing_axis", msg, [
      ["add", function() { this.doBindAxis() }],
      ["replace", function() {
        foreach (item in alreadyBindedAxes) {
          this.curJoyParams.bindAxis(item.axisIndex, -1)
          this.changedAxes.append(item)
        }
        this.doBindAxis()
      }],
      ["cancel", function() {}],
    ], "add")
  }

  function findBindedAxes(curAxisId, checkGroup) {
    if (curAxisId < 0 || !this.axisItem.checkAssign)
      return []

    let res = []
    foreach (item in ::shortcutsList)
      if (item.type == CONTROL_TYPE.AXIS && item != this.axisItem && (checkGroup & item.checkGroup)) {
        let axis = this.curJoyParams.getAxis(item.axisIndex)
        if (curAxisId == axis.axisId)
          res.append(item)
      }
    return res
  }

  function doBindAxis() {
    this.curJoyParams.bindAxis(this.setupAxisMode, this.bindAxisNum)
    this.doApplyJoystick()
    ::g_controls_manager.commitControls()
    this.guiScene.performDelayed(this, this.closeWnd)
  }

  function updateButtons() {
    let item = this.getCurItem()
    if (!item)
      return

    let showScReset = item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT
    this.showSceneBtn("btn_axis_reset_shortcut", showScReset)
    this.showSceneBtn("btn_axis_assign", showScReset)
  }

  function onTblSelect() {
    this.updateButtons()
  }

  function onTblDblClick() {
    let item = this.getCurItem()
    if (!item)
      return

    if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      this.callAssignButton()
  }

  function callAssignButton() {
    ::assignButtonWindow(this, this.onAssignButton)
  }

  function onAssignButton(dev, btn) {
    if (dev.len() > 0 && dev.len() == btn.len()) {
      let item = this.getCurItem()
      if (item)
        this.bindShortcut(dev, btn, item)
    }
  }

  function findButtons(devs, btns, curItem) {
    let res = []

    if (u.find_in_array(this.dontCheckControlsDupes, curItem.shortcutId) < 0)
      foreach (idx, event in this.shortcuts)
        if (this.axisItem.checkGroup & this.shortcutItems[idx].checkGroup)
          foreach (button_index, button in event) {
            if (!button || button.dev.len() != devs.len())
              continue
            local numEqual = 0
            for (local i = 0; i < button.dev.len(); i++)
              for (local j = 0; j < devs.len(); j++)
                if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                  numEqual++

            if (numEqual == btns.len() && u.find_in_array(this.dontCheckControlsDupes, this.shortcutItems[idx].id) < 0)
              res.append([idx, button_index])
          }

    return res
  }

  function getShortcutLocId(reqNameId, fullName = true) {
    if (!(reqNameId in this.shortcutItems))
      return ""

    let reqItem = this.shortcutItems[reqNameId]
    local reqName = reqItem.id

    if ("modifiersId" in reqItem)
      foreach (name, shortcutId in reqItem.modifiersId)
        if (shortcutId == reqNameId) {
          reqName = (fullName ? reqItem.id + (name == "" ? "" : "_") : "") + name
          break
        }

    return reqName
  }

  function bindShortcut(devs, btns, item) {
    if (!(item.shortcutId in this.shortcuts))
      return

    let curBinding = this.findButtons(devs, btns, item)
    if (curBinding.len() == 0) {
      this.doBind(devs, btns, item)
      return
    }

    for (local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0] == item.shortcutId)
        return

    local actions = ""
    foreach (_idx, shortcut in curBinding)
      actions += (actions == "" ? "" : ", ") + loc("hotkeys/" + this.getShortcutLocId(shortcut[0]))

    let msg = loc("hotkeys/msg/unbind_question", { action = actions })

    this.msgBox("controls_axis_bind_existing_shortcut", msg, [
      ["add", @() this.doBind(devs, btns, item)],
      ["replace", function() {
        foreach (binding in curBinding) {
          this.shortcuts[binding[0]].remove(binding[1])
          this.onShortcutChange(binding[0])
        }
        this.doBind(devs, btns, item)
      }],
      ["cancel", function() { }],
    ], "cancel")
    return
  }

  function doBind(devs, btns, item) {
    let event = this.shortcuts[item.shortcutId]
    event.append({
                   dev = devs,
                   btn = btns
                })

    if (event.len() > MAX_SHORTCUTS)
      event.remove(0)

    this.onShortcutChange(item.shortcutId)
  }

  function updateShortcut(shortcutId) {
    if (!(shortcutId in this.shortcuts) ||
      !isInArray(shortcutId, u.values(this.axisItem.modifiersId)))
      return

    let itemId = this.getShortcutLocId(shortcutId, false)
    let itemObj = this.scene.findObject($"sc_{itemId}")

    if (itemObj?.isValid()) {
      let data = getShortcutData(this.shortcuts, shortcutId)
      this.guiScene.replaceContentFromText(itemObj, data, data.len(), this)
    }
  }

  function onShortcutChange(shortcutId) {
    this.updateShortcut(shortcutId)
    u.appendOnce(shortcutId, this.changedShortcuts)
  }

  function onButtonReset() {
    let item = this.getCurItem()
    if (!item)
      return

    this.shortcuts[item.shortcutId].clear()
    this.onShortcutChange(item.shortcutId)
  }

  function doApplyJoystick() {
    if (this.curJoyParams != null)
      this.doApplyJoystickImpl(shortcutsAxisListModule.types, this.curJoyParams.getAxis(this.setupAxisMode))
  }

  function onApply() {
    if (!this.checkZoomOnMWheel())
      this.doAxisApply()
  }

  function afterModalDestroy() {
    broadcastEvent("ControlsChangedShortcuts", { changedShortcuts = this.changedShortcuts })
    broadcastEvent("ControlsChangedAxes", { changedAxes = this.changedAxes })
  }

  function goBack() {
    this.onApply()
  }

  function setShortcutsParams(params) {
    this.curJoyParams = params.curJoyParams
    this.shortcuts = params.shortcuts
    this.shortcutItems = params.shortcutItems
    let axisId = this.axisItem.id
    this.axisItem = ::shortcutsList.findvalue(@(s) s.id == axisId) ?? this.axisItem
    this.reinitScreen()
  }
}
