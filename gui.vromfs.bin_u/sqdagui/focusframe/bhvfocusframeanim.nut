#explicit-this
#no-root-fallback

let { check_obj } = require("%sqDagui/daguiUtil.nut")
let { abs } = require("math")
let focusTarget = require("%sqDagui/focusFrame/bhvFocusFrameTarget.nut")

//uses the first child to play anim.
//set self position and size according to target
//if animation function not set
//it set state _blink=yes to child object to start anim (so it should be tuned self as you need)

local registerFunc = null      //registerFunc(obj)
local unregisterFunc = null    //unregisterFunc(obj)
local animFunc = null         //animFunc(animObj, curTargetObjData, prevTargetObjData), where objData = { obj, size, pos }
local hideTgtImageTimeMsec = 0

let minDiffForAnimPx = 10

const SWITCH_OFF_TIME = 10000000

let PROPID_TIMER_TIMENOW = ::dagui_propid.add_name_id("timer-timenow")
::dagui_propid.add_name_id("focusImageSource")
::dagui_propid.add_name_id("focusAnimColor")

let imageParamsList = ["image", "position", "repeat", "svg-size", "rotation"]


let function gatherObjData(targetObj) {
  return {
    obj = targetObj
    size = targetObj.getSize()
    pos = targetObj.getPosRC()
  }
}

let function setDelay(obj, timeMsec) {
  obj.setIntProp(PROPID_TIMER_TIMENOW, 0)
  obj.timer_interval_msec = timeMsec.tostring()
}


let function restoreTargetImage(obj) {
  let curData = obj.getUserData()
  if (check_obj(curData?.obj))
    focusTarget.unhideImage(curData.obj)
}

let function needAnim(curTgt, prevTgt) {
  if (!prevTgt)
    return true

  foreach (propName in ["size", "pos"])
    foreach (axis, value in curTgt[propName])
      if (abs(prevTgt[propName][axis] - value) > minDiffForAnimPx)
        return true
  return false
}


let function play(obj, targetObj) {
  if (obj.childrenCount() < 1)
    return

  let animObj = obj.getChild(0)
  if (!check_obj(animObj) || !check_obj(targetObj))
    return

  let prevData = obj.getUserData()
  let curData = gatherObjData(targetObj)
  if (!needAnim(curData, prevData)) {
    if (check_obj(curData?.obj))
      focusTarget.unhideImage(curData.obj)
    return
  }

  obj.setUserData(curData)

  //set image visual from target
  let focusImageSource = targetObj.getFinalProp("focusImageSource")
  let imagePrefixList = {
    ["background-"] = focusImageSource != "foreground",
    ["foreground-"] = focusImageSource != "background"
  }

  animObj["re-type"] = targetObj.getFinalProp("re-type") ?? "9rect"
  foreach (prefix, isUsed in imagePrefixList) {
    animObj[$"{prefix}color"] = isUsed ? (targetObj.getFinalProp("focusAnimColor") ?? "") : ""
    foreach (key in imageParamsList) {
      let fullKey = $"{prefix}{key}"
      animObj[fullKey] = isUsed ? targetObj.getFinalProp(fullKey) ?? "" : ""
    }
  }

  if (hideTgtImageTimeMsec > 0)
    setDelay(obj, hideTgtImageTimeMsec)

  //set position and size
  obj.position = "root"
  obj.left = curData.pos[0]
  obj.top = curData.pos[1]
  obj.width = curData.size[0]
  obj.height = curData.size[1]

  //start anim
  if (animFunc)
    animFunc(animObj, curData, prevData)
  animObj._blink = "yes"
}


let class bhvFocusFrameAnim {
  eventMask = EV_TIMER

  function onAttach(obj) {
    setDelay(obj, SWITCH_OFF_TIME)
    if (registerFunc)
      registerFunc(obj)
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    if (unregisterFunc)
      unregisterFunc(obj)
    return RETCODE_NOTHING
  }

  function onTimer(obj, _dt) {
    setDelay(obj, SWITCH_OFF_TIME)
    restoreTargetImage(obj)
  }
}

::replace_script_gui_behaviour("focusFrameAnim", bhvFocusFrameAnim)

let function setRegisterFunctions(registerFunction, unregisterFunction) {
  registerFunc = registerFunction
  unregisterFunc = unregisterFunction
}

let function setHideTgtImageTimeMsec(timeMsec) {
  hideTgtImageTimeMsec = timeMsec
  focusTarget.setShouldHideImage(hideTgtImageTimeMsec > 0)
}

return {
   play
   setRegisterFunctions
   setAnimFunction = @(animFunction)  animFunc = animFunction
   setHideTgtImageTimeMsec
}